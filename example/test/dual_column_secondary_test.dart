import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 双栏下详情必须位于 **secondary 槽**，并与主内容并排（新架构下的双栏回归保护）。
///
/// 单栏改为根 navigator 全屏路由后，必须确保双栏行为**未被波及**：
/// - 详情在右侧槽内（不是全屏覆盖）；
/// - 中间主内容同时渲染，且详情**不是**根 navigator 上的路由；
/// - 左侧主导航可点（详情层没有吸收它的指针事件）。
double? _slotWidth(WidgetTester tester, String slotId) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is LayoutId && widget.id == slotId,
    skipOffstage: false,
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.getSize(finder.first).width;
}

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
  testWidgets('双栏：详情在 secondary 槽内并排展示，主内容与主导航同时可用',
      (tester) async {
    const landscape = Size(1200, 1000);
    tester.view.physicalSize = landscape;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final root = AutoRouter.of(tester.element(find.text('Messages 0'))).root;
    final rootStackBefore = root.stack.map((e) => e.routeData.name).toList();

    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 详情在 secondary 槽内，body 与 secondary 同时占宽。
    final body = _slotWidth(tester, 'body');
    final secondary = _slotWidth(tester, 'secondaryBody');
    expect(body, isNotNull);
    expect(secondary, isNotNull);
    expect(body! > 1.0, isTrue, reason: '双栏下 body 应占宽，实际 $body');
    expect(secondary! > 1.0, isTrue, reason: '双栏下 secondary 应占宽，实际 $secondary');
    expect(_detailIsFullScreen(tester, landscape), isFalse,
        reason: '双栏下详情不应全屏（应在右侧槽内）');

    // 详情**不应**进入根 navigator（那是单栏的宿主）。
    expect(root.stack.map((e) => e.routeData.name).toList(), rootStackBefore,
        reason: '双栏详情不应进根栈');
    expect(root.navigatorKey.currentState!.canPop(), isFalse,
        reason: '双栏下根 navigator 不应有可 pop 的详情');

    // 三栏元素同时在场，且主导航可点（未被详情层吸收指针）。
    expect(find.text('Messages Detail ').evaluate(), isNotEmpty);
    expect(find.text('Messages 0').evaluate(), isNotEmpty);
    final rail = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'PrimaryNavigation',
    );
    expect(rail.hitTestable().evaluate().length, 1,
        reason: '左侧主导航应可点');
    expect(find.text('Contact').hitTestable().evaluate(), isNotEmpty,
        reason: '左侧 tab 应可点');
  });
}
