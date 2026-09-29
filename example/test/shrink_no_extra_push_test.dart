import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 缩窄（双栏→单栏）时的导航语义（**新架构**）。
///
/// ## 与旧断言的区别
///
/// 旧架构下缩窄只是 `bodyRatio` 插值，详情始终留在 secondary 槽内，因此旧断言是
/// 「根栈恒等 + 详情仍在 secondary 槽 + 槽宽占满屏幕」。
///
/// 新架构下缩窄会**把详情迁移到根 navigator**，成为覆盖全屏（含底部导航）的真实
/// 路由。因此本文件的断言改为：
/// - 详情确实出现在根 navigator 上（`root.canPop()` 为真）；
/// - 详情铺满整屏并**遮住底部导航**；
/// - 根栈**不多压一层**（迁移走显式 `RouteData`，不追加 HomeRoute 之类的壳）。
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

/// 是否存在铺满视口的详情 Scaffold（即详情由根 navigator 全屏承载）。
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
  testWidgets('横屏空态缩窄到竖屏，根栈不应多压一层', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final root = AutoRouter.of(tester.element(find.text('Messages 0'))).root;
    final before = root.stack.length;

    // 缩窄（不选任何详情）
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(root.stack.length, before, reason: '空态缩窄不应迁移任何路由到根栈');
    // tab 列表页仍可见
    expect(_width(tester, find.text('Messages 0')), greaterThan(1.0));
  });

  testWidgets('横屏有详情缩窄到竖屏：详情迁到根 navigator 且全屏遮住底部导航',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 进入详情（双栏，详情在 secondary）。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final root = AutoRouter.of(tester.element(find.text('Messages 0'))).root;
    final before = root.stack.length;
    expect(_slotWidth(tester, 'secondaryBody')! > 1.0, isTrue,
        reason: '双栏下详情应在 secondary 槽内');

    const portrait = Size(390, 844);
    tester.view.physicalSize = portrait;
    await tester.pumpAndSettle();

    // 终态（新架构）：详情已成为根 navigator 上的全屏路由。
    expect(root.navigatorKey.currentState!.canPop(), isTrue,
        reason: '缩窄后详情应由根 navigator 承载（可 pop）');
    expect(root.stack.length, before,
        reason: '迁移应走显式 RouteData，不向根栈追加多余层级');
    expect(_detailIsFullScreen(tester, portrait), isTrue,
        reason: '单栏详情应铺满整屏');
    final bottomNav = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'BottomNavigation',
    );
    expect(bottomNav.hitTestable().evaluate().length, 0,
        reason: '全屏详情应遮住底部导航');
    expect(_width(tester, find.text('Messages Detail ')), greaterThan(1.0),
        reason: '详情应可见');
  });
}
