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
          //! Detail（横屏 secondary 详情栈使用：Home child collection）
          AutoRoute(page: DetailRoute.page),
        ]),
        //! Detail（竖屏全屏详情使用：根级 route，覆盖底部导航）
        //! 与 Home 下的 Detail 同名分属不同 collection，互不冲突。
        //! 竖屏时 secondary 未挂载，wetland push 落到根 router，命中此根级 Detail；
        //! 横屏时 wetland push 落到当前 tab 的 secondary router，命中 Home 下的 Detail。
        AutoRoute(page: DetailRoute.page),
      ];
}
