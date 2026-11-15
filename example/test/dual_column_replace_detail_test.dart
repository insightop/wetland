import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wetland_example/main.dart';

/// 双栏下「点另一个条目」必须是**替换**当前详情，而不是无反应或叠加。
///
/// 回归背景：example 的详情曾不带条目标识，条目 0 与条目 1 打开的内容完全一样，
/// 替换在视觉上等同于「点击没反应」；现在列表头像显示序号、详情 AppBar 显示
/// `#序号`，既能肉眼区分，也用栈深度锁住语义（替换=2，下钻=3）。
void main() {
  testWidgets('双栏：点击其它条目替换当前详情，详情内下钻仍为 push', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 列表头像显示序号（条目 0）。
    expect(find.text('0'), findsOneWidget);

    // 条目 0 打开详情：AppBar 显示序号。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages #0'), findsOneWidget);

    final router = AutoRouter.of(tester.element(find.text('Messages Detail ')));
    expect(router.stack.length, 2, reason: '外壳页 + 1 层详情');

    // 点条目 1：替换，不叠加。
    await tester.tap(find.text('Messages 1'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages #1'), findsOneWidget);
    expect(find.text('Messages #0'), findsNothing);
    expect(router.stack.length, 2, reason: '点其它条目是替换，不应压栈');

    // 详情内下钻：叠加一层，序号跟随同一条目。
    await tester.tap(find.text('drill-down'));
    await tester.pumpAndSettle();
    expect(find.text('Messages > Messages #1'), findsOneWidget);
    expect(router.stack.length, 3, reason: '下钻是 push，应叠加');

    // 再点列表里的条目 2：整条详情链被替换，只剩新详情。
    await tester.tap(find.text('Messages 2'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages #2'), findsOneWidget);
    expect(find.text('Messages > Messages #1'), findsNothing);
    expect(router.stack.length, 2, reason: '替换应清掉下钻层');
  });
}
