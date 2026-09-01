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
    if (key != null && key.currentState != null) {
      Log.d('Push [${route.routeName}] to [SecondaryBody#$index]');
      return await AutoRouter.of(key.currentState!.context).push<T>(route);
    } else {
      Log.d('Push [${route.routeName}] to [PrimaryBody]');
      return await AutoRouter.of(context).push<T>(route);
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
