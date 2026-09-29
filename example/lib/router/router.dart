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
          //! Placeholder
          AutoRoute(path: '', page: PlaceholderRoute.page),
          //! Messages
          AutoRoute(page: MessagesRoute.page),
          //! Contacts
          AutoRoute(page: ContactsRoute.page),
          //! Mine
          AutoRoute(page: MineRoute.page),
          //! Detail：**只声明一次**。
          //!
          //! 单栏（竖屏）时由 wetland 把它推入根 navigator，成为全屏真路由；
          //! 双栏（横屏）时推入当前 tab 的 secondary 详情栈。库内部通过显式匹配
          //! （而非按名解析）决定目标，因此**无需**为了竖屏全屏再声明一条根级
          //! 同名路由。
          AutoRoute(page: DetailRoute.page),
        ]),
      ];
}
