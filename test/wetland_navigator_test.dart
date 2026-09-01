import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/wetland.dart';

/// 一个最小的 RootStackRouter，用于在测试中提供 auto_route 的 route 上下文。
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
            AutoRoute(
              path: 'detail',
              page: PageInfo(
                'Detail',
                builder: (data) => const _DetailPage(),
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
    return const Scaffold(body: _WetlandHarness());
  }
}

class _WetlandHarness extends StatelessWidget {
  const _WetlandHarness();

  @override
  Widget build(BuildContext context) {
    return Wetland(
      destinations: [
        TabDestination(
          label: 'A',
          icon: const Icon(Icons.chat),
          page: _TabBody(label: 'A'),
        ),
        TabDestination(
          label: 'B',
          icon: const Icon(Icons.group),
          page: _TabBody(label: 'B'),
        ),
      ],
    );
  }
}

/// 主 body 页面，点击按钮通过 context.wetland.push 进入详情。
class _TabBody extends StatelessWidget {
  final String label;
  const _TabBody({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => context.wetland.push(const _DetailRoute()),
          child: Text('$label push'),
        ),
      ),
    );
  }
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Detail Page')));
  }
}

class _DetailRoute extends PageRouteInfo<void> {
  const _DetailRoute() : super('Detail');
}

void main() {
  testWidgets('WetlandNavigator.push targets current tab secondary navigator',
      (tester) async {
    // 使用宽屏尺寸，确保 secondaryBody 槽位（mediumLargeAndUp）激活
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _TestRouter().config()),
    );
    await tester.pumpAndSettle();

    // 初始 tab 0：push 应进入 tab 0 的 secondary navigator
    await tester.tap(find.text('A push'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Page'), findsOneWidget);

    // 切到 tab 1
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    // tab 1 的 secondary navigator 是空的，不应显示 Detail Page
    expect(find.text('Detail Page'), findsNothing);

    // 在 tab 1 push，应进入 tab 1 的 secondary navigator
    await tester.tap(find.text('B push'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Page'), findsOneWidget);

    // 切回 tab 0，tab 0 的详情栈应保留
    await tester.tap(find.text('A'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Page'), findsOneWidget);
  });
}
