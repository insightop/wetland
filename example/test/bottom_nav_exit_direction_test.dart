import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 底部导航的**退出方向**验收。
///
/// 用户要求：底部导航退场时应「退向屏幕底部」（内容向下移出），
/// 而不是被吸向槽位顶部。
///
/// 实现约束：槽位高度必须真正收缩（见 `_collapseHeight` 的文档），否则框架的
/// `bottomMargin` 补间退化为常量、body 不会收回。但 `Align` 的**对齐点**决定了
/// 收缩时内容往哪边走：
/// - `bottomCenter`（底对齐）：槽位从底部收缩，内容被「吸」向上方；
/// - `topCenter`（顶对齐）：槽位从顶部收缩，内容向下移出屏幕。
void main() {
  testWidgets('单栏→双栏：底部导航应向下移出（而非被吸向上方）', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 用底导航里第一个 tab 的文字作为「内容」的观测点。
    Finder label() => find.descendant(
          of: find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == 'BottomNavigation',
            skipOffstage: false,
          ),
          matching: find.text('Message'),
        );

    final tops = <double>[];
    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (label().evaluate().isEmpty) break;
      tops.add(tester.getRect(label().first).top);
    }

    expect(tops.length, greaterThan(3), reason: '应能观测到多帧底导内容');
    // 单调向下（允许极小抖动）：终点应明显大于起点。
    expect(
      tops.last,
      greaterThan(tops.first + 20.0),
      reason: '底导内容应向下移出屏幕，实测 '
          '${tops.first.toStringAsFixed(1)} → ${tops.last.toStringAsFixed(1)}',
    );
    // 且中途不应出现「先向上」的反向位移。
    for (var i = 1; i < tops.length; i++) {
      expect(
        tops[i],
        greaterThan(tops[i - 1] - 1.0),
        reason: '第 $i 帧出现向上回退：'
            '${tops[i - 1].toStringAsFixed(1)} → ${tops[i].toStringAsFixed(1)}',
      );
    }
  });
}
