import 'package:flutter/material.dart';

/// 描述一个主 tab 的配置：标签、图标与对应的主内容页。
///
/// 传给 [Wetland] 的 `destinations` 列表，用于构建左侧主导航（横屏）
/// 或底部导航（竖屏），并在中间 body 渲染对应的 [page]。
class TabDestination {
  /// 导航项显示的标签文本。
  final String label;

  /// 未选中时的图标。
  final Widget icon;

  /// 选中时的图标（可选，缺省时复用 [icon]）。
  final Widget? selectedIcon;

  /// 该 tab 对应的主内容页。
  final Widget page;

  TabDestination({
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.page,
  });
}
