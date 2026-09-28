import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 逐帧宽度时间线：证明「单⇄双栏」过渡由 `AdaptiveLayout.bodyRatio` 连续插值驱动。
///
/// 本文件同时是**架构判别器**：它断言过渡结束时详情仍在 **secondary 槽**内
/// （`secondaryBody` 槽宽 > 0），而不是被迁移进 primary 根栈。旧补丁方案在
/// 「横→竖」终态下 secondary 槽被卸载（实测 `body=390, sec=0`）并把详情 push 到
/// primary 根栈，因此会在本测试失败 —— 这正是用户反馈的「明显的 push 动作」。
///
/// 可见性一律用**实际布局宽度**判断：宽度为 0 的 widget 仍在 widget 树上，
/// `find.text` 是否命中不能代表可见。
///
/// 双栏下 body 占剩余宽度的目标比例（与 `Wetland._targetBodyRatio` 一致）。
const double _dualBodyRatio = 0.35;

/// `LayoutId` 是 `CustomMultiChildLayout` 用来标识槽位的 widget，其 RenderBox
/// 尺寸即 delegate 分配给该槽的尺寸；因此这是「槽实际占宽」的真值。
double? _slotWidth(WidgetTester tester, String slotId) {  final finder = find.byWidgetPredicate(
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
  testWidgets('时间线：横→竖（有详情）详情全程留在 secondary 槽内', (tester) async {
    const landscape = Size(1200, 1000);
    const portrait = Size(390, 844);
    tester.view.physicalSize = landscape;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 起点：双栏，body 与 secondary 同时占宽。
    final bodyStart = _slotWidth(tester, 'body');
    final secondaryStart = _slotWidth(tester, 'secondaryBody');
    _logSample('横→竖', 0, tester, landscape.width.round());
    expect(bodyStart, isNotNull);
    expect(secondaryStart, isNotNull);
    expect(secondaryStart! > 1.0, isTrue, reason: '双栏下 secondary 应占宽');

    tester.view.physicalSize = portrait;
    for (var i = 1; i <= 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      final ms = i * 100;
      _logSample('横→竖', ms, tester, portrait.width.round());

      final body = _slotWidth(tester, 'body');
      final secondary = _slotWidth(tester, 'secondaryBody');

      // 连续性：过渡每一帧详情都必须可见，且 secondary 槽始终占宽。
      expect(_textVisible(tester, 'Messages Detail '), isTrue,
          reason: '第 ${ms}ms 详情不应消失');
      expect(secondary, isNotNull, reason: '第 ${ms}ms secondary 槽应存在');
      expect(secondary! > 1.0, isTrue,
          reason: '第 ${ms}ms secondary 槽不应为 0 宽（详情不在 primary 里）');

      // 不得出现「primary 独占、详情缺席」的中间态。
      final primaryExclusive =
          body != null && body >= portrait.width * 0.9 && secondary <= 1.0;
      expect(primaryExclusive, isFalse,
          reason: '第 ${ms}ms 不应出现 primary 独占的中间态 '
              '(body=$body, secondary=$secondary)');
    }

    await tester.pumpAndSettle();
    _logSample('横→竖', -1, tester, portrait.width.round());

    // 终态（架构判别器）：详情仍在 secondary 槽内并占满屏幕，body 收为 0。
    final bodyEnd = _slotWidth(tester, 'body');
    final secondaryEnd = _slotWidth(tester, 'secondaryBody');
    expect(bodyEnd, isNotNull);
    expect(bodyEnd! < 1.0, isTrue,
        reason: '单栏有详情时 body 应收为 0，实际 $bodyEnd');
    expect(secondaryEnd, isNotNull);
    expect(secondaryEnd! > portrait.width * 0.9, isTrue,
        reason: '单栏有详情时 secondary 应占满屏幕（证明详情未被迁移到 primary），'
            '实际 $secondaryEnd');
    expect(_textVisible(tester, 'Messages Detail '), isTrue);
    expect(_textVisible(tester, 'Messages 0'), isFalse);
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

    // 终态：真正的双栏 —— body、secondary、左侧 tab 同时可见。
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
  });

  testWidgets('时间线：单栏返回后详情移出 secondary，body 收回全屏', (tester) async {
    const portrait = Size(390, 844);
    tester.view.physicalSize = portrait;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_slotWidth(tester, 'secondaryBody')! > portrait.width * 0.9, isTrue);

    await tester.pageBack();
    await tester.pumpAndSettle();
    _logSample('单栏返回', -1, tester, portrait.width.round());

    final bodyEnd = _slotWidth(tester, 'body');
    final secondaryEnd = _slotWidth(tester, 'secondaryBody');
    expect(bodyEnd, isNotNull);
    expect(secondaryEnd, isNotNull);
    expect(bodyEnd! > portrait.width * 0.9, isTrue,
        reason: '返回后 body 应收回全屏，实际 $bodyEnd');
    expect(secondaryEnd! < 1.0, isTrue,
        reason: '返回后 secondary 应收为 0，实际 $secondaryEnd');
    expect(_textVisible(tester, 'Messages Detail '), isFalse);
    expect(_textVisible(tester, 'Messages 0'), isTrue);
  });

  testWidgets('bodyRatio 收敛：单栏有详情应为 0，双栏应为 0.35', (tester) async {
    // 直接验证「有/无 secondary」与 bodyRatio 的对应关系，防止回归到
    // 「靠迁移导航栈」的旧机制。
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

    // 单栏：body 占满。
    tester.view.physicalSize = portrait;
    await tester.pumpAndSettle();
    final bodySingle = _slotWidth(tester, 'body')!;
    expect(bodySingle > portrait.width * 0.9, isTrue,
        reason: '单栏无详情时 body 应占满，实际 $bodySingle');
  });
}
