import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/wetland.dart';
import 'package:wetland/src/utils/wetland_scope.dart';
import 'package:wetland/src/widgets/secondary_body.dart';

/// 一个最小的 RootStackRouter，用于在测试中提供 auto_route 的 route 上下文。
/// SecondaryBody 内部的 AutoRouter 需要 RouteData/RouterScope 祖先，
/// 因此 Wetland 必须被渲染在一个 AutoRoutePage 内。
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
          page: const SizedBox(),
        ),
        TabDestination(
          label: 'B',
          icon: const Icon(Icons.group),
          page: const SizedBox(),
        ),
      ],
    );
  }
}

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

  testWidgets('Wetland secondaryBody keeps all per-tab navigators mounted',
      (tester) async {
    // 使用宽屏尺寸，确保 secondaryBody 槽位（mediumLargeAndUp）激活
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: _TestRouter().config()),
    );
    await tester.pumpAndSettle();

    // 初始 tab 0：应挂载 2 个 per-tab navigator（IndexedStack 保持全部挂载，
    // 未选中的处于 offstage，需 skipOffstage: false 才能找到）
    expect(find.byType(SecondaryBody, skipOffstage: false), findsNWidgets(2));
    // 切到 tab 1
    await tester.tap(find.text('B'));
    await tester.pumpAndSettle();
    // 切 tab 后所有 per-tab navigator 仍应挂载（IndexedStack 特性）
    expect(find.byType(SecondaryBody, skipOffstage: false), findsNWidgets(2));
  });
}
