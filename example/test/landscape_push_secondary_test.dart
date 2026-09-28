import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏空态下 push 详情仍进右侧 secondary（未被 primary 全屏覆盖）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 前置条件：空态时右侧显示外壳页（example 的 logo 占位页）
    expect(find.byType(Image), findsOneWidget);

    // 从中间列表点开详情
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 详情出现在右侧 secondary
    expect(find.text('Messages Detail '), findsOneWidget);
    // 且外壳页被详情盖住
    expect(find.byType(Image), findsNothing);
    // 关键：中间列表页与左侧主导航仍可见 —— 说明详情进的是右侧 secondary，
    // 而不是被误推进 primary 造成全屏覆盖（那会遮住列表与 tab 导航）。
    expect(find.text('Messages 0'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
  });
}
