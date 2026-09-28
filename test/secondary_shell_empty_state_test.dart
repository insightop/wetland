import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/wetland.dart';

/// 最小 router，提供 auto_route 上下文（与 wetland_navigator_test 同构）。
///
/// secondary 的空态由**外壳页自身**承担：约定子路由集合首项是一条
/// `path: ''` 的路由，它既让嵌套 `Navigator` 存在，也是空态画面。
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
                'Shell',
                builder: (data) => const Center(child: Text('SHELL_EMPTY_STATE')),
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
      ),
    );
  }
}

void main() {
  testWidgets('空态时 secondary 显示自己的外壳页（无需额外占位 API）',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _TestRouter().config()),
    );
    await tester.pumpAndSettle();

    expect(find.text('SHELL_EMPTY_STATE'), findsOneWidget);
  });
}
