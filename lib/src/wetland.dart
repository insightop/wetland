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
import "utils/root_detail_stack.dart";
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

/// 宽度收缩出场动画（用于导航栏，见 `outAnimation`）。
///
/// `AdaptiveLayout.updateSize` 只在动画**结束**时刷新槽位尺寸基准，因此 body 左
/// 偏移的补间是 `Tween(旧宽, 新宽)`。若出场动画不改布局宽度（Slide/Fade 都只改
/// 绘制），子尺寸全程不变、补间退化成常量，body 左偏移会卡住到动画结束才突跳。
Widget _collapseWidth(Widget child, Animation<double> animation) {
  return ClipRect(
    child: Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1.0 - animation.value,
      child: child,
    ),
  );
}

/// 高度收缩出场动画（用于底部导航）。
///
/// 与 [_collapseWidth] 同理：底导向下滑出时若槽位高度不变，框架的
/// `bottomMargin` 补间退化为常量，body 高度不会平滑收回。
/// 用高度收缩让槽位逐帧变矮，同时导航栏被裁掉上半部分 —— 视觉上等价于
/// 「向下滑出」，但**槽位区域始终有内容绘制**，不会露出纯黑。
Widget _collapseHeight(Widget child, Animation<double> animation) {
  return ClipRect(
    child: Align(
      alignment: AlignmentDirectional.topCenter,
      heightFactor: 1.0 - animation.value,
      child: child,
    ),
  );
}

/// 判断一条嵌套路由栈的首项是否为 wetland 约定的**空路径外壳页**。
///
/// 这是本库最重要的隐性约定：每个 destination 的嵌套路由集合必须以一条
/// `path: ''` 的外壳路由开头。它有两个作用：
/// 1. 让嵌套 [Navigator] 始终存在（否则详情无处可推）；
/// 2. 作为「右侧还没有详情」时的空态画面。
///
/// 违反约定会让详情**静默不可见**：push 成功、但永远画不出来。因此本函数
/// 公开为纯谓词，调用方（与库自身）都能据此校验配置。
///
/// 空栈视为**满足**约定（尚无路由时不算违规）。
bool hasRequiredShellPage(List<AutoRoutePage> stack) {
  if (stack.isEmpty) return true;
  return stack.first.routeData.route.hasEmptyPath;
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
    this.transitionDuration = const Duration(milliseconds: 1000),
  }) : assert(
         logicalXor(destinations == null, primaryBody == null),
         'Only one of [destinations] or [primaryBody] can be set',
       ),
       // 空列表是**调用方错误**而非可降级的运行状态：它会让 body 取
       // `destinations[0]` 时抛 `RangeError`。在构造处断言能让错误暴露在
       // 出错的那一行，而不是若干帧后的构建期。
       //
       // 单个 destination 是**合法**配置（单 tab 应用），因此这里只拒绝空列表。
       assert(
         destinations == null || destinations.isNotEmpty,
         '[destinations] must not be empty; provide at least one destination',
       );

  @override
  State<Wetland> createState() => _WetlandState();
}

class _WetlandState extends State<Wetland> {
  late List<GlobalKey<NavigatorState>> _secondaryKeys;

  /// 每个 tab 的 secondary [StackRouter] 引用。
  ///
  /// 用于三件事：① 监听详情栈变化以驱动布局；② 供 [SecondaryBody] 上报自身
  /// router；③ 作为单栏全屏详情的**候选路由集合**（单栏下嵌套 navigator 依然
  /// 挂载，其集合里有详情路由声明，可据此显式匹配而无需按名 push）。
  final List<StackRouter?> _secondaryRouters = [];

  /// 单栏（竖屏）全屏详情的宿主。
  ///
  /// 单栏下详情挂在根 navigator 上（真路由 ⇒ 真 push/pop、覆盖底部导航）；
  /// 双栏下该宿主为空栈，详情仍走各 tab 的 secondary。
  late final RootDetailStack _rootDetails = RootDetailStack(
    candidates: () => [
      // 优先当前 tab 的集合，其次其余 tab，最后根集合。
      if (_safeTabRouter(_currentIndex) != null) _safeTabRouter(_currentIndex)!,
      ..._secondaryRouters.whereType<StackRouter>(),
      ...AutoRouter.of(context).root.childControllers.whereType<StackRouter>(),
    ],
    wrapChild: _wrapRootDetailChild,
  );

  /// 承载 tab 状态与模式的 bloc。
  ///
  /// 由 State 自己持有（而非在 build 里 `BlocProvider(create:)`），因为
  /// [RootDetailStack] 需要把根级详情包回 Wetland 子树，而 State 的 `context`
  /// 位于 `BlocProvider` **之上** —— 在那里 `context.read<WetlandBloc>()` 会抛
  /// "Could not find the correct Provider"。自持 bloc 后两者都能直接取用。
  late final WetlandBloc _bloc = WetlandBloc();

  /// 把根级详情的内容包回 Wetland 语义子树（scope + bloc 可用）。
  ///
  /// 不做这一步的话，详情内部 `context.wetland.push`（下钻）会因 `scope == null`
  /// 退回按名 push，从而被嵌套 router 截获（已实测：下钻的详情完全不可见）。
  Widget _wrapRootDetailChild(Widget child) {
    return BlocProvider<WetlandBloc>.value(
      value: _bloc,
      child: WetlandScope(
        secondaryKeys: _secondaryKeys,
        rootDetails: _rootDetails,
        child: child,
      ),
    );
  }

  /// 当前 bloc 里的 tab 下标（供 [_rootDetails] 的候选集合排序使用）。
  int _currentIndex = 0;

  /// 上一次生效的布局模式，用于识别模式**边沿**（只在真正切换时迁移一次）。
  WetlandMode? _previousMode;

  /// 上一次已应用到系统 UI 的模式。
  ///
  /// 与 [_previousMode] 分开：系统 UI 需要在**首帧**就应用一次，而它不在
  /// `BlocListener` 的触发范围内（listener 只在状态**变化**时触发；应用以宽屏
  /// 启动时模式从未变化，导致状态栏/导航栏从未被隐藏，已实测）。
  WetlandMode? _appliedSystemUiMode;

  /// 由**布局本身**推导当前模式，而不是「哪个槽位的 builder 恰好跑了」。
  ///
  /// 旧实现把模式写在槽位 builder 里（`_setMode`），于是：
  /// - `primaryBody` 配置下两个导航槽都不构建 ⇒ 模式永远停在默认 `dual`，
  ///   详情在两个方向都不可见（已实测：详情不在 widget 树中）；
  /// - 以宽屏启动时模式从未变化 ⇒ 系统 UI 从未被应用。
  ///
  /// 改为在此处推导后，模式在**首帧**就正确，且与布局无关地覆盖所有配置。
  ///
  /// 判定复用框架自己的断点谓词 [Breakpoint.isActive]，而不是直接比较
  /// `MediaQuery` 宽度：该谓词还包含高度条件，自己重写会在部分视口与
  /// `AdaptiveLayout` 实际选择的槽位不一致。
  WetlandMode _derivedMode(BuildContext context) {
    // 未提供 destinations ⇒ 不存在 secondary 区域，详情一律走全屏根路由，
    // 主内容占满整屏，因此语义上等同单栏。
    if (widget.destinations == null) return WetlandMode.single;
    return Breakpoints.mediumLargeAndUp.isActive(context)
        ? WetlandMode.dual
        : WetlandMode.single;
  }

  StackRouter? _safeTabRouter(int index) {
    if (index < 0 || index >= _secondaryRouters.length) return null;
    return _secondaryRouters[index];
  }

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

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  /// 将当前选中的 tab index 限制在 destinations 范围内，避免 shrink 后越界。
  int _safeIndex(int index, int length) {
    if (index < length) return index;
    return length > 0 ? length - 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WetlandBloc>.value(
      value: _bloc,
      child: BlocListener<WetlandBloc, WetlandState>(
        // 模式边沿触发导航栈迁移：详情在两个「家」之间搬家。
        // - 单→双：根 navigator 上的全屏详情回填到当前 tab 的 secondary。
        // - 双→单：当前 tab secondary 的详情迁入根 navigator，成为全屏路由。
        listener: (context, state) {
          _applySystemUi(state.mode);
          final previous = _previousMode;
          if (previous == null || previous == state.mode) return;
          _previousMode = state.mode;
          final index = _safeIndex(
            state.index,
            widget.destinations?.length ?? 0,
          );
          if (previous == WetlandMode.single &&
              state.mode == WetlandMode.dual) {
            // 单→双：根 navigator 上的全屏详情回填到当前 tab 的 secondary。
            _backfillRootToSecondary(index);
          } else if (previous == WetlandMode.dual &&
              state.mode == WetlandMode.single) {
            // 双→单：当前 tab secondary 的详情迁入根 navigator，成为全屏路由。
            _migrateSecondaryToRoot(index);
          }
        },
        child: BlocBuilder<WetlandBloc, WetlandState>(
          builder: (context, state) {
            // 当 destinations 数量变化（如被 shrink）时，clamp 防止越界。
            final destCount = widget.destinations?.length ?? 0;
            final safeIndex = _safeIndex(state.index, destCount);
            _currentIndex = safeIndex;

            // 模式由**布局**推导（见 [_derivedMode]），而不是由哪个槽位 builder
            // 跑了决定。这里把推导结果同步进 bloc，使既有的迁移边沿逻辑
            // （BlocListener）保持不变地继续工作。
            final mode = _derivedMode(context);
            if (state.mode != mode) {
              // 与旧的槽位 builder 写入时机一致（同样发生在 build 期间），
              // 因此不会引入额外的一帧延迟 —— 这一点很关键：迁移若晚一帧会
              // 露出「源已移除、目标未上台」的空白帧。
              _setMode(context, mode);
            }

            // 系统 UI：不能只依赖 BlocListener（它只在状态变化时触发）。应用以
            // 宽屏启动时模式从未变化，旧实现因此**从未隐藏状态栏/导航栏**（已实测
            // `SystemChrome` 只有 MaterialApp 的两次默认调用）。此处按「已应用的
            // 模式」去重后补齐首帧。平台调用排在帧末，避免在 build 中产生副作用。
            if (_appliedSystemUiMode != mode) {
              _appliedSystemUiMode = mode;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _applySystemUi(mode);
              });
            }

            // bodyRatio 跟随**推导出的**模式，与 mode 保持同一来源。
            final targetRatio = _targetBodyRatio(mode, safeIndex);

            // 用 build 里看到的模式初始化「上一次模式」。
            //
            // 不能只靠 listener 自己累积：若应用启动即处于 dual（宽屏）且模式
            // 始终未变，listener 不会被调用，`_previousMode` 会一直是 null，
            // 于是首次「dual→single」边沿被漏掉 —— 实测表现为横转竖后详情
            // 完全没有迁移（详情消失）。build 在首次渲染时必然执行，且此刻尚未
            // 可能发生迁移，因此在这里兜底初始化是最稳的。
            _previousMode ??= mode;

            return WetlandScope(
              secondaryKeys: _secondaryKeys,
              rootDetails: _rootDetails,
              // bodyRatio 用 TweenAnimationBuilder 插值：布局在动画第一帧起就按
              // 目标比例拉伸，"单⇄双栏"因此是一条连续动画。
              //
              // 注意：单栏下 bodyRatio 不再随「是否有详情」变化。详情已改由根
              // navigator 承载（全屏真路由），单栏恒定 1.0（primary 占满、
              // secondary 槽宽 0），因此进入/退出详情时**外层布局完全不动**，
              // 不存在"scaffold 切换比例"的观感。
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: targetRatio, end: targetRatio),
                duration: widget.transitionDuration,
                curve: Curves.easeInOutCubic,
                builder: (context, ratio, child) => ColoredBox(
                  //! 兜底背景：`AdaptiveLayout` 只绘制各槽位内部的内容，
                  //! 槽位之间（过渡中导航栏与 body 瞬时错开的那条缝隙）
                  //! **不绘制任何背景**，露出的区域是纯黑 —— 即用户看到的
                  //! 「一闪而过的黑色竖条」（实测该区域像素为 (0,0,0)）。
                  //! 垫一层应用背景色后，缝隙显示为背景色而非黑色。
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: AdaptiveLayout(
                    //! 比例（动画中）
                    bodyRatio: ratio,
                    //! 保留框架内置的槽位尺寸过渡（默认 true）。
                    //!
                    //! 它让 body / 导航栏的 margin 随 `transitionDuration` 平滑插值
                    //! （框架内置曲线为 `Curves.easeInOutCubic`），这是「单⇄双栏
                    //! 切换有过渡动画」的来源。若关掉（`false`），框架会把内部
                    //! `AnimationController` 的 duration 置 0，margin 直接跳到终值，
                    //! 表现为切换时生硬跳变、毫无动画。
                    //!
                    //! **迁移期间必须关掉**：根级不透明详情会把 Wetland 子树的
                    //! `TickerMode` 置为 false（已实测 `TickerMode.of` 由 true 变
                    //! false），框架的内部控制器随之中止，布局会**永久冻结在中间
                    //! 几何**（实测 body 238.8 / secondary 109.3，既非单栏也非双栏）。
                    //! 关掉后布局按当前 bodyRatio 直接计算，不再依赖 ticker；
                    //! 详情覆盖全屏，因此这个瞬时跳变对用户不可见。
                    internalAnimations: true,
                  //! 过渡动画
                  //
                  transitionDuration: widget.transitionDuration,
                  //! 主导航
                  primaryNavigation: widget.destinations != null
                      ? SlotLayout(
                          config: <Breakpoint, SlotLayoutConfig>{
                            Breakpoints.mediumLargeAndUp: SlotLayout.from(
                              key: const Key('Primary Navigation'),
                              builder: (_) {
                                return PrimaryNavigation(
                                  widget.destinations!,
                                  leading: widget.primaryNavigationRailLeading,
                                  trailing: widget.primaryNavigationRailTrailing,
                                );
                              },
                              //! 导航栏进/出场都用「从左侧滑入/滑出」，并与
                              //! body 的让位动画（框架内置 `internalAnimations`）
                              //! 使用同一时长与曲线，二者因此同步：
                              //! - 单→双：body 用 1s 从 0 让到 74.1，导航栏同时
                              //!   从屏幕左外侧滑到 0 —— 两者速度一致，中间不会
                              //!   出现「已让位但导航栏还没到」的空隙；
                              //! - 双→单：body 用 1s 从 74.1 收回 0，导航栏同时
                              //!   向左滑出，始终盖住那条正在收窄的区域。
                              //! 若只给 inAnimation 而用「原地出现」
                              //! （`stayOnScreen`），双→单时导航栏会立刻消失，
                              //! 而 body 还要 1s 才收回，左侧便露出 74px 空隙。
                              inAnimation: (child, animation) =>
                                  AdaptiveScaffold.leftOutIn(child, animation),
                              inCurve: Curves.easeInOutCubic,
                              outAnimation: _collapseWidth,
                              outCurve: Curves.easeInOutCubic,
                          ),
                        },
                      )
                    : null,
                //! 底部导航
                //
                // 出场动画（单→双，即底部导航消失、左侧导航栏出现）：
                // 小屏/中屏的槽位配置只在单栏生效，切到双栏时会落到
                // `SlotLayoutConfig.empty()`（builder 为 null）。若不给动画，
                // `AnimatedSwitcher` 不做任何过渡，底部导航瞬间消失。
                // 用 `topToBottom`（向下滑出）并配同一曲线，与 body / 导航栏的
                // 尺寸补间同步，使「底部导航退场、左侧导航栏进场」连贯。
                bottomNavigation: widget.destinations != null
                    ? SlotLayout(
                        config: <Breakpoint, SlotLayoutConfig>{
                          Breakpoints.small: SlotLayout.from(
                            key: const Key('Bottom Navigation'),
                            builder: (_) =>
                                BottomNavigation(widget.destinations!),
                            //! 进场只淡入：槽位的**位置**已由框架的
                            //! `bottomMargin` 补间平滑驱动（实测槽位 top 从 844
                            //! 平滑移到 793.6），再叠加滑动会重复位移。
                            inAnimation: (child, animation) =>
                                AdaptiveScaffold.fadeIn(child, animation),
                            inCurve: Curves.easeInOutCubic,
                            //! 出场用高度收缩：既产生「向下收起」的位移观感，
                            //! 又保证槽位区域始终有内容绘制、不露纯黑。
                            outAnimation: _collapseHeight,
                            outCurve: Curves.easeInOutCubic,
                          ),
                          Breakpoints.medium: SlotLayout.from(
                            key: const Key('Bottom Navigation'),
                            builder: (_) =>
                                BottomNavigation(widget.destinations!),
                            //! 进场只淡入：槽位的**位置**已由框架的
                            //! `bottomMargin` 补间平滑驱动（实测槽位 top 从 844
                            //! 平滑移到 793.6），再叠加滑动会重复位移。
                            inAnimation: (child, animation) =>
                                AdaptiveScaffold.fadeIn(child, animation),
                            inCurve: Curves.easeInOutCubic,
                            //! 出场用高度收缩：既产生「向下收起」的位移观感，
                            //! 又保证槽位区域始终有内容绘制、不露纯黑。
                            outAnimation: _collapseHeight,
                            outCurve: Curves.easeInOutCubic,
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

  /// 目标 [AdaptiveLayout.bodyRatio]：决定 body 占宽比例。
  /// - 双栏（dual）：0.35，左宽右窄的三栏观感；
  /// - 单栏（single）：1.0 —— body（tab 列表页）占满，secondary 槽宽收为 0。
  ///
  /// 单栏**不再**因「有详情」而变 0.0：详情已由根 navigator 以全屏真路由承载，
  /// 外层布局在进入/退出详情时保持不动（这正是不再出现"scaffold 切比例"的原因）。
  /// 单⇄双栏切换仍由这个数值的插值表达。
  ///
  /// [safeIndex] 保留在签名中，供双栏后续按 tab 细化比例时使用（当前未参与计算）。
  double _targetBodyRatio(WetlandMode mode, int safeIndex) {
    if (mode == WetlandMode.dual) return 0.35;
    return 1.0;
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


  /// 双→单：把当前 tab secondary 里的详情迁入根 navigator（成为全屏路由）。
  ///
  /// 只取**真实详情**：跳过栈底外壳页（index 0，nested router 的初始页，只负责
  /// 让 Navigator 存在）与 `autoFilled` 的父级壳（如 Home）。因此空态不会被误迁。
  ///
  /// 时序：先把详情推入根 navigator，**等其入场动画结束**再移除 secondary 里的源。
  /// 根级详情是全屏路由，入场后即铺满屏幕 —— 因此布局照常按
  /// `transitionDuration` 从双栏过渡到单栏，不会暴露任何空白帧，也不需要
  /// 「保持布局」或「瞬时落位」之类的中转状态。
  void _migrateSecondaryToRoot(int tabIndex) {
    final router = _safeTabRouter(tabIndex);
    if (router == null) return;
    final sourceEntries = _detailEntriesOf(router.stack);
    if (sourceEntries.isEmpty) return; // 空态：无需迁移。
    final routes = [for (final e in sourceEntries) e.route.toPageRouteInfo()];
    Log.d('Migrate ${routes.length} detail route(s) from secondary'
        ' (tab #$tabIndex) to root navigator (full-screen)');
    _rootDetails.pushAll(context, routes);
    // 等根侧详情入场完成再移除源：避免「源已空、根侧尚未上台」的空白帧。
    // 注意不能等 `Route.completed`（它只在 dispose 时完成，会死锁）。
    _rootDetails.topRouteEntered.whenComplete(() {
      if (!mounted) return;
      for (final entry in sourceEntries) {
        router.removeRoute(entry);
      }
    });
  }

  /// 单→双：把根 navigator 上的全屏详情回填到当前 tab 的 secondary。
  ///
  /// 时序：先把详情 push 进 secondary，**等 secondary 槽有宽度**后再移除根路由。
  /// 单栏下 `bodyRatio` 为 1.0 ⇒ 槽宽为 0、内容被 `Offstage`；若立刻移除根路由，
  /// 会出现「根已移除、槽位仍为 0 宽」的空白帧（实测该帧详情宽 `-1`）。
  ///
  /// 这里**不做**旧实现那种「等根成为 top-most」的 300 帧轮询：根级详情的推入
  /// 走显式 `RouteData`（见 [RootDetailStack]），不依赖按名解析，因此不需要等
  /// 嵌套 router 卸载 —— 那正是旧方案「先占满、约 1s 后才出现详情」的病根。
  void _backfillRootToSecondary(int tabIndex, {int attempt = 0}) {
    if (!_rootDetails.hasDetail) return;
    final router = _safeTabRouter(tabIndex);
    if (router == null || router.navigatorKey.currentState == null) {
      // secondary 尚未就绪（旋转后首帧）：等下一帧重试（上限覆盖过渡期）。
      _retryLater(attempt, () => _backfillRootToSecondary(tabIndex, attempt: attempt + 1));
      return;
    }
    final routes = _rootDetails.routeInfos;
    if (routes.isEmpty) return;
    Log.d('Backfill ${routes.length} detail route(s) from root navigator to'
        ' secondary (tab #$tabIndex)');
    router.pushAll(routes);
    _removeRootWhenSlotVisible(router, attempt: 0);
  }

  /// 等 secondary 槽有宽度后移除根级详情（上限 [_maxMigrationFrames] 帧）。
  void _removeRootWhenSlotVisible(StackRouter router, {required int attempt}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final width = router.navigatorKey.currentContext?.size?.width ?? 0;
      if (width < 1.0 && attempt < _maxMigrationFrames) {
        _removeRootWhenSlotVisible(router, attempt: attempt + 1);
        return;
      }
      _rootDetails.removeAll();
    });
  }

  /// 在下一帧重试 [action]，直到上限（用于等待 secondary 就绪）。
  void _retryLater(int attempt, VoidCallback action) {
    if (attempt >= _maxMigrationFrames) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) action();
    });
  }

  /// 迁移等待的上限帧数（约 5s@60fps，足以覆盖默认 1000ms 过渡期）。
  static const int _maxMigrationFrames = 300;

  /// 从一条 nested 栈里筛出**真实详情**条目（跳过外壳页与 `autoFilled` 壳）。
  ///
  /// 跳过 index 0 是因为它约定为 `path: ''` 的外壳页（只为让嵌套 Navigator 存在），
  /// 不是用户选中的详情；跳过 `autoFilled` 则排除 auto_route 自动补齐的父级壳
  /// （如 Home）。空态（只有外壳页）因此返回空列表，不会被误迁移。
  List<RouteData> _detailEntriesOf(List<AutoRoutePage> stack) {
    final entries = <RouteData>[];
    for (var i = 1; i < stack.length; i++) {
      final data = stack[i].routeData;
      if (data.route.autoFilled) continue;
      entries.add(data);
    }
    return entries;
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
