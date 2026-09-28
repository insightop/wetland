import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// 右侧详情（secondary）导航容器。
///
/// 每个主 tab 一个独立的 [AutoRouter]，各自维护独立的详情栈，
/// 因此切换主 tab 时详情栈不丢失。
///
/// **空态由 secondary 自己的外壳页承担**：约定子路由集合首项是一条
/// `path: ''` 的外壳路由（example 里是渲染 logo 的 `PlaceholderPage`）。
/// 它既让嵌套 [Navigator] 存在，也是「右侧还没有详情」时用户看到的画面。
/// 因此这里**不做任何覆盖**——有详情页时自然盖住外壳页，没有时自然显示它。
class SecondaryBody extends StatefulWidget {
  /// 该 secondary 导航器的 key。
  final GlobalKey<NavigatorState> navigatorKey;

  /// 挂载后可安全读取 [StackRouter] 时回调（用于记录 per-tab router）。
  final void Function(int index, StackRouter router)? onRouterReady;

  /// 该 secondary 在 destinations 中的下标。
  final int? index;

  /// 详情栈发生任何变化（push/pop/replace/remove）时回调。
  ///
  /// 用途：布局需要据此决定单栏下由 body 还是 secondary 占满屏幕。
  /// 用 [NavigatorObserver] 而非 `StackRouter` 的 ChangeNotifier —— 后者在
  /// auto_route 的 `onPopPage` 路径上不会 `notifyAll`，pop 时收不到通知。
  final VoidCallback? onStackChanged;

  const SecondaryBody({
    super.key,
    required this.navigatorKey,
    this.onRouterReady,
    this.index,
    this.onStackChanged,
  });

  @override
  State<SecondaryBody> createState() => _SecondaryBodyState();
}

class _SecondaryBodyState extends State<SecondaryBody> {
  /// 每次 build 都返回**全新**的 observer 实例。
  ///
  /// [AutoRouter.navigatorObservers] 的文档明确要求：一个 [NavigatorObserver]
  /// 实例只能被单个 Navigator 使用，复用到多个 Navigator 会触发断言。
  List<NavigatorObserver> _observers() => [
        _StackChangedObserver(onChanged: _onStackChanged),
      ];

  /// 栈变化后通知上层重算布局（单栏下由谁占满屏幕取决于此）。
  ///
  /// 延到本帧结束：这些事件可能在 build 期间触发，直接回调会让上层 `setState`
  /// 撞上 "setState() called during build"。
  void _onStackChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onStackChanged?.call();
    });
  }

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

  @override
  Widget build(BuildContext context) {
    return AutoRouter(
      navigatorKey: widget.navigatorKey,
      navigatorObservers: _observers,
    );
  }
}

/// 把 Navigator 的栈变化事件转成单一回调。
///
/// [NavigatorObserver] 是 Flutter 原生的导航事件源，相比 `StackRouter` 的
/// ChangeNotifier 更可靠：auto_route 在 `onPopPage` 路径上不会 `notifyAll`，
/// 仅靠监听 router 会漏掉 pop。
class _StackChangedObserver extends NavigatorObserver {
  _StackChangedObserver({required this.onChanged});

  /// 栈发生任意变化时调用。
  final VoidCallback onChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChanged();

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      onChanged();
}
