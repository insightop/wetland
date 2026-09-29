import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// pop 单栏详情时，**任何一帧都不得露出空态页（logo）**，且最终露出的是列表页。
///
/// 这是用户原始反馈的核心（「退出时能看到空的 placeholder 页闪一下」）。
/// 单栏详情之所以不会露空态：它住在**根 navigator** 上，其下是整个 Wetland
/// （列表 + 底部导航），而不是 secondary 那条以空态页为栈底的嵌套栈。
/// 空态页（logo）是否**真的可见**。
///
/// 注意：每个 tab 的 secondary 嵌套 navigator 都常驻挂载，其中的空态页 logo
/// 一直存在于 widget 树上（未选中的处于 offstage）。因此不能用
/// `find.byType(Image)` 直接判断，必须确认它位于**可见**（非 offstage）位置。
bool _hasVisibleEmptyPlaceholder(WidgetTester tester) {
  // 默认 finder 跳过 offstage，因此命中的即为可见（或被 IndexedStack 激活）的。
  final images = find.byType(Image);
  for (var i = 0; i < images.evaluate().length; i++) {
    final size = tester.getSize(images.at(i));
    if (size.width > 1.0 && size.height > 1.0) return true;
  }
  return false;
}

double _width(WidgetTester tester, String text) {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) return -1;
  return tester.getSize(finder.first).width;
}

void main() {
  testWidgets('单栏 pop 详情全程不露空态页，最终露出列表页', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_width(tester, 'Messages Detail '), greaterThan(1.0));

    // 触发 pop，并逐帧观察过渡全程。
    await tester.pageBack();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_hasVisibleEmptyPlaceholder(tester), isFalse,
          reason: '第 ${i * 16}ms 不应露出空态页');
    }
    await tester.pumpAndSettle();

    // 终态：详情消失，露出列表页。
    expect(_width(tester, 'Messages Detail '), lessThanOrEqualTo(0));
    expect(_width(tester, 'Messages 0'), greaterThan(1.0),
        reason: 'pop 后应回到列表页而非空态页');
  });
}
