import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// 右侧详情（secondary）导航容器。
///
/// 每个主 tab 一个独立的 [AutoRouter]，各自维护独立的详情栈，
/// 因此切换主 tab 时详情栈不丢失。
class SecondaryBody extends StatefulWidget {
  /// 该 secondary 导航器的 key。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 挂载后可安全读取 [StackRouter] 时回调（用于 mode 迁移等）。
  final void Function(int index, StackRouter router)? onRouterReady;

  /// 该 secondary 在 destinations 中的下标。
  final int? index;

  /// 详情栈为空时显示的占位页（如引导文案）。
  final WidgetBuilder? placeholder;

  const SecondaryBody({
    super.key,
    required this.navigatorKey,
    this.onRouterReady,
    this.index,
    this.placeholder,
  });

  @override
  State<SecondaryBody> createState() => _SecondaryBodyState();
}

class _SecondaryBodyState extends State<SecondaryBody> {
  @override
  void initState() {
    super.initState();
    // 不能在 initState 里同步拿 router：初始帧 Navigator 尚未挂载，且首次 build
    // 期间做 ancestor 查找会触发 "Looking up a deactivated widget's ancestor"。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryCaptureRouter(attempt: 0);
    });
  }

  /// 反复尝试捕获当前 tab 的 [NestedStackRouter]。
  ///
  /// 不能直接用 [AutoRouter.of] 的当前 [context]——SecondaryBody 的 context 位于它
  /// 自己的 [AutoRouter] 之上，解析到的是根 AppRouter（上一级 scope）。必须从
  /// navigatorKey 的 NavigatorState.context（位于该 AutoRouter 内部）向上解析，
  /// 才能拿到当前 tab 对应的 NestedStackRouter。
  ///
  /// 需要重试的原因：初始帧 [Navigator] 尚未挂载（hasEntries=false 时
  /// [AutoRouteNavigator] 只渲染 placeholder，不创建 Navigator），必须等 initial
  /// 路由入栈、Navigator 挂载后才能解析。每次都在稳定的 post-frame 里做，并在
  /// Navigator 已 unmount（旋转 rebuild 中被卸载）时放弃本轮，等下一帧再试。
  void _tryCaptureRouter({required int attempt}) {
    if (!mounted || attempt > 20) return;
    final navigator = widget.navigatorKey.currentState;
    if (navigator == null || !navigator.mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _tryCaptureRouter(attempt: attempt + 1);
      });
      return;
    }
    final router = AutoRouter.of(navigator.context);
    widget.onRouterReady?.call(widget.index ?? -1, router);
  }

  /// 判断该 router 是否「只剩外壳页」——即详情栈里没有任何用户详情。
  ///
  /// wetland 约定：secondary 的子路由集合首项是一条 `path: ''` 的外壳路由，
  /// 它的唯一职责是让 nested [Navigator] 存在（见 `lib/src/utils/navigator.dart`
  /// 的 replace 逻辑：push 时保留栈底外壳页、只替换其上的详情层）。
  ///
  /// 因此判定条件为「栈中恰好只有一条空路径的外壳页」：
  /// - 栈长 > 1 —— 外壳页之上还有详情，不是空态；
  /// - 栈长 == 1 但该页路径非空 —— 调用方没配外壳页，而把某个真实页面作为
  ///   初始子路由，此时应正常显示该页面，不能被默认画面覆盖；
  /// - 栈为空 —— 调用方完全没配外壳页，交给 auto_route 自身的 `placeholder`
  ///   处理（见 [AutoRouteNavigator]），避免同一占位被渲染两次。
  bool _isShellOnly(StackRouter router) {
    final stack = router.stack;
    if (stack.length != 1) return false;
    return stack.first.routeData.route.hasEmptyPath;
  }

  /// [AutoRouter.builder] 回调：在 Navigator 之上叠加用户定制的默认画面。
  ///
  /// [AutoRouter] 把 `builder` 包在 [StackRouterScope] 之内
  /// （auto_route `auto_router.dart:184-191`），因此这里的 [context] 可解析到
  /// 当前 secondary 自己的 [StackRouter]，而不是上一级的 AppRouter。
  ///
  /// 为什么用叠加而不是替换：若在空态时直接返回 [placeholder] 而丢掉
  /// `navigator`，nested [Navigator] 会被移出 widget 树，
  /// `widget.navigatorKey.currentState` 随之变为 null，导致
  /// `context.wetland.push` 走「secondary 未挂载」分支、把详情误推进 primary
  /// （横屏下详情变成全屏覆盖，右侧双栏失效）。因此必须让 Navigator 常驻树上。
  ///
  /// 覆盖层用 [ColoredBox]（命中行为 opaque）承载，既能遮住外壳页，也能吸收
  /// 点击，避免用户误触到被遮住的外壳页。
  Widget _buildWithPlaceholder(BuildContext context, Widget navigator) {
    final router = AutoRouter.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        navigator,
        // 保持 children 形状稳定（空态只是多一个覆盖层），
        // 避免 Navigator 在「空态 ↔ 有详情」之间切换时被重新挂载。
        if (_isShellOnly(router))
          ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: widget.placeholder!(context),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AutoRouter(
      navigatorKey: widget.navigatorKey,
      placeholder: widget.placeholder,
      builder: widget.placeholder == null ? null : _buildWithPlaceholder,
    );
  }
}
