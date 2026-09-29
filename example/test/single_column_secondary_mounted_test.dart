import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';
import 'package:wetland/src/widgets/secondary_body.dart';

/// 单栏下 secondary 的嵌套 navigator 必须**仍然挂载**。
///
/// 理由（库内部依赖）：`WetlandNavigator` 用
/// `navigatorKey.currentState != null` 判断「双栏的详情宿主是否可用」；同时
/// [RootDetailStack] 需要从这些嵌套 navigator 的 route collection 里**显式匹配**
/// 详情路由（因为按名 push 会被它们截获）。
///
/// 若单栏时把该子树替换为 `SizedBox.shrink()`，`currentState` 会变 null，
/// 详情匹配与双栏回填都会失效。因此这里断言它在单栏下依然挂载。
void main() {
  testWidgets('单栏下每个 tab 的 secondary navigator 仍挂载（详情匹配依赖它）',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // IndexedStack 保持全部挂载，未选中的处于 offstage。
    expect(find.byType(SecondaryBody, skipOffstage: false), findsNWidgets(4));

    // 单栏下进入详情（详情由根 navigator 全屏承载）。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail ').evaluate(), isNotEmpty);

    // 详情打开后，嵌套 navigator 仍须挂载（迁移回双栏时要往里 push）。
    expect(find.byType(SecondaryBody, skipOffstage: false), findsNWidgets(4));
  });
}
