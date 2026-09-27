import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏有详情缩窄：不出现 primary 占满的中间态', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 844);
    // 只 pump 一帧，检查是否出现"列表页可见但详情不可见"的中间态
    await tester.pump();
    final listVisible = find.text('Messages 0').evaluate().isNotEmpty;
    final detailVisible = find.text('Messages Detail ').evaluate().isNotEmpty;
    expect(listVisible && !detailVisible, isFalse,
        reason: '不应出现 primary 占满而详情未就位的中间态');

    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);
  });
}
