import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏 pop 详情后右侧回到外壳页（不黑屏）', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 进入详情
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);

    // pop 详情
    await tester.tap(find.text('pop-detail'));
    await tester.pumpAndSettle();

    // 应回到外壳页（logo 图），而不是空栈导致的空白/黑屏
    expect(find.text('Messages Detail '), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });
}
