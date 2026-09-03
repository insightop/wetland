import "package:flutter/material.dart";
import "package:auto_route/auto_route.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_logcat/flutter_logcat.dart";

import "../blocs/wetland_bloc.dart";
import "wetland_scope.dart";

final GlobalKey<NavigatorState> primaryNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'primaryNavigator');

/// Extend WetlandNavigator to BuildContext
///
/// Convenient way to get WetlandNavigator from BuildContext,
/// and push and pop routes.
/// Like `context.wetland.push(route)` or `context.wetland.pop()`
extension WetlandNavigationExtension on BuildContext {
  WetlandNavigator get wetland => WetlandNavigator(this);
}

class WetlandNavigator {
  final BuildContext context;

  WetlandNavigator(this.context);

  Future<T?> push<T extends Object?>(PageRouteInfo<dynamic> route) async {
    final scope = WetlandScope.maybeOf(context);
    // 不在 Wetland 子树内（无 scope，必然也无 bloc），直接推入 primary。
    if (scope == null) {
      Log.d('Push [${route.routeName}] to [PrimaryBody]');
      return await AutoRouter.of(context).push<T>(route);
    }
    final index = context.read<WetlandBloc>().state.index;
    final key = (index < scope.secondaryKeys.length)
        ? scope.secondaryKeys[index]
        : null;
    if (key == null || key.currentState == null) {
      // 竖屏（secondary 未挂载）或 key 无效：推入 primary。
      Log.d('Push [${route.routeName}] to [PrimaryBody]');
      return await AutoRouter.of(context).push<T>(route);
    }
    final secondaryRouter = AutoRouter.of(key.currentState!.context);
    // 判断来源：若调用 push 的 context 就在当前 tab 的 secondary navigator 内，
    // 说明是详情页内下钻，应叠加 push；否则（来自 primary body 主列表）应清空
    // 当前 tab 的 secondary 栈并替换为最新详情。
    final nearestNavigator = context.findAncestorStateOfType<NavigatorState>();
    final fromSecondary = nearestNavigator != null &&
        scope.secondaryKeys.any((k) => k.currentState == nearestNavigator);
    if (fromSecondary) {
      Log.d('Push [${route.routeName}] to [SecondaryBody#$index] (drill-down)');
      return await secondaryRouter.push<T>(route);
    } else {
      Log.d('Push [${route.routeName}] to [SecondaryBody#$index] (replace)');
      await secondaryRouter.replaceAll([route]);
      return null;
    }
  }

  void pop<T extends Object?>([T? result]) {
    final scope = WetlandScope.maybeOf(context);
    if (scope == null) {
      context.router.pop<T>(result);
      return;
    }
    final index = context.read<WetlandBloc>().state.index;
    final key = (index < scope.secondaryKeys.length)
        ? scope.secondaryKeys[index]
        : null;
    final target = (key != null && key.currentState != null)
        ? key.currentState!.context
        : context;
    AutoRouter.of(target).pop<T>(result);
  }
}

//! 重要！！ 堆栈push原则！！
//! 只要secondaryBody活跃，就push到当前tab对应的secondaryBody，否则push到primaryBody
//! 可以同时适配平板和手机的布局
