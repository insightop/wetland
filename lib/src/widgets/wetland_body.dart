import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart";

import "../blocs/wetland_cubit.dart";
import "../utils/destination.dart";

class WetlandBody extends StatelessWidget {
  final List<TabDestination> destinations;
  final Widget primaryNavigationRailBuilder;
  final Widget bottomNavigationBarBuilder;
  final Widget placeholderPage;
  const WetlandBody({
    super.key,
    required this.destinations,
    required this.primaryNavigationRailBuilder,
    required this.bottomNavigationBarBuilder,
    required this.placeholderPage,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WetlandCubit, WetlandState>(
      builder: (context, state) => AdaptiveLayout(
        // 比例
        bodyRatio: 0.35,
        // 过渡动画
        transitionDuration: const Duration(milliseconds: 500),
        // 主导航
        primaryNavigation: SlotLayout(
          config: <Breakpoint, SlotLayoutConfig>{
            Breakpoints.mediumLargeAndUp: SlotLayout.from(
              key: const Key('Primary Navigation'),
              builder: (_) => primaryNavigationRailBuilder,
            ),
          },
        ),
        // 底部导航
        bottomNavigation: SlotLayout(
          config: <Breakpoint, SlotLayoutConfig>{
            Breakpoints.small: SlotLayout.from(
              key: const Key('Bottom Navigation'),
              builder: (_) => bottomNavigationBarBuilder,
            ),
            Breakpoints.medium: SlotLayout.from(
              key: const Key('Bottom Navigation'),
              builder: (_) => bottomNavigationBarBuilder,
            )
          },
        ),
        // 主体
        body: SlotLayout(
          config: <Breakpoint, SlotLayoutConfig>{
            Breakpoints.standard: SlotLayout.from(
              key: const Key('Primary Body Small'),
              builder: (_) => destinations[
                      state is WetlandStateSelectedDestination
                          ? state.index
                          : (state as WetlandStateInitial).index]
                  .page,
            ),
          },
        ),
        // 次要主体
        secondaryBody: SlotLayout(
          config: <Breakpoint, SlotLayoutConfig>{
            Breakpoints.mediumLargeAndUp: SlotLayout.from(
              key: const Key('Secondary Body'),
              builder: (_) => placeholderPage,
            ),
          },
        ),
      ),
    );
  }
}
