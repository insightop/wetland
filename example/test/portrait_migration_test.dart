import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横转竖后当前 tab 的详情栈应迁移到竖屏全屏栈顶部，可 back 回 tab 页',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 横屏进入 Messages 详情（secondaryBody 挂载）
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);

    // 旋转为竖屏
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    // 期望详情仍在根栈顶部显示
    expect(find.text('Messages Detail '), findsOneWidget);

    // 返回应回到 tab 页（列表）
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsNothing);
    expect(find.text('Messages 0'), findsOneWidget);
  });
}
