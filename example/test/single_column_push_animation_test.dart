import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 单栏 push/pop 必须有**真实的路由过渡动画**（不能是硬切换）。
///
/// ## 为什么需要这条测试
///
/// 单栏详情由根 navigator 承载，且为了不冻结 Wetland 子树的布局过渡，它的路由
/// 必须是**非不透明**的（不透明路由会让其下子树 offstage、停用 ticker）。
///
/// 但「非不透明」有个陷阱：auto_route 的 `CustomRouteType` 在
/// `transitionsBuilder` 为 null 时使用它的 `_defaultTransitionsBuilder`，而那个
/// 实现**原样返回 child** —— 等于没有动画。实测曾表现为详情从第一帧就在终点
/// 位置（用户感知为「硬切换」）。
///
/// 因此本测试断言：详情在过渡期间的位置**逐帧变化**，且覆盖多个中间值。
void main() {
  /// 详情标题在当前帧的位置（屏幕内左侧坐标）；不可见时返回 null。
  double? detailLeft(WidgetTester tester) {
    final finder = find.text('Messages Detail ', skipOffstage: false);
    for (var i = 0; i < finder.evaluate().length; i++) {
      final size = tester.getSize(finder.at(i));
      if (size.width > 1.0) return tester.getRect(finder.at(i)).left;
    }
    return null;
  }

  testWidgets('单栏 push 详情应有逐帧变化的路由过渡', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    // 不 pumpAndSettle：逐帧采样，观察详情是否在移动。
    final samples = <double>[];
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      final left = detailLeft(tester);
      if (left != null) samples.add(left);
    }
    await tester.pumpAndSettle();

    expect(samples.length, greaterThan(2), reason: '过渡期间详情应可见');
    // 硬切换时所有采样都相同（详情一开始就在终点）；真实过渡会有多个不同值。
    final distinct = samples.map((v) => v.toStringAsFixed(1)).toSet();
    expect(distinct.length, greaterThan(2),
        reason: '详情位置应逐帧变化（真实过渡），实际采样=$samples');
  });

  testWidgets('单栏 pop 详情应有逐帧变化的路由过渡', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    await tester.pageBack();
    final samples = <double>[];
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      final left = detailLeft(tester);
      if (left != null) samples.add(left);
    }
    await tester.pumpAndSettle();

    expect(samples.length, greaterThan(2), reason: 'pop 过渡期间详情应仍可见');
    final distinct = samples.map((v) => v.toStringAsFixed(1)).toSet();
    expect(distinct.length, greaterThan(2),
        reason: 'pop 时详情位置应逐帧变化（真实过渡），实际采样=$samples');
    expect(detailLeft(tester), isNull, reason: 'pop 完成后详情应消失');
  });

  testWidgets('横→竖切换布局应平滑过渡而非冻结在中间值', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 有详情时旋转：布局必须仍能完成过渡（曾因 ticker 被静音而永久冻结）。
    tester.view.physicalSize = const Size(390, 844);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    final body = find.byWidgetPredicate(
      (w) => w is LayoutId && w.id == 'body',
      skipOffstage: false,
    );
    expect(tester.getSize(body.first).width, greaterThan(389.0),
        reason: '最终应落位到单栏（body 占满 390），而非冻结在中间几何');
  });
}
