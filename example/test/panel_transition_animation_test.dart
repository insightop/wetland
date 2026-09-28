import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 问题2的两条验收：
/// 1. 单栏 ⇄ 双栏过渡**应有动画**（body/导航栏平滑移动），而不是瞬间跳变。
/// 2. 过渡中主导航栏与 body 之间**不应出现未填充的空隙**（黑条）。
void main() {
  /// 某个槽位的 `LayoutId`。
  Finder slot(String id) => find.byWidgetPredicate(
        (w) => w is LayoutId && w.id == id,
        skipOffstage: false,
      );

  /// 槽位的**绘制**矩形（含 `SlideTransition` 的位移变换）。
  ///
  /// `tester.getRect` 会套用 `localToGlobal`，因此已经包含
  /// `FractionalTranslation` 造成的位移；这里额外把该位移换算成实际像素，
  /// 以便算出「槽位已占的宽度」与「导航栏实际画到哪儿」之间的差。
  Rect paintedRect(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder.first);
    final slide = find.descendant(
      of: finder,
      matching: find.byType(FractionalTranslation),
      matchRoot: true,
    );
    if (slide.evaluate().isEmpty) return rect;
    final dx =
        (slide.evaluate().first.widget as FractionalTranslation).translation.dx;
    // getRect 已含位移，这里不再叠加，直接返回即可（保留该分支以便将来
    // 需要按比例换算时使用）。FractionalTranslation 的位移由 getRect 反映。
    assert(dx <= 1.0 && dx >= -1.0);
    return rect;
  }

  /// body 左边界与主导航栏绘制右边界之间的空隙（像素）。
  double railBodyGap(WidgetTester tester) {
    final nav = slot('primaryNavigation');
    if (nav.evaluate().isEmpty) return 0;
    final body = slot('body');
    if (body.evaluate().isEmpty) return 0;
    final navRect = paintedRect(tester, nav);
    final bodyLeft = tester.getRect(body.first).left;
    return bodyLeft - navRect.right;
  }

  testWidgets('问题2a：单栏→双栏过渡应有动画（body 左边界出现中间值）',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final samples = <double>[];
    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      samples.add(tester.getRect(slot('body').first).left);
    }

    final distinct = samples.map((v) => v.toStringAsFixed(1)).toSet();
    expect(
      distinct.length,
      greaterThan(2),
      reason: 'body 左边界应平滑插值，实测采样值只有 $distinct —— 说明是瞬间跳变',
    );
    expect(samples.last, greaterThan(50.0), reason: '终点应为双栏（body 让位）');
  });

  testWidgets('问题2a：双栏→单栏过渡应有动画（宽度出现中间值）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 双→单时框架是先让 body **变宽**（吸收导航栏让出的空间），
    // 因此采样宽度而非左边界。
    final samples = <double>[];
    tester.view.physicalSize = const Size(390, 844);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      samples.add(tester.getRect(slot('body').first).width);
    }

    final distinct = samples.map((v) => v.toStringAsFixed(1)).toSet();
    expect(
      distinct.length,
      greaterThan(2),
      reason: 'body 宽度应平滑插值，实测采样值只有 $distinct —— 说明是瞬间跳变',
    );
    expect(samples.last, greaterThan(samples.first),
        reason: '终点应更宽（导航栏让出的空间被 body 吸收）');
  });

  testWidgets('问题2b：单栏→双栏过渡中导航栏与 body 不留空隙', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 25));
      final gap = railBodyGap(tester);
      expect(
        gap,
        lessThan(1.0),
        reason: '第 ${frame * 25}ms：导航栏右侧到 body 之间有 '
            '${gap.toStringAsFixed(1)}px 空隙',
      );
    }
  });

  testWidgets('问题2b：双栏→单栏过渡中导航栏与 body 不留空隙', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 844);
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 25));
      final gap = railBodyGap(tester);
      expect(
        gap,
        lessThan(1.0),
        reason: '第 ${frame * 25}ms：导航栏右侧到 body 之间有 '
            '${gap.toStringAsFixed(1)}px 空隙',
      );
    }
  });

  testWidgets('问题2c：单栏→双栏时底部导航应淡出而非瞬间消失', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 淡出层由槽内 `AnimatedSwitcher` 在**切换期间**生成，稳定态不存在，
    // 因此只在过渡过程中采样。
    Finder bottomFade() => find.descendant(
          of: slot('bottomNavigation'),
          matching: find.byType(FadeTransition, skipOffstage: false),
        );

    final opacities = <double>[];
    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      if (bottomFade().evaluate().isEmpty) continue;
      opacities.add(
          tester.widget<FadeTransition>(bottomFade().first).opacity.value);
    }

    expect(opacities, isNotEmpty, reason: '过渡中应出现底部导航淡出层');
    final distinct = opacities.map((v) => v.toStringAsFixed(2)).toSet();
    expect(
      distinct.length,
      greaterThan(2),
      reason: '底部导航应淡出，实测不透明度采样只有 $distinct —— 说明是瞬间消失',
    );
    expect(opacities.first, greaterThan(0.5), reason: '淡出应从接近全可见开始');
    expect(opacities.last, lessThan(0.2), reason: '最终应基本透明');
  });
}
