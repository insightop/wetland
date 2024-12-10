import 'package:auto_route/auto_route.dart';

import './router.gr.dart';
export './router.gr.dart';

@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
        //! Login
        AutoRoute(page: LoginRoute.page),
        //! Home
        AutoRoute(page: HomeRoute.page, initial: true, children: [
          //! Messages
          AutoRoute(page: MessagesRoute.page),
          //! Contacts
          AutoRoute(page: ContactsRoute.page),
          //! Mine
          AutoRoute(page: MineRoute.page),
          //! Detail
          AutoRoute(page: DetailRoute.page),
        ]),
      ];
}
