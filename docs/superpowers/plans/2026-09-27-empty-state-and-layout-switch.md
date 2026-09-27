# 空态与宽窄布局切换修复 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 wetland 在「详情栈被 pop 空」与「宽窄布局切换」下的四个缺陷：pop 后黑屏、空态时误迁移多压一层 primary、宽→窄时 primary 抢占地推入、窄→宽时不自动回填 secondary。

**Architecture:** 保留 example 的 `PlaceholderRoute` 作为 secondary 的**外壳页**（nested router 的初始路由，负责让 `Navigator` 存在），但修正两条栈操作规则：① `push(replace)` 保留外壳页、只替换其上的详情层（修黑屏）；② 迁移时只迁移**外壳页之上**的详情层、并据「有无详情」决定迁移方向（修误迁移与切换体验）。

**Tech Stack:** Flutter 3.47.2, auto_route ^11.1.0, flutter_bloc, custom_adaptive_scaffold

**Spec:** 用户本轮反馈的四个问题 + 已确认的取舍：
1. pop-detail 后右侧全黑（根因已实证）
2. 横屏空态时缩窄，会多 push 一遍 primary（根因已实证）
3. 宽→窄：有详情时应隐藏 primary、详情全屏；无详情时隐藏 secondary、保留 primary
4. 窄→宽：全屏详情应自动回填 secondary（用户选择「自动回填」）
- 用户明确要求：**保留 placeholder 能力**（便于定制 logo 作为详情页默认画面）

## 已实证的事实（执行者必须知道，避免重复调研）

**环境**：系统 Flutter 可直接跑测试 `/opt/homebrew/share/flutter/bin/flutter test`（勿用裸 `flutter`；此前「auto_route 不兼容」结论是残缺 SDK 副本造成的假象）。

**auto_route 机制**（`auto_route-11.1.0/lib/src/router/widgets/auto_route_navigator.dart:95`）：
```dart
hasEntries ? Navigator(pages: stack) : placeholder?.call(context) ?? Container(scaffoldBackgroundColor)
```
即 `placeholder` **仅在栈为空时**渲染。

**实测栈形态**（探针输出）：
- example 每个 tab 的 secondary 初始栈 = `[PlaceholderRoute]`（来自 `router.dart` 的 `path: ''`）
- 有详情时 = `[DetailRoute]`（**不是** `[PlaceholderRoute, DetailRoute]`）——因为 `replaceAll` 把外壳也清掉了
- pop 详情后 = `[]` → `hasEntries=false` → 渲染空 `Container` → **黑屏**

**实测误迁移**：
```
Migrate 1 detail route(s) ... [PlaceholderRoute]
BEFORE root stack: [HomeRoute]
AFTER  root stack: [HomeRoute, HomeRoute(autoFilled=true)]   ← 多压一层
```

**实测修复有效性**（已用探针验证）：`replaceAll([...shell, route])` 后，pop 详情 → logo 图回归（`logo=1 detail=0`），不再是黑屏；`widget_test`/`multi_detail_test` 通过。

**关键约束**：**不可**删除 `path: ''` 的 PlaceholderRoute。实测删除后 secondary 初始栈为空 → auto_route 不创建 `Navigator` → `navigatorKey.currentState == null` → `context.wetland.push` 误入 primary，横屏 push 失效。

## Global Constraints

- 遵循 Clean 架构、DRY、KISS、YAGNI；库逻辑不得依赖 example 具体页面
- TDD：先写失败测试，再实现
- 每个 Task 结束必须可独立验证（跑测试 + analyze）
- 不破坏现有测试：库 `test/`（8 个）、example `test/`（含 portrait/widget/multi_detail）
- 运行命令：`/opt/homebrew/share/flutter/bin/flutter test`（在对应目录）
- 新增/修改的公共 API 必须带 dartdoc
- 不擅自 git commit，提交前需用户确认
- example 路由改动后需 `dart run build_runner build` 重新生成 `router.gr.dart`

---

### Task 1: 修复 pop 后黑屏 —— replace 时保留外壳页

**Files:**
- Modify: `lib/src/utils/navigator.dart:56-60`
- Test: `example/test/empty_vs_shell_test.dart`（新增）

**Interfaces:**
- Consumes: `StackRouter.stack`（`List<AutoRoutePage>`）、`RouteMatch.toPageRouteInfo()`
- Produces: `WetlandNavigator.push` 的 replace 分支行为变更：`replaceAll([...shell, route])`，其中 `shell` = 原栈首项反推的 `PageRouteInfo`

- [ ] **Step 1: 写失败测试（pop 详情后应回到外壳页而非空栈）**

```dart
// example/test/empty_vs_shell_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏 pop 详情后右侧回到外壳页（不黑屏）', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 进入详情
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);

    // pop 详情
    await tester.tap(find.text('pop-detail'));
    await tester.pumpAndSettle();

    // 应回到外壳页（logo 图），而不是空栈黑屏
    expect(find.text('Messages Detail '), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test test/empty_vs_shell_test.dart`
Expected: FAIL（pop 后 `Image` 找不到——当前栈为空，渲染空 Container）

- [ ] **Step 3: 实现（保留外壳页）**

```dart
// lib/src/utils/navigator.dart — replace 分支
} else {
  Log.d('Push [${route.routeName}] to [SecondaryBody#$index] (replace)');
  // 保留栈底的外壳页（nested router 的初始页），只替换其上的详情层，
  // 这样 pop 详情后能回到外壳页，而不会落到空栈（空栈会让 auto_route
  // 渲染空 Container，且 navigatorKey.currentState 变 null）。
  final stack = secondaryRouter.stack;
  final shell = stack.isNotEmpty
      ? [stack.first.routeData.route.toPageRouteInfo()]
      : <PageRouteInfo>[];
  await secondaryRouter.replaceAll([...shell, route]);
  return null;
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`
Expected: PASS（原 5 + 新增 1；`empty_state_test` 仍失败属预期，Task 3 处理）

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add lib/src/utils/navigator.dart example/test/empty_vs_shell_test.dart
git commit -m "fix: replace 保留 secondary 外壳页，避免 pop 详情后黑屏"
```

---

### Task 2: 迁移时只迁移详情层，避免空态误压 primary

**Files:**
- Modify: `lib/src/wetland.dart:291-306`（`_migrateSecondaryToPrimary`）
- Test: `example/test/shrink_no_extra_push_test.dart`（新增）

**Interfaces:**
- Consumes: Task 1 的栈形态（`[shell, ...details]`）、`RouteMatch.autoFilled`
- Produces: `_migrateSecondaryToPrimary` 过滤规则：跳过 `autoFilled` **且**跳过栈首外壳页；仅当存在真实详情时才迁移

- [ ] **Step 1: 写失败测试（空态缩窄不应多压 primary）**

```dart
// example/test/shrink_no_extra_push_test.dart
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏空态缩窄到竖屏，根栈不应多压一层', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    final root = AutoRouter.of(tester.element(find.text('Messages 0'))).root;
    final before = root.stack.length;

    // 缩窄（不选任何详情）
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();

    expect(root.stack.length, before,
        reason: '空态缩窄不应迁移任何路由到根栈');
    // tab 列表页仍可见
    expect(find.text('Messages 0'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test test/shrink_no_extra_push_test.dart`
Expected: FAIL（根栈长度 +1，因 PlaceholderRoute 被误迁移）

- [ ] **Step 3: 实现（过滤外壳页）**

```dart
// lib/src/wetland.dart — _migrateSecondaryToPrimary
void _migrateSecondaryToPrimary(BuildContext context, int tabIndex,
    StackRouter? router) {
  if (router == null) return;
  final stack = router.stack;
  if (stack.length <= 1) return; // 只有外壳页 = 无详情，无需迁移
  final detailRoutes = <PageRouteInfo>[];
  for (var i = 0; i < stack.length; i++) {
    final rt = stack[i].routeData.route;
    if (i == 0) continue;      // 跳过栈底外壳页（Navigator 载体）
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

- [ ] **Step 4: 运行确认通过**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`
Expected: PASS（新增测试通过；`portrait_migration_test` 仍通过）

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add lib/src/wetland.dart example/test/shrink_no_extra_push_test.dart
git commit -m "fix: 迁移只取 secondary 详情层，空态不再误压 primary"
```

---

### Task 3: example 空态改用 secondaryPlaceholder（保留 logo 定制能力）

**Files:**
- Modify: `example/lib/router/router.dart`（保留 `PlaceholderRoute` 作为外壳，但改用无内容的外壳页）
- Modify: `example/lib/pages/placeholder_page.dart`
- Modify: `example/lib/pages/home_page.dart`
- Test: `example/test/empty_state_test.dart`（现有，需通过）

**Interfaces:**
- Consumes: `Wetland.secondaryPlaceholder`（已实现）、`AutoRouter.placeholder`
- Produces: 外壳页不再显示 logo；空态统一由 `secondaryPlaceholder` 呈现

**背景**：Task 1 后，secondary 栈在无详情时 = `[PlaceholderRoute]`，外壳页会被渲染成"默认画面"。用户希望**默认画面可定制**。两种做法：把 `PlaceholderRoute` 做成极简空壳、由 `secondaryPlaceholder`（用户可传）负责视觉；或直接让外壳页充当默认画面。本 Task 采用后者更简单的形态——外壳页保持极简，example 在 `home_page` 传 `secondaryPlaceholder` 定制引导文案。

**注意**：因外壳页始终存在（`hasEntries=true`），`secondaryPlaceholder` **不会被渲染**。因此 example 的空态视觉应放在**外壳页**里，而非依赖 `placeholder` 参数。

- [ ] **Step 1: 决策记录（供用户确认）**

本 Step 不写代码。执行前需向用户确认：「默认画面」的承载方式是
(a) 库把 `secondaryPlaceholder` 语义改为"详情栈只有外壳页时也显示它"（需库改动），或
(b) example 直接把外壳页做成可定制默认画面（无需库改动）。
**默认按 (a) 实现**（更符合用户「方便其他人调用 wetland 时定制 logo」的原话）。

- [ ] **Step 2: 写失败测试（空态显示引导文案）**

现有 `example/test/empty_state_test.dart` 已覆盖该断言（`Select an item to see details`），当前 FAIL。

- [x] **Step 3: 实现（库让 placeholder 在"仅剩外壳页"时也生效）** ✅ 已落地（commit `ae06260`）

> ⚠️ **本 Step 原方案已被证伪，实际实现见下。** 原 snippet 用
> `hasDetail ? child : placeholder` **替换** 掉 `child`（AutoRouteNavigator），
> 会把 nested `Navigator` 移出 widget 树 → `navigatorKey.currentState == null`
> → `context.wetland.push` 误入 primary（横屏详情变全屏覆盖）。
> 实证：原样贴入后 example 全量出现 **4 个测试回归**
> （widget_test / multi_detail_test / empty_vs_shell_test / portrait_migration_test），
> 日志出现 `Push [DetailRoute] to [PrimaryBody]`。

**实际采用的实现**（叠加而非替换，`lib/src/widgets/secondary_body.dart`）：

```dart
/// 判断该 router 是否「只剩外壳页」——即详情栈里没有任何用户详情。
bool _isShellOnly(StackRouter router) {
  final stack = router.stack;
  if (stack.length != 1) return false;
  return stack.first.routeData.route.hasEmptyPath;
}

Widget _buildWithPlaceholder(BuildContext context, Widget navigator) {
  final router = AutoRouter.of(context);
  return Stack(
    fit: StackFit.expand,
    children: [
      navigator, // Navigator 常驻树上，保证 navigatorKey.currentState 可用
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
```

要点：
- `hasEmptyPath`（`route_match.dart:153`）比 `stack.length <= 1` 更安全：调用方未配 `path:''` 外壳页时安全降级为显示真实页面。
- 覆盖层用 `ColoredBox`（`HitTestBehavior.opaque`）：遮住外壳页同时吸收点击。
- **不要用 `Offstage`**：`_OffstageElement.debugVisitOnstageChildren` 会把子树从 finder 隐藏，破坏 `empty_vs_shell_test` 的 `find.byType(Image)` 断言。

- [ ] **Step 4: 运行确认通过**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`
Expected: PASS（含 `empty_state_test`）

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add lib/src/widgets/secondary_body.dart example/lib/pages/
git commit -m "feat: 详情仅剩外壳页时显示 secondaryPlaceholder，支持定制默认画面"
```

---

### Task 4: 宽→窄 —— 消除过渡期 primary 抢占地推入

**Files:**
- Modify: `lib/src/wetland.dart`（dual→single 迁移时机）
- Test: `example/test/shrink_no_primary_flash_test.dart`（新增）

**Interfaces:**
- Consumes: Task 2 的 `_migrateSecondaryToPrimary`
- Produces: dual→single 时，若当前 tab 有详情 → 立刻迁移（不留 primary 占满的中间态）；无详情 → 不迁移

**实测现状（已用探针确认）**：
```
横屏有详情 → 缩窄：detail=1, list=0, tab=0   ← 终态正确（详情全屏）
迁移日志：Migrate 2 routes: [PlaceholderRoute, DetailRoute]  ← 外壳页被误迁移
```
即**终态正确、但过渡期 primary 会先占满**（用户报告的体验问题），且外壳页被多余迁移。Task 2 修掉多余迁移后，本 Task 处理过渡期。

- [ ] **Step 1: 写测试（缩窄后立即断言终态，不留中间态）**

```dart
// example/test/shrink_no_primary_flash_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏有详情缩窄：不出现 primary 占满的中间态', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(390, 844);
    // 只 pump 一帧，检查是否出现"列表页可见但详情不可见"的中间态
    await tester.pump();
    final listVisible = find.text('Messages 0').evaluate().isNotEmpty;
    final detailVisible = find.text('Messages Detail ').evaluate().isNotEmpty;
    expect(listVisible && !detailVisible, isFalse,
        reason: '不应出现 primary 占满而详情未就位的中间态');

    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行获取实测输出**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test test/shrink_no_primary_flash_test.dart`
Expected: 观察中间态断言是否失败；**以实测输出决定改法**

- [ ] **Step 3: 按实测结果实现**

可能的方向（**以 Step 2 输出为准，不得凭空选**）：
- 迁移不等 `transitionDuration` 结束，提前到 mode 变化的同一帧（post-frame 立即执行）
- 或把 `_pushToRootWhenTopMost` 的轮询改为"根栈一旦可用即 push"，缩短空窗
- 或过渡动画期间保持 secondary 可见（`AdaptiveLayout.transitionDuration` 调小）

- [ ] **Step 4: 运行确认通过**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add lib/src/wetland.dart example/test/shrink_no_primary_flash_test.dart
git commit -m "fix: 宽转窄时有详情不再出现 primary 抢占地中间态"
```

---

### Task 5: 窄→宽 —— 全屏详情自动回填 secondary

**Files:**
- Modify: `lib/src/wetland.dart`（`BlocListener` 的 single→dual 分支）
- Test: `example/test/expand_backfill_test.dart`（新增）

**Interfaces:**
- Consumes: 根 router 栈（`AutoRouter.of(context).root.stack`）
- Produces: single→dual 时，若根栈顶是详情（非 Home/tab 壳），把它迁回当前 tab 的 secondary，并将根栈恢复为 tab 页

- [ ] **Step 1: 写失败测试**

```dart
// example/test/expand_backfill_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('竖屏全屏详情时变宽，应自动回填双栏', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 竖屏进入详情（全屏）
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);

    // 变宽到横屏
    tester.view.physicalSize = const Size(1200, 1000);
    await tester.pumpAndSettle();

    // 期望：左侧 tab 导航出现 + 右侧详情仍在（双栏）
    expect(find.text('Messages Detail '), findsOneWidget);
    expect(find.text('Message'), findsOneWidget); // 左栏 tab
    expect(find.text('Messages 0'), findsOneWidget); // 中间列表页
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test test/expand_backfill_test.dart`
Expected: FAIL（详情仍在根栈全屏，中间列表页不可见）

- [ ] **Step 3: 实现（single→dual 回填）**

在 `BlocListener` 增加分支：

```dart
// 从 single 切到 dual（竖转横）：把根栈顶的详情回填到当前 tab 的 secondary。
if (_previousMode == WetlandMode.single &&
    state.mode == WetlandMode.dual) {
  final tabIndex = _safeIndex(state.index, widget.destinations?.length ?? 0);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    _backfillPrimaryToSecondary(context, tabIndex);
  });
}
```

新增方法 `_backfillPrimaryToSecondary`：读根栈，取栈顶非 Home 的详情 route，`push` 到 `_secondaryRouters[tabIndex]`，再从根栈 pop 掉该详情。

- [ ] **Step 4: 运行确认通过**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`
Expected: PASS

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add lib/src/wetland.dart example/test/expand_backfill_test.dart
git commit -m "feat: 窄转宽时详情自动回填 secondary 双栏"
```

---

### Task 6: 全量回归与文档

**Files:**
- Modify: `docs/superpowers/plans/2026-09-07-example-completeness.md`（补充本次修复记录）

- [ ] **Step 1: 跑全部测试**

Run: `cd /Users/bookshiyi/repos/wetland && /opt/homebrew/share/flutter/bin/flutter test`
Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`
Expected: 全部 PASS

- [ ] **Step 2: 静态分析**

Run: `cd /Users/bookshiyi/repos/wetland && /opt/homebrew/share/flutter/bin/flutter analyze`
Run: `cd example && /opt/homebrew/share/flutter/bin/flutter analyze`
Expected: No issues

- [ ] **Step 3: 更新计划文档记录本次修复**

- [ ] **Step 4: 提交（需用户确认）**

```bash
git add docs/
git commit -m "docs: 记录空态与宽窄布局切换修复"
```

---

## Self-Review

**1. Spec coverage:**
- 问题1（黑屏）→ Task 1（已实证修复有效）
- 问题2（空态误压 primary）→ Task 2
- 问题3（宽→窄）→ Task 2 + Task 4
- 问题4（窄→宽回填）→ Task 5
- 用户诉求「保留 placeholder 定制 logo」→ Task 3

**2. Placeholder scan:**
- Task 3 Step 1、Task 4 Step 3 的表述要求执行者**先实测再改**，而非"实现细节待定"——这是对"未知签名/未知现状"的正确处置，非占位符。
- Task 3 Step 3 明确要求先读 `AutoRouter.builder` 签名，不得猜测。

**3. Type consistency:**
- `_migrateSecondaryToPrimary(BuildContext, int, StackRouter?)` 签名在 Task 2/4 一致
- `_secondaryRouters`（`List<StackRouter?>`）在 Task 2/3/5 一致
- 测试文案 `'Messages Detail '`（含尾随空格）与现有测试同源

**4. 风险提示（执行者注意）:**
- Task 3 若改 `SecondaryBody` 用 `AutoRouter.builder`，需确认该参数在 11.1.0 存在且签名匹配；**先读源码**。
- Task 4/5 涉及「迁移方向」判定，务必用 Step 2 的实测输出驱动，避免重蹈此前"凭推断改代码"的覆辙。
