import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 缩窄后根栈不应被污染（新架构）。
///
/// 旧方案在缩窄时执行 `_migrateSecondaryToPrimary`，把 secondary 的详情迁移进
/// primary 根栈（并曾因把外壳页也迁过去而多压一层，即任务描述里的「又 push 一遍
/// primary」）。新架构下不再有任何迁移：详情始终留在自己的 nested navigator，
/// 根栈在旋转前后**恒等**。本文件因此断言根栈不变，而不是验证已删除的迁移机制。
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

  testWidgets('横屏有详情缩窄到竖屏，根栈恒等而详情仍在 secondary', (tester) async {
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

    // 缩窄到竖屏：终态为「详情占满 screen」，但实现上必须仍是同一个
    // secondary 槽在占满，而不是把详情迁移进根栈。
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(root.stack.length, before,
        reason: '缩窄不应把 secondary 详情迁移进根栈（不应多压一层）');
    expect(_slotWidth(tester, 'body'), lessThan(1.0),
        reason: '单栏有详情时 body 应收为 0');
    expect(_slotWidth(tester, 'secondaryBody'), greaterThan(390 * 0.9),
        reason: '详情应仍由 secondary 槽占满（未迁移到 primary）');
    expect(_width(tester, find.text('Messages Detail ')), greaterThan(1.0));
  });
}
