import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 问题2回归测试：单栏 → 双栏过渡中，导航栏与 body 之间不应出现空隙。
///
/// 实测到的 bug：`AdaptiveLayout` 会把 `primaryNavigation` 槽**立即**布局到
/// `[0, railWidth]`，并让 `body` 立即从 `railWidth` 开始；但导航栏自身用的是
/// `AdaptiveScaffold.leftOutIn`（`SlideTransition`，`Offset(-1,0) → Offset.zero`），
/// 即整条导航栏从屏幕左外侧滑入。于是过渡前半段那条已让出的宽度在视觉上还是
/// 空的（露出底色），看起来像「一条黑色竖条逐渐被填充」。
///
/// 判定方式：取 `primaryNavigation` 槽的布局宽度与导航栏实际的
/// `FractionalTranslation` 位移，算出**未被导航栏覆盖的宽度**（视觉空隙）。
void main() {
  /// 导航栏槽（`LayoutId('primaryNavigation')`）。
  final railSlot = find.byWidgetPredicate(
    (w) => w is LayoutId && w.id == 'primaryNavigation',
    skipOffstage: false,
  );

  /// 导航栏的位移动画（`SlideTransition` 内部就是 `FractionalTranslation`）。
  final railSlide = find.descendant(
    of: railSlot,
    matching: find.byType(FractionalTranslation),
    matchRoot: true,
  );

  /// 导航栏与 body 之间的视觉空隙（像素）。
  ///
  /// `FractionalTranslation` 的 `dx` 是相对自身宽度的比例，故实际位移为
  /// `slotWidth * dx`；导航栏绘制范围为 `[slotWidth*dx, slotWidth*(1+dx)]`，
  /// 而 `body` 从 `slotWidth` 开始，因此空隙为 `slotWidth * (-dx)`。
  double railGap(WidgetTester tester) {
    if (railSlot.evaluate().isEmpty) return 0;
    final width = tester.getSize(railSlot.first).width;
    if (railSlide.evaluate().isEmpty) return 0;
    final slide = railSlide.evaluate().first.widget as FractionalTranslation;
    final dx = slide.translation.dx;
    if (dx >= 0) return 0;
    return width * -dx;
  }

  testWidgets('问题2：单栏→双栏过渡中导航栏不应留下未填充的空隙', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 变宽触发单栏→双栏。
    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      final gap = railGap(tester);
      expect(
        gap,
        lessThan(1.0),
        reason: '第 ${frame * 50}ms：导航栏与 body 之间有 ${gap.toStringAsFixed(1)}px '
            '未填充空隙',
      );
    }
  });

  testWidgets('问题2：双栏→单栏过渡中导航栏不应留下未填充的空隙', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 缩窄触发双栏→单栏。
    tester.view.physicalSize = const Size(390, 844);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      final gap = railGap(tester);
      expect(
        gap,
        lessThan(1.0),
        reason: '第 ${frame * 50}ms：导航栏与 body 之间有 ${gap.toStringAsFixed(1)}px '
            '未填充空隙',
      );
    }
  });
}
