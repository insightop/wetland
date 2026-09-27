import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "package:auto_route/auto_route.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:custom_adaptive_scaffold/custom_adaptive_scaffold.dart";
import "package:flutter_logcat/flutter_logcat.dart";

import "package:wetland/src/widgets/bottom_navigation.dart";
import "package:wetland/src/widgets/primary_navigation.dart";

import "blocs/wetland_bloc.dart";
// import "pages/default_placeholder_page.dart";
import "widgets/secondary_body.dart";
import "utils/destination.dart";
import "utils/wetland_scope.dart";

/// 逻辑异或：仅当 [a]、[b] 恰好一个为真时返回 true。
bool logicalXor(bool a, bool b) {
  return (a || b) && !(a && b);
}

/// 布局切换过渡期间保持子树原位可见（位置不随动画改变）。
///
/// 用作 [SlotLayoutConfig] 的 `inAnimation` 与 `outAnimation`，**两者必须是同一
/// 函数**，这样 [AnimatedSwitcher] 在切换时不会改变 transition 的 widget 树形状，
/// 出场的旧子树得以原样复用、Element 不被重建。
///
/// 若两侧形状不一致（例如只给 `outAnimation` 包一层），出场时多出的 widget 层会
/// 使 `SecondaryBody` 及其内部 `AutoRouter` 被销毁重建：详情丢失、只剩 primary
/// 全屏，直到过渡动画结束才由迁移补回详情 —— 即"primary 先抢占地"的中间态。
Widget _keepOnScreen(Widget child, Animation<double> animation) {
  return SlideTransition(
    position: Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(animation),
    child: child,
  );
}

/// 自适应导航根组件。
///
/// 根据屏幕尺寸自动切换布局：
/// - 横屏/宽屏（mediumLargeAndUp）：三栏布局，左侧主导航 + 中间主内容 + 右侧详情面板。
/// - 竖屏/窄屏：单栏布局，底部导航 + 主内容全屏。
///
/// 每个主 tab 维护独立的右侧详情导航栈，切换 tab 时详情保留不丢。
/// 通过 [destinations] 或 [primaryBody] 二选一配置内容。
class Wetland extends StatefulWidget {
  /// 主 tab 配置列表（横屏主导航 / 竖屏底部导航 + 中间 body）。
  final List<TabDestination>? destinations;

  /// 自定义主内容（当不使用 [destinations] 时）。
  final Widget? primaryBody;

  /// 布局切换过渡动画时长。
  final Duration transitionDuration;

  /// 主导航栏顶部自定义组件。
  final Widget? primaryNavigationRailLeading;

  /// 主导航栏底部自定义组件。
  final Widget? primaryNavigationRailTrailing;

  /// 是否使用抽屉式导航（预留）。
  final bool useDrawer;

  /// 右侧详情区在详情栈为空时显示的占位（如引导文案）。
  ///
  /// 仅在横屏（dual 模式）的 secondaryBody 生效；竖屏（single 模式）
  /// 没有独立详情区，不显示该占位。
  final WidgetBuilder? secondaryPlaceholder;

  Wetland({
    super.key,
    this.destinations,
    this.primaryBody,
    this.useDrawer = false,
    this.primaryNavigationRailLeading,
    this.primaryNavigationRailTrailing,
    this.secondaryPlaceholder,
    // this.placeholder = const DefaultPlaceholderPage(),
    this.transitionDuration = const Duration(milliseconds: 1000),
  }) : assert(
         logicalXor(destinations == null, primaryBody == null),
         'Only one of [destinations] or [primaryBody] can be set',
       );

  @override
  State<Wetland> createState() => _WetlandState();
}

class _WetlandState extends State<Wetland> {
  late List<GlobalKey<NavigatorState>> _secondaryKeys;
  /// 保存每个 tab 的 secondary [StackRouter] 引用。
  /// 在横屏 secondaryBody build 时写入；push/pop 后 controller 的 stack 仍最新，
  /// 转竖屏（widget 卸载）后仍能读到，用于迁移。
  final List<StackRouter?> _secondaryRouters = [];
  /// 上一个 mode，用于监听 dual→single 迁移时机。
  WetlandMode _previousMode = WetlandMode.dual;

  @override
  void initState() {
    super.initState();
    final keys = _buildKeys(widget.destinations?.length ?? 0);
    _secondaryKeys = keys;
    _secondaryRouters
      ..clear()
      ..addAll(List.filled(keys.length, null));
  }

  @override
  void didUpdateWidget(Wetland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCount = oldWidget.destinations?.length ?? 0;
    final newCount = widget.destinations?.length ?? 0;
    if (newCount == oldCount) return;
    // 重新分配新列表，保证引用变化，使 WetlandScope.updateShouldNotify 能触发。
    _secondaryKeys = [
      ..._secondaryKeys.take(newCount),
      ..._buildKeys((newCount - oldCount).clamp(0, newCount)),
    ];
    // 同步 router 引用数组长度。
    _secondaryRouters
      ..clear()
      ..addAll(List.filled(_secondaryKeys.length, null));
  }

  List<GlobalKey<NavigatorState>> _buildKeys(int count) {
    return List.generate(
      count,
      (i) => GlobalKey<NavigatorState>(debugLabel: 'secondary_$i'),
    );
  }

  /// 将当前选中的 tab index 限制在 destinations 范围内，避免 shrink 后越界。
  int _safeIndex(int index, int length) {
    if (index < length) return index;
    return length > 0 ? length - 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WetlandBloc(),
      child: BlocListener<WetlandBloc, WetlandState>(
        listener: (context, state) {
          _applySystemUi(state.mode);
          // 从 dual 切到 single（横转竖）：把当前 tab 的 secondary 详情栈迁移到根。
          if (_previousMode == WetlandMode.dual &&
              state.mode == WetlandMode.single) {
            final tabIndex =
                _safeIndex(state.index, widget.destinations?.length ?? 0);
            // post-frame 时 secondary 已随竖屏卸载，但 captured controller 的
            // stack 仍保留迁移前的详情序列，此时读取安全。
            final router =
                (tabIndex < _secondaryRouters.length)
                    ? _secondaryRouters[tabIndex]
                    : null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _migrateSecondaryToPrimary(context, tabIndex, router);
            });
          }
          // 从 single 切到 dual（竖转横）：把根栈上的详情回填到当前 tab 的
          // secondary，使变宽后立即呈现左右双栏。
          if (_previousMode == WetlandMode.single &&
              state.mode == WetlandMode.dual) {
            final tabIndex =
                _safeIndex(state.index, widget.destinations?.length ?? 0);
            // 与迁移相反：此刻 secondary 正在挂载，其 router 引用还没写入
            // [_secondaryRouters]，需等就绪后再回填，故把首帧查询也放进
            // post-frame 回调（见 [_backfillPrimaryToSecondary]）。
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _backfillPrimaryToSecondary(context, tabIndex, attempt: 0);
            });
          }
          _previousMode = state.mode;
        },
        child: BlocBuilder<WetlandBloc, WetlandState>(
          builder: (context, state) {
            // 当 destinations 数量变化（如被 shrink）时，clamp 防止越界。
            final destCount = widget.destinations?.length ?? 0;
            final safeIndex = _safeIndex(state.index, destCount);
            return WetlandScope(
              secondaryKeys: _secondaryKeys,
              child: AdaptiveLayout(
                //! 比例
                bodyRatio: 0.35,
                //! 过渡动画
                transitionDuration: widget.transitionDuration,
                //! 主导航
                primaryNavigation: widget.destinations != null
                    ? SlotLayout(
                        config: <Breakpoint, SlotLayoutConfig>{
                          Breakpoints.mediumLargeAndUp: SlotLayout.from(
                            key: const Key('Primary Navigation'),
                            builder: (_) {
                              _setMode(context, WetlandMode.dual);

                              return PrimaryNavigation(
                                widget.destinations!,
                                leading: widget.primaryNavigationRailLeading,
                                trailing: widget.primaryNavigationRailTrailing,
                              );
                            },
                            inAnimation: (child, animation) =>
                                AdaptiveScaffold.leftOutIn(child, animation),
                            inCurve: Curves.linear,
                            // outAnimation: (child, animation) =>
                            // AdaptiveScaffold.leftInOut(child, animation),
                            // outCurve: Curves.linear,
                          ),
                        },
                      )
                    : null,
                //! 底部导航
                bottomNavigation: widget.destinations != null
                    ? SlotLayout(
                        config: <Breakpoint, SlotLayoutConfig>{
                          Breakpoints.small: SlotLayout.from(
                            key: const Key('Bottom Navigation'),
                            builder: (_) {
                              _setMode(context, WetlandMode.single);
                              return BottomNavigation(widget.destinations!);
                              // outAnimation: (child, animation) => AdaptiveScaffold.topToBottom(child, animation),
                              // outCurve: Curves.easeInOutCubic,
                            },
                          ),
                          Breakpoints.medium: SlotLayout.from(
                            key: const Key('Bottom Navigation'),
                            builder: (_) {
                              _setMode(context, WetlandMode.single);
                              return BottomNavigation(widget.destinations!);
                              // outAnimation: (child, animation) => AdaptiveScaffold.topToBottom(child, animation),
                              // outCurve: Curves.easeInOutCubic,
                            },
                          ),
                        },
                      )
                    : null,
                //! 主体
                body: SlotLayout(
                  config: <Breakpoint, SlotLayoutConfig>{
                    Breakpoints.standard: SlotLayout.from(
                      key: const Key('Primary Body MediumLarge'),
                      builder: (_) => widget.destinations != null
                          ? widget.destinations![safeIndex].page
                          // : Text('test')
                          : widget.primaryBody!,
                    ),
                  },
                ),
                //! 次要主体
                secondaryBody: widget.destinations != null
                    ? SlotLayout(
                        config: <Breakpoint, SlotLayoutConfig>{
                          Breakpoints.mediumLargeAndUp: SlotLayout.from(
                            key: const Key('Secondary Body'),
                            builder: (_) => IndexedStack(
                              index: safeIndex,
                              children: [
                                for (var i = 0;
                                    i < widget.destinations!.length;
                                    i++)
                                  SecondaryBody(
                                    navigatorKey: _secondaryKeys[i],
                                    index: i,
                                    onRouterReady: _onSecondaryRouterReady,
                                    placeholder: widget.secondaryPlaceholder,
                                  ),
                              ],
                            ),
                            //! inAnimation 与 outAnimation 必须使用**同一个**函数，
                            //! 否则 AnimatedSwitcher 切换时会改变 transition 的
                            //! widget 树形状：之前只设 outAnimation，dual→single
                            //! 出场时旧子树会从 `config` 被重新包成
                            //! `SlideTransition(config)`，多出的一层导致 Element
                            //! 不匹配，整棵 IndexedStack→SecondaryBody→AutoRouter
                            //! 被销毁并重建为空栈，详情消失、只剩 primary 全屏；
                            //! 且重建出的空 secondary router 会继续挂在根 router 上
                            //! 直到出场动画（transitionDuration，默认 1000ms）结束，
                            //! 阻塞迁移 —— 这就是用户看到的"primary 先抢占地，之后
                            //! secondary 才 push 进来"。两层形状一致后，出场子树被
                            //! 原样复用，详情在整个过渡期保持可见。
                            inAnimation: _keepOnScreen,
                            // outAnimation: (child, animation) => AdaptiveScaffold.rightOutIn(child, animation),
                            outAnimation: _keepOnScreen,
                            outCurve: Curves.easeInOutCubic,
                          ),
                        },
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }

  /// 仅在模式真正变化时派发事件，避免在 build 中重复派发导致状态循环。
  void _setMode(BuildContext context, WetlandMode mode) {
    final bloc = context.read<WetlandBloc>();
    if (bloc.state.mode != mode) {
      bloc.add(WetlandEvent.setMode(mode));
    }
  }

  /// 某 tab 的 secondary [StackRouter] 挂载就绪时，记录其引用。
  /// 保存 controller 引用后，即便后续 push/pop 或转竖屏 widget 卸载，
  /// 都能通过该引用读到 controller 的最新 stack。
  void _onSecondaryRouterReady(int index, StackRouter router) {
    if (index < 0 || index >= _secondaryRouters.length) return;
    // 只接受每个 tab 的 NestedStackRouter。旋转重建的瞬时帧里 AutoRouter.of 可能
    // 解析到根 AppRouter（RootStackRouter），若存下来会覆盖 per-tab 引用，导致迁移
    // 目标错误。
    if (router is! NestedStackRouter) return;
    _secondaryRouters[index] = router;
  }

  /// 把当前 tab 的 secondary 详情栈迁移到根 router 顶部，使竖屏根栈顶部为当前详情页。
  ///
  /// 详情序列只取 [tabIndex] 对应的 per-tab [NestedStackRouter] 栈里**真实详情页**：
  /// - 跳过栈底的外壳页（index 0，nested router 的初始 `PlaceholderRoute`，
  ///   它只负责让 secondary 的 `Navigator` 存在，不是用户选中的详情）；
  /// - 跳过 `autoFilled` 的页（Home 这类由 auto_route 自动补齐的父级壳）。
  ///
  /// 仅当过滤后仍有详情时才迁移，因此空态（栈里只有外壳页）不会误把
  /// primary 再压一层。这些详情直接以自身的 [PageRouteInfo] push 到根 router ——
  /// 根 collection 里已存在同名的根级详情 route（如 DetailRoute），因此不会
  /// buildPathTo 重复补齐 Home。
  void _migrateSecondaryToPrimary(BuildContext context, int tabIndex,
      StackRouter? router) {
    if (router == null) return;
    final stack = router.stack;
    if (stack.length <= 1) return; // 只有外壳页 = 无详情，无需迁移
    final detailRoutes = <PageRouteInfo>[];
    for (var i = 0; i < stack.length; i++) {
      if (i == 0) continue; // 跳过栈底外壳页（Navigator 载体）
      final rt = stack[i].routeData.route;
      if (rt.autoFilled) continue; // 跳过 Home 等自动补齐的父级壳
      detailRoutes.add(rt.toPageRouteInfo());
    }
    if (detailRoutes.isEmpty) return;
    Log.d('Migrate ${detailRoutes.length} detail route(s) from secondary'
        ' (tab #$tabIndex) to portrait root stack:'
        ' ${detailRoutes.map((r) => r.routeName).toList()}');
    final rootRouter = AutoRouter.of(context).root;
    _pushToRootWhenTopMost(rootRouter, detailRoutes, attempt: 0);
  }

  /// 把竖屏根栈上的详情回填到 [tabIndex] 对应的 secondary 栈，使窄→宽切换后
  /// 立即呈现左右双栏，无需用户先返回上一页。
  ///
  /// 与 [_migrateSecondaryToPrimary] 互为逆操作，取根的规则对称：
  /// - 跳过根栈首项（app 的首页/tab 外壳，如 `HomeRoute`）—— 它是承载 `Wetland`
  ///   的容器页，不是用户选中的详情；
  /// - 跳过 `autoFilled` 的页（auto_route 自动补齐的父级壳）；
  /// - 其余按原顺序回填，保留竖屏期间的下钻层级。
  ///
  /// 时序：本方法在模式切到 dual 后的 post-frame 触发。此刻 secondary 的
  /// [NestedStackRouter] 往往尚未就绪：initial 路由由 auto_route 在
  /// `didChangeDependencies` 的 post-frame 里 setup，Navigator 随后才存在，
  /// 其引用也要等 [SecondaryBody] 上报后才会写入 [_secondaryRouters]。
  /// 因此与 [_pushToRootWhenTopMost] 一样按帧重试，直到该 tab 的 router：
  /// 1. 仍是 [NestedStackRouter]，且挂在根 router 的 `childControllers` 下
  ///    （排除上一轮 dual 周期遗留、已卸载的旧引用）；
  /// 2. 其 `Navigator` 已挂载（等价于外壳页已入栈）。
  ///
  /// 必须等外壳页就位再 push：否则详情先入栈，随后 `setupInitialRoutes` 会把
  /// 外壳页压到详情之上，详情反被盖住。
  ///
  /// 回填后再把详情从根栈移除，使根栈只剩 tab 页。顺序是先 push 后移除，
  /// 避免中间帧两侧都没有详情而闪回列表页。
  void _backfillPrimaryToSecondary(
    BuildContext context,
    int tabIndex, {
    required int attempt,
  }) {
    // 300 帧 ≈ 5s@60fps，与迁移重试上限一致，足以覆盖 1000ms 过渡期。
    if (attempt > 300) {
      Log.w(
        'Abandon backfilling portrait root details to secondary'
        ' (tab #$tabIndex): secondary router not ready after $attempt frames',
      );
      return;
    }
    // 无 destinations（[Wetland.primaryBody] 模式）时根本没有 secondary，
    // 直接返回，避免无意义地空转重试。这是结构性判断，与"router 尚未写入
    // 引用"的时序问题不同，后者需要重试。
    if (_secondaryRouters.isEmpty) return;
    final rootRouter = AutoRouter.of(context).root;
    final rootStack = rootRouter.stack;
    if (rootStack.length <= 1) return; // 只有首页/tab 外壳 = 无详情
    final detailRoutes = <PageRouteInfo>[];
    final detailEntries = <RouteData>[];
    for (var i = 1; i < rootStack.length; i++) {
      final entry = rootStack[i];
      final rt = entry.routeData.route;
      if (rt.autoFilled) continue; // 跳过 Home 等自动补齐的父级壳
      detailRoutes.add(rt.toPageRouteInfo());
      detailEntries.add(entry.routeData);
    }
    if (detailRoutes.isEmpty) return;

    final router = (tabIndex < _secondaryRouters.length)
        ? _secondaryRouters[tabIndex]
        : null;
    if (router is! NestedStackRouter ||
        router.navigatorKey.currentState == null ||
        !rootRouter.childControllers.contains(router)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _backfillPrimaryToSecondary(context, tabIndex, attempt: attempt + 1);
      });
      return;
    }

    Log.d('Backfill ${detailRoutes.length} detail route(s) from portrait root'
        ' to secondary (tab #$tabIndex):'
        ' ${detailRoutes.map((r) => r.routeName).toList()}');
    // 先 push 再移除：两者都在同一帧内同步生效，任一帧都不会出现"两侧都没有
    // 详情"的空白中间态。
    router.pushAll(detailRoutes);
    for (final entry in detailEntries.reversed) {
      rootRouter.removeRoute(entry);
    }
  }

  /// 等根 router 成为 top-most 后再把 [routes] push 到根栈。
  ///
  /// 旋转瞬间 secondaryBody 的 NestedStackRouter 尚未完全 dispose，仍挂在根 router
  /// 的 childControllers 下。此时直接 `rootRouter.pushAll` 会经 auto_route 的
  /// `_findStackScope` 解析到最内层仍存活的 router（它能处理同名的 DetailRoute），
  /// 导致详情被压进已卸载的 tab 壳而非根栈。必须等这些 secondary router 全部卸载、
  /// 根 router 成为 top-most 后，push 才会命中根级 DetailRoute。
  ///
  /// disposal 会在竖屏布局切换动画（transitionDuration，默认 1000ms）结束后发生，
  /// 因此用帧率无关的宽松重试上限覆盖整个过渡期，一旦 root 成为 top-most 立即迁移。
  void _pushToRootWhenTopMost(
    RootStackRouter rootRouter,
    List<PageRouteInfo> routes, {
    required int attempt,
  }) {
    // 300 帧 ≈ 5s@60fps，足以覆盖默认 1000ms 过渡期及二次分发后剩余帧。
    if (attempt > 300) {
      Log.w(
        'Abandon migrating ${routes.length} detail route(s) to portrait root:'
        ' root never became top-most after $attempt frames',
      );
      return;
    }
    if (!rootRouter.isTopMost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pushToRootWhenTopMost(rootRouter, routes, attempt: attempt + 1);
      });
      return;
    }
    rootRouter.pushAll(routes);
  }

  /// 根据模式应用系统 UI 样式。仅在模式变化时由 [BlocListener] 触发。
  void _applySystemUi(WetlandMode mode) {
    Log.d('Apply [WetlandMode] to [$mode]');
    switch (mode) {
      case WetlandMode.dual: // 双屏模式
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent, // 透明状态栏
            systemNavigationBarColor: Colors.transparent, // 透明导航栏
            systemNavigationBarContrastEnforced: false, // 禁用对比度强制
          ),
        );
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: [],
        ); // 隐藏 状态栏 和 导航栏
        // SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft]);
        break;
      case WetlandMode.single: // 单屏模式
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
        ); // 显示 状态栏 和 导航栏
        // SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
        break;
    }
  }
}

// leanBack:
// - 全屏，隐藏 状态栏 和 导航栏
// - 点击屏幕任意位置，会弹出导航栏
// - 系统手势不会传递给应用
// - 场景：视频播放、幻灯片等

// Immersive:
// - 全屏，隐藏 状态栏 和 导航栏
// - 边缘滑动唤起导航栏和状态栏
// - 系统手势不会传递给应用
// - 场景：阅读、绘图等

// ImmersiveSticky:
// - 全屏，隐藏 状态栏 和 导航栏
// - 边缘滑动唤起导航栏和状态栏
// - 系统手势会传递给应用
// - 场景：游戏、AR等

// EdgeToEdge:
// - 显示 状态栏 和 导航栏（默认）
// - 系统ui始终覆盖在应用上方（可透明化）
// - 不会自动隐藏
