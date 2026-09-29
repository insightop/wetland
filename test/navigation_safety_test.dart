import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/wetland.dart';
import 'package:wetland/src/wetland.dart' as internal;
import 'package:wetland/src/utils/wetland_scope.dart';

/// 导航安全性回归测试（openspec: fix-adaptive-navigation-safety）。
///
/// 针对审计确认的缺陷，**先于修复编写**（TDD）；修复前这些测试应当失败。
/// 覆盖：pop 归属（D1）、canPop/maybePop（D2）、构造函数与单 destination（D3）、
/// push 返回值一致性（D4）、模式由布局推导（D5）。
///
/// 用最小 `RootStackRouter` 提供 auto_route 上下文；每个 destination 的嵌套集合
/// 首项是 `path: ''` 外壳页（库的硬性约定）。

const _portrait = Size(390, 844);
const _landscape = Size(1200, 1000);

// ---------------------------------------------------------------------------
// 共用脚手架
// ---------------------------------------------------------------------------

class _ShellPage extends StatelessWidget {
  const _ShellPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Shell Page')));
}

class _DetailPage extends StatelessWidget {
  const _DetailPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Detail Page')));
}

class _DetailRoute extends PageRouteInfo<void> {
  const _DetailRoute() : super('Detail');
}

/// destination 根页面：push / pop / maybePop 三个入口。
class _TabBody extends StatelessWidget {
  final String label;

  const _TabBody(this.label);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () => context.wetland.push(const _DetailRoute()),
              child: Text('$label push'),
            ),
            ElevatedButton(
              onPressed: () => context.wetland.pop(),
              child: Text('$label pop'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 可选 tab 数量的宿主（用于单 destination 验证）。
class _Harness extends StatefulWidget {
  const _Harness({this.tabCount = 2});
  final int tabCount;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) {
    return Wetland(
      destinations: [
        for (var i = 0; i < widget.tabCount; i++)
          TabDestination(
            label: 'Tab$i',
            icon: const Icon(Icons.circle),
            page: _TabBody('Tab$i'),
          ),
      ],
    );
  }
}

class _SafetyRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: PageInfo('Home', builder: (data) => const _Harness()),
          initial: true,
          children: [
            AutoRoute(
              path: '',
              page: PageInfo('Shell', builder: (data) => const _ShellPage()),
            ),
            AutoRoute(
              page: PageInfo('Detail', builder: (data) => const _DetailPage()),
            ),
          ],
        ),
      ];
}

/// 单 tab 宿主（验证 D3）。
class _SingleTabHarness extends StatelessWidget {
  const _SingleTabHarness();

  @override
  Widget build(BuildContext context) => const _Harness(tabCount: 1);
}

class _SingleTabRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: PageInfo('Home', builder: (data) => const _SingleTabHarness()),
          initial: true,
          children: [
            AutoRoute(
              path: '',
              page: PageInfo('Shell', builder: (data) => const _ShellPage()),
            ),
            AutoRoute(
              page: PageInfo('Detail', builder: (data) => const _DetailPage()),
            ),
          ],
        ),
      ];
}



/// 完全没有 `path: ''` 路由的配置（用于记录「嵌套 Navigator 不挂载」这一实测结论）。
class _NoEmptyPathRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: PageInfo('Home', builder: (data) => const _Harness()),
          initial: true,
          children: [
            AutoRoute(
              page: PageInfo('Detail', builder: (data) => const _DetailPage()),
            ),
          ],
        ),
      ];
}

/// 外壳页声明在**第二位**（验证 auto_route 的排序行为）。
class _ShellSecondRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: PageInfo('Home', builder: (data) => const _Harness()),
          initial: true,
          children: [
            AutoRoute(
              page: PageInfo('Detail', builder: (data) => const _DetailPage()),
            ),
            AutoRoute(
              path: '',
              page: PageInfo('Shell', builder: (data) => const _ShellPage()),
            ),
          ],
        ),
      ];
}

// ---------------------------------------------------------------------------
// D4 专用：携带 String 结果的路由
// ---------------------------------------------------------------------------

/// 保存最近一次 `push<String>` 的结果，供断言读取。
final _lastPushResult = ValueNotifier<String?>(null);

class _ResultBody extends StatelessWidget {
  const _ResultBody();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              final r = await context.wetland.push<String>(const _ResultRoute());
              _lastPushResult.value = r;
            },
            child: const Text('open'),
          ),
        ),
      );
}

class _ResultDetail extends StatelessWidget {
  const _ResultDetail();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Result Detail'),
              ElevatedButton(
                onPressed: () => context.wetland.pop<String>('RET'),
                child: const Text('close-with-result'),
              ),
            ],
          ),
        ),
      );
}

class _ResultRoute extends PageRouteInfo<String> {
  const _ResultRoute() : super('ResultDetail');
}

class _ResultHarness extends StatelessWidget {
  const _ResultHarness();

  @override
  Widget build(BuildContext context) => Wetland(
        destinations: [
          TabDestination(
            label: 'Tab0',
            icon: const Icon(Icons.circle),
            page: const _ResultBody(),
          ),
          TabDestination(
            label: 'Tab1',
            icon: const Icon(Icons.square),
            page: const _ResultBody(),
          ),
        ],
      );
}

class _ResultRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: PageInfo('Home', builder: (data) => const _ResultHarness()),
          initial: true,
          children: [
            AutoRoute(
              path: '',
              page: PageInfo('Shell', builder: (data) => const _ShellPage()),
            ),
            AutoRoute(
              page: PageInfo(
                'ResultDetail',
                builder: (data) => const _ResultDetail(),
              ),
            ),
          ],
        ),
      ];
}

// ---------------------------------------------------------------------------
// 辅助
// ---------------------------------------------------------------------------

Future<void> _mountRouter(
  WidgetTester tester,
  RootStackRouter router,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp.router(routerConfig: router.config()),
  );
  await tester.pumpAndSettle();
}

/// 当前是否还有 Wetland 子树存活。
int _wetlandCount() =>
    find.byType(Wetland, skipOffstage: false).evaluate().length;

/// 取当前（第一个）tab 的嵌套路由栈。
///
/// `WetlandScope` 由 `Wetland.build` **内部**注入，因此必须从**后代** context
/// 读取（`find.byType(Wetland)` 的元素位于 scope 之上，查不到它）。该 scope 未从
/// 公共入口导出（审计已记录此 API 缺口），故测试走内部路径，与既有
/// `test/wetland_scope_test.dart` 的做法一致。
List<AutoRoutePage> _nestedStackOf(WidgetTester tester) {
  final finder = find.text('Tab0 push');
  if (finder.evaluate().isEmpty) return const [];
  final scope = WetlandScope.maybeOf(tester.element(finder.first));
  final state = scope?.secondaryKeys.first.currentState;
  if (state == null) return const [];
  return AutoRouter.of(state.context).stack;
}

void main() {
  group('pop 归属（D1）', () {
    testWidgets('单栏无详情时 pop 不应弹掉整个 App', (tester) async {
      await _mountRouter(tester, _SafetyRouter(), _portrait);
      expect(_wetlandCount(), 1);

      await tester.tap(find.text('Tab0 pop'));
      await tester.pumpAndSettle();

      expect(_wetlandCount(), 1, reason: 'pop 不应把 Wetland 自己弹掉');
      expect(find.text('Tab0 push', skipOffstage: false), findsOneWidget,
          reason: 'destination 内容应仍在');
      expect(tester.takeException(), isNull);
    });

    testWidgets('双栏空态 pop 不应弹掉外壳页', (tester) async {
      await _mountRouter(tester, _SafetyRouter(), _landscape);

      final shellCountBefore =
          find.text('Shell Page', skipOffstage: false).evaluate().length;
      expect(shellCountBefore, 2, reason: '双栏下两个 tab 各有一个外壳页');

      await tester.tap(find.text('Tab0 pop', skipOffstage: false).first);
      await tester.pumpAndSettle();

      expect(find.text('Shell Page', skipOffstage: false).evaluate().length, 2,
          reason: 'pop 不应移除外壳页');

      await tester.tap(find.text('Tab0 push', skipOffstage: false).first);
      await tester.pumpAndSettle();
      expect(find.text('Detail Page', skipOffstage: false), findsOneWidget,
          reason: '外壳页仍在时，后续详情应可见');
      expect(tester.takeException(), isNull);
    });

    testWidgets('有详情时 pop 应关闭详情并回到内容页', (tester) async {
      await _mountRouter(tester, _SafetyRouter(), _portrait);
      await tester.tap(find.text('Tab0 push'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Page', skipOffstage: false), findsOneWidget);

      final context =
          tester.element(find.text('Detail Page', skipOffstage: false));
      context.wetland.pop();
      await tester.pumpAndSettle();

      expect(find.text('Detail Page', skipOffstage: false), findsNothing);
      expect(find.text('Tab0 push'), findsOneWidget);
    });
  });

  group('canPop / maybePop（D2）', () {
    testWidgets('无详情时 canPop 为 false，有详情时为 true', (tester) async {
      await _mountRouter(tester, _SafetyRouter(), _portrait);

      final context = tester.element(find.text('Tab0 push'));
      expect(context.wetland.canPop, isFalse, reason: '无详情时不应可 pop');

      await tester.tap(find.text('Tab0 push'));
      await tester.pumpAndSettle();
      final context2 = tester.element(find.text('Detail Page'));
      expect(context2.wetland.canPop, isTrue, reason: '有详情时应可 pop');
    });

    testWidgets('无详情时 maybePop 返回 false 且不弹任何东西', (tester) async {
      await _mountRouter(tester, _SafetyRouter(), _portrait);

      final context = tester.element(find.text('Tab0 push'));
      final popped = await context.wetland.maybePop();
      await tester.pumpAndSettle();

      expect(popped, isFalse);
      expect(_wetlandCount(), 1, reason: 'maybePop 不应破坏 App');
      expect(find.text('Tab0 push', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('有详情时 maybePop 返回 true 并关闭详情', (tester) async {
      await _mountRouter(tester, _SafetyRouter(), _portrait);
      await tester.tap(find.text('Tab0 push'));
      await tester.pumpAndSettle();

      final context = tester.element(find.text('Detail Page'));
      final popped = await context.wetland.maybePop();
      await tester.pumpAndSettle();

      expect(popped, isTrue, reason: '有详情时 maybePop 应返回 true');
      expect(find.text('Detail Page', skipOffstage: false), findsNothing);
    });
  });

  group('构造函数与单 destination（D3）', () {
    testWidgets('单 destination 在单栏应正常渲染', (tester) async {
      await _mountRouter(tester, _SingleTabRouter(), _portrait);

      expect(tester.takeException(), isNull,
          reason: '单 destination 不应抛异常（BottomNavigationBar 要求 >=2 items）');
      expect(find.text('Tab0 push'), findsOneWidget);
    });

    testWidgets('单 destination 在双栏应正常渲染', (tester) async {
      await _mountRouter(tester, _SingleTabRouter(), _landscape);

      expect(tester.takeException(), isNull);
      expect(find.text('Tab0 push', skipOffstage: false), findsOneWidget);
    });

    testWidgets('单 destination 在单栏能进详情并返回', (tester) async {
      await _mountRouter(tester, _SingleTabRouter(), _portrait);

      await tester.tap(find.text('Tab0 push'));
      await tester.pumpAndSettle();
      expect(find.text('Detail Page', skipOffstage: false), findsOneWidget);

      final context = tester.element(find.text('Detail Page'));
      await context.wetland.maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Detail Page', skipOffstage: false), findsNothing);
      expect(find.text('Tab0 push'), findsOneWidget);
    });

    testWidgets('空 destinations 应在构造时断言失败', (tester) async {
      expect(
        () => Wetland(destinations: const []),
        throwsAssertionError,
        reason: '空列表是调用方错误，应在构造处断言',
      );
    });
  });

  group('push 返回值一致性（D4）', () {
    /// 验证 `push<String>` 的 Future 在详情被 pop 时以该结果完成，
    /// 且**不随布局模式变化**。
    ///
    /// 修复前：双栏 replace 路径用 `replaceAll`（内部不传 `popCompleter`）
    /// 后直接 `return null` —— 实测同一个 `await push<String>()` 在单栏得到
    /// `'RET'`、双栏得到 `null`。
    Future<void> assertResultDelivered(WidgetTester tester, Size size) async {
      _lastPushResult.value = null;
      await _mountRouter(tester, _ResultRouter(), size);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Result Detail', skipOffstage: false), findsOneWidget,
          reason: '详情应可见（宽度 ${size.width}）');

      await tester.tap(find.text('close-with-result', skipOffstage: false).first);
      await tester.pumpAndSettle();

      expect(_lastPushResult.value, 'RET',
          reason: 'push 的返回值应携带 pop 结果（宽度 ${size.width}）');
    }

    testWidgets('单栏 push 结果应可传递', (tester) async {
      await assertResultDelivered(tester, _portrait);
    });

    testWidgets('双栏 push 结果应可传递', (tester) async {
      await assertResultDelivered(tester, _landscape);
    });

    testWidgets('双栏下已有详情时再次 push（replace）结果仍应可传递', (tester) async {
      _lastPushResult.value = null;
      await _mountRouter(tester, _ResultRouter(), _landscape);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Result Detail', skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Result Detail', skipOffstage: false), findsOneWidget,
          reason: 'replace 后仍应只有一个详情');

      await tester.tap(find.text('close-with-result', skipOffstage: false).first);
      await tester.pumpAndSettle();

      expect(_lastPushResult.value, 'RET',
          reason: 'replace 路径的 push 结果也必须能回传');
    });
  });

  group('模式由布局推导（D5）', () {
    testWidgets('以窄屏启动时系统 UI 应在首帧被应用', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method.contains('SystemChrome')) {
            calls.add('${call.method}:${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _mountRouter(tester, _SafetyRouter(), _portrait);

      expect(
        calls.where((m) =>
            m.contains('setEnabledSystemUIMode') ||
            m.contains('setEnabledSystemUIOverlays')),
        isNotEmpty,
        reason: '首帧就应应用与推导模式一致的系统 UI，而不是等模式变化',
      );
    });

    testWidgets('以宽屏启动时系统 UI 应被应用（状态栏/导航栏隐藏）', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method.contains('SystemChrome')) {
            calls.add('${call.method}:${call.arguments}');
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await _mountRouter(tester, _SafetyRouter(), _landscape);

      // dual 模式的「隐藏状态栏/导航栏」在测试绑定上以 legacy 接口
      // `setEnabledSystemUIOverlays` 出现（Flutter 对 `SystemUiMode.manual`
      // 的转译）。旧实现只在模式变化时调用，故宽屏启动时该调用**不存在**。
      expect(
        calls.any((m) =>
            m.startsWith('SystemChrome.setEnabledSystemUIOverlays:')),
        isTrue,
        reason: '以宽屏启动也应隐藏系统 UI（旧实现只在模式变化时调用）。实际=$calls',
      );
    });
  });

  group('外壳页约定（D6）', () {
    testWidgets('正确配置下嵌套栈以空路径外壳页开头', (tester) async {
      await _mountRouter(tester, _SafetyRouter(), _landscape);

      final stack = _nestedStackOf(tester);
      expect(stack, isNotEmpty, reason: '应能取到嵌套栈');
      expect(stack.first.routeData.route.hasEmptyPath, isTrue,
          reason: "栈首应为 path: '' 外壳页");
      expect(internal.hasRequiredShellPage(stack), isTrue);
    });

    testWidgets('empty-path 路由被 auto_route 排在栈首（声明顺序不影响）',
        (tester) async {
      await _mountRouter(tester, _ShellSecondRouter(), _landscape);

      final stack = _nestedStackOf(tester);
      expect(stack, isNotEmpty);
      expect(stack.first.routeData.route.hasEmptyPath, isTrue,
          reason: '外壳页声明在第二位时也应位于栈首');
      expect(internal.hasRequiredShellPage(stack), isTrue);
    });

    testWidgets('没有 empty-path 路由时嵌套 Navigator 不会挂载', (tester) async {
      // 实测结论：该配置下 currentState == null，详情无处可推。
      // 因此「外壳页缺失」并非可达状态，库不引入运行时告警（避免死代码）。
      await _mountRouter(tester, _NoEmptyPathRouter(), _landscape);

      expect(_nestedStackOf(tester), isEmpty,
          reason: '无 empty-path 路由时嵌套 Navigator 不挂载（实测）');
      expect(tester.takeException(), isNull);
    });
  });
}
