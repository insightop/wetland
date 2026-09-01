import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/src/utils/wetland_scope.dart';

void main() {
  testWidgets('WetlandScope exposes secondaryKeys to descendants',
      (tester) async {
    final keys = [
      GlobalKey<NavigatorState>(),
      GlobalKey<NavigatorState>(),
    ];
    List<GlobalKey<NavigatorState>>? found;
    await tester.pumpWidget(
      WetlandScope(
        secondaryKeys: keys,
        child: Builder(
          builder: (context) {
            found = WetlandScope.of(context).secondaryKeys;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, same(keys));
  });

  testWidgets('maybeOf returns null when no WetlandScope ancestor',
      (tester) async {
    GlobalKey<NavigatorState>? found;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          found = WetlandScope.maybeOf(context)?.secondaryKeys.first;
          return const SizedBox();
        },
      ),
    );
    expect(found, isNull);
  });
}
