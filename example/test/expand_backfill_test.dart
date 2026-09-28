import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 变宽后的双栏断言（新架构）。
///
/// 旧方案里 secondary 槽只在宽屏挂载，缩窄时详情被迁移进 primary、变宽后再
/// 由 `_backfillPrimaryToSecondary` 回填 —— 本文件原先验证的就是那个「回填动作」。
/// 新架构下 secondary 槽**常驻挂载**，详情从未离开自己的 navigator，因此不存在
/// 回填：变宽只是 `bodyRatio` 从 0.0 插值回 0.35。这里改为验证**布局结果**
/// （双栏几何），不再验证已删除的迁移/回填机制。
///
/// 可见性用实际布局宽度判断（宽度为 0 的 widget 仍在树上）。
double _width(WidgetTester tester, Finder finder) =>
    finder.evaluate().isEmpty ? -1 : tester.getSize(finder.first).width;

double? _slotWidth(WidgetTester tester, String slotId) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is LayoutId && widget.id == slotId,
    skipOffstage: false,
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.getSize(finder.first).width;
}

void main() {
  testWidgets('竖屏全屏详情时变宽：应形成双栏，无需回填导航栈', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 竖屏进入详情：单栏，详情占满（body 收为 0），详情停在 secondary 槽内。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_slotWidth(tester, 'body'), lessThan(1.0));
    expect(_slotWidth(tester, 'secondaryBody'), greaterThan(390 * 0.9));
    expect(_width(tester, find.text('Messages Detail ')), greaterThan(1.0));

    // 变宽到横屏：bodyRatio 插值回 0.35，双栏几何出现。
    tester.view.physicalSize = const Size(1200, 1000);
    await tester.pumpAndSettle();

    // 关键：详情从未离开 secondary 槽（证明不存在「迁移 + 回填」这一对操作）。
    final body = _slotWidth(tester, 'body');
    final secondary = _slotWidth(tester, 'secondaryBody');
    expect(body, isNotNull);
    expect(secondary, isNotNull);
    expect(body! > 1.0, isTrue, reason: '双栏下 body 应占宽，实际 $body');
    expect(secondary! > 1.0, isTrue,
        reason: '双栏下 secondary 应占宽，实际 $secondary');

    // 双栏三个可视元素同时在场。
    expect(_width(tester, find.text('Messages Detail ')), greaterThan(1.0));
    expect(_width(tester, find.text('Message')), greaterThan(1.0)); // 左栏 tab
    expect(_width(tester, find.text('Messages 0')), greaterThan(1.0)); // 中间列表
  });

  testWidgets('竖屏全屏详情时变宽：详情在过渡全程不缺席', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1200, 1000);
    // 逐帧推进：详情在任一帧都必须可见，且始终留在 secondary 槽内。
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(_width(tester, find.text('Messages Detail ')), greaterThan(1.0),
          reason: '第 $i 帧详情不应消失');
      final secondary = _slotWidth(tester, 'secondaryBody');
      expect(secondary, isNotNull, reason: '第 $i 帧 secondary 槽应存在');
      expect(secondary! > 1.0, isTrue,
          reason: '第 $i 帧 secondary 槽不应为 0 宽，实际 $secondary');
    }
    await tester.pumpAndSettle();
    expect(_slotWidth(tester, 'body'), greaterThan(1.0));
    expect(_width(tester, find.text('Messages Detail ')), greaterThan(1.0));
  });
}
