import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 空态应为「secondary 自己的外壳页」（example 里是 `PlaceholderPage` 的 logo），
/// 而不是任何后加的覆盖文案。
///
/// 历史问题：曾用 `Wetland.secondaryPlaceholder` 在空态时叠一层覆盖层遮住外壳页。
/// 副作用是 —— push 详情时覆盖层被**立即**移除，而详情路由还在过渡中，
/// 于是外壳页（logo）在过渡期间暴露出来，表现为「logo 一闪而过」；
/// 稳定态反而看不到 logo。需求是相反的：空态显示 logo，有内容显示详情。
void main() {
  /// 外壳页的内容（example 的 `PlaceholderPage` 是一张 logo 图）。
  final logo = find.byType(Image);

  /// 曾经用于覆盖外壳页的引导文案，现在不应存在。
  final legacyHint = find.text('Select an item to see details');

  testWidgets('空态应显示外壳页（logo），且没有覆盖文案', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    expect(logo, findsOneWidget, reason: '空态应显示外壳页（logo）');
    expect(legacyHint, findsNothing, reason: '不应再有覆盖文案');
  });

  testWidgets('进详情后应显示详情、不显示外壳页 logo', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Messages Detail '), findsOneWidget);
    expect(logo, findsNothing, reason: '详情应盖住外壳页');
  });

  testWidgets('push 详情全程：外壳页 logo 不应被用户看到', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 逐帧检查过渡：一旦详情开始出现，外壳页就不该同时可见。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final detailShown = find.text('Messages Detail ').evaluate().isNotEmpty;
      final logoShown = logo.evaluate().isNotEmpty;
      // 详情已入栈但还没绘制完成时允许 logo 在树（路由栈底），
      // 但稳定后不得再看到 logo。
      if (frame > 10) {
        expect(logoShown && !detailShown, isFalse,
            reason: '第 $frame 帧：详情缺席但外壳页可见');
      }
    }
    await tester.pumpAndSettle();
    expect(logo, findsNothing);
    expect(find.text('Messages Detail '), findsOneWidget);
  });
}
