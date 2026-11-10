// 6.x 的导航栏由 `material_ui` 渲染，直接使用该包导出的 Material 与导航类型，
// 避免同时混入 SDK 的 `flutter/material`（两套同名类型不能混用）。
import "package:custom_adaptive_scaffold/custom_adaptive_scaffold.dart";
import "package:custom_adaptive_scaffold/material_ui.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "../blocs/wetland_bloc.dart";
import "../utils/destination.dart";

/// 横屏（dual 模式）下的左侧主导航栏。
///
/// 根据 [destinations] 渲染导航项，点击时通过 [WetlandBloc] 切换当前主 tab。
class PrimaryNavigation extends StatelessWidget {
  /// 主导航栏的固定宽度。
  static const double _railWidth = 74;

  /// 主导航的 tab 配置列表。
  final List<TabDestination> destinations;

  /// 导航栏顶部自定义组件。
  final Widget? leading;

  /// 导航栏底部自定义组件。
  final Widget? trailing;

  const PrimaryNavigation(
    this.destinations, {
    this.leading,
    this.trailing,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WetlandBloc, WetlandState>(
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            //导航栏右侧增加竖线
            border: Border(
              right: BorderSide(color: Colors.grey.shade300, width: 0.1),
            ),
          ),
          // 选中态样式沿用 Material 3 默认值（指示器 + onSecondaryContainer 图标），
          // 由宿主 app 的 Theme 驱动，不再手写 M2 的 selected/unselected 覆盖。
          child: AdaptiveScaffold.standardNavigationRail(
            leading: leading,
            trailing: trailing,
            padding: EdgeInsets.zero,
            width: _railWidth,
            labelType: NavigationRailLabelType.all, // 标题显示方式
            destinations: destinations
                .map(
                  (e) => NavigationDestination(
                    label: e.label,
                    icon: e.icon,
                    selectedIcon: e.selectedIcon,
                  ),
                )
                .toList(),
            selectedIndex: state.index < destinations.length
                ? state.index
                : destinations.isEmpty
                    ? null
                    : destinations.length - 1,
            onDestinationSelected: (e) =>
                context.read<WetlandBloc>().add(WetlandEvent.setIndex(e)),
          ),
        );
      },
    );
  }
}
