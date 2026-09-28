import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 问题2的两条验收：
/// 1. 单栏 ⇄ 双栏过渡**应有动画**（body/导航栏平滑移动），而不是瞬间跳变。
/// 2. 过渡中主导航栏与 body 之间**不应出现未填充的空隙**（黑条）。
void main() {
  /// 某个槽位的 `LayoutId`。
  Finder slot(String id) => find.byWidgetPredicate(
        (w) => w is LayoutId && w.id == id,
        skipOffstage: false,
      );

  testWidgets('问题2a：单栏→双栏过渡应有动画（body 左边界出现中间值）',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final samples = <double>[];
    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      samples.add(tester.getRect(slot('body').first).left);
    }

    final distinct = samples.map((v) => v.toStringAsFixed(1)).toSet();
    expect(
      distinct.length,
      greaterThan(2),
      reason: 'body 左边界应平滑插值，实测采样值只有 $distinct —— 说明是瞬间跳变',
    );
    expect(samples.last, greaterThan(50.0), reason: '终点应为双栏（body 让位）');
  });

  testWidgets('问题2a：双栏→单栏过渡应有动画（宽度出现中间值）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 双→单时框架是先让 body **变宽**（吸收导航栏让出的空间），
    // 因此采样宽度而非左边界。
    final samples = <double>[];
    tester.view.physicalSize = const Size(390, 844);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      samples.add(tester.getRect(slot('body').first).width);
    }

    final distinct = samples.map((v) => v.toStringAsFixed(1)).toSet();
    expect(
      distinct.length,
      greaterThan(2),
      reason: 'body 宽度应平滑插值，实测采样值只有 $distinct —— 说明是瞬间跳变',
    );
    expect(samples.last, greaterThan(samples.first),
        reason: '终点应更宽（导航栏让出的空间被 body 吸收）');
  });

  testWidgets('问题2b：双栏→单栏时 body 左边界应平滑收敛（末端不突跳）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 记录「过渡期」与「结束后」两段。此前的 bug：过渡期 body 左边界一直是
    // 74.1（那条导航栏宽度被一直占着），直到过渡结束才一次性跳到 0 ——
    // 表现为「动画到位后空隙被突然填满」。
    final during = <double>[];
    tester.view.physicalSize = const Size(390, 844);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      during.add(tester.getRect(slot('body').first).left);
    }
    await tester.pumpAndSettle();
    final settled = tester.getRect(slot('body').first).left;

    // 过渡期内就应出现明显小于起点的中间值（即真的在收敛），
    // 而不是全程停在起点等结束后突跳。
    expect(
      during.any((v) => v < 40.0),
      isTrue,
      reason: '过渡期内 body 左边界应已明显收敛，实测=${during.map((v) => v.toStringAsFixed(1)).toSet()}',
    );
    // 末端不应出现大步突跳：最后一次采样与稳定值的差应较小。
    expect(
      (during.last - settled).abs(),
      lessThan(40.0),
      reason: '末端突跳 ${(during.last - settled).abs().toStringAsFixed(1)}px '
          '（过渡末 ${during.last.toStringAsFixed(1)} → 稳定 ${settled.toStringAsFixed(1)}）',
    );
    expect(settled, lessThan(1.0), reason: '最终应收敛到 0（导航栏让出的空间被填满）');
  });
}
