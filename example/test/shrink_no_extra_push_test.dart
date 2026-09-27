import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏空态缩窄到竖屏，根栈不应多压一层', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final root = AutoRouter.of(tester.element(find.text('Messages 0'))).root;
    final before = root.stack.length;

    // 缩窄（不选任何详情）
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(root.stack.length, before,
        reason: '空态缩窄不应迁移任何路由到根栈');
    // tab 列表页仍可见
    expect(find.text('Messages 0'), findsOneWidget);
  });
}
