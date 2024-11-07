import "package:flutter/material.dart";
import "package:flutter_adaptive_scaffold/flutter_adaptive_scaffold.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/wetland_cubit.dart";
import "../utils/destination.dart";

class WetlandPrimaryNavigation extends StatelessWidget {
  final List<TabDestination> destinations;
  const WetlandPrimaryNavigation({super.key, required this.destinations});

  @override
  Widget build(BuildContext context) {
    // 导航栏主题
    final selectedIconTheme = Theme.of(context).iconTheme.copyWith(
          color: Theme.of(context).colorScheme.primary, // 使用主题中的主要颜色
        );
    final unselectedIconTheme = Theme.of(context).iconTheme.copyWith(
          color: Theme.of(context).colorScheme.onSurface, // 使用主题中的次要颜色
        );
    final selectedLabelTextStyle =
        Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.primary, // 选中的标签颜色
              fontWeight: FontWeight.bold, // 可选，设置字体加粗
            );
    final unSelectedLabelTextStyle =
        Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Theme.of(context).colorScheme.onSurface, // 未选中的标签颜色
            );

    return BlocBuilder<WetlandCubit, WetlandState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            //导航栏右侧增加竖线
            border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5)),
          ),
          child: AdaptiveScaffold.standardNavigationRail(
            leading: Padding(
                padding: const EdgeInsets.all(20.0), child: CircleAvatar()),
            padding: EdgeInsets.zero,
            width: 74,
            labelType: NavigationRailLabelType.all, // 标题显示方式
            selectedIconTheme: selectedIconTheme,
            unselectedIconTheme: unselectedIconTheme,
            selectedLabelTextStyle: selectedLabelTextStyle,
            unSelectedLabelTextStyle: unSelectedLabelTextStyle,
            destinations: destinations
                .map(
                  (e) => NavigationRailDestination(
                    label: Text(e.label),
                    icon: e.icon,
                    selectedIcon: e.selectedIcon,
                  ),
                )
                .toList(),
            selectedIndex: state is WetlandStateSelectedDestination
                ? state.index
                : (state as WetlandStateInitial).index,
            onDestinationSelected: (e) =>
                context.read<WetlandCubit>().changeDestination(e),
          ),
        );
      },
    );
  }
}
