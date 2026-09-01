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

/// Stateful 外壳，可在运行时动态增删 destinations，用于测试 shrink clamp。
class _WetlandHarness extends StatefulWidget {
  const _WetlandHarness();

  @override
  State<_WetlandHarness> createState() => _WetlandHarnessState();
}

class _WetlandHarnessState extends State<_WetlandHarness> {
  bool _shrink = false;

  void shrink() => setState(() => _shrink = true);

  @override
  Widget build(BuildContext context) {
    final all = [
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
    ];
    return Stack(
      children: [
        Positioned.fill(
          child: Wetland(
            destinations: _shrink ? all.sublist(0, 1) : all,
          ),
        ),
        if (!_shrink)
          Positioned(
            top: 0,
            right: 0,
            child: TextButton(
              onPressed: shrink,
              child: const Text('shrink-destinations'),
            ),
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
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Detail Page'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.wetland.pop(),
              child: const Text('pop-detail'),
            ),
          ],
        ),
      ),
    );
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

  testWidgets('WetlandNavigator.pop targets current tab secondary navigator',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: _TestRouter().config(),
      ),
    );
    await tester.pumpAndSettle();

    // tab 0 push 进入详情
    await tester.tap(find.text('A push'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Page'), findsOneWidget);

    // pop 详情，应从当前 tab 的 secondary navigator 弹出
    await tester.tap(find.text('pop-detail'));
    await tester.pumpAndSettle();
    expect(find.text('Detail Page'), findsNothing);
  });

  testWidgets('Wetland shrink destinations clamps index without crash',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _TestRouter().config()),
    );
    await tester.pumpAndSettle();

    // 切到 tab 1（index 1），再 shrink 掉 B
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('shrink-destinations'));
    await tester.pumpAndSettle();

    // 仅剩 1 个 destination，不会崩溃；body 显示 tab A 内容
    expect(find.text('A push'), findsOneWidget);
    expect(find.text('B push'), findsNothing);
  });
}
