import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏下详情页可逐层下钻并逐层返回', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 进入第一层详情
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);

    // 下钻到第二层
    await tester.tap(find.text('drill-down'));
    await tester.pumpAndSettle();
    expect(find.text('Messages > Messages Detail '), findsOneWidget);

    // back 回到第一层
    await tester.tap(find.text('pop-detail'));
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);
    expect(find.text('Messages > Messages Detail '), findsNothing);
  });
}
