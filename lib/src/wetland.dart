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

  Wetland({
    super.key,
    this.destinations,
    this.primaryBody,
    this.useDrawer = false,
    this.primaryNavigationRailLeading,
    this.primaryNavigationRailTrailing,
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
                                  ),
                              ],
                            ),
                            // outAnimation: (child, animation) => AdaptiveScaffold.rightOutIn(child, animation),
                            outAnimation: (child, animation) =>
                                SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset(0.0, 0.0),
                                end: Offset(0.0, 0.0),
                              ).animate(animation),
                              child: child,
                            ),
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
  /// 详情序列来自 [tabIndex] 对应的 per-tab [NestedStackRouter] 栈里
  /// **非 autoFilled** 的真实详情页（已过滤 Home 这类由 auto_route 自动补齐的父级壳），
  /// 并直接以它们自身的 [PageRouteInfo] push 到根 router —— 根 collection 里已存在
  /// 同名的根级详情 route（如 DetailRoute），因此不会 buildPathTo 重复补齐 Home。
  void _migrateSecondaryToPrimary(BuildContext context, int tabIndex,
      StackRouter? router) {
    if (router == null) return;
    final detailRoutes = <PageRouteInfo>[];
    for (final page in router.stack) {
      final rt = page.routeData.route;
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
