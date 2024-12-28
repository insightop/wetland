import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class SecondaryBody extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const SecondaryBody({
    super.key,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return AutoRouter(
      navigatorKey: navigatorKey,
      // placeholder: (_) => placeholder,
    );
  }
}
        // return Navigator(
        // observers: Observers.instances,
        // initialRoute: '/preset',
        // pages: allPages,
        // key: (state is WetlandState.pageState)
        //     ? state.secondaryBodyKey
        //     : (state as WetlandStateInitial).secondaryBodyKey,
        // onGenerateRoute: (settings) {
        // debugPrint('onGenerateRoute: ${settings}');
        // final route = routes.firstWhere((e) => e.name == settings.name,
        //     orElse: () =>
        //         routes.firstWhere((e) => e.path == '/placeholder'));
        // return MaterialPageRoute(
        //   settings: settings,
        //   builder: (context) => route.builder!,
        // );
        // },
        // );
// context,
// GoRouterState(
//   RouteConfiguration(
//     ValueNotifier(RoutingConfig(routes: routes)),
//     navigatorKey: GlobalKey<NavigatorState>(),
//   ),
//   uri: Uri.parse(settings.name!),
//   fullPath: settings.name!,
//   pathParameters: {},
//   matchedLocation: settings.name!,
//   pageKey: ValueKey(settings.name!),
// ),

// onGenerateRoute: (settings) {
//   final Widget page;
//   if (settings.name == routeHome) {
//     page = const HomeScreen();
//   } else if (settings.name == routeSettings) {
//     page = const SettingsScreen();
//   } else if (settings.name!.startsWith(routePrefixDeviceSetup)) {
//     final subRoute =
//         settings.name!.substring(routePrefixDeviceSetup.length);
//     page = SetupFlow(
//       setupPageRoute: subRoute,
//     );
//   } else {
//     throw Exception('Unknown route: ${settings.name}');
//   }

//   return MaterialPageRoute<dynamic>(
//     builder: (context) {
//       return page;
//     },
//     settings: settings,
//   );
// },

// debugPrint('onGenerateRoute: ${settings.name}');
// RootController.updateSecondaryBodyCurrentRoute(settings.name!);
// final route =
//     secondaryPages.firstWhere((page) => page.name == settings.name,
//         orElse: () => secondaryPages.firstWhere(
//               (page) => page.name == RouteNames.preset,
//             )); // 在所有页面中查找 name 与 settings.name 相同的页面
// //! 非常重要的代码，解决secondary页面无法传递参数的问题,相关讨论：
// //! https://github.com/jonataslaw/getx/issues/2935
// //! https://github.com/jonataslaw/getx/issues/179
// Get.routing.args = settings.arguments;
// return GetPageRoute(
//   settings: settings,
//   page: route.page,
//   binding: route.binding,
//   bindings: route.bindings,
// );
