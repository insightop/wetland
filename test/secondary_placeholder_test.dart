import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/wetland.dart';

/// 最小 router，提供 auto_route 上下文（与 wetland_navigator_test 同构）。
class _TestRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: PageInfo(
            'Home',
            builder: (data) => const _HomePage(),
          ),
          initial: true,
          children: [
            AutoRoute(
              path: '',
              page: PageInfo(
                'Placeholder',
                builder: (data) => const SizedBox(),
              ),
            ),
          ],
        ),
      ];
}

class _HomePage extends StatelessWidget {
  const _HomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Wetland(
        destinations: [
          TabDestination(
            label: 'A',
            icon: const Icon(Icons.chat),
            page: const SizedBox(),
          ),
        ],
        secondaryPlaceholder: (_) => const Center(child: Text('NO_DETAIL')),
      ),
    );
  }
}

void main() {
  testWidgets('传 secondaryPlaceholder 时 secondary 空栈显示该占位',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _TestRouter().config()),
    );
    await tester.pumpAndSettle();

    expect(find.text('NO_DETAIL'), findsOneWidget);
  });
}
