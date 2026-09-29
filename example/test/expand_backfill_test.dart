import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 单栏⇄双栏切换时详情的连续性与最终归属（**新架构**）。
///
/// ## 架构要点
///
/// - 单栏：详情住在**根 navigator** 上，是铺满整屏的真实路由（覆盖底部导航）。
/// - 双栏：详情住在当前 tab 的 **secondary 槽**内，与列表并排。
/// - 模式切换时详情在两者之间**迁移一次**，全程连续可见。
///
/// ## 为什么断言「几何覆盖」而不是「宽度为 0」
///
/// 根级详情是**非不透明**路由 —— 这是刻意的：不透明根路由会停用 Wetland 子树的
/// ticker（`TickerMode` 由 true 变 false，已实测），使 `AdaptiveLayout` 的过渡
/// 永久冻结在中间几何。非不透明则下层列表仍在树上、仍有宽度，只是绘制被覆盖。
/// 因此「用户是否还能看到列表」要用几何覆盖判断。
///
/// 可见性一律用**实际布局宽度**判断：宽度为 0 的 widget 仍在 widget 树上。
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

/// 是否存在铺满视口的 Scaffold（详情由根 navigator 全屏承载的标志）。
bool _detailIsFullScreen(WidgetTester tester, Size viewport) {
  final scaffolds = find.byType(Scaffold, skipOffstage: false);
  for (var i = 0; i < scaffolds.evaluate().length; i++) {
    final r = tester.getRect(scaffolds.at(i));
    if (r.width >= viewport.width - 1 && r.height >= viewport.height - 1) {
      return true;
    }
  }
  return false;
}

void main() {
  testWidgets('竖屏全屏详情时变宽：详情回到 secondary 槽，双栏几何出现', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 竖屏进入详情：单栏，详情由根 navigator 全屏承载，body 占满、secondary 为 0。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_detailIsFullScreen(tester, const Size(390, 844)), isTrue,
        reason: '单栏详情应全屏（根 navigator）');
    expect(_slotWidth(tester, 'secondaryBody')! < 1.0, isTrue,
        reason: '单栏下详情不在 secondary 槽内');

    // 变宽到横屏：详情迁移回 secondary，双栏几何出现。
    const landscape = Size(1200, 1000);
    tester.view.physicalSize = landscape;
    await tester.pumpAndSettle();

    // 关键：详情已离开根 navigator，回到 secondary 槽（迁移方向正确）。
    final body = _slotWidth(tester, 'body');
    final secondary = _slotWidth(tester, 'secondaryBody');
    expect(body, isNotNull);
    expect(secondary, isNotNull);
    expect(body! > 1.0, isTrue, reason: '双栏下 body 应占宽，实际 $body');
    expect(secondary! > 1.0, isTrue,
        reason: '双栏下 secondary 应占宽（详情已回填），实际 $secondary');
    expect(_detailIsFullScreen(tester, landscape), isFalse,
        reason: '双栏下详情不应再全屏（应在 secondary 槽内）');

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
    // 逐帧推进：详情在任一帧都必须可见（迁移中可能两份副本短暂共存，
    // 因此检查「至少一份副本有真实布局宽度」）。
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final copies = find.text('Messages Detail ', skipOffstage: false);
      var rendered = false;
      for (var j = 0; j < copies.evaluate().length; j++) {
        if (tester.getSize(copies.at(j)).width > 1.0) rendered = true;
      }
      expect(rendered, isTrue, reason: '第 $i 帧详情不应消失');
    }
    await tester.pumpAndSettle();

    // 终态：详情回到 secondary 槽，不再是全屏根路由。
    expect(_slotWidth(tester, 'body')! > 1.0, isTrue);
    expect(_slotWidth(tester, 'secondaryBody')! > 1.0, isTrue,
        reason: '变宽后详情应在 secondary 槽内');
    expect(_detailIsFullScreen(tester, const Size(1200, 1000)), isFalse,
        reason: '变宽后详情不应仍是全屏根路由');
    expect(_width(tester, find.text('Messages Detail ')), greaterThan(1.0));
  });
}
