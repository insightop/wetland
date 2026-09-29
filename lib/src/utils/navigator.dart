import "package:flutter/material.dart";
import "package:auto_route/auto_route.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_logcat/flutter_logcat.dart";

import "../blocs/wetland_bloc.dart";
import "wetland_scope.dart";

/// 主内容导航器的全局 key（预留，供 primary 导航使用）。
final GlobalKey<NavigatorState> primaryNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'primaryNavigator');

/// 扩展 [BuildContext] 以便捷获取 [WetlandNavigator]。
///
/// 用法：`context.wetland.push(route)` 或 `context.wetland.pop()`。
extension WetlandNavigationExtension on BuildContext {
  WetlandNavigator get wetland => WetlandNavigator(this);
}

/// 面向 wetland 的导航助手。
///
/// 根据调用来源与当前布局模式，把路由推入正确的导航栈：
/// - 单栏（竖屏）：推入**根 navigator**，成为覆盖全屏（含底部导航）的真实路由，
///   因此进入/退出都是原生 push/pop 过渡。详见 `RootDetailStack`。
/// - 双栏（横屏）：推入当前主 tab 的 secondary 详情栈，右侧并排展示。
class WetlandNavigator {
  final BuildContext context;

  WetlandNavigator(this.context);

  Future<T?> push<T extends Object?>(PageRouteInfo<dynamic> route) async {
    final scope = WetlandScope.maybeOf(context);
    // 不在 Wetland 子树内（无 scope，必然也无 bloc），直接推入最近 router。
    if (scope == null) {
      Log.d('Push [${route.routeName}] to [RootNavigator] (outside scope)');
      return await AutoRouter.of(context).push<T>(route);
    }
    final state = context.read<WetlandBloc>().state;
    final index = state.index;
    final key = (index < scope.secondaryKeys.length)
        ? scope.secondaryKeys[index]
        : null;

    // 单栏（竖屏）：详情推入根 navigator，成为全屏路由（覆盖底部导航），
    // 进出均为原生 push/pop。判定用 mode 而非「key 是否可用」：嵌套 navigator
    // 在单栏下依然挂载，只看 key 会误判为双栏。
    if (state.mode == WetlandMode.single) {
      final rootDetails = scope.rootDetails;
      if (rootDetails != null) {
        final fromDetail = rootDetails.isInsideRootDetail(context);
        Log.d('Push [${route.routeName}] to [RootDetailStack]'
            ' (single, ${fromDetail ? 'drill-down' : 'replace'})');
        return await rootDetails.push<T>(context, route, replace: !fromDetail);
      }
      Log.d('Push [${route.routeName}] to [RootNavigator] (single, no host)');
      return await AutoRouter.of(context).push<T>(route);
    }

    if (key == null || key.currentState == null) {
      // 双栏但 secondary 尚未就绪：退回最近 router。
      Log.d('Push [${route.routeName}] to [PrimaryBody]');
      return await AutoRouter.of(context).push<T>(route);
    }
    final secondaryRouter = AutoRouter.of(key.currentState!.context);
    // 判断来源：若调用 push 的 context 就在当前 tab 的 secondary navigator 内，
    // 说明是详情页内下钻，应叠加 push；否则（来自 primary body 主列表）应清空
    // 当前 tab 的 secondary 栈并替换为最新详情。
    final nearestNavigator = context.findAncestorStateOfType<NavigatorState>();
    final fromSecondary = nearestNavigator != null &&
        scope.secondaryKeys.any((k) => k.currentState == nearestNavigator);
    if (fromSecondary) {
      Log.d('Push [${route.routeName}] to [SecondaryBody#$index] (drill-down)');
      return await secondaryRouter.push<T>(route);
    } else {
      Log.d('Push [${route.routeName}] to [SecondaryBody#$index] (replace)');
      // 保留栈底的外壳页（nested router 的初始页），只替换其上的详情层，
      // 这样 pop 详情后能回到外壳页，而不会落到空栈。
      final stack = secondaryRouter.stack;
      final shell = stack.isNotEmpty
          ? [stack.first.routeData.route.toPageRouteInfo()]
          : <PageRouteInfo>[];
      await secondaryRouter.replaceAll([...shell, route]);
      return null;
    }
  }

  void pop<T extends Object?>([T? result]) {
    final scope = WetlandScope.maybeOf(context);
    if (scope == null) {
      context.router.pop<T>(result);
      return;
    }
    final state = context.read<WetlandBloc>().state;
    // 单栏：详情在根 navigator 上，pop 根栈顶部。
    if (state.mode == WetlandMode.single) {
      final rootDetails = scope.rootDetails;
      if (rootDetails != null && rootDetails.hasDetail) {
        rootDetails.pop<T>(result);
        return;
      }
      context.router.pop<T>(result);
      return;
    }
    final index = state.index;
    final key = (index < scope.secondaryKeys.length)
        ? scope.secondaryKeys[index]
        : null;
    final target = (key != null && key.currentState != null)
        ? key.currentState!.context
        : context;
    AutoRouter.of(target).pop<T>(result);
  }
}

//! 重要！！ 堆栈push原则！！
//! 单栏（竖屏）：详情推入根 navigator，全屏覆盖并走原生 push/pop；
//! 双栏（横屏）：详情推入当前 tab 的 secondaryBody，右侧并排展示。
//! 可以同时适配平板和手机的布局
