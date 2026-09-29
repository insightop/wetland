import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 逐帧宽度时间线（**新架构判别器**）。
///
/// ## 本文件断言什么
///
/// 新架构下，单栏详情是**根 navigator 上的真实全屏路由**，而不再是「secondary 槽
/// 被 bodyRatio 撑满」。因此两个模式的判别特征完全不同：
///
/// | 模式 | body 槽 | secondary 槽 | 详情位置 |
/// |---|---|---|---|
/// | 单栏（有详情） | 占满全宽 | **0 宽** | 根 navigator（全屏） |
/// | 双栏（有详情） | ≈0.35×剩余 | ≈0.65×剩余 | secondary 槽内 |
///
/// 旧实现的特征（单栏 body=0、secondary 占满）在本文件会失败 —— 这正是用户反馈的
/// 「进详情像缩放而非 push」的来源。
///
/// 可见性一律用**实际布局宽度**判断：宽度为 0 的 widget 仍在 widget 树上，
/// `find.text` 是否命中不能代表可见。
///
/// 双栏下 body 占剩余宽度的目标比例（与 `Wetland._targetBodyRatio` 一致）。
const double _dualBodyRatio = 0.35;

/// `LayoutId` 是 `CustomMultiChildLayout` 用来标识槽位的 widget，其 RenderBox
/// 尺寸即 delegate 分配给该槽的尺寸；因此这是「槽实际占宽」的真值。
double? _slotWidth(WidgetTester tester, String slotId) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is LayoutId && widget.id == slotId,
    skipOffstage: false,
  );
  if (finder.evaluate().isEmpty) return null;
  return tester.getSize(finder.first).width;
}

/// 文本是否占据可见宽度（>1 像素）。
bool _textVisible(WidgetTester tester, String text) {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) return false;
  return tester.getSize(finder.first).width > 1.0;
}

/// 详情是否**在画面中**（至少一份副本具备真实布局宽度）。
///
/// 迁移的中间帧里，详情可能同时存在于两个宿主（源侧尚未移除、目标侧已入场），
/// 此时「onstage」的判定会短暂落在两份之间，但画面始终有详情。因此这里检查
/// 所有副本（含 offstage）中是否至少有一份被真正布局过 —— 这才是用户可见性
/// 的真实含义；「详情最终在哪个宿主」由终态断言负责。
bool _detailRendered(WidgetTester tester) {
  final finder = find.text('Messages Detail ', skipOffstage: false);
  for (var i = 0; i < finder.evaluate().length; i++) {
    if (tester.getSize(finder.at(i)).width > 1.0) return true;
  }
  return false;
}

/// 详情是否由根 navigator 承载（全屏铺满当前视口）。
///
/// 这是新架构的**核心判别器**：单栏详情必须铺满整屏（含底部导航所在区域），
/// 而不是只占 secondary 槽那么宽。
bool _detailIsFullScreen(WidgetTester tester, Size viewport) {
  final scaffolds = find.byType(Scaffold, skipOffstage: false);
  final count = scaffolds.evaluate().length;
  for (var i = 0; i < count; i++) {
    final r = tester.getRect(scaffolds.at(i));
    if (r.width >= viewport.width - 1 && r.height >= viewport.height - 1) {
      return true;
    }
  }
  return false;
}

/// 文本是否被某个铺满视口的详情层遮住。
///
/// 详情是非不透明路由（为了让 Wetland 子树 ticker 保持启用），因此下层列表仍在
/// 树上、仍有宽度，只是绘制上被详情覆盖。判断「用户是否还能看到列表」要看几何
/// 覆盖，而非宽度是否为 0。
bool _isCoveredByFullScreenLayer(WidgetTester tester, Size viewport) {
  final text = find.text('Messages 0');
  if (text.evaluate().isEmpty) return true;
  final textRect = tester.getRect(text.first);
  final scaffolds = find.byType(Scaffold, skipOffstage: false);
  for (var i = 0; i < scaffolds.evaluate().length; i++) {
    final r = tester.getRect(scaffolds.at(i));
    if (r.width >= viewport.width - 1 &&
        r.height >= viewport.height - 1 &&
        r.overlaps(textRect) &&
        r.contains(textRect.center)) {
      return true;
    }
  }
  return false;
}

void _logSample(String label, int ms, WidgetTester tester, int viewportWidth) {
  final body = _slotWidth(tester, 'body');
  final secondary = _slotWidth(tester, 'secondaryBody');
  debugPrint(
    'TL $label t=${ms}ms '
    'body=${body?.toStringAsFixed(1) ?? 'null'} '
    'secondary=${secondary?.toStringAsFixed(1) ?? 'null'} '
    'viewport=$viewportWidth',
  );
}

void main() {
  testWidgets('时间线：横→竖（有详情）详情全程可见且终态为全屏根路由', (tester) async {
    const landscape = Size(1200, 1000);
    const portrait = Size(390, 844);
    tester.view.physicalSize = landscape;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 起点：双栏，body 与 secondary 同时占宽，详情在 secondary 槽内。
    final bodyStart = _slotWidth(tester, 'body');
    final secondaryStart = _slotWidth(tester, 'secondaryBody');
    _logSample('横→竖', 0, tester, landscape.width.round());
    expect(bodyStart, isNotNull);
    expect(secondaryStart, isNotNull);
    expect(secondaryStart! > 1.0, isTrue, reason: '双栏下 secondary 应占宽');
    expect(_detailIsFullScreen(tester, landscape), isFalse,
        reason: '双栏下详情不应铺满整屏（它在 secondary 槽内）');

    tester.view.physicalSize = portrait;
    for (var i = 1; i <= 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final ms = i * 100;
      _logSample('横→竖', ms, tester, portrait.width.round());

      // 连续性：过渡每一帧详情都必须在画面中（迁移中可能两份副本短暂共存）。
      expect(_detailRendered(tester), isTrue,
          reason: '第 ${ms}ms 详情不应消失');
    }

    await tester.pumpAndSettle();
    _logSample('横→竖', -1, tester, portrait.width.round());

    // 终态（新架构判别器）：详情是根 navigator 上的全屏路由；
    // 单栏 bodyRatio=1.0 ⇒ body 占满、secondary 槽为 0 宽。
    final bodyEnd = _slotWidth(tester, 'body');
    final secondaryEnd = _slotWidth(tester, 'secondaryBody');
    expect(bodyEnd, isNotNull);
    expect(bodyEnd! > portrait.width * 0.9, isTrue,
        reason: '单栏 body 应占满全宽，实际 $bodyEnd');
    expect(secondaryEnd, isNotNull);
    expect(secondaryEnd! < 1.0, isTrue,
        reason: '单栏 secondary 槽应收为 0（详情不在槽内），实际 $secondaryEnd');
    expect(_detailIsFullScreen(tester, portrait), isTrue,
        reason: '单栏详情应由根 navigator 全屏承载');
    expect(_textVisible(tester, 'Messages Detail '), isTrue);
    expect(_isCoveredByFullScreenLayer(tester, portrait), isTrue,
        reason: '全屏详情应遮住列表页');
  });

  testWidgets('时间线：竖→横（有详情）双栏连续展开', (tester) async {
    const portrait = Size(390, 844);
    const landscape = Size(1200, 1000);
    tester.view.physicalSize = portrait;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    _logSample('竖→横', 0, tester, portrait.width.round());
    expect(_detailIsFullScreen(tester, portrait), isTrue,
        reason: '单栏详情应从根 navigator 全屏开始');

    tester.view.physicalSize = landscape;
    for (var i = 1; i <= 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final ms = i * 100;
      _logSample('竖→横', ms, tester, landscape.width.round());

      expect(_textVisible(tester, 'Messages Detail '), isTrue,
          reason: '第 ${ms}ms 详情不应消失');
    }

    await tester.pumpAndSettle();
    _logSample('竖→横', -1, tester, landscape.width.round());

    // 终态：真正的双栏 —— body、secondary、左侧 tab 同时可见，
    // 详情已由 secondary 槽承载（不再全屏）。
    final bodyEnd = _slotWidth(tester, 'body');
    final secondaryEnd = _slotWidth(tester, 'secondaryBody');
    expect(bodyEnd, isNotNull);
    expect(secondaryEnd, isNotNull);
    expect(bodyEnd! > 1.0, isTrue, reason: '双栏下 body 应占宽，实际 $bodyEnd');
    expect(secondaryEnd! > 1.0, isTrue,
        reason: '双栏下 secondary 应占宽，实际 $secondaryEnd');
    expect(_textVisible(tester, 'Messages Detail '), isTrue);
    expect(_textVisible(tester, 'Messages 0'), isTrue);
    expect(_textVisible(tester, 'Message'), isTrue);
    expect(_detailIsFullScreen(tester, landscape), isFalse,
        reason: '双栏下详情应回到 secondary 槽，不再全屏');
  });

  testWidgets('时间线：单栏返回后详情消失，body 维持全屏', (tester) async {
    const portrait = Size(390, 844);
    tester.view.physicalSize = portrait;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_detailIsFullScreen(tester, portrait), isTrue,
        reason: '单栏详情应全屏');

    await tester.pageBack();
    await tester.pumpAndSettle();
    _logSample('单栏返回', -1, tester, portrait.width.round());

    // 返回后：详情消失，列表页可见；body 始终占满（单栏本就是 1.0）。
    final bodyEnd = _slotWidth(tester, 'body');
    expect(bodyEnd, isNotNull);
    expect(bodyEnd! > portrait.width * 0.9, isTrue,
        reason: '单栏 body 应占满，实际 $bodyEnd');
    expect(_textVisible(tester, 'Messages Detail '), isFalse,
        reason: '返回后详情应消失');
    expect(_textVisible(tester, 'Messages 0'), isTrue,
        reason: '返回后应回到列表页');
  });

  testWidgets('bodyRatio 收敛：单栏应为 1.0，双栏应为 0.35', (tester) async {
    const portrait = Size(390, 844);
    const landscape = Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = landscape;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 双栏：body ≈ 0.35 × (屏宽 - 左侧导航)。
    final nav = _slotWidth(tester, 'primaryNavigation')!;
    final body = _slotWidth(tester, 'body')!;
    final secondary = _slotWidth(tester, 'secondaryBody')!;
    final remaining = landscape.width - nav;
    expect((body / remaining - _dualBodyRatio).abs() < 0.01, isTrue,
        reason: '双栏 body 占比应≈$_dualBodyRatio，实际 ${body / remaining}');
    expect((body + secondary - remaining).abs() < 1.0, isTrue,
        reason: '双栏下 body + secondary 应恰好铺满剩余宽度');

    // 单栏：body 占满（不再随「有无详情」变化）。
    tester.view.physicalSize = portrait;
    await tester.pumpAndSettle();
    final bodySingle = _slotWidth(tester, 'body')!;
    expect(bodySingle > portrait.width * 0.9, isTrue,
        reason: '单栏 body 应占满，实际 $bodySingle');
    final secondarySingle = _slotWidth(tester, 'secondaryBody')!;
    expect(secondarySingle < 1.0, isTrue,
        reason: '单栏 secondary 槽应为 0，实际 $secondarySingle');
  });
}
