import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 反复在单栏⇄双栏之间切换时，打开的详情**不得丢失**。
///
/// 每次切换都会在两个宿主之间迁移一次详情（单栏=根 navigator 全屏路由，
/// 双栏=当前 tab 的 secondary 槽）。迁移涉及「先 push 到目标、再从源移除」，
/// 若顺序或记账有误，反复切换就会把详情弄丢或堆叠重复副本。
///
/// 详情在两个宿主下的宽度不同（单栏≈294、双栏≈636），因此也用宽度确认它确实
/// 完成了迁移而非滞留在旧宿主。
double _detailWidth(WidgetTester tester) {
  final finder = find.text('Messages Detail ', skipOffstage: false);
  for (var i = 0; i < finder.evaluate().length; i++) {
    final width = tester.getSize(finder.at(i)).width;
    if (width > 1.0) return width;
  }
  return -1;
}

void main() {
  testWidgets('反复单⇄双切换 4 轮，详情始终保留且只存在一份', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    final portraitWidth = _detailWidth(tester);
    expect(portraitWidth, greaterThan(1.0), reason: '单栏详情应可见');

    for (var round = 0; round < 4; round++) {
      tester.view.physicalSize = const Size(1200, 1000);
      await tester.pumpAndSettle();
      final dualWidth = _detailWidth(tester);
      expect(dualWidth, greaterThan(portraitWidth),
          reason: '第 $round 轮双栏下详情应更宽（说明已回填到 secondary 槽）');
      expect(find.text('Messages Detail ').evaluate().length, 1,
          reason: '第 $round 轮双栏下只应有一份详情');

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(_detailWidth(tester), greaterThan(1.0),
          reason: '第 $round 轮回到单栏后详情不应丢失');
      expect(find.text('Messages Detail ').evaluate().length, 1,
          reason: '第 $round 轮单栏下只应有一份详情');
    }
  });
}
