import 'package:flutter/material.dart';

/// 向 Wetland 子树暴露每个主 tab 对应的 secondary navigator key 列表。
///
/// 由 [Wetland] 组件在 build 时注入，供 [WetlandNavigator] 等后代读取，
/// 以决定 push 到哪个 secondary 详情栈。
class WetlandScope extends InheritedWidget {
  /// 每个主 tab 对应的 secondary navigator key。
  final List<GlobalKey<NavigatorState>> secondaryKeys;

  const WetlandScope({
    super.key,
    required this.secondaryKeys,
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
    return secondaryKeys != oldWidget.secondaryKeys;
  }
}
