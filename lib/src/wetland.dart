import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart";
import "package:wetland/src/widgets/bottom_navigation.dart";
import "package:wetland/src/widgets/primary_navigation.dart";

import "blocs/wetland_bloc.dart";
import "pages/default_placeholder_page.dart";
import "widgets/secondary_body.dart";
import "utils/destination.dart";
import "utils/navigator.dart";

class Wetland extends StatelessWidget {
  final List<TabDestination> destinations;
  final Widget placeholderPage;

  final Widget _primaryNavigationRail;
  final Widget _bottomNavigationBar;

  Wetland({
    super.key,
    required this.destinations,
    this.placeholderPage = const DefaultPlaceholderPage(),
  })  : _primaryNavigationRail = WetlandPrimaryNavigation(destinations),
        _bottomNavigationBar = WetlandBottomNavigation(destinations);

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
            transitionDuration: const Duration(milliseconds: 1000),
            //! 主导航
            primaryNavigation: SlotLayout(
              config: <Breakpoint, SlotLayoutConfig>{
                Breakpoints.mediumLargeAndUp: SlotLayout.from(
                  key: const Key('Primary Navigation'),
                  builder: (_) => _primaryNavigationRail,
                  inAnimation: (child, animation) =>
                      AdaptiveScaffold.leftOutIn(child, animation),
                  inCurve: Curves.linear,
                  // outAnimation: (child, animation) =>
                  // AdaptiveScaffold.leftInOut(child, animation),
                  // outCurve: Curves.linear,
                ),
              },
            ),
            //! 底部导航
            bottomNavigation: SlotLayout(
              config: <Breakpoint, SlotLayoutConfig>{
                Breakpoints.small: SlotLayout.from(
                  key: const Key('Bottom Navigation'),
                  builder: (_) => _bottomNavigationBar,
                  // outAnimation: (child, animation) => AdaptiveScaffold.topToBottom(child, animation),
                  // outCurve: Curves.easeInOutCubic,
                ),
                Breakpoints.medium: SlotLayout.from(
                  key: const Key('Bottom Navigation'),
                  builder: (_) => _bottomNavigationBar,
                  // outAnimation: (child, animation) => AdaptiveScaffold.topToBottom(child, animation),
                  // outCurve: Curves.easeInOutCubic,
                )
              },
            ),
            //! 主体
            body: SlotLayout(
              config: <Breakpoint, SlotLayoutConfig>{
                Breakpoints.standard: SlotLayout.from(
                  key: const Key('Primary Body Small'),
                  builder: (_) => destinations[state.selectedDestination].page,
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
                    placeholder: placeholderPage,
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
