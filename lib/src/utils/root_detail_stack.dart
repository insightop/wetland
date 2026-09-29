import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_logcat/flutter_logcat.dart";

/// 单栏（竖屏）下承载「全屏详情」的宿主。
///
/// ## 为什么需要它
///
/// 单栏详情必须是**根 navigator 上的一条真实路由**，才能同时满足两件事：
/// 全屏覆盖（含底部导航）与原生 push/pop 过渡。但它**不能按名字推入**：
/// auto_route 的 `StackRouter.push` 经 `_findStackScope` 按路由名解析目标，
/// 而根下每个 tab 都有一个 `NestedStackRouter`（且 key/matchId 相同），
/// 详情路由又注册在这些嵌套集合里，于是会被截获进最后一个嵌套栈 ——
/// 实测表现为 `L2` 完全不可见、详情被压进嵌套栈而非根栈。
///
/// 因此这里改为**显式匹配**（[candidates] 依次尝试）拿到 `RouteMatch`，构造绑定
/// 到根 router 的 [RouteData]，再直接调用 `root.navigatorKey.currentState.push`。
/// 这条路径绕开按名解析，也就同时消掉了旧实现里「等根成为 top-most」的轮询。
///
/// ## 为什么要把页面内容包回 Wetland 子树
///
/// 根级路由挂在 Wetland **之上**，天然看不到 `WetlandScope` / `WetlandBloc`。
/// 若不包回去，详情内部 `context.wetland.push`（下钻）会因 `scope == null`
/// 退回「按名 push」，从而**再次被嵌套 router 截获**（已实测）。因此推入时把
/// 页面内容包一层 `BlocProvider.value` + [WetlandScope]，让根级详情在导航语义上
/// 仍是 Wetland 子树的一部分：下钻继续走根栈、pop 也命中根栈顶部。
///
/// 代价（已记录于 design.md）：绕过 auto_route 的 `NavigationHistory`，
/// 单栏详情不同步 web URL；移动端与桌面端不受影响。
class RootDetailStack {
  /// 候选路由集合（按优先级：当前 tab → 其余嵌套 → 根）。
  ///
  /// 由 [Wetland] 提供。用「候选集合」而非「按名 push」，是因为同名路由可能
  /// 同时存在于多个集合中，只有显式匹配才能确定用它构造根级路由。
  final List<StackRouter> Function() candidates;

  /// 把根级详情的内容包回 Wetland 语义子树（scope + bloc 可用）。
  ///
  /// 由 `Wetland` 注入：根级路由挂在 Wetland 之上，天然看不到 WetlandScope /
  /// WetlandBloc。不包回去的话，详情内部 `context.wetland.push`（下钻）会因
  /// `scope == null` 退回按名 push，从而被嵌套 router 截获（已实测下钻不可见）。
  final Widget Function(Widget child) wrapChild;

  RootDetailStack({required this.candidates, required this.wrapChild});

  /// 已推入根 navigator 的详情条目（按推入顺序）。
  final List<_RootDetailEntry> _entries = [];

  /// 根 navigator 上是否存在由本宿主托管的详情。
  bool get hasDetail => _entries.isNotEmpty;

  /// 已托管详情的路由信息（供模式切换时迁移回双栏使用）。
  List<PageRouteInfo<dynamic>> get routeInfos =>
      _entries.map((e) => e.data.route.toPageRouteInfo()).toList();

  /// 最顶部托管详情的**入场过渡结束**信号（迁移时用于等待其真正上台）。
  ///
  /// 若根侧详情尚未入场完成就移除源侧详情，会出现「源已空、根侧仍未绘制」的空白帧。
  ///
  /// 注意**不能**用 `TransitionRoute.completed`：它只在路由 `dispose` 时完成
  /// （Flutter 源码 routes.dart:637），等它再移除源会死锁（实测迁移永不收尾、
  /// 源详情一直留着）。这里监听入场动画，在其 `completed` 时立即发出信号。
  Future<void> get topRouteEntered {
    final route = _entries.isEmpty ? null : _entries.last.route;
    final animation = route is TransitionRoute ? route.animation : null;
    if (animation == null || animation.status == AnimationStatus.completed) {
      return Future<void>.value();
    }
    final completer = Completer<void>();
    void listener(AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        animation.removeStatusListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    }

    animation.addStatusListener(listener);
    return completer.future;
  }

  /// 调用方是否位于本宿主托管的某条根级详情内部。
  ///
  /// 用于区分「从列表页进入详情」（替换既有详情栈，与双栏 secondary 一致）
  /// 与「详情内下钻」（叠加）。判定依据是最近的 [RouteDataScope] 是否为本宿主
  /// 创建的那份 [RouteData] —— 比查找 `NavigatorState` 更精确，不受嵌套层级影响。
  bool isInsideRootDetail(BuildContext context) {
    final scope = context.findAncestorWidgetOfExactType<RouteDataScope>();
    if (scope == null) return false;
    return _entries.any((e) => identical(e.data, scope.routeData));
  }

  /// 把详情推入根 navigator。
  ///
  /// [replace] 为 true 时先清空既有托管详情（语义：从列表页进入详情，
  /// 与双栏 secondary 的 `replaceAll` 一致）；为 false 时叠加（详情内下钻）。
  Future<T?> push<T extends Object?>(
    BuildContext context,
    PageRouteInfo<dynamic> route, {
    bool replace = false,
  }) {
    if (replace) removeAll();
    return _pushRoute<T>(context, route);
  }

  /// 依次推入多条详情（模式切换迁移用），**不替换**既有栈。
  ///
  /// 注意：`Navigator.push` 返回的 Future 直到该路由被 pop 才完成，因此这里
  /// 绝不 await —— 否则迁移会永久挂起。
  void pushAll(
    BuildContext context,
    List<PageRouteInfo<dynamic>> routes,
  ) {
    for (final route in routes) {
      _pushRoute<void>(context, route);
    }
  }

  /// 弹出根 navigator 上最顶部的托管详情。
  void pop<T extends Object?>([T? result]) {
    if (_entries.isEmpty) return;
    _entries.last.route.navigator?.pop(result);
  }

  /// 从根 navigator 移除全部托管详情（迁移到双栏后调用）。
  void removeAll() {
    for (final entry in _entries) {
      entry.route.navigator?.removeRoute(entry.route);
    }
    _entries.clear();
  }


  /// 构造根级全屏详情使用的 [RouteType]。
  ///
  /// 需要同时满足两个条件：
  ///
  /// 1. **非不透明**：不透明根路由会让其下整棵 Wetland 子树 offstage，停用其
  ///    ticker，`AdaptiveLayout` 的过渡因此**永久冻结在中间几何**（实测 body 卡在
  ///    110.6，pop 时才突跳到 390）。
  /// 2. **保留平台过渡动画**：不能只写 `opaque: false` —— auto_route 的
  ///    [CustomRouteType] 在 `transitionsBuilder` 为 null 时使用
  ///    `_defaultTransitionsBuilder`，它**原样返回 child**（无任何动画）。实测
  ///    表现为单栏 push 时详情从第一帧就在终点位置，即"硬切换"。
  ///
  /// 因此这里用 `customRouteBuilder` 自行构造 [PageRouteBuilder]：`opaque: false`，
  /// 过渡则**委托给应用的 `PageTransitionsTheme`**（iOS/macOS→Cupertino、
  /// Android→Material，也尊重应用自定义的 transitions 主题），从而与原生观感一致。
  static RouteType _rootDetailRouteType(RouteType type) {
    // 已经是非不透明：保持调用方的原始配置（含其过渡）。
    if (!type.opaque) return type;
    // 调用方用 CustomRouteType 显式给了过渡：尊重它，只关掉不透明。
    if (type is CustomRouteType && type.transitionsBuilder != null) {
      return RouteType.custom(
        opaque: false,
        transitionsBuilder: type.transitionsBuilder,
        duration: type.duration,
        reverseDuration: type.reverseDuration,
      );
    }
    return RouteType.custom(
      opaque: false,
      customRouteBuilder: <T>(BuildContext context, Widget child, AutoRoutePage<T> page) {
        // `late` 自引用：transitionsBuilder 在路由构建完成后的布局阶段才被调用，
        // 此时 `route` 已赋值。这是能同时拿到"路由实例"（PageTransitionsTheme
        // 需要它）与自定义 opaque 的最小写法。
        late PageRouteBuilder<T> route;
        route = PageRouteBuilder<T>(
          settings: page,
          opaque: false,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (_, __, ___) => child,
          transitionsBuilder: (ctx, animation, secondaryAnimation, content) =>
              Theme.of(ctx).pageTransitionsTheme.buildTransitions<T>(
            route,
            ctx,
            animation,
            secondaryAnimation,
            content,
          ),
        );
        return route;
      },
    );
  }

  /// 在候选集合中按名查找匹配项。
  RouteMatch? _match(PageRouteInfo<dynamic> route) {
    for (final router in candidates()) {
      final match = router.matcher.matchByRoute(route);
      if (match != null) return match;
    }
    return null;
  }

  Future<T?> _pushRoute<T extends Object?>(
    BuildContext context,
    PageRouteInfo<dynamic> route,
  ) {
    final root = AutoRouter.of(context).root;
    final navigator = root.navigatorKey.currentState;
    final match = _match(route) ?? root.matcher.matchByRoute(route);
    if (match == null || navigator == null) {
      // 路由未注册或根 navigator 尚未挂载：退回最近 router，保证调用仍可用。
      Log.w(
        'Cannot resolve [${route.routeName}] for root full-screen detail;'
        ' falling back to nearest router',
      );
      return AutoRouter.of(context).push<T>(route);
    }
    final data = RouteData(
      route: match,
      router: root,
      stackKey: root.key,
      pendingChildren: const [],
      // 用**非不透明** RouteType（见 [_nonOpaque]）。
      //
      // 根级**不透明**路由会让覆盖层之下的一切 offstage（Flutter `Overlay` 的
      // `_Theatre` 对顶层 opaque entry 之下的子树置 offstage），Wetland 子树的
      // ticker 因此被停用：`TickerMode.of` 由 true 变 false（已实测）。后果是
      // `AdaptiveLayout` 的过渡**永久冻结在中间几何** —— 实测横→竖后 body 卡在
      // 110.6，pop 时才突跳到 390（用户可见的跳变）。
      //
      // 改为非不透明后：ticker 保持启用、布局照常平滑过渡（实测 111→390 连续），
      // 且因为详情自带全屏 Scaffold 背景，视觉上仍完整覆盖屏幕。
      type: _rootDetailRouteType(match.type ?? root.defaultRouteType),
    );
    // 用同一份 RouteData 重建页面，并把内容包回 Wetland 子树（见类文档）。
    final page = data.buildPage<T>();
    final rootRoute = AutoRoutePage<T>(
      routeData: data,
      child: wrapChild(page.child),
    ).createRoute(context);
    final entry = _RootDetailEntry(data: data, route: rootRoute);
    _entries.add(entry);
    // pop 与 removeRoute 都会完成 popped，两种清理路径都能触发记账出栈。
    rootRoute.popped.whenComplete(() {
      _entries.removeWhere((e) => identical(e, entry));
    });
    Log.d('Push [${route.routeName}] to root navigator (full-screen detail)');
    return navigator.push<T>(rootRoute);
  }

}

/// 一条托管在根 navigator 上的详情。
class _RootDetailEntry {
  _RootDetailEntry({required this.data, required this.route});

  /// 该详情的路由数据（构造根级路由时创建）。
  final RouteData data;

  /// 推入根 navigator 的原生路由。
  final Route<dynamic> route;
}
