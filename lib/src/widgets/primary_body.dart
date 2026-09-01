import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class PrimaryBody extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
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
