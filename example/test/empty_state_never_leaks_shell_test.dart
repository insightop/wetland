import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 问题1回归测试：右侧详情栈为空时，**任何一帧**都不应露出外壳页（logo）。
///
/// wetland 约定 secondary 的子路由集合首项是一条 `path: ''` 的外壳路由
/// （example 里是 `PlaceholderPage`，内容是一张 logo 图）。它的唯一职责是让
/// nested `Navigator` 存在，**不应被用户看到**；空态必须由
/// `Wetland.secondaryPlaceholder` 覆盖。
///
/// 实测过的 bug：pop 详情后第 0 帧，Navigator 已移除详情页、router 栈已回到
/// 纯外壳，但覆盖层要等下一帧才重建 → 该帧露出 logo 且没有 placeholder。
///
/// 判定用「覆盖层是否存在」而非「logo 是否不可见」：覆盖层缺席就是缺陷，
/// 即使 logo 恰好被其它层挡住。
void main() {
  /// 外壳页的 logo 图片（`PlaceholderPage` 内容）。
  final logo = find.byType(Image);

  /// 用户定制的空态占位。
  final placeholder = find.text('Select an item to see details');

  testWidgets('问题1：pop 详情后的每一帧都不应露出外壳页', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    expect(placeholder, findsOneWidget);

    // 进详情：外壳页被详情盖住，此时不该有 placeholder。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(placeholder, findsNothing);

    // 点 pop-detail 后逐帧检查：只要外壳页在树上，覆盖层就必须在。
    await tester.tap(find.text('pop-detail'));
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final shellVisible = logo.evaluate().isNotEmpty;
      final covered = placeholder.evaluate().isNotEmpty;
      expect(
        !shellVisible || covered,
        isTrue,
        reason: 'pop 后第 $frame 帧：外壳页可见（logo）但没有 placeholder 覆盖',
      );
    }
    await tester.pumpAndSettle();
    expect(placeholder, findsOneWidget);
  });

  testWidgets('问题1：旋转经过的每一帧都不应露出外壳页', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 横 → 竖 → 横 逐帧扫描（无详情：全程都应显示 placeholder）
    tester.view.physicalSize = const Size(390, 844);
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final shellVisible = logo.evaluate().isNotEmpty;
      final covered = placeholder.evaluate().isNotEmpty;
      expect(
        !shellVisible || covered,
        isTrue,
        reason: '缩小第 $frame 帧：外壳页可见但没有 placeholder 覆盖',
      );
    }
    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 40; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final shellVisible = logo.evaluate().isNotEmpty;
      final covered = placeholder.evaluate().isNotEmpty;
      expect(
        !shellVisible || covered,
        isTrue,
        reason: '放大第 $frame 帧：外壳页可见但没有 placeholder 覆盖',
      );
    }
  });
}
