import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('切换主tab后右侧详情栈保留', (tester) async {
    // 使用宽屏尺寸（宽>=840 且 高>=900）以触发三栏布局（mediumLargeAndUp）
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 在 Messages tab 进入详情
    await tester.tap(find.text('Messages 0'));
    await tester.pumpAndSettle();
    // DetailPage 渲染 '$title Detail '（带尾随空格）
    expect(find.text('Messages Detail '), findsOneWidget);

    // 切到 Contacts tab
    await tester.tap(find.text('Contact'));
    await tester.pumpAndSettle();

    // 切回 Messages tab，详情应保留
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);
  });
}
