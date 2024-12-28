import "package:flutter/material.dart";
import "package:flutter/services.dart";

import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart";
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

  Wetland({
    super.key,
    this.destinations,
    this.primaryBody,
    this.primaryNavigationRailLeading,
    this.primaryNavigationRailTrailing,
    // this.placeholder = const DefaultPlaceholderPage(),
    this.transitionDuration = const Duration(milliseconds: 1000),
  }) : assert(logicalXor(destinations == null, primaryBody == null),
            'Only one of destinations or primaryBody can be set');

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WetlandBloc(),
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
                          // 临时隐藏状态栏
                          SystemChrome.setEnabledSystemUIMode(
                              SystemUiMode.manual,
                              overlays: []);
                          return WetlandPrimaryNavigation(
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
                          // 显示状态栏
                          SystemChrome.setEnabledSystemUIMode(
                              SystemUiMode.manual,
                              overlays: SystemUiOverlay.values);
                          return WetlandBottomNavigation(destinations!);
                          // outAnimation: (child, animation) => AdaptiveScaffold.topToBottom(child, animation),
                          // outCurve: Curves.easeInOutCubic,
                        },
                      ),
                      Breakpoints.medium: SlotLayout.from(
                        key: const Key('Bottom Navigation'),
                        builder: (_) {
                          // 显示状态栏
                          SystemChrome.setEnabledSystemUIMode(
                              SystemUiMode.manual,
                              overlays: SystemUiOverlay.values);
                          return WetlandBottomNavigation(destinations!);
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
                  key: const Key('Primary Body Small'),
                  builder: (_) => destinations != null
                      ? destinations![state.selectedDestination].page
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
    );
  }
}
