import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class RouterObserver extends AutoRouterObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('New route pushed: ${route.settings.name}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('Route popped: ${route.settings.name}');
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    debugPrint('Route removed: ${route.settings.name}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint('Route replaced: ${newRoute?.settings.name}');
  }

  @override
  void didStartUserGesture(Route route, Route? previousRoute) {
    debugPrint('User gesture started: ${route.settings.name}');
  }

  @override
  void didStopUserGesture() {
    debugPrint('User gesture stopped');
  }

  // only override to observer tab routes
  @override
  void didInitTabRoute(TabPageRoute route, TabPageRoute? previousRoute) {
    debugPrint('Tab route visited: ${route.name}');
  }

  @override
  void didChangeTabRoute(TabPageRoute route, TabPageRoute previousRoute) {
    debugPrint('Tab route re-visited: ${route.name}');
  }
}
