import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

/// 问题2b：过渡期间不应出现「未上色」的黑色区域。
///
/// 根因：`AdaptiveLayout` 只在槽位内部绘制内容，槽位之间（如导航栏与 body
/// 之间在过渡中瞬时错开的缝隙）**不绘制任何背景**，露出的区域是纯黑
/// （实测像素 `(0,0,0)`），表现为「一闪而过的黑色竖条」。
///
/// 判据：整屏扫描**纯黑**像素（亮度 < 10）。
///
/// 为什么不是「所有深色像素」：正常 UI 内容（图标/文字）在实测中最暗到 29，
/// 而未上色区域是精确的 (0,0,0)。因此用亮度 < 10 即可精确区分
/// 「框架没画背景」与「正常的深色图标文字」。
const int _unpaintedLuminance = 10;
void main() {
  /// 统计未上色（纯黑）像素占比。
  Future<double> darkRatio(WidgetTester tester, GlobalKey key) async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    var ratio = 0.0;
    await tester.runAsync(() async {
      final img = await boundary.toImage();
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      final w = img.width, h = img.height;
      final bytes = bd!.buffer.asUint8List();
      var dark = 0, total = 0;
      for (var y = 0; y < h; y += 3) {
        for (var x = 0; x < w; x += 3) {
          total++;
          final o = (y * w + x) * 4;
          final lum = (bytes[o] + bytes[o + 1] + bytes[o + 2]) / 3;
          if (lum < _unpaintedLuminance) dark++;
        }
      }
      ratio = total == 0 ? 0 : dark / total;
    });
    return ratio;
  }

  testWidgets('单栏→双栏过渡不应出现黑色未上色区域', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: key, child: const WetlandExampleApp()));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(1200, 1000);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      final ratio = await darkRatio(tester, key);
      expect(
        ratio,
        lessThan(0.005),
        reason: '第 ${frame * 33}ms：未上色像素占比 '
            '${(ratio * 100).toStringAsFixed(2)}% —— 存在纯黑未上色区域',
      );
    }
  });

  testWidgets('双栏→单栏过渡不应出现黑色未上色区域', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(
        RepaintBoundary(key: key, child: const WetlandExampleApp()));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 844);
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 33));
      final ratio = await darkRatio(tester, key);
      expect(
        ratio,
        lessThan(0.005),
        reason: '第 ${frame * 33}ms：未上色像素占比 '
            '${(ratio * 100).toStringAsFixed(2)}% —— 存在纯黑未上色区域',
      );
    }
  });
}
