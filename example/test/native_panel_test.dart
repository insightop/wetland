import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 单栏⇄双栏过渡期间详情始终连续可见（**新架构**）。
///
/// ## 与旧断言的区别
///
/// 旧架构下「进出详情」是 `bodyRatio` 在 1.0/0.0 之间插值，因此旧断言关心
/// 「secondary 槽是否占满」「body 是否收为 0」。新架构下这些都不再成立：
///
/// - 单栏有详情：详情在**根 navigator**（全屏），body 恒占满、secondary 槽恒为 0；
/// - 双栏有详情：详情在 secondary 槽内，body≈0.35、secondary≈0.65；
/// - 模式切换：详情在两个宿主之间迁移一次，全程连续可见。
///
/// 因此本文件改为断言**连续性 + 终态归属**，并且用几何覆盖判断「是否被全屏详情
/// 遮住」（详情是非不透明路由，下层仍在树上、仍有宽度）。
double _widthOf(WidgetTester tester, Finder finder) =>
    finder.evaluate().isEmpty ? -1 : tester.getSize(finder.first).width;

/// 「详情在画面中」：至少一份副本被真实布局过。
bool _detailRendered(WidgetTester tester) {
  final copies = find.text('Messages Detail ', skipOffstage: false);
  for (var i = 0; i < copies.evaluate().length; i++) {
    if (tester.getSize(copies.at(i)).width > 1.0) return true;
  }
  return false;
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

double? _slotWidth(WidgetTester tester, String slotId) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is LayoutId && widget.id == slotId,
    skipOffstage: false,
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.getSize(finder.first).width;
}

void main() {
  testWidgets('横屏进详情后缩窄，详情全程连续可见并最终全屏', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_detailRendered(tester), isTrue);
    expect(_slotWidth(tester, 'secondaryBody')! > 1.0, isTrue,
        reason: '双栏下详情在 secondary 槽内');

    const portrait = Size(390, 844);
    tester.view.physicalSize = portrait;
    // 整个过渡期逐帧断言：详情必须始终可见（不允许出现 primary 独占的中间态）
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_detailRendered(tester), isTrue,
          reason: '过渡第 ${i * 100}ms 详情不应消失');
    }
    await tester.pumpAndSettle();

    // 单栏终态：详情由根 navigator 全屏承载，body 占满、secondary 槽为 0。
    expect(_detailIsFullScreen(tester, portrait), isTrue,
        reason: '单栏详情应全屏');
    expect(_slotWidth(tester, 'body')! > portrait.width * 0.9, isTrue,
        reason: '单栏 body 应占满');
    expect(_slotWidth(tester, 'secondaryBody')! < 1.0, isTrue,
        reason: '单栏 secondary 槽应为 0（详情已迁到根 navigator）');
    expect(_widthOf(tester, find.text('Messages Detail ')), greaterThan(1.0),
        reason: '详情应可见');
  });

  testWidgets('竖屏详情时变宽，双栏应连续出现', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_detailRendered(tester), isTrue);
    expect(_detailIsFullScreen(tester, const Size(390, 844)), isTrue,
        reason: '单栏详情应从根 navigator 全屏开始');

    const landscape = Size(1200, 1000);
    tester.view.physicalSize = landscape;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(_detailRendered(tester), isTrue,
          reason: '过渡第 ${i * 100}ms 详情不应消失');
    }
    await tester.pumpAndSettle();

    // 双栏终态：详情 + 左侧 tab + 中间列表页同时可见，详情回到槽内。
    expect(_detailRendered(tester), isTrue);
    expect(_widthOf(tester, find.text('Messages 0')), greaterThan(1.0));
    expect(_widthOf(tester, find.text('Message')), greaterThan(1.0));
    expect(_slotWidth(tester, 'secondaryBody')! > 1.0, isTrue,
        reason: '双栏下详情应回到 secondary 槽');
    expect(_detailIsFullScreen(tester, landscape), isFalse,
        reason: '双栏下详情不应全屏');
  });

  testWidgets('单栏返回后应回到列表页（详情已从根 navigator 弹出）', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_detailRendered(tester), isTrue);
    expect(_detailIsFullScreen(tester, const Size(390, 844)), isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(_detailRendered(tester), isFalse, reason: '返回后详情应消失');
    expect(_widthOf(tester, find.text('Messages 0')), greaterThan(1.0),
        reason: '返回后应回到列表页');
    // 底部导航应恢复可点（单栏无详情时它是可用的）
    final bottomNav = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'BottomNavigation',
    );
    expect(bottomNav.hitTestable().evaluate().length, 1,
        reason: '返回后底部导航应恢复');
  });
}
