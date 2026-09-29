import 'package:flutter/material.dart';

import 'root_detail_stack.dart';

/// 向 Wetland 子树暴露每个主 tab 对应的 secondary navigator key 列表。
///
/// 由 [Wetland] 组件在 build 时注入，供 [WetlandNavigator] 等后代读取，
/// 以决定 push 到哪个 secondary 详情栈。
class WetlandScope extends InheritedWidget {
  /// 每个主 tab 对应的 secondary navigator key。
  final List<GlobalKey<NavigatorState>> secondaryKeys;

  /// 单栏（竖屏）全屏详情的宿主。
  ///
  /// 单栏下详情挂在根 navigator 上；[WetlandNavigator] 通过它把详情推入根栈、
  /// 并判断「当前是否已在某条根级详情内部」（决定替换还是下钻）。
  /// 双栏模式下该宿主始终为空栈，不影响原有行为。
  final RootDetailStack? rootDetails;

  const WetlandScope({
    super.key,
    required this.secondaryKeys,
    this.rootDetails,
    required super.child,
  });

  /// 在 build 中使用，注册依赖，scope 变化时触发重建。
  static WetlandScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WetlandScope>();
    assert(scope != null, 'No WetlandScope found in context');
    return scope!;
  }

  /// 在事件回调（非 build）中使用，不注册依赖。
  static WetlandScope? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<WetlandScope>();
  }

  @override
  bool updateShouldNotify(WetlandScope oldWidget) {
    return secondaryKeys != oldWidget.secondaryKeys ||
        rootDetails != oldWidget.rootDetails;
  }
}
