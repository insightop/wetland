import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 测试辅助：widget 宽度为 0 时它仍在 widget 树中（只是不可见），
/// 因此判断「可见性」要看实际宽度，而不是 finder 是否命中。
double _widthOf(WidgetTester tester, Finder finder) =>
    finder.evaluate().isEmpty ? -1 : tester.getSize(finder.first).width;

bool _isVisible(WidgetTester tester, Finder finder) =>
    _widthOf(tester, finder) > 1.0;

void main() {
  testWidgets('原生方案：横屏进详情后缩窄，详情全程连续可见', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_isVisible(tester, find.text('Messages Detail ')), isTrue);

    tester.view.physicalSize = const Size(390, 844);
    // 整个过渡期逐帧断言：详情必须始终可见（不允许出现 primary 独占的中间态）
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isVisible(tester, find.text('Messages Detail ')), isTrue,
          reason: '过渡第 ${i * 100}ms 详情不应消失');
    }
    await tester.pumpAndSettle();
    // 单栏：详情占满，列表页宽度收为 0
    expect(_isVisible(tester, find.text('Messages Detail ')), isTrue);
    expect(_isVisible(tester, find.text('Messages 0')), isFalse);
  });

  testWidgets('原生方案：竖屏详情时变宽，双栏应连续出现', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_isVisible(tester, find.text('Messages Detail ')), isTrue);

    tester.view.physicalSize = const Size(1200, 1000);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_isVisible(tester, find.text('Messages Detail ')), isTrue,
          reason: '过渡第 ${i * 100}ms 详情不应消失');
    }
    await tester.pumpAndSettle();
    // 双栏：详情 + 左侧 tab + 中间列表页同时可见
    expect(_isVisible(tester, find.text('Messages Detail ')), isTrue);
    expect(_isVisible(tester, find.text('Messages 0')), isTrue);
    expect(_isVisible(tester, find.text('Message')), isTrue);
  });

  testWidgets('原生方案：单栏返回后应回到列表页（详情栈空则显示 primary）',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_isVisible(tester, find.text('Messages Detail ')), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_isVisible(tester, find.text('Messages Detail ')), isFalse);
    expect(_isVisible(tester, find.text('Messages 0')), isTrue);
  });
}
