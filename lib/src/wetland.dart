import "package:flutter/material.dart";
import "package:flutter/services.dart";

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

bool logicalXor(bool a, bool b) {
  return (a || b) && !(a && b);
}

class Wetland extends StatefulWidget {
  final List<TabDestination>? destinations;
  final Widget? primaryBody;
  // final Widget placeholder;
  final Duration transitionDuration;
  final Widget? primaryNavigationRailLeading;
  final Widget? primaryNavigationRailTrailing;
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

  @override
  void initState() {
    super.initState();
    _secondaryKeys = _buildKeys(widget.destinations?.length ?? 0);
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
        listener: (context, state) => _applySystemUi(state.mode),
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
