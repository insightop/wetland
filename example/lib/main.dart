import 'package:flutter/material.dart';
import 'package:wetland_example/router/observer.dart';

import './router/router.dart';

void main() {
  runApp(WetlandExampleApp());
}

class WetlandExampleApp extends StatelessWidget {
  const WetlandExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: AppRouter().config(
        navigatorObservers: () => [RouterObserver()],
      ),
    );
  }
}
