import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 过渡的**对称性**与**末端收敛**验收。
///
/// 这两条都源于框架 `AdaptiveLayout.updateSize` 的行为：槽位尺寸只在动画
/// **结束**时才刷新基准值，因此 margin 的补间是 `Tween(旧尺寸, 新尺寸)`。
/// 若出场动画不改变槽位的**布局尺寸**（`SlideTransition` / `FadeTransition`
/// 都只改绘制），子尺寸全程不变、补间退化成常量 —— 于是：
/// - 导航栏：body 左偏移一直卡在 74，动画结束才一次性跳回 0（末端突跳）；
/// - 底部导航：槽位位置不移动，看起来只有淡出、没有滑出。
/// 修法是让出场动画真正改变布局尺寸（宽度/高度收缩）。
void main() {
  Finder slot(String id) => find.byWidgetPredicate(
        (w) => w is LayoutId && w.id == id,
        skipOffstage: false,
      );

  testWidgets('双栏→单栏：导航栏应逐帧收窄（而非保持满宽后突跳）', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final widths = <double>[];
    tester.view.physicalSize = const Size(390, 844);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      final nav = slot('primaryNavigation');
      widths.add(nav.evaluate().isEmpty ? 0 : tester.getSize(nav.first).width);
    }

    // 应出现多个中间宽度 —— 证明导航栏在布局上真的逐帧收窄。
    final distinct = widths.map((v) => v.toStringAsFixed(1)).toSet();
    expect(
      distinct.length,
      greaterThan(2),
      reason: '导航栏应逐帧收窄，实测宽度只有 $distinct —— 说明保持满宽后突跳',
    );
    expect(widths.first, greaterThan(50.0), reason: '起点应为双栏满宽');
    expect(widths.last, lessThan(5.0), reason: '终点应收窄到 0');
  });

  testWidgets('单栏→双栏：底部导航应向下收起（高度收缩而非原地淡出）',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final tops = <double>[];
    final heights = <double>[];
    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      final rect = tester.getRect(slot('bottomNavigation').first);
      tops.add(rect.top);
      heights.add(rect.height);
    }

    // 高度应逐帧变小（向下收起），且槽位上边界随之下移。
    final distinctHeights =
        heights.map((v) => v.toStringAsFixed(1)).toSet();
    expect(
      distinctHeights.length,
      greaterThan(2),
      reason: '底部导航应逐帧变矮，实测高度只有 $distinctHeights —— 说明是原地淡出',
    );
    expect(heights.first, greaterThan(heights.last),
        reason: '应从满高收起到 0（实测首 ${heights.first} 末 ${heights.last}）');
    expect(tops.last, greaterThan(tops.first),
        reason: '槽位上边界应下移（向下收起）');
  });
}
