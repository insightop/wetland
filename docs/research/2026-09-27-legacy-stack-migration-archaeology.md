# 旧「导航栈迁移」设计考古报告（single↔dual secondary↔primary 迁移）

> 目的：为「把单栏详情改回**外层全屏路由**（真正 push 覆盖 / pop 滑出），同时保留横→竖旋转不丢详情」提供一手历史证据。
>
> 调研范围：`/Users/bookshiyi/repos/wetland`，分支 `feat/native-adaptive-panel`，只读操作（`git show` / `git log` / `read` / `grep`）。所有引用均为 git 原文。
>
> 关键分界：**`98082f4`（2026-09-28 13:32）删除了整套迁移机制**。本报告称其父提交 `1f18bf5` 的状态为「旧架构终态」。经 `diff` 验证，`lib/` 在 `a9bcdef` 与 `98082f4^` 之间**完全一致**（`docs` 提交 `1f18bf5` 未改代码），因此下文「旧架构」的行号引用对 `a9bcdef` 也成立。

---

## 0. 相关提交一览（时间正序）

| SHA | 日期 | 主题 | 对本报告的意义 |
|---|---|---|---|
| `a118c66` | 09-27 | feat: 横转竖时把当前 tab 的 secondary 详情栈迁移到竖屏根栈 | **迁移机制首次引入**（dual→single 单向） |
| `ded31c7` | 09-27 | feat: Wetland 支持 secondaryPlaceholder 详情空态 | 引入 `secondaryPlaceholder`（透传 `AutoRouter.placeholder`） |
| `b23aa36` | 09-27 16:36 | feat(example): 补全核心能力演示（下钻/DRY/空态） | example 首次传入 `secondaryPlaceholder`；detail 页加 drill-down/pop |
| `7b0bb5f` | 09-27 17:31 | fix: replace 保留 secondary 外壳页，避免 pop 详情后黑屏 | **外壳页约定**的由来（`replaceAll([shell, route])`） |
| `164f74a` | 09-27 17:40 | fix: 迁移只取 secondary 详情层，空态不再误压 primary | 迁移取根规则：跳过 index 0 外壳页 + `autoFilled` |
| `ae06260` | 09-27 18:01 | feat: 详情仅剩外壳页时叠加 secondaryPlaceholder 默认画面 | placeholder 从 `AutoRouter.placeholder` 改为 `builder` 叠加；`_isShellOnly` |
| `5fb2f74` | 09-27 19:00 | fix: secondary 槽 in/out 动画同形，消除宽转窄时 primary 抢占地 | 同形动画（`_keepOnScreen`）缩短「两栈交接」空窗 |
| `a9bcdef` | 09-27 19:36 | feat: 窄转宽时全屏详情自动回填 secondary 双栏 | **反向回填**（single→dual），与迁移对称 |
| `1f18bf5` | 09-27 | docs: 补充 example 补全计划与空态/布局切换修复计划 | 旧架构代码终态（= `a9bcdef`） |
| `98082f4` | 09-28 13:32 | feat: 原生自适应面板布局，消除单⇄双栏过渡跳变 | **删除全部迁移**，改 `bodyRatio` 插值 |
| `46abdbe` | 09-28 | feat: 右侧空态改用外壳页，并补齐单⇄双栏过渡动画 | **删除 `secondaryPlaceholder`**（及覆盖层） |

---

## 1. 旧架构的迁移触发点（回答 Q2）

**触发点 = `_WetlandState.build` 里的 `BlocListener<WetlandBloc, WetlandState>` 的 `listener` 回调**，监听 `WetlandState.mode` 的**变化边沿**（不是监听导航栈），比较依据是成员变量 `_previousMode`。

`git show 1f18bf5:lib/src/wetland.dart`（= `98082f4^`）：

```dart
// L100-101
  /// 上一个 mode，用于监听 dual→single 迁移时机。
  WetlandMode _previousMode = WetlandMode.dual;

// L147-181
      child: BlocListener<WetlandBloc, WetlandState>(
        listener: (context, state) {
          _applySystemUi(state.mode);
          // 从 dual 切到 single（横转竖）：把当前 tab 的 secondary 详情栈迁移到根。
          if (_previousMode == WetlandMode.dual &&              // L151
              state.mode == WetlandMode.single) {
            final tabIndex =
                _safeIndex(state.index, widget.destinations?.length ?? 0);
            // post-frame 时 secondary 已随竖屏卸载，但 captured controller 的
            // stack 仍保留迁移前的详情序列，此时读取安全。
            final router =
                (tabIndex < _secondaryRouters.length)
                    ? _secondaryRouters[tabIndex]
                    : null;
            WidgetsBinding.instance.addPostFrameCallback((_) {   // L161
              if (!mounted) return;
              _migrateSecondaryToPrimary(context, tabIndex, router);
            });
          }
          // 从 single 切到 dual（竖转横）：把根栈上的详情回填到当前 tab 的
          // secondary，使变宽后立即呈现左右双栏。
          if (_previousMode == WetlandMode.single &&             // L168
              state.mode == WetlandMode.dual) {
            final tabIndex =
                _safeIndex(state.index, widget.destinations?.length ?? 0);
            WidgetsBinding.instance.addPostFrameCallback((_) {   // L175
              if (!mounted) return;
              _backfillPrimaryToSecondary(context, tabIndex, attempt: 0);
            });
          }
          _previousMode = state.mode;                            // L180
        },
```

要点：

- **监听的状态**：`WetlandBloc` 的 `mode`（`WetlandMode.dual` / `WetlandMode.single`，见 `lib/src/blocs/wetland_bloc.dart:10-16`）。**不是**监听导航栈变化。
- **`mode` 从哪来**：`mode` 由槽位 builder 在 build 期间派发 —— `Breakpoints.small/medium` 的 bottomNavigation builder 调 `_setMode(context, WetlandMode.single)`，`Breakpoints.mediumLargeAndUp` 的 primaryNavigation builder 调 `_setMode(context, WetlandMode.dual)`（`1f18bf5:lib/src/wetland.dart` L200-240 附近；`_setMode` 只在 `bloc.state.mode != mode` 时派发，避免 build 循环，L304-310）。
- **在 build 还是 post-frame**：判断在 `BlocListener`（build 阶段）里做，但**实际迁移动作在 `addPostFrameCallback` 里**执行。原因见注释：post-frame 时 secondary 已随竖屏卸载，而 captured controller 的 `stack` 仍保留迁移前序列。
- **router 引用是"提前捕获"的**：`_secondaryRouters[tabIndex]` 由 `SecondaryBody` 在挂载时经 `onRouterReady` 上报并缓存（见下节），因此槽位卸载后仍能读到迁移前的栈。这是旧设计的关键前提。

---

## 2. 迁移的具体做法（回答 Q3）

### 2.1 取出 secondary 的详情路由 —— `_migrateSecondaryToPrimary`

`git show 98082f4^:lib/src/wetland.dart`，方法从 **L324 开始到 L353 结束**（`a118c66` 首次引入，`164f74a` 加入外壳页过滤）：

```dart
// L324-353  【98082f4^ 原文】
  /// 把当前 tab 的 secondary 详情栈迁移到根 router 顶部，使竖屏根栈顶部为当前详情页。
  ///
  /// 详情序列只取 [tabIndex] 对应的 per-tab [NestedStackRouter] 栈里**真实详情页**：
  /// - 跳过栈底的外壳页（index 0，nested router 的初始 `PlaceholderRoute`，
  ///   它只负责让 secondary 的 `Navigator` 存在，不是用户选中的详情）；
  /// - 跳过 `autoFilled` 的页（Home 这类由 auto_route 自动补齐的父级壳）。
  ///
  /// 仅当过滤后仍有详情时才迁移，因此空态（栈里只有外壳页）不会误把
  /// primary 再压一层。这些详情直接以自身的 [PageRouteInfo] push 到根 router ——
  /// 根 collection 里已存在同名的根级详情 route（如 DetailRoute），因此不会
  /// buildPathTo 重复补齐 Home。
  void _migrateSecondaryToPrimary(BuildContext context, int tabIndex,
      StackRouter? router) {
    if (router == null) return;
    final stack = router.stack;
    if (stack.length <= 1) return; // 只有外壳页 = 无详情，无需迁移
    final detailRoutes = <PageRouteInfo>[];
    for (var i = 0; i < stack.length; i++) {
      if (i == 0) continue; // 跳过栈底外壳页（Navigator 载体）
      final rt = stack[i].routeData.route;
      if (rt.autoFilled) continue; // 跳过 Home 等自动补齐的父级壳
      detailRoutes.add(rt.toPageRouteInfo());
    }
    if (detailRoutes.isEmpty) return;
    Log.d('Migrate ${detailRoutes.length} detail route(s) from secondary'
        ' (tab #$tabIndex) to portrait root stack:'
        ' ${detailRoutes.map((r) => r.routeName).toList()}');
    final rootRouter = AutoRouter.of(context).root;
    _pushToRootWhenTopMost(rootRouter, detailRoutes, attempt: 0);
  }
```

**用到的 auto_route API（取出阶段）**：

| API | 用途 | 一手位置 |
|---|---|---|
| `StackRouter.stack` → `List<RouteMatch>` | 读取 secondary 当前栈 | 上方 L338 |
| `RouteMatch.routeData.route` → `PageRouteInfo` | 拿到每层的路由描述对象（含 `routeName` / `autoFilled` / `args`） | L343 |
| `PageRouteInfo.toPageRouteInfo()` | 把 `RouteMatch` 反推回**可重新 push 的 `PageRouteInfo`**（保留 path/args） | L345 |
| `RootStackRouter.pushAll(List<PageRouteInfo>)` | 一次把整条详情序列压到根栈 | L462 |
| `RootStackRouter.isTopMost` | 轮询条件 | L456 |

### 2.2 塞进 primary —— `_pushToRootWhenTopMost`（L433-463）

```dart
// L433-463  【98082f4^ 原文】
  /// 等根 router 成为 top-most 后再把 [routes] push 到根栈。
  ///
  /// 旋转瞬间 secondaryBody 的 NestedStackRouter 尚未完全 dispose，仍挂在根 router
  /// 的 childControllers 下。此时直接 `rootRouter.pushAll` 会经 auto_route 的
  /// `_findStackScope` 解析到最内层仍存活的 router（它能处理同名的 DetailRoute），
  /// 导致详情被压进已卸载的 tab 壳而非根栈。必须等这些 secondary router 全部卸载、
  /// 根 router 成为 top-most 后，push 才会命中根级 DetailRoute。
  ///
  /// disposal 会在竖屏布局切换动画（transitionDuration，默认 1000ms）结束后发生，
  /// 因此用帧率无关的宽松重试上限覆盖整个过渡期，一旦 root 成为 top-most 立即迁移。
  void _pushToRootWhenTopMost(
    RootStackRouter rootRouter,
    List<PageRouteInfo> routes, {
    required int attempt,
  }) {
    // 300 帧 ≈ 5s@60fps，足以覆盖默认 1000ms 过渡期及二次分发后剩余帧。
    if (attempt > 300) {
      Log.w(
        'Abandon migrating ${routes.length} detail route(s) to portrait root:'
        ' root never became top-most after $attempt frames',
      );
      return;
    }
    if (!rootRouter.isTopMost) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pushToRootWhenTopMost(rootRouter, routes, attempt: attempt + 1);
      });
      return;
    }
    rootRouter.pushAll(routes);
  }
```

**为什么必须轮询 `isTopMost`**：`pushAll` 内部走 `_findStackScope(routes.first)`，会解析到**最内层仍存活的 router**（验证：`auto_route-11.1.0/lib/src/router/controller/routing_controller.dart:1418-1428`，`pushAll` 第一行即 `return _findStackScope(routes.first)._pushAll(...)`）。而 `isTopMost => this == _topMostRouter()`（同文件 `:411`）。`childControllers` 是公开 getter（`:68`）。

### 2.3 反向回填 —— `_backfillPrimaryToSecondary`（`a9bcdef` 引入，L355-431）

```dart
// L378-431  【98082f4^ 原文，节选核心】
  void _backfillPrimaryToSecondary(
    BuildContext context,
    int tabIndex, {
    required int attempt,
  }) {
    // 300 帧 ≈ 5s@60fps，与迁移重试上限一致，足以覆盖 1000ms 过渡期。
    if (attempt > 300) { /* Log.w ... */ return; }
    // 无 destinations（[Wetland.primaryBody] 模式）时根本没有 secondary，
    // 直接返回，避免无意义地空转重试。……
    if (_secondaryRouters.isEmpty) return;
    final rootRouter = AutoRouter.of(context).root;
    final rootStack = rootRouter.stack;
    if (rootStack.length <= 1) return; // 只有首页/tab 外壳 = 无详情
    final detailRoutes = <PageRouteInfo>[];
    final detailEntries = <RouteData>[];
    for (var i = 1; i < rootStack.length; i++) {
      final entry = rootStack[i];
      final rt = entry.routeData.route;
      if (rt.autoFilled) continue; // 跳过 Home 等自动补齐的父级壳
      detailRoutes.add(rt.toPageRouteInfo());
      detailEntries.add(entry.routeData);
    }
    if (detailRoutes.isEmpty) return;

    final router = (tabIndex < _secondaryRouters.length)
        ? _secondaryRouters[tabIndex]
        : null;
    if (router is! NestedStackRouter ||
        router.navigatorKey.currentState == null ||
        !rootRouter.childControllers.contains(router)) {   // L414
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _backfillPrimaryToSecondary(context, tabIndex, attempt: attempt + 1);
      });
      return;
    }

    Log.d('Backfill ...');
    // 先 push 再移除：两者都在同一帧内同步生效，任一帧都不会出现"两侧都没有
    // 详情"的空白中间态。
    router.pushAll(detailRoutes);                            // L427
    for (final entry in detailEntries.reversed) {
      rootRouter.removeRoute(entry);                         // L429
    }
  }
```

**回填用到的额外 API**：`NestedStackRouter`、`router.navigatorKey.currentState`、`RootStackRouter.childControllers.contains(router)`、`StackRouter.pushAll`、`RootStackRouter.removeRoute(RouteData)`。

**为什么先 push 再 remove**：注释原文（L425-426）「两者都在同一帧内同步生效，任一帧都不会出现"两侧都没有详情"的空白中间态」—— 这是防"详情闪失"的关键顺序约束。

### 2.4 per-tab router 的捕获（迁移的前置条件）

`a118c66` 把 `SecondaryBody` 从 `StatelessWidget` 改成 `StatefulWidget`，新增 `_tryCaptureRouter`（重试上限 20 帧）：

```dart
// 98082f4^:lib/src/widgets/secondary_body.dart  L55-66
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
```

`_WetlandState` 侧：

```dart
// 98082f4^:lib/src/wetland.dart  L312-322
  void _onSecondaryRouterReady(int index, StackRouter router) {
    if (index < 0 || index >= _secondaryRouters.length) return;
    // 只接受每个 tab 的 NestedStackRouter。旋转重建的瞬时帧里 AutoRouter.of 可能
    // 解析到根 AppRouter（RootStackRouter），若存下来会覆盖 per-tab 引用，导致迁移
    // 目标错误。
    if (router is! NestedStackRouter) return;
    _secondaryRouters[index] = router;
  }
```

> 该 `_onSecondaryRouterReady` + 类型守卫**至今仍存在**于 `lib/src/wetland.dart:373-377`，只是注释里删掉了「用于迁移」的说法。

---

## 3. 外壳页（shell）的跳过与保住（回答 Q4）

### 3.1 约定本身来自 `7b0bb5f`

`git show 7b0bb5f -- lib/src/utils/navigator.dart`：

```diff
       Log.d('Push [${route.routeName}] to [SecondaryBody#$index] (replace)');
-      await secondaryRouter.replaceAll([route]);
+      // 保留栈底的外壳页（nested router 的初始页），只替换其上的详情层，
+      // 这样 pop 详情后能回到外壳页，而不会落到空栈。
+      final stack = secondaryRouter.stack;
+      final shell = stack.isNotEmpty
+          ? [stack.first.routeData.route.toPageRouteInfo()]
+          : <PageRouteInfo>[];
+      await secondaryRouter.replaceAll([...shell, route]);
       return null;
```

commit message 原文：「`replaceAll([route])` 会把嵌套 router 的外壳页（初始路由）一并清掉，导致 pop 详情后 secondary 栈为空：auto_route 此时渲染空 Container（黑屏），且 `navigatorKey.currentState` 变 null 使后续 push 误入 primary。改为保留栈底外壳页、只替换其上的详情层。」

**该 `replaceAll([shell, route])` 逻辑至今保留**：`lib/src/utils/navigator.dart:57-65`。

### 3.2 迁移侧跳过外壳页 = `164f74a`

`git show 164f74a -- lib/src/wetland.dart`（diff 原文）：

```diff
   void _migrateSecondaryToPrimary(BuildContext context, int tabIndex,
       StackRouter? router) {
     if (router == null) return;
+    final stack = router.stack;
+    if (stack.length <= 1) return; // 只有外壳页 = 无详情，无需迁移
     final detailRoutes = <PageRouteInfo>[];
-    for (final page in router.stack) {
-      final rt = page.routeData.route;
+    for (var i = 0; i < stack.length; i++) {
+      if (i == 0) continue; // 跳过栈底外壳页（Navigator 载体）
+      final rt = stack[i].routeData.route;
       if (rt.autoFilled) continue; // 跳过 Home 等自动补齐的父级壳
       detailRoutes.add(rt.toPageRouteInfo());
     }
```

commit message 原文：「空态时 secondary 栈为 `[PlaceholderRoute]`（外壳页），其 `autoFilled=false` 被误判为真实详情并迁移到根栈，auto_route 随即补出 `[HomeRoute, HomeRoute(autoFilled=true)]`，表现为缩窄时多 push 一层 primary。现跳过栈底外壳页与 autoFilled 页，仅在确有详情时迁移。」

> 结论：**旧迁移用两种互不等价的判据** ——「index 0 一律跳过」（迁移侧）与「`stack.length == 1 && hasEmptyPath`（外壳页判定）」（placeholder/新架构侧）。二者在 example 里等价，但语义不同。

### 3.3 `secondaryIsShellOnly` / `secondaryHasDetail` 是为**谁**写的？

时间线证据：

- `ae06260`（09-27 18:01）在 `lib/src/widgets/secondary_body.dart` 里新增了一个 `_isShellOnly(StackRouter router)` **私有方法**（用 `hasEmptyPath`），供 `_buildWithPlaceholder` 判断是否叠加 `secondaryPlaceholder` 覆盖层。它**不是**为迁移写的，而是为 placeholder 覆盖层写的。
- `98082f4`（09-28 13:32）**新增** `lib/src/utils/secondary_stack.dart`，把同一判据提升为公共函数 `secondaryIsShellOnly` / `secondaryHasDetail`。commit message 原文：「新增 secondary_stack.dart：secondaryIsShellOnly / secondaryHasDetail」。
- 同一提交 `98082f4` 里，`wetland.dart` 同时**删除了 `_migrateSecondaryToPrimary` / `_backfillPrimaryToSecondary` / `_pushToRootWhenTopMost`**，并把新函数接到 `_currentTabHasDetail` → `_targetBodyRatio` 上。
- `git show 98082f4:lib/src/widgets/secondary_body.dart` 确认：**同一时刻 `_isShellOnly` 与 `secondary_stack.dart` 的 `secondaryIsShellOnly` 并存**（前者在 `secondary_body.dart:106-109`，后者在新文件），是重复实现。
- `46abdbe` 删掉了 `secondary_body.dart` 里的 `_isShellOnly` 与 `_buildWithPlaceholder`，重复消除。

**所以**：`secondary_stack.dart` 的两个函数**不是**为「导航栈迁移」写的，而是 `98082f4` **取代迁移方案**后新引入的布局判据（决定单栏下由 body 还是 secondary 占满屏幕）。

**现在还有谁在用**（`grep` 全仓 `.dart`，排除 build 产物）：

```
lib/src/wetland.dart:18:import "utils/secondary_stack.dart";
lib/src/wetland.dart:389:    return secondaryHasDetail(_secondaryRouters[safeIndex]);
lib/src/utils/secondary_stack.dart:8:bool secondaryIsShellOnly(StackRouter? router) {
lib/src/utils/secondary_stack.dart:18:bool secondaryHasDetail(StackRouter? router) {
```

即：**唯一生产使用者是 `_WetlandState._currentTabHasDetail`（`lib/src/wetland.dart:387-390`），它的唯一使用者是 `_targetBodyRatio`（同文件 `:400`），最终喂给 `AdaptiveLayout.bodyRatio`。** 没有测试直接引用这两个函数（库测试走的是 `test/secondary_shell_empty_state_test.dart` 的行为断言）。

---

## 4. 「避免重复 push」——两个测试在守护什么（回答 Q5）

> 两个文件**今天仍然存在**，但已在 `98082f4` 被**改写**成验证新架构；`diff` 确认它们自 `98082f4` 起至 HEAD 未再变动。

### 4.1 `example/test/shrink_no_extra_push_test.dart`

- **诞生**（`164f74a`，原文）：单例「横屏空态缩窄到竖屏，根栈不应多压一层」
  ```dart
  final root = AutoRouter.of(tester.element(find.text('Messages 0'))).root;
  final before = root.stack.length;
  tester.view.physicalSize = const Size(390, 844);
  await tester.pumpAndSettle();
  expect(root.stack.length, before, reason: '空态缩窄不应迁移任何路由到根栈');
  ```
  守护的是：**空态（secondary 只有外壳页）缩窄时不得把外壳页也迁移进根栈**。若迁移没跳过 index 0，auto_route 会补出 `[HomeRoute, HomeRoute(autoFilled=true)]`，根栈 +1 —— 即「多 push 一层 primary」。
- **`98082f4` 改写后**（HEAD 现状）：新增第二个用例「横屏有详情缩窄到竖屏，根栈恒等而详情仍在 secondary」，断言 `root.stack.length` 不变 **且** `LayoutId('body')` 宽度 < 1.0、`LayoutId('secondaryBody')` 宽度 > 390*0.9 —— 即证明"详情从未迁移进根栈，占满屏幕的是 secondary 槽本身"。

### 4.2 `example/test/expand_backfill_test.dart`

- **诞生**（`a9bcdef`，原文）：两条用例
  1. 「竖屏全屏详情时变宽，应自动回填 secondary 双栏」—— 断言变宽后同时看到 `Messages Detail `（右栏）、`Message`（左栏 tab）、`Messages 0`（中间列表）。
  2. 「竖屏全屏详情时变宽：不出现详情缺席的中间帧」—— 逐帧 `pump(16ms)` × 20，每帧断言详情可见。守护的是 `_backfillPrimaryToSecondary` 里「**先 pushAll 再 removeRoute**」的顺序约束（见 §2.3 L425-426）。
- **`98082f4` 改写后**（HEAD 现状）：改为断言「双栏几何 + secondary 槽常驻」，用 `LayoutId('body')` / `LayoutId('secondaryBody')` 的实测宽度替代文本 finder（注释理由：宽度为 0 的 widget 仍在树上）。用例名改为「应形成双栏，无需回填导航栈」「详情在过渡全程不缺席」。

**共同守护的本质**：迁移/回填都是"把一个栈的内容搬到另一个栈"，天然有**重复 push**（空态误迁）与**空白空窗**（两栈交接）两类风险。这两条测试是这两类风险的历史回归闸门。

---

## 5. `secondaryPlaceholder` 在迁移里扮演什么角色（回答 Q6）

### 5.1 角色：**与迁移无直接关系**，它是"secondary 空态画面"的 API

- `ded31c7` 引入 `Wetland.secondaryPlaceholder`（`WidgetBuilder?`），实现方式是**直接透传**给 `AutoRouter(placeholder: widget.placeholder)`：
  ```diff
  // ded31c7:lib/src/widgets/secondary_body.dart
     return AutoRouter(
       navigatorKey: widget.navigatorKey,
  +    placeholder: widget.placeholder,
     );
  ```
  语义是「详情栈**为空**时显示」。
- `ae06260` 发现 `AutoRouter.placeholder` 只在栈**完全为空**时生效，而 `7b0bb5f` 之后 secondary 栈恒有外壳页，于是改为 `AutoRouter.builder` 叠加覆盖层，并用 `_isShellOnly` 判定：
  ```dart
  // ae06260:lib/src/widgets/secondary_body.dart（原文）
  bool _isShellOnly(StackRouter router) {
    final stack = router.stack;
    if (stack.length != 1) return false;
    return stack.first.routeData.route.hasEmptyPath;
  }
  ```
  commit message 原文：「此前 secondary 初始栈恒为 `[PlaceholderRoute]`（外壳页），auto_route 只在栈为空时才渲染 placeholder，导致 `Wetland.secondaryPlaceholder` 永不生效。」
- `b23aa36` 在 example 的 `home_page.dart` 里首次传入它（引导文案 "Select an item to see details"）。

**与迁移的交集只有一处**：`ae06260` 的 `_isShellOnly` 与 `164f74a` 的「跳过 index 0 外壳页」是**同一约定的两处独立表达**；`98082f4` 把前者提升为 `secondary_stack.dart` 的公共函数，后者随迁移一起被删。

### 5.2 现在被删了吗？—— **是，已被完全删除**

- `46abdbe` 删除了公共 API `Wetland.secondaryPlaceholder`。commit message 原文：「移除 `Wetland.secondaryPlaceholder`（该 API 未发布到 pub.dev，0.1.0 不含，移除不破坏已发布接口）」。
- 同一提交删除了 `SecondaryBody.placeholder` 字段、`AutoRouter.placeholder` 透传、`builder: _buildWithPlaceholder`、`_isShellOnly`、以及 `_StackChangedObserver` 里专为同帧刷新覆盖层的 `onPop` 回调。
- `grep -rn "secondaryPlaceholder" lib test example/lib example/test` 现在只剩两处**注释/文档性引用**，无生产使用：
  - `example/test/secondary_shell_is_empty_state_test.dart:8`（历史说明）
  - `example/lib/pages/home_page.dart:50`（注释：无需再传）
- `lib/src/pages/default_placeholder_page.dart`（`DefaultPlaceholderPage`，一个空的 `Scaffold`）**文件仍在，但从未被使用** —— 唯一引用是 `lib/src/wetland.dart:110` 的注释行 `// this.placeholder = const DefaultPlaceholderPage(),`。它自 `108722a`（init 期）就存在，与本次迁移无关。

### 5.3 删除 `secondaryPlaceholder` 的真实理由（对本次重构是重要教训）

`46abdbe` commit message 原文：

> 问题：稳定态看不到 logo（被覆盖层遮住），反而在 push/pop secondary 时 logo 一闪而过 —— 与预期完全相反。
> 根因：`Wetland.secondaryPlaceholder` 会在空态叠一层覆盖层遮住外壳页；push 详情时覆盖层被**立即**移除，而详情路由还在过渡中，于是外壳页在过渡期间暴露出来。覆盖层本身才是闪现代理源。

现在空态由 **secondary 自己的外壳页**（router 约定 `path: ''` 的首项，example 里是渲染 logo 的 `PlaceholderPage`，`example/lib/router/router.dart:18`）承担。

---

## 6. `98082f4` 删除了什么（回答 Q7）

### 6.1 被删除的具体代码块（`lib/`，原文）

**A. `_previousMode` 字段**（`98082f4^:lib/src/wetland.dart:100-101`，删除后仅保留 `_secondaryRouters`）：

```dart
  /// 保存每个 tab 的 secondary [StackRouter] 引用。
  /// 在横屏 secondaryBody build 时写入；push/pop 后 controller 的 stack 仍最新，
  /// 转竖屏（widget 卸载）后仍能读到，用于迁移。
  final List<StackRouter?> _secondaryRouters = [];
  /// 上一个 mode，用于监听 dual→single 迁移时机。
  WetlandMode _previousMode = WetlandMode.dual;
```

**B. 整个 `BlocListener.listener`（L148-181）被塌缩为一行**（见 §1 已引全文）：

```diff
-        listener: (context, state) {
-          _applySystemUi(state.mode);
-          if (_previousMode == WetlandMode.dual && state.mode == WetlandMode.single) { ... }
-          if (_previousMode == WetlandMode.single && state.mode == WetlandMode.dual) { ... }
-          _previousMode = state.mode;
-        },
+        // 布局切换不再迁移导航栈：secondary 槽常驻挂载，单/双栏差异完全由
+        // [AdaptiveLayout.bodyRatio] 的动画插值表达（见下方 build）。
+        listener: (context, state) => _applySystemUi(state.mode),
```

**C. 三个方法整体删除**（`_migrateSecondaryToPrimary` L324-353、`_backfillPrimaryToSecondary` L355-431、`_pushToRootWhenTopMost` L433-463）—— 全文见 §2.1/2.2/2.3。

**D. secondary 槽从 `mediumLargeAndUp` 改为 `standard`，并包上 `_mountedSlot`**：

```diff
-                          Breakpoints.mediumLargeAndUp: SlotLayout.from(
+                          Breakpoints.standard: SlotLayout.from(
                             key: const Key('Secondary Body'),
-                            builder: (_) => IndexedStack(...),
+                            builder: (_) => _mountedSlot(IndexedStack(...)),
```

**E. `bodyRatio` 从常量 `0.35` 改为 `TweenAnimationBuilder` 插值**：

```diff
-              child: AdaptiveLayout(
-                //! 比例
-                bodyRatio: 0.35,
+              child: TweenAnimationBuilder<double>(
+                tween: Tween<double>(begin: targetRatio, end: targetRatio),
+                duration: widget.transitionDuration,
+                curve: Curves.easeInOutCubic,
+                builder: (context, ratio, child) => AdaptiveLayout(
+                  bodyRatio: ratio,
+                  internalAnimations: false,
```

并新增 `_currentTabHasDetail` / `_targetBodyRatio` / `_mountedSlot` / `_onSecondaryStackChanged`、`dart:math` import、`utils/secondary_stack.dart` import。commit message 原文：

> 方案：secondary 槽常驻挂载，单/双栏差异完全由 `AdaptiveLayout.bodyRatio` 表达：双栏 0.35 / 单栏有详情 0.0（详情占满）/ 单栏无详情 1.0（body 占满）
> 详情永远留在自己的 navigator 里，删除全部迁移逻辑（`_migrateSecondaryToPrimary` / `_backfillPrimaryToSecondary` / `_pushToRootWhenTopMost`）。
> 实测时间线（横→竖）：body 394→0、secondary 731→390 逐帧单调插值，全程无消失帧；旧方案在 t=1200ms secondary 卸载、t=1300ms 详情才以 primary 重现。

> 注：`internalAnimations: false` 在随后的 `46abdbe` 被改回 `true`（理由：`false` 会把框架内部 `AnimationController` 的 duration 置 0，margin 直接跳变、全部过渡动画失效）。HEAD 现状是 `lib/src/wetland.dart:212` `internalAnimations: true`。

### 6.2 计划文档里「为什么放弃迁移」的说明原文

`docs/superpowers/plans/2026-09-27-native-adaptive-panel.md` —— **该文件由 `98082f4` 本身新增**（`git log --diff-filter=A` 证实；`98082f4 -- docs/` 的 stat 为 `1 file changed, 322 insertions(+)`，而 `1f18bf5` 只加了另外两份计划），因此它是**新架构的决策记录**，不是旧架构的计划。关键原文：

**L5（Goal）：**
> 用 `custom_adaptive_scaffold` 的原生布局能力替换当前「布局切换后再迁移导航栈」的补丁方案，使单⇄双栏过渡**连续无跳变**：进详情/返回、变宽/缩窄都表现为同一条布局动画，不再有「primary 先占满、动画结束才 push 详情」的中间态。

**L16-19（用户反馈原话，即放弃迁移的直接动因）：**
> 1. 从双栏变单栏，最终 secondary 占满屏幕，但过程中有一个明显的 push 动作，而且基本是 primary 动画过渡结束占满屏幕才触发
> 2. 从单栏变双栏，初始 secondary 占满屏幕，这个好一些，貌似在 adaptive_scaffold 动画过渡过程中就开始 push 了，但是还稍微有点不连贯
> 「似乎是同一个问题…过渡动画不是基于是否有 secondary 进行执行过渡的，而像是我们打的补丁。我希望你看看 adaptive_scaffold 能否提供更原生的这种能力」

**L12（架构决策）：**
> 这样详情永远留在自己的 navigator 里，**不需要迁移导航栈**（已删除 `_migrateSecondaryToPrimary` / `_backfillPrimaryToSecondary` / `_pushToRootWhenTopMost`）。

**L80-81（改动清单）：**
> - 删除 `_migrateSecondaryToPrimary` / `_backfillPrimaryToSecondary` / `_pushToRootWhenTopMost` / `_previousMode`
> - `secondaryBody` 槽改用 `Breakpoints.standard`（常驻挂载）

**L114-116（测试处置）：**
> | `expand_backfill_test.dart` | 已改写为验证**双栏几何 + secondary 槽常驻**（不再验证已删的 backfill） |
> | `shrink_no_extra_push_test.dart` | 已改写为验证**根栈恒等 + 详情仍在 secondary**（不再验证已删的 migrate） |
> | `portrait_migration_test.dart` | 已更名 `portrait_rotate_keeps_detail_test.dart`，断言用户可见结果（无迁移） |

**L319-321（Self-Review 风险提示）：**
> - **`navigatorKey.currentState` 必须始终可用**（Task 1 的核心约束）。任何「移除子树」的优化都会导致竖屏 push 误入 primary。
> - `internalAnimations: false` 会让 `animatedSize` 失活 —— 这是 Task 2 要解决的核心障碍。
> - 判断可见性用**宽度**，不是 finder 命中（0 宽 widget 仍在树上）。

**另一份计划 `docs/superpowers/plans/2026-09-27-empty-state-and-layout-switch.md`（旧架构的需求基线）** L325-330：

```
横屏有详情 → 缩窄：detail=1, list=0, tab=0   ← 终态正确（详情全屏）
迁移日志：Migrate 2 routes: [PlaceholderRoute, DetailRoute]  ← 外壳页被误迁移
```
> 即**终态正确、但过渡期 primary 会先占满**（用户报告的体验问题），且外壳页被多余迁移。

以及 `docs/superpowers/plans/2026-09-26-portrait-stack-migration.md`（迁移的原始设计文档）L14-16：

> - 迁移目标：根 router 顶部 replaceAll/pushAll 详情序列。
> - 触发时机：BlocListener 监听 mode 变化（dual→single）。
> - 反向（竖转横）不做（YAGNI，仅覆盖用户确认的横→竖单方向）。
>
> 风险点（L86-88）：
> - secondary 槽位在 mode 变 single 的 build 中卸载、`currentState` 提前变 null → 需在 `_setMode`（build 早期）先快照，避免 post-frame 读取不到。
> - 反推的 detail `PageRouteInfo` name 为 `DetailRoute`，根 collection 顶层需存在（问题2 已具备）→ 若不具备会 `buildPathTo` 补 Home（重复 tab 壳 bug）。

---

## 7. 结论：重引入「单栏详情走外层全屏路由 + 旋转保留详情」的可复用性（回答 Q8）

### 7.1 语义差异必须先说清（这决定复用哪一半）

| | 旧迁移（`98082f4^`） | 现架构（HEAD） | 新需求 |
|---|---|---|---|
| 单栏详情的载体 | **根 router 的 push**（真正的 route，有 push/pop 过渡） | secondary 槽 + `bodyRatio = 0.0`（原地缩放） | 根 router 的 push |
| 详情路由在哪 | 横=secondary 栈；竖=根栈 | 永远在 secondary 栈 | 横=secondary；竖=根栈 |
| 旋转保留机制 | 显式迁移（+ 反向回填） | 不迁移，同一 router | 需要显式迁移 |

**新需求在导航语义上等同旧迁移**，差别只在旧迁移的触发时机与过渡观感（这正是 `98082f4` 要修的）。因此旧实现大体可直接复用。

### 7.2 可直接复用（代码今天就还在，只需接回调用点）

| 资产 | 位置（HEAD） | 说明 |
|---|---|---|
| `WetlandNavigator.push` 的「保留外壳页 + replace」 | `lib/src/utils/navigator.dart:57-65` | `replaceAll([shell, route])` 原样保留 |
| `WetlandNavigator.push` 的「来源判定」（下钻 vs 替换） | `lib/src/utils/navigator.dart:46-56` | `findAncestorStateOfType<NavigatorState>` + `scope.secondaryKeys` 比对 |
| `_onSecondaryRouterReady` + `is! NestedStackRouter` 守卫 | `lib/src/wetland.dart:373-377`（doc 从 370 起） | per-tab router 捕获，迁移的前置条件 |
| `SecondaryBody._tryCaptureRouter`（post-frame + 重试 20 帧） | `lib/src/widgets/secondary_body.dart:83-94` | 同一件事的挂载侧 |
| 外壳页约定与 `path: ''` 首项 | `example/lib/router/router.dart:18`；`lib/src/utils/navigator.dart:58-63` | 迁移跳过 index 0 的前提 |
| `secondaryIsShellOnly` / `secondaryHasDetail` | `lib/src/utils/secondary_stack.dart:8-21` | 判据可复用（但注意 §3.3 语义差异，见风险 3） |
| `_StackChangedObserver`（`NavigatorObserver`） | `lib/src/widgets/secondary_body.dart:105-131` | **比旧方案更好**：旧方案没有栈变化通知源（靠 `BlocListener` 边沿）；新方案可直接用它驱动"进入详情时才 push 根路由" |
| `WetlandScope.secondaryKeys` | `lib/src/utils/wetland_scope.dart` | 定位 secondary navigator |
| example 的**根级 `DetailRoute`** | `example/lib/router/router.dart:28-32` | 迁移能命中根级 route、避免 `buildPathTo` 补 Home 的前提。**新方案必须保留这条根级同名 route** |

### 7.3 已被删除、需要重写

在 `98082f4` 中被删（原文见 §6.1，可用 `git show 98082f4^:lib/src/wetland.dart` 取回）：

1. `_previousMode` 字段 + `BlocListener` 的 dual→single / single→dual 分支。
2. `_migrateSecondaryToPrimary`（L324-353）—— 取 secondary 详情层。
3. `_pushToRootWhenTopMost`（L433-463）—— 轮询 `isTopMost` 后 `pushAll`。
4. `_backfillPrimaryToSecondary`（L355-431）—— 反向回填（`pushAll` + `removeRoute`）。

`46abdbe` 中另外删除、与本需求相关的：

5. `Wetland.secondaryPlaceholder`（公共 API）+ `SecondaryBody.placeholder` + `_buildWithPlaceholder` + `_isShellOnly`。**若新方案需要"空态画面"不要再走这个 API**（其失败原因见 §5.3）；空态交回外壳页即可。
6. `_StackChangedObserver.onPop` 的同帧刷新路径（被并入 `onChanged`）。

### 7.4 风险点清单（每条都有历史证据）

| # | 风险 | 证据 | 缓解 |
|---|---|---|---|
| R1 | **迁移必须等根 router `isTopMost`**，否则 `pushAll` 会经 `_findStackScope` 命中还没 dispose 的 nested router，详情被压进正在卸载的 tab 壳 | `98082f4^:lib/src/wetland.dart:433-463` 注释原文；`auto_route-11.1.0/lib/src/router/controller/routing_controller.dart:1418-1428` | 复用 `_pushToRootWhenTopMost` 的轮询，上限 300 帧 |
| R2 | **空态（只有外壳页）不得迁移**，否则 auto_route 补出 `[Home, Home(autoFilled)]`，根栈多一层 | `164f74a` message + diff（§3.2）；`example/test/shrink_no_extra_push_test.dart` | 迁移侧沿用「跳过 index 0 + 跳过 `autoFilled` + `detailRoutes.isEmpty` 则 return」 |
| R3 | **「跳过 index 0」与 `secondaryIsShellOnly` 判据不等价**：前者假定外壳页恒在栈底，后者要求 `stack.length == 1 && hasEmptyPath` | 两段原文对比（§3.2 vs §3.3）；`example/lib/router/router.dart:18/26` | 迁移侧沿用 index 0（与 `replaceAll([shell, route])` 的写入方式配对）；不要混用 |
| R4 | **回填/迁移的顺序**：必须"先往目标栈 push，再从源栈 remove"，否则有"两侧都没详情"的空白帧 | `98082f4^:lib/src/wetland.dart:425-430` 注释；`example/test/expand_backfill_test.dart`（a9bcdef 版第 29-50 行逐帧断言） | 保持顺序；保留逐帧测试 |
| R5 | **回填前必须等 nested router 就绪**：`NestedStackRouter` 且 `navigatorKey.currentState != null` 且 `rootRouter.childControllers.contains(router)`；否则 `setupInitialRoutes` 会把外壳页压到详情之上，详情被盖住 | `98082f4^:lib/src/wetland.dart:368-374, 409-420` | 复用三条件 + 逐帧重试 |
| R6 | **`mode` 的派发时机**：`mode` 由槽位 builder 在 build 内派发；迁移的实际动作必须在 post-frame（否则槽位未卸载，`_findStackScope` 会命中 nested router） | §1 引文 + `_pushToRootWhenTopMost` 注释 | 保持 `BlocListener` 判边沿 + `addPostFrameCallback` |
| R7 | **过渡期观感回归**（这正是 `98082f4` 要修的）：旧方案实测 t=1200ms secondary 卸载、t=1300ms 详情才在 primary 重现 | `98082f4` commit message 原文（§6.1 末） | 若重引入迁移，必须解决"外层 push 与布局动画的时序"，否则重蹈原问题 |
| R8 | **`navigatorKey.currentState` 必须始终可用**：`WetlandNavigator.push` 靠它判断"secondary 是否可用"，一旦子树被移出树（如 `SizedBox.shrink()` 替身），竖屏 push 会误入 primary | `native-adaptive-panel.md` L319；`lib/src/utils/navigator.dart:41-45` | `_mountedSlot`（HEAD `lib/src/wetland.dart:445-...`）的形状恒定守卫必须保留 |
| R9 | **槽位 widget 树形状恒定**：按宽度切 shape 会让 `AutoRouter.didChangeDependencies` 重跑、`NestedStackRouter.setupInitialRoutes()` 重新入栈，已 push 的详情被抹掉（实测 `stack=[/, detail]` → `[/]`） | `native-adaptive-panel.md` L96-101；`98082f4` lib diff 的 `_mountedSlot` 注释 | 保留 `ClipRect→Offstage→OverflowBox→child` 固定链 |
| R10 | **`internalAnimations` 与槽同形动画**：`false` 会让框架内部 duration 归零、过渡消失；`inAnimation`/`outAnimation` 不同形会重建整棵 `IndexedStack→SecondaryBody→AutoRouter` | `46abdbe` message；`5fb2f74` message + diff（`_keepOnScreen`） | 若走外层 push，这套动画多半可简化，但**不要**恢复 `internalAnimations: false` |
| R11 | **example 必须保留根级 `DetailRoute`**（与 Home 下的同名 route 分属不同 collection）：迁移/回填命中它才不会 `buildPathTo` 补 Home | `example/lib/router/router.dart:25-32` 注释；`2026-09-26-portrait-stack-migration.md` L87 | 保留根级 route；用测试守住 `buildPathTo` 不回填 |
| R12 | **不要重新引入 `secondaryPlaceholder` 覆盖层**：它在 push 详情时被立即移除，而详情路由仍在过渡中 → 外壳页暴露、logo 一闪而过 | `46abdbe` message（§5.3） | 空态用外壳页；若外层全屏路由的空态需要画面，另设"空态路由"而不是覆盖层 |

### 7.5 与旧实现的建议差异（YAGNI 边界）

旧实现为了"过渡期两侧都有详情"付出了 `_pushToRootWhenTopMost` + `_backfillPrimaryToSecondary` 双轮询（各 300 帧）的复杂度。若新需求是**外层全屏路由**，`_backfillPrimaryToSecondary`（single→dual 回填）**未必需要**：可以反过来做"详情只在单栏时是外层路由，变宽时 pop 回 secondary"—— 这与旧回填语义等价但复用同一套"取详情层"的过滤规则。这部分旧代码只能作为**规则来源**（跳过 index 0 / 跳过 `autoFilled` / 先 push 后 remove），不能整体照搬。

---

## 附：本报告使用的取证命令

```bash
git show --stat --format='%H%n%B' <sha>                 # 6+ 个提交的 message 与 stat
git show --format='' <sha> -- lib/                      # lib 侧 diff 原文
git show <sha>:<path> | cat -n                          # 任意提交的文件原文 + 行号
git show 98082f4^:lib/src/wetland.dart                  # 旧架构终态（= a9bcdef 的 lib）
git log --oneline --follow -- <test path>                # 测试文件的改名/改写史
git log --oneline -S "secondaryPlaceholder" -- lib/      # 符号级历史
diff <(git show a9bcdef:lib/src/wetland.dart) <(git show 98082f4^:lib/src/wetland.dart)
```

未找到 / 未证实的事项（如有遗漏请指出）：

- 未找到 `DefaultPlaceholderPage` 的任何生产使用（仅 `lib/src/wetland.dart:110` 的注释）。
- 未找到 `shrink_no_primary_flash_test.dart` 之外的过渡探针；该文件在 HEAD 仍存在，本报告未展开其内容。
- 未运行 `flutter test`：本任务只读，且结论全部可由 git 原文与测试源码文本支撑；测试意图均取自测试文件自身注释与 commit message。
