import "package:auto_route/auto_route.dart";

/// wetland 约定：secondary 的子路由集合首项是一条 `path: ''` 的外壳路由
/// （如 `PlaceholderRoute`），它唯一的职责是让嵌套 `Navigator` 存在。
///
/// 见 `lib/src/utils/navigator.dart` 的 replace 逻辑：push 时保留栈底外壳页、
/// 只替换其上的详情层；因此「栈里恰好只有一条空路径页」等价于「没有用户详情」。
bool secondaryIsShellOnly(StackRouter? router) {
  if (router == null) return true;
  final stack = router.stack;
  if (stack.length != 1) return false;
  return stack.first.routeData.route.hasEmptyPath;
}

/// 当前 secondary 是否展示了用户详情（外壳页之外还有内容）。
///
/// 用于决定单栏布局下该由 body 还是 secondary 占满屏幕。
bool secondaryHasDetail(StackRouter? router) {
  if (router == null) return false;
  return !secondaryIsShellOnly(router);
}
