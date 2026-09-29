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
    }

    // 从主列表进入详情：**替换**该 tab 上已有的详情层（与单栏 `replace` 一致），
    // 但保留栈底外壳页，pop 详情后回到外壳页而非空栈。
    //
    // 实现要点：不能再用 `replaceAll`。它内部走 `_pushAll`，而 `_pushAll` 创建页面
    // 时**不传 `popCompleter`**（auto_route `routing_controller.dart:787-805`），导致
    // `RouteData.popped` 立即以 null 完成 —— 详情的结果永远无法回传。实测表现为
    // 同一个 `await push<String>()` 在单栏返回 `'RET'`、双栏返回 `null`。
    //
    // 改为「先移除外壳页之上的详情层，再用带结果的 `push`」，语义与单栏、下钻一致：
    // 返回的 Future 在详情被 pop 时完成并携带结果。
    final stale = [
      for (var i = 1; i < secondaryRouter.stack.length; i++)
        secondaryRouter.stack[i].routeData,
    ];
    for (final entry in stale) {
      secondaryRouter.removeRoute(entry);
    }
    Log.d('Push [${route.routeName}] to [SecondaryBody#$index] (replace)');
    return await secondaryRouter.push<T>(route);
  }

  /// 当前是否**存在由本库托管的详情**可被 pop。
  ///
  /// 调用方可用它安全地守卫返回按钮：`canPop` 为 false 时不要调用 [pop]，
  /// 或改用 [maybePop]。判定只关注「本库自己的详情」，不涉及 destination 本身，
  /// 因此横竖屏语义一致。
  bool get canPop {
    final scope = WetlandScope.maybeOf(context);
    if (scope == null) return context.router.canPop();
    final state = context.read<WetlandBloc>().state;
    if (state.mode == WetlandMode.single) {
      return scope.rootDetails?.hasDetail ?? false;
    }
    return _secondaryDetailOf(scope, state.index).isNotEmpty;
  }

  /// 仅当存在本库托管的详情时才 pop，并返回是否真的 pop 了。
  ///
  /// 相当于「安全版 [pop]」：无详情时不做任何事并返回 false，绝不触碰
  /// destination 本身或其外壳页，因此可以无条件绑定到返回按钮。
  Future<bool> maybePop<T extends Object?>([T? result]) async {
    if (!canPop) return false;
    pop<T>(result);
    return true;
  }

  /// 弹出本库托管的详情。**只影响自己拥有的详情**：
  /// - 单栏：仅当根 navigator 上有托管的详情时才 pop；
  /// - 双栏：仅 pop 当前 tab 外壳页**之上**的详情层。
  ///
  /// 无可 pop 的详情时是 **no-op**（不弹 destination，也不弹外壳页）。
  ///
  /// 历史教训：旧实现会 fall through 到 `context.router.pop()`，实测在单栏
  /// destination 根页面上调用会**把整棵 Wetland 弹掉**（`Wetland` 存活 1→0、白屏、
  /// 无任何异常）；双栏空态则弹掉外壳页，导致此后推入的详情永远不可见。
  /// 也不能改用 auto_route 的 `maybePop`：它在本级 navigator 拒绝后会递归到
  /// `_parent`（`routing_controller.dart:1215-1225`），仍会弹出 destination。
  void pop<T extends Object?>([T? result]) {
    final scope = WetlandScope.maybeOf(context);
    if (scope == null) {
      // 不在 Wetland 子树内：没有可归属的详情，保持旧有直通行为。
      context.router.pop<T>(result);
      return;
    }
    final state = context.read<WetlandBloc>().state;
    // 单栏：详情在根 navigator 上。
    if (state.mode == WetlandMode.single) {
      final rootDetails = scope.rootDetails;
      if (rootDetails != null && rootDetails.hasDetail) {
        rootDetails.pop<T>(result);
        return;
      }
      // 无托管详情：no-op（绝不弹 destination）。
      Log.d('Pop ignored: no root detail owned (single)');
      return;
    }
    // 双栏：pop 外壳页之上的最顶层详情（`_secondaryDetailOf` 已排除外壳页）。
    final details = _secondaryDetailOf(scope, state.index);
    if (details.isEmpty) {
      Log.d('Pop ignored: no secondary detail above shell (dual)');
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

  /// 当前 tab 的 secondary 栈中**外壳页之上的详情层**（按栈序）。
  ///
  /// 与 `Wetland._detailEntriesOf` 同一约定：跳过 index 0 的外壳页与
  /// `autoFilled` 的父级壳，只返回用户真正打开的详情。
  List<RouteData> _secondaryDetailOf(WetlandScope scope, int index) {
    final key = (index < scope.secondaryKeys.length)
        ? scope.secondaryKeys[index]
        : null;
    final state = key?.currentState;
    if (state == null) return const [];
    final router = AutoRouter.of(state.context);
    return [
      for (var i = 1; i < router.stack.length; i++)
        if (!router.stack[i].routeData.route.autoFilled)
          router.stack[i].routeData,
    ];
  }
}

//! 重要！！ 堆栈push原则！！
//! 单栏（竖屏）：详情推入根 navigator，全屏覆盖并走原生 push/pop；
//! 双栏（横屏）：详情推入当前 tab 的 secondaryBody，右侧并排展示。
//! 可以同时适配平板和手机的布局
