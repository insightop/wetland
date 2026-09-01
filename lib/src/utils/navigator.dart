import "package:flutter/material.dart";
import "package:auto_route/auto_route.dart";

import "package:flutter_logcat/flutter_logcat.dart";

final GlobalKey<NavigatorState> primaryNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'primaryNavigator');
final GlobalKey<NavigatorState> secondaryNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'secondaryNavigator');

/// Extend WetlandNavigator to BuildContext
///
/// Convenient way to get WetlandNavigator from BuildContext,
/// and push and pop routes.
/// Like `context.wetland.push(route)` or `context.wetland.pop()`
extension WetlandNavigationExtension on BuildContext {
  WetlandNavigator get wetland => WetlandNavigator(this,
      primaryNavigatorKey: primaryNavigatorKey,
      secondaryNavigatorKey: secondaryNavigatorKey);
}

class WetlandNavigator {
  final BuildContext context;
  final GlobalKey<NavigatorState> primaryNavigatorKey;
  final GlobalKey<NavigatorState> secondaryNavigatorKey;

  WetlandNavigator(
    this.context, {
    required this.primaryNavigatorKey,
    required this.secondaryNavigatorKey,
  });

  // static WetlandNavigator of(BuildContext context) {
  //   return WetlandNavigator(context,
  //       primaryNavigatorKey: primaryNavigatorKey,
  //       secondaryNavigatorKey: secondaryNavigatorKey);
  // }

  Future<T?> push<T extends Object?>(PageRouteInfo<dynamic> route) async {
    // 判断secondaryBody是否活跃
    if (secondaryNavigatorKey.currentState != null) {
      Log.d('Push [${route.routeName}] to [SecondaryBody]');
      return await AutoRouter.of(secondaryNavigatorKey.currentState!.context)
          .push<T>(route);
      // TODO:判断来源是否为secondaryBody
    } else {
      Log.d('Push [${route.routeName}] to [PrimaryBody]');
      return await AutoRouter.of(context).push<T>(route);
      // context.router.push<T>(route);
    }
  }

  void pop<T extends Object?>([T? result]) {
    context.router.pop<T>(result);
  }
}

//! 重要！！ 堆栈push原则！！
//! 只要secondaryBody活跃，就push到secondaryBody，否则push到primaryBody
//! 可以同时适配平板和手机的布局
