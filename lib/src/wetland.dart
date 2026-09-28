import "dart:math" as math;

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
import "utils/secondary_stack.dart";
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

  /// 每个 tab 的 secondary [StackRouter] 引用。
  ///
  /// 用于两件事：① 监听详情栈变化以驱动布局（单栏时决定由谁占满屏幕）；
  /// ② 供 [SecondaryBody] 上报自身 router。
  final List<StackRouter?> _secondaryRouters = [];

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
        // 布局切换不再迁移导航栈：secondary 槽常驻挂载，单/双栏差异完全由
        // [AdaptiveLayout.bodyRatio] 的动画插值表达（见下方 build）。
        listener: (context, state) => _applySystemUi(state.mode),
        child: BlocBuilder<WetlandBloc, WetlandState>(
          builder: (context, state) {
            // 当 destinations 数量变化（如被 shrink）时，clamp 防止越界。
            final destCount = widget.destinations?.length ?? 0;
            final safeIndex = _safeIndex(state.index, destCount);
            final hasDetail = _currentTabHasDetail(safeIndex);
            final targetRatio = _targetBodyRatio(state.mode, hasDetail);

            return WetlandScope(
              secondaryKeys: _secondaryKeys,
              // bodyRatio 用 TweenAnimationBuilder 插值：布局在动画第一帧起就按
              // 目标比例拉伸，"进详情/返回""单⇄双栏"因此都是同一条连续动画，
              // 不再需要迁移导航栈，也没有"过渡结束才补一刀"的空窗。
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: targetRatio, end: targetRatio),
                duration: widget.transitionDuration,
                curve: Curves.easeInOutCubic,
                builder: (context, ratio, child) => AdaptiveLayout(
                  //! 比例（动画中）
                  bodyRatio: ratio,
                  //! 该槽位切换动画由我们自己的 ratio 插值承担，
                  //! 关闭其内部动画避免两套动画互相干扰。
                  internalAnimations: false,
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
                      builder: (_) => _mountedSlot(
                        widget.destinations != null
                            ? widget.destinations![safeIndex].page
                            : widget.primaryBody!,
                      ),
                    ),
                  },
                ),
                //! 次要主体
                //
                // 始终挂载（不再绑定 mediumLargeAndUp）：详情永远留在自己的
                // navigator 里，单/双栏差异完全交给 bodyRatio 表达，因此不存在
                // 「布局切换后还要迁移导航栈」的中间态。窄屏下该槽宽为 0 时
                // Navigator 仍在树上，navigatorKey.currentState 保持可用。
                secondaryBody: widget.destinations != null
                    ? SlotLayout(
                        config: <Breakpoint, SlotLayoutConfig>{
                          Breakpoints.standard: SlotLayout.from(
                            key: const Key('Secondary Body'),
                            builder: (_) => _mountedSlot(
                              IndexedStack(
                                index: safeIndex,
                                children: [
                                  for (var i = 0;
                                      i < widget.destinations!.length;
                                      i++)
                                    SecondaryBody(
                                      navigatorKey: _secondaryKeys[i],
                                      index: i,
                                      onRouterReady: _onSecondaryRouterReady,
                                      onStackChanged: _onSecondaryStackChanged,
                                      placeholder: widget.secondaryPlaceholder,
                                    ),
                                ],
                              ),
                            ),
                            //! inAnimation 与 outAnimation 必须使用**同一个**函数。
                            //! 否则 AnimatedSwitcher 切换时会改变 transition 的
                            //! widget 树形状，导致 Element 无法复用、整棵
                            //! IndexedStack→SecondaryBody→AutoRouter 被销毁重建。
                            //! 本槽已改为常驻（key 恒定），理论上不再触发切换，
                            //! 保留同形设置作为防御。
                            inAnimation: _keepOnScreen,
                            outAnimation: _keepOnScreen,
                            outCurve: Curves.easeInOutCubic,
                          ),
                        },
                      )
                    : null,
                ),
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

  /// 某 tab 的 secondary [StackRouter] 挂载就绪时记录引用。
  ///
  /// 只接受每个 tab 的 NestedStackRouter；瞬时帧里 AutoRouter.of 可能解析到
  /// 根 AppRouter，存下来会覆盖 per-tab 引用。
  void _onSecondaryRouterReady(int index, StackRouter router) {
    if (index < 0 || index >= _secondaryRouters.length) return;
    if (router is! NestedStackRouter) return;
    _secondaryRouters[index] = router;
  }

  /// 详情栈变化时重建布局（单栏下由谁占满屏幕取决于此）。
  ///
  /// 由 [SecondaryBody] 的 [NavigatorObserver] 触发，覆盖 push/pop/replace/remove。
  void _onSecondaryStackChanged() {
    if (mounted) setState(() {});
  }

  /// 当前选中 tab 的 secondary 是否有用户详情。
  bool _currentTabHasDetail(int safeIndex) {
    if (safeIndex >= _secondaryRouters.length) return false;
    return secondaryHasDetail(_secondaryRouters[safeIndex]);
  }

  /// 目标 [AdaptiveLayout.bodyRatio]：决定 body 占宽比例。
  /// - 双栏（dual）：0.35，左宽右窄的三栏观感；
  /// - 单栏且详情栈非空：0.0 —— body 收窄为 0，secondary 占满全屏；
  /// - 单栏且无详情：1.0 —— secondary 收窄为 0，body（tab 列表页）占满。
  ///
  /// 单/双栏切换与「进详情/返回」因此都退化为同一个数值的插值，
  /// 由 [AdaptiveLayout] 的布局在动画第一帧起就按目标比例拉伸，
  /// 不再需要迁移导航栈。
  double _targetBodyRatio(WetlandMode mode, bool hasDetail) {
    if (mode == WetlandMode.dual) return 0.35;
    return hasDetail ? 0.0 : 1.0;
  }

  /// 调用方内容可舒适布局的槽宽下限（逻辑像素）。
  ///
  /// [bodyRatio] 收缩槽位时，槽会经过 0.5px、5px 这类极窄宽度。低于此宽度时
  /// 调用方内容（如含 `ListTile` 的列表页，其 leading 需要数十像素；或带
  /// padding 的居中 `Column`）会抛 `Leading widget consumes the entire tile
  /// width` / `RenderFlex overflowed`。库不能假设调用方内容能抗极小宽度，
  /// 故统一按此值兜底。
  ///
  /// 取值来自实测：例子的列表页在 150 以下开始 `RenderFlex overflowed`
  /// （120/130/140 均溢出，150 起稳定）。这里取 200 留余量，同时**必须小于**
  /// 双栏在最小断点（840dp）下的 body 实宽（实测 268.1），否则合法的窄双栏
  /// 内容会被无谓裁切。
  static const double _minRenderableSlotWidth = 200.0;

  /// 槽位内容的守卫：**始终保留子树 State**，只隐藏或裁剪。
  ///
  /// 两条硬约束，缺一不可：
  ///
  /// 1. **子树常驻**：`WetlandNavigator.push` 依赖
  ///    `navigatorKey.currentState != null` 判断「secondary 是否可用」。若窄宽时把
  ///    子树替换为 `SizedBox.shrink()`，嵌套 [Navigator] 会被移出树，
  ///    `currentState` 变 null，详情就会被误推进 primary（表现为竖屏详情变成
  ///    全屏覆盖、右侧双栏失效）。
  ///
  /// 2. **widget 树形状恒定**：无论槽宽多少都必须返回**同一形状**的 widget 链。
  ///    若按宽度阈值在「直接返回 child」与「包若干层」之间切换，Flutter 会因
  ///    Element 无法复用而重建整棵子树 —— `AutoRouter` 的
  ///    `didChangeDependencies` 随之重跑、`NestedStackRouter.setupInitialRoutes()`
  ///    重新入栈，**已 push 的详情被抹掉**（实测：`stack=[/, detail]` → `[/]`）。
  ///    故这里始终返回固定的 `ClipRect → Offstage → OverflowBox → child` 链，
  ///    只让参数随宽度变化。
  ///
  /// 布局策略：槽宽不足时，先用 [OverflowBox] 给内容一个可渲染宽度
  /// （`min(_minRenderableSlotWidth, 屏幕宽)` —— 屏幕本身更窄时不放大，
  /// 避免为极窄设备引入横向裁切），再由 [ClipRect] 裁到真实槽宽。视觉上等价于
  /// 内容随布局滑出屏幕。槽宽充足时 [OverflowBox] 不改写约束，等价于不包裹，
  /// 因此双栏下内容仍按真实槽宽（而非屏幕宽）布局。
  ///
  /// 槽宽不足 1 逻辑像素时用 [Offstage] 停止绘制、命中与语义：既避免亚像素
  /// 残影，也让默认跳过 offstage 的 finder 如实返回空。
  static Widget _mountedSlot(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final renderableWidth = math.min(
          _minRenderableSlotWidth,
          MediaQuery.sizeOf(context).width,
        );
        final tooNarrow = width < renderableWidth;
        return ClipRect(
          child: Offstage(
            offstage: width < 1.0,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: tooNarrow ? renderableWidth : null,
              maxWidth: tooNarrow ? renderableWidth : null,
              child: child,
            ),
          ),
        );
      },
    );
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
