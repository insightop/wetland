import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// 右侧详情（secondary）导航容器。
///
/// 每个主 tab 一个独立的 [AutoRouter]，各自维护独立的详情栈，
/// 因此切换主 tab 时详情栈不丢失。
class SecondaryBody extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  /// 挂载后可安全读取 [StackRouter] 时回调（用于 mode 迁移等）。
  final void Function(int index, StackRouter router)? onRouterReady;
  /// 该 secondary 在 destinations 中的下标。
  final int? index;

  const SecondaryBody({
    super.key,
    required this.navigatorKey,
    this.onRouterReady,
    this.index,
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

  @override
  Widget build(BuildContext context) {
    return AutoRouter(
      navigatorKey: widget.navigatorKey,
    );
  }
}
