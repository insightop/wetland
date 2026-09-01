import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/wetland_bloc.dart";
import "../utils/destination.dart";

class BottomNavigation extends StatelessWidget {
  final List<TabDestination> destinations;
  const BottomNavigation(this.destinations, {super.key});

  @override
  Widget build(BuildContext context) {
    // 导航栏主题
    final selectedIconTheme = Theme.of(context).iconTheme.copyWith(
      color: Theme.of(context).colorScheme.primary, // 使用主题中的主要颜色
    );
    final unselectedIconTheme = Theme.of(context).iconTheme.copyWith(
      color: Theme.of(context).colorScheme.onSurface, // 使用主题中的次要颜色
    );
    final selectedLabelTextStyle = Theme.of(context).textTheme.bodySmall!
        .copyWith(
          color: Theme.of(context).colorScheme.primary, // 选中的标签颜色
          fontWeight: FontWeight.bold, // 可选，设置字体加粗
        );
    final unSelectedLabelTextStyle = Theme.of(context).textTheme.bodySmall!
        .copyWith(
          color: Theme.of(context).colorScheme.onSurface, // 未选中的标签颜色
        );

    return BlocBuilder<WetlandBloc, WetlandState>(
      builder: (context, state) {
        return BottomNavigationBar(
          selectedLabelStyle: selectedLabelTextStyle,
          unselectedLabelStyle: unSelectedLabelTextStyle,
          selectedIconTheme: selectedIconTheme,
          unselectedIconTheme: unselectedIconTheme,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          landscapeLayout: BottomNavigationBarLandscapeLayout
              .linear, // centered, spread, linear
          currentIndex: state.index < destinations.length
              ? state.index
              : destinations.isEmpty
                  ? 0
                  : destinations.length - 1,
          items: destinations
              .map(
                (e) => BottomNavigationBarItem(
                  label: e.label,
                  icon: e.icon,
                  activeIcon: e.selectedIcon,
                ),
              )
              .toList(),
          onTap: (e) =>
              context.read<WetlandBloc>().add(WetlandEvent.setIndex(e)),
        );
      },
    );
  }
}

// // 底部导航
// final bottomNavigationBarBuilder =
//     AdaptiveScaffold.standardBottomNavigationBar(
//         height: 60,
//         selectedIconTheme: selectedIconTheme,
//         unselectedIconTheme: unselectedIconTheme,
//         selectedLabelTextStyle: selectedLabelTextStyle,
//         unSelectedLabelTextStyle: unSelectedLabelTextStyle,
//         destinations: destinations
//             .map((e) => NavigationDestination(
//                   label: e.label,
//                   icon: e.icon,
//                   selectedIcon: e.selectedIcon,
//                 ))
//             .toList(),
//         currentIndex: context.watch<RootBloc>().state
//                 is RootStateSelectedNavigation
//             ? (context.watch<RootBloc>().state
//                     as RootStateSelectedNavigation)
//                 .index
//             : (context.watch<RootBloc>().state as RootStateInitial).index,
//         onDestinationSelected: (e) =>
//             context.read<RootBloc>().add(RootEventSelectedNavigation(e)));

//     Builder(
//   builder: (BuildContext context) {
//     return BottomNavigationBar(
//         showSelectedLabels: false,
//         showUnselectedLabels: false,
//         type: BottomNavigationBarType.fixed,
//         landscapeLayout: BottomNavigationBarLandscapeLayout.linear,
//         // centered
//         // spread
//         // linear
//         currentIndex: context.watch<WetlandBloc>().state
//                 is WetlandStateSelectedNavigation
//             ? (context.watch<WetlandBloc>().state
//                     as WetlandStateSelectedNavigation)
//                 .index
//             : (context.watch<WetlandBloc>().state as WetlandStateInitial).index,
//         items: destinations
//             .map((e) => BottomNavigationBarItem(
//                   label: e.label,
//                   icon: e.icon,
//                   activeIcon: e.selectedIcon,
//                 ))
//             .toList(),
//         onTap: (e) {
//           context.read<WetlandBloc>().add(WetlandEventSelectedNavigation(e));
//         });
//   },
// );
