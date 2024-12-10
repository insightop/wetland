import "package:flutter/material.dart";
import "package:auto_route/auto_route.dart";

final GlobalKey<NavigatorState> primaryNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'primaryNavigator');
final GlobalKey<NavigatorState> secondaryNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'secondaryNavigator');

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

  Future<void> push(PageRouteInfo<dynamic> route) async {
    // 判断secondaryBody是否活跃
    if (secondaryNavigatorKey.currentState != null) {
      debugPrint('push to secondaryBody');
      AutoRouter.of(secondaryNavigatorKey.currentState!.context).push(route);
    } else {
      debugPrint('push to primaryBody');
      // AutoRouter.of(context).push(route);
      context.router.push(route);
    }
  }

  void pop() {
    context.router.popForced();
  }
}


//! 重要！！ 堆栈push原则！！
//! 只要secondaryBody活跃，就push到secondaryBody，否则push到primaryBody
//! 可以同时适配平板和手机的布局