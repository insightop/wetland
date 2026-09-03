import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('竖屏点击消息列表项进入详情页而不是另一个列表页', (tester) async {
    // 竖屏尺寸（宽 < 600），只激活 bottomNavigation（single 模式），
    // secondaryBody 不挂载，导航走 primary 全屏栈。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 默认 tab 0（Messages），点击列表第一项
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 期望进入详情页（而非另一个列表页）
    expect(find.text('Messages Detail '), findsOneWidget);

    // 返回列表页
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsNothing);
    expect(find.text('Messages 0'), findsOneWidget);
  });

  testWidgets('竖屏在消息/联系人/发现三个 tab 都应进入详情页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // Messages
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 切到 Contacts tab（底部导航）
    await tester.tap(find.text('Contact'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Contacts 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Contacts Detail '), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 切到 Discover tab（ListPage）
    await tester.tap(find.text('Discover'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discover 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Discover Detail '), findsOneWidget);
  });
}
