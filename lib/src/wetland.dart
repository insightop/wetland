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
import "utils/navigator.dart";

bool logicalXor(bool a, bool b) {
  return (a || b) && !(a && b);
}

class Wetland extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WetlandBloc(),
      child: BlocListener<WetlandBloc, WetlandState>(
        listener: (context, state) => _applySystemUi(state.mode),
        child: BlocBuilder<WetlandBloc, WetlandState>(
          builder: (context, state) {
            return AdaptiveLayout(
              //! 比例
              bodyRatio: 0.35,
              //! 过渡动画
              transitionDuration: transitionDuration,
              //! 主导航
              primaryNavigation: destinations != null
                  ? SlotLayout(
                      config: <Breakpoint, SlotLayoutConfig>{
                        Breakpoints.mediumLargeAndUp: SlotLayout.from(
                          key: const Key('Primary Navigation'),
                          builder: (_) {
                            _setMode(context, WetlandMode.dual);

                            return PrimaryNavigation(
                              destinations!,
                              leading: primaryNavigationRailLeading,
                              trailing: primaryNavigationRailTrailing,
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
              bottomNavigation: destinations != null
                  ? SlotLayout(
                      config: <Breakpoint, SlotLayoutConfig>{
                        Breakpoints.small: SlotLayout.from(
                          key: const Key('Bottom Navigation'),
                          builder: (_) {
                            _setMode(context, WetlandMode.single);
                            return BottomNavigation(destinations!);
                            // outAnimation: (child, animation) => AdaptiveScaffold.topToBottom(child, animation),
                            // outCurve: Curves.easeInOutCubic,
                          },
                        ),
                        Breakpoints.medium: SlotLayout.from(
                          key: const Key('Bottom Navigation'),
                          builder: (_) {
                            _setMode(context, WetlandMode.single);
                            return BottomNavigation(destinations!);
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
                    builder: (_) => destinations != null
                        ? destinations![state.index].page
                        // : Text('test')
                        : primaryBody!,
                  ),
                },
              ),
              //! 次要主体
              secondaryBody: SlotLayout(
                config: <Breakpoint, SlotLayoutConfig>{
                  Breakpoints.mediumLargeAndUp: SlotLayout.from(
                    key: const Key('Secondary Body'),
                    builder: (_) => SecondaryBody(
                      navigatorKey: secondaryNavigatorKey,
                    ),
                    // outAnimation: (child, animation) => AdaptiveScaffold.rightOutIn(child, animation),
                    outAnimation: (child, animation) => SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(0.0, 0.0),
                        end: Offset(0.0, 0.0),
                      ).animate(animation),
                      child: child,
                    ),
                    outCurve: Curves.easeInOutCubic,
                  ),
                },
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
