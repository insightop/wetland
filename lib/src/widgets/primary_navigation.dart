import "package:flutter/material.dart" hide NavigationDestination;
import "package:custom_adaptive_scaffold/custom_adaptive_scaffold.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/wetland_bloc.dart";
import "../utils/destination.dart";

class PrimaryNavigation extends StatelessWidget {
  final List<TabDestination> destinations;
  final Widget? leading;
  final Widget? trailing;
  const PrimaryNavigation(
    this.destinations, {
    this.leading,
    this.trailing,
    super.key,
  });

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
        return Container(
          decoration: BoxDecoration(
            //导航栏右侧增加竖线
            border: Border(
              right: BorderSide(color: Colors.grey.shade300, width: 0.1),
            ),
          ),
          child: AdaptiveScaffold.standardNavigationRail(
            // backgroundColor:
            //     Theme.of(context).colorScheme.surface.withAlpha(250),
            leading: leading,
            trailing: trailing,
            padding: EdgeInsets.zero,
            width: 74, //74
            labelType: NavigationRailLabelType.all, // 标题显示方式
            selectedIconTheme: selectedIconTheme,
            unselectedIconTheme: unselectedIconTheme,
            selectedLabelTextStyle: selectedLabelTextStyle,
            unSelectedLabelTextStyle: unSelectedLabelTextStyle,
            destinations: destinations
                .map(
                  (e) => NavigationDestination(
                    label: e.label,
                    icon: e.icon,
                    selectedIcon: e.selectedIcon,
                  ),
                )
                .toList(),
            selectedIndex: state.index,
            onDestinationSelected: (e) =>
                context.read<WetlandBloc>().add(WetlandEvent.setIndex(e)),
          ),
        );
      },
    );
  }
}
