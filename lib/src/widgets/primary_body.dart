import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// 主内容（primary body）导航容器。
///
/// 用 [AutoRouter] 包裹 [page]，使主内容页也能参与路由导航。
class PrimaryBody extends StatelessWidget {
  /// 主内容导航器的 key。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 主内容页。
  final Widget page;

  const PrimaryBody({
    super.key,
    required this.navigatorKey,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return AutoRouter(
      navigatorKey: navigatorKey,
      builder: (_, __) => page,
      // placeholder: (_) => page,
    );
  }
}
