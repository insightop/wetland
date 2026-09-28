import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  // 新架构下不再有导航栈迁移：横转竖只是 bodyRatio 从 0.35 插值到 0.0，
  // 详情始终留在同一个 secondary navigator 里。本用例验证该行为等价于旧
  // 「迁移」用例的用户可见结果：详情仍在、back 可回列表页。
  testWidgets('横转竖后详情仍占满屏幕且可 back 回列表页（无导航栈迁移）',
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
