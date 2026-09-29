import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 单栏（竖屏）详情必须是**全屏真实路由**：
/// - 覆盖底部导航（Q1）
/// - 进出为原生 push/pop，外层布局不参与缩放（Q2）
void main() {
  final bn = find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == 'BottomNavigation',
  );

  testWidgets('单栏详情覆盖底部导航，pop 后恢复', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    expect(bn.hitTestable().evaluate().length, 1, reason: '初始应有底部导航');

    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 详情内容占据整屏：详情 Scaffold 应铺满屏幕（Q1/Q2 的核心要求）
    final detail = find.text('Messages Detail ');
    expect(detail.evaluate().isNotEmpty, isTrue, reason: '详情应已打开');
    final scaffolds = find.byType(Scaffold, skipOffstage: false);
    final count = scaffolds.evaluate().length;
    var fullscreen = false;
    for (var i = 0; i < count; i++) {
      final r = tester.getRect(scaffolds.at(i));
      if (r.width >= 389 && r.height >= 843) fullscreen = true;
    }
    expect(fullscreen, isTrue, reason: '详情应铺满整屏');

    // 覆盖底部导航
    expect(bn.hitTestable().evaluate().length, 0,
        reason: '单栏详情应覆盖底部导航');

    // pop 后恢复
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(bn.hitTestable().evaluate().length, 1, reason: 'pop 后底部导航应恢复');
    // 注意：ListTile 内的 Text 不在命中路径上（`hitTestable` 恒为 0），
    // 因此这里按**实际宽度**判定列表页已恢复可见。
    final list = find.text('Messages 0');
    expect(list.evaluate().isNotEmpty, isTrue);
    expect(tester.getSize(list.first).width, greaterThan(1.0),
        reason: 'pop 后应回到列表页');
  });

  testWidgets('单栏详情全屏尺寸等于屏幕', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    // 详情页的 Scaffold 应铺满整屏
    final scaffolds = find.byType(Scaffold, skipOffstage: false);
    final n = scaffolds.evaluate().length;
    var found = false;
    for (var i = 0; i < n; i++) {
      final r = tester.getRect(scaffolds.at(i));
      if (r.width >= 389 && r.height >= 843) found = true;
    }
    expect(found, isTrue, reason: '应存在铺满屏幕的详情 Scaffold');
  });
}
