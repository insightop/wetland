import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 单栏全屏详情内部的**下钻**与 **pop 归属**。
///
/// 契约（见 openspec 变更 `single-column-detail-fullscreen-route`）：
/// - 从详情内下钻应**叠加**（而不是替换），因此 pop 一次回到上一层详情；
/// - pop 只移除详情，**不得**弹出 destination 本身；
/// - 详情全程由根 navigator 承载（全屏、遮住底部导航），且根栈不被多余层级污染。
double _width(WidgetTester tester, String text) {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty) return -1;
  return tester.getSize(finder.first).width;
}

void main() {
  testWidgets('单栏下钻叠层，pop 依次回退且不弹出 destination', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final root = AutoRouter.of(tester.element(find.text('Messages 0'))).root;
    final rootStackBefore = root.stack.map((e) => e.routeData.name).toList();

    final bottomNav = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == 'BottomNavigation',
    );

    // 进入第一层详情（单栏 ⇒ 根 navigator 全屏）。
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(_width(tester, 'Messages Detail '), greaterThan(1.0));
    expect(bottomNav.hitTestable().evaluate().length, 0,
        reason: '单栏详情应遮住底部导航');

    // 下钻一层：应叠加（标题变为 "Messages > Messages"）。
    await tester.tap(find.text('drill-down'));
    await tester.pumpAndSettle();
    final l2 = find.textContaining('Messages > Messages');
    expect(l2.evaluate(), isNotEmpty, reason: '下钻应叠加上一层详情');
    expect(bottomNav.hitTestable().evaluate().length, 0,
        reason: '下钻后的详情仍应全屏');
    // 根栈不应因详情而被追加层级（迁移/推入走显式 RouteData）。
    expect(root.stack.map((e) => e.routeData.name).toList(), rootStackBefore,
        reason: '详情不应污染根栈');

    // pop 一次 ⇒ 回到上一层详情（而非 destination 根）。
    // 用 `.last`：详情叠加时两层的 "pop-detail" 都在树上，而 overlay 中**后**
    // 加入的条目绘制在上层，因此最后一个才是当前可见、真正可点的那个。
    // （`.first` 是被压在下层的按钮，点击会被上层路由吸收。）
    await tester.tap(find.text('pop-detail').last);
    await tester.pumpAndSettle();
    expect(l2.evaluate(), isEmpty, reason: 'pop 后应离开下钻层');
    expect(_width(tester, 'Messages Detail '), greaterThan(1.0),
        reason: 'pop 一次应回到上一层详情');

    // 再 pop 一次 ⇒ 回到 destination 根（列表页 + 底部导航恢复）。
    // 用 `.last`：详情叠加时两层的 "pop-detail" 都在树上，而 overlay 中**后**
    // 加入的条目绘制在上层，因此最后一个才是当前可见、真正可点的那个。
    // （`.first` 是被压在下层的按钮，点击会被上层路由吸收。）
    await tester.tap(find.text('pop-detail').last);
    await tester.pumpAndSettle();
    expect(_width(tester, 'Messages Detail '), lessThanOrEqualTo(0),
        reason: '详情应已全部弹出');
    expect(_width(tester, 'Messages 0'), greaterThan(1.0),
        reason: '应回到列表页');
    expect(bottomNav.hitTestable().evaluate().length, 1,
        reason: '底部导航应恢复');
    expect(root.stack.map((e) => e.routeData.name).toList(), rootStackBefore,
        reason: 'destination 本身不应被弹出或改变');
  });
}
