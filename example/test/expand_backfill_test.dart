import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('竖屏全屏详情时变宽，应自动回填 secondary 双栏', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 竖屏进入详情（全屏，secondary 未挂载）。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);

    // 变宽到横屏：应自动回填 secondary 双栏。
    tester.view.physicalSize = const Size(1200, 1000);
    await tester.pumpAndSettle();

    // 右侧详情仍在 + 左侧 tab 导航出现 + 中间列表页出现（双栏，而非全屏详情）。
    expect(find.text('Messages Detail '), findsOneWidget);
    expect(find.text('Message'), findsOneWidget); // 左栏 tab
    expect(find.text('Messages 0'), findsOneWidget); // 中间列表页
  });

  testWidgets('竖屏全屏详情时变宽：不出现详情缺席的中间帧', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1200, 1000);
    // 逐帧推进：过渡期旧的全屏布局与新双栏布局会共存（AnimatedSwitcher），
    // 但详情在任一帧都不应缺席（先 push 后移除，不存在空白空窗）。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Messages Detail '), findsWidgets,
          reason: '第 $i 帧详情不应消失');
    }
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);
    expect(find.text('Messages 0'), findsOneWidget);
  });
}
