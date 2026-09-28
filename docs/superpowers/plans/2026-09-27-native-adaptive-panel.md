# 原生自适应面板方案（feat/native-adaptive-panel 分支）交接计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to execute this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 用 `custom_adaptive_scaffold` 的原生布局能力替换当前「布局切换后再迁移导航栈」的补丁方案，使单⇄双栏过渡**连续无跳变**：进详情/返回、变宽/缩窄都表现为同一条布局动画，不再有「primary 先占满、动画结束才 push 详情」的中间态。

**Architecture:** secondary 槽**常驻挂载**（不再绑定 `mediumLargeAndUp`），单/双栏差异完全由 `AdaptiveLayout.bodyRatio` 表达：
- 双栏 → 0.35
- 单栏有详情 → 0.0（secondary 占满）
- 单栏无详情 → 1.0（body 占满）

这样详情永远留在自己的 navigator 里，**不需要迁移导航栈**（已删除 `_migrateSecondaryToPrimary` / `_backfillPrimaryToSecondary` / `_pushToRootWhenTopMost`）。

**Tech Stack:** Flutter 3.47.2, auto_route ^11.1.0, custom_adaptive_scaffold 5.3.0, flutter_bloc

**Spec:** 用户反馈（原话）：
> 1. 从双栏变单栏，最终 secondary 占满屏幕，但过程中有一个明显的 push 动作，而且基本是 primary 动画过渡结束占满屏幕才触发
> 2. 从单栏变双栏，初始 secondary 占满屏幕，这个好一些，貌似在 adaptive_scaffold 动画过渡过程中就开始 push 了，但是还稍微有点不连贯
> 「似乎是同一个问题…过渡动画不是基于是否有 secondary 进行执行过渡的，而像是我们打的补丁。我希望你看看 adaptive_scaffold 能否提供更原生的这种能力」
>
> 用户已确认：**在单独分支实现，效果好就用**。分支已建：`feat/native-adaptive-panel`。

## Global Constraints

- 遵循 Clean 架构、DRY、KISS、YAGNI；库逻辑不得依赖 example 具体页面
- TDD：先写失败测试，再实现
- 每个 Task 结束必须可独立验证（跑测试 + analyze）
- **不得破坏既有测试**（见 Task 1 的基线清单）
- 运行命令一律 `/opt/homebrew/share/flutter/bin/flutter test`（**不要用裸 flutter**；本机无 `timeout` 命令）
- 新增/修改公共 API 必须带 dartdoc
- **不要 git commit**（由 Lead 统一确认后提交）
- 不擅自改动 `example/macos/*`、`example/ios/*` 等平台文件

---

## 已确认的事实（执行者必读，避免重复调研）

### 环境
- 系统 Flutter：`/opt/homebrew/share/flutter/bin/flutter`（可用；此前「auto_route 不兼容」结论是残缺 SDK 副本造成的假象）
- 仓库：`/Users/bookshiyi/repos/wetland`，当前分支 `feat/native-adaptive-panel`

### auto_route 机制
- `StackRouter` 继承 `ChangeNotifier`，但 **`onPopPage` 不调用 `notifyAll`** → 仅监听 router 会漏掉 pop
- 可靠做法：`AutoRouter.navigatorObservers`（Flutter 原生 `NavigatorObserver`），每次 build 必须返回**新实例**（一个 observer 只能挂一个 Navigator，否则断言失败）
- `NavigatorObserver.didPush/didPop` 可能在 **build 期间**触发 → 回调里直接 `setState` 会撞 "setState() called during build"，必须 `addPostFrameCallback` 延迟

### custom_adaptive_scaffold 5.3.0 机制
- `AdaptiveLayout` 参数：`bodyRatio`、`transitionDuration`、`internalAnimations`、`body`/`secondaryBody`/`primaryNavigation`/`bottomNavigation` 槽
- `_AdaptiveLayoutDelegate.shouldRelayout` **只比较 `slots`**（不比较 `bodyRatio`）
- `animatedSize(begin, end)` 仅当 `isAnimating.contains(secondaryBody)` 时插值；而 `isAnimating` **只在 slot 的 key 变化时**才添加
- `SlotLayoutConfig.builder` 可为 `null`（等价 `SlotLayoutConfig.empty()` → `SizedBox.shrink()`）
- `DualPanel`（`lib/src/dual_panel/`）是更高层封装，`secondaryBody` 可为 null，但 `bodyRatio` 固定 0.5 且不含 tab 导航栏，**不适合直接替换**
- `AdaptiveScaffoldController` + `PanelFocus{body, secondaryBody}` 是 `AdaptiveScaffold`（非 `AdaptiveLayout`）才有的「单栏显示哪一栏」原生机制

### ⚠️ 对「已知障碍」的实测更正（本分支实测推翻，务必先读）

原计划断言「`internalAnimations: false` ⇒ `animatedSize` 直接返回 `end` ⇒ `bodyRatio` 变化不会产生过渡」，
并据此把 Task 2 定性为「需要绕开 delegate 的尺寸动画」。**实测证明该推论不成立**：

1. `shouldRelayout` 里 `oldDelegate.slots != slots` 比较的是**每帧新建的 Map 实例**
   （`build` 里的 `<String, SlotLayout?>{}` 字面量）。Dart 的 `Map` 用**同一性**比较，
   故该表达式**恒为 true** ⇒ delegate **每帧都会 relayout**，与 `animatedSize` 无关。
   （实测：`{'x':1} != {'x':1}` 为 `true`。）
2. `bodyRatio` 在 LTR + `builder != null` 分支里**不经过 `animatedSize`**：
   body 走 `animatedSize(...)`，但 `secondaryBody` 直接用 `finalSBodySize`（`isAnimating` 门控只影响前者）。

**决定性实验（同一套断言，只改一处）**：
- 保留 `TweenAnimationBuilder`：`body` 宽 390→0 在 1.2s 内**逐帧单调插值**（16ms 粒度实测 ~70 个中间值）。
- 把 `TweenAnimationBuilder` 换成直接传 `targetRatio`（其余不变）：布局在 **1 帧内直接跳到终态**
  （横→竖 `t=200ms` 时 `body=0`）。

⇒ 结论：**`TweenAnimationBuilder` 包 `bodyRatio` 确实驱动逐帧重排**，候选 A（改 slot key）、
B（自驱动尺寸动画）均**不必要**；候选 C（换 `AdaptiveScaffold` + `PanelFocus`）代价最大且需重做
导航集成，**不予采用**。Task 2 因此无实现改动，只需补上能证明连续性的时间线测试。

### 本分支已完成的改动
- `lib/src/utils/secondary_stack.dart`（新增）：`secondaryIsShellOnly(router)` / `secondaryHasDetail(router)`
  - 依赖约定：secondary 子路由首项是 `path: ''` 外壳页，`stack.length == 1 && hasEmptyPath` ⇒ 无详情
- `lib/src/wetland.dart`：
  - 删除 `_migrateSecondaryToPrimary` / `_backfillPrimaryToSecondary` / `_pushToRootWhenTopMost` / `_previousMode`
  - `secondaryBody` 槽改用 `Breakpoints.standard`（常驻挂载）
  - 新增 `_currentTabHasDetail`、`_targetBodyRatio`、`_mountedSlot`、`_onSecondaryStackChanged`
  - `bodyRatio` 用 `TweenAnimationBuilder` 插值 + `internalAnimations: false`
- `lib/src/widgets/secondary_body.dart`：
  - 新增 `onStackChanged` 回调；用 `_StackChangedObserver extends NavigatorObserver` 上报栈变化（post-frame 延迟）
  - 保留既有 `placeholder` 叠加逻辑（`_buildWithPlaceholder`，Navigator 常驻树）

### ⚠️ 槽位守卫的第二条硬约束：widget 树形状必须恒定（Task 1 实测）

原计划的方案是「窄宽时用 `Visibility(maintainState: true)` 隐藏」，但实测发现**两个坑**，
只做「隐藏而非移除」并不够：

1. **仅 `Offstage`/`Visibility` 不够**：它们会用收到的（极窄，如 0.5px）约束去 layout 子树，
   调用方内容照样抛布局断言（实测 18 次 `Leading widget consumes the entire tile width`、
   多次 `RenderFlex overflowed`）。必须再套 `OverflowBox` 先给内容一个最小可渲染宽度。
2. **按宽度阈值切换 widget 链形状 ⇒ 子树被重建**：最初实现为
   「宽 ≥ 阈值 → 直接返回 child；窄 → 包 `ClipRect→Offstage→OverflowBox`」。
   这会改变 widget 树形状，Flutter 无法复用 Element，于是 `AutoRouter` 的
   `didChangeDependencies` 重跑、`NestedStackRouter.setupInitialRoutes()` 重新入栈，
   **已 push 的详情被抹掉**（实测 `stack=[/, detail]` → `[/]`，`Messages Detail` 消失）。
   ⇒ 守卫必须**始终返回同一形状**的链，只让 `minWidth/maxWidth/offstage` 等参数随宽度变化。

`_minRenderableSlotWidth` 取值同样来自实测：例子的列表页在 150 以下溢出（120/130/140 均溢出，
150 起稳定），取 200 留余量；且必须 **< 双栏在 840dp 最小断点下的 body 实宽（实测 268.1）**，
否则合法的窄双栏内容会被无谓裁切。

### 测试状态（Task 1–3 完成后，未提交）

`cd example && flutter test` → **+20 全绿**；`cd wetland && flutter test` → **+8 全绿**；
两处 `flutter analyze` 均 `No issues found`。

| 测试 | 处置 |
|---|---|
| `expand_backfill_test.dart` | 已改写为验证**双栏几何 + secondary 槽常驻**（不再验证已删的 backfill） |
| `shrink_no_extra_push_test.dart` | 已改写为验证**根栈恒等 + 详情仍在 secondary**（不再验证已删的 migrate） |
| `portrait_migration_test.dart` | 已更名 `portrait_rotate_keeps_detail_test.dart`，断言用户可见结果（无迁移） |
| `portrait_test.dart` | Task 1 修复后转绿 |
| `native_panel_test.dart` | 转绿（可见性用宽度断言） |
| `panel_transition_timeline_test.dart` | **新增**：逐帧宽度时间线 + 架构判别器 |

| 其余 | 需逐个确认 |

**已定位的真实回归根因**：`_slotOrEmpty` 在竖屏（宽度 < 120）时返回 `SizedBox.shrink()`，**把 secondary 的 Navigator 从树上移除了** → `navigatorKey.currentState == null` → `WetlandNavigator.push` 走 primary 分支（`portrait_test` 的日志 `Push [DetailRoute] to [PrimaryBody]` 证实）。

---

### Task 1: 修复 `_slotOrEmpty` 移除 Navigator 导致的回归

**Files:**
- Modify: `lib/src/wetland.dart`（`_slotOrEmpty` 及其两处调用）
- Test: `example/test/portrait_test.dart`（现有，须转绿）

**Interfaces:**
- Consumes: `WetlandNavigator.push` 依赖 `navigatorKey.currentState != null` 来判断「secondary 是否可用」
- Produces: 槽位守卫**不能在窄宽时移除内容子树**，只能隐藏

**核心约束**：secondary 槽必须**始终保留其子树的 Element/State**（尤其 `Navigator`），否则 `navigatorKey.currentState` 变 null，`context.wetland.push` 会把详情误推进 primary。

- [ ] **Step 1: 先跑基线，确认失败**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test test/portrait_test.dart`
Expected: FAIL，日志含 `Push [DetailRoute] to [PrimaryBody]`

- [ ] **Step 2: 改写 `_slotOrEmpty` —— 隐藏而非移除**

改为用 `Visibility(maintainState: true, maintainAnimation: true, maintainSize: false)` 或 `Offstage` 包裹，**保持子树挂载**但不可见：

```dart
/// 槽位内容的宽度守卫。
///
/// [bodyRatio] 收缩某个槽时，过渡过程中该槽会经过极窄宽度（0.5px、5px…）。
/// 若此时照常渲染内容（如含 `ListTile` 的列表页），内部会抛
/// `Leading widget consumes the entire tile width` 等布局异常。
///
/// **关键**：只能用 [Visibility] 隐藏，**不能**替换为 `SizedBox.shrink()` ——
/// secondary 的 `Navigator` 必须常驻 widget 树，否则
/// `navigatorKey.currentState` 变 null，
/// [WetlandNavigator.push] 会误把详情推进 primary。
static Widget _slotOrEmpty(Widget child) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final visible = constraints.maxWidth >= 1.0;
      return Visibility(
        visible: visible,
        maintainState: true,
        maintainAnimation: true,
        maintainSize: false,
        child: child,
      );
    },
  );
}
```

> ⚠️ 若仍出布局异常，说明极窄宽度下内容自身会抛错。此时改用
> `ClipRect(child: OverflowBox(minWidth: 120, maxWidth: 120, child: SizedBox(width: 120, child: child)))`
> 让内容按可渲染宽度布局后再裁剪 —— 但**必须保留子树的 State**（不可用 shrink 替换）。

- [ ] **Step 3: 运行确认转绿**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test test/portrait_test.dart`
Expected: PASS（含 `Push [DetailRoute] to [SecondaryBody#0]` 日志）

- [ ] **Step 4: 全量回归，记录剩余失败**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`
Expected: 记录仍失败的用例（预期只剩与已删机制相关的 + native_panel_test）

- [ ] **Step 5: 提交（需 Lead/用户确认）**

```bash
git add lib/src/wetland.dart
git commit -m "fix: 槽位守卫改为隐藏而非移除，保住 secondary Navigator"
```

---

### Task 2: 让 `bodyRatio` 真正驱动过渡动画

**Files:**
- Modify: `lib/src/wetland.dart`（`bodyRatio` 的动画方式）
- Test: `example/test/native_panel_test.dart`（现有，须转绿）

**Interfaces:**
- Consumes: Task 1 的槽位守卫
- Produces: 单⇄双栏、进详情/返回的过渡由 `bodyRatio` 连续插值驱动

**已知障碍**（见「已确认的事实」）：
`_AdaptiveLayoutDelegate.shouldRelayout` 只比 `slots`；`animatedSize` 受 `isAnimating` 门控，而 `isAnimating` 仅在 slot key 变化时添加。因此单纯用 `TweenAnimationBuilder` 包 `bodyRatio` **不会让布局逐帧重排**。

- [ ] **Step 1: 写测试（已有则复用）**

`example/test/native_panel_test.dart` 已含 3 个用例（横→竖连续可见、竖→横连续可见、单栏返回）。**注意**：判断可见性要用**宽度**（`tester.getSize(...).width > 1`），不能用 `find.text` 是否存在 —— 宽度为 0 的 widget 仍在树上。

- [ ] **Step 2: 跑出真实行为，再决定实现**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test test/native_panel_test.dart`
记录：哪条断言失败、失败时的实际宽度值。**以实测为准，不得凭空选实现**。

- [ ] **Step 3: 实现（候选方案，按实测择一）**

候选 A：**不关 `internalAnimations`**，改为通过**改变 slot key** 触发 `isAnimating`，让 `animatedSize` 用 `bodyRatio` 的 `begin/end` 插值。
- 风险：改 key 会重建子树，可能破坏 Navigator 常驻（与本方案核心冲突）。**先验证再采用**。

候选 B：**自己驱动 `AdaptiveLayout` 的尺寸动画**：给 `body`/`secondaryBody` 槽各包一层 `AnimatedBuilder` + `TweenAnimationBuilder<double>`，用 `Align`/`SizedBox` 按插值比例直接约束尺寸（绕开 delegate 的 `animatedSize`）。
- 风险：与 delegate 自身的 tight 约束叠加，需验证不会冲突。

候选 C：**改用 `AdaptiveScaffold` + `AdaptiveScaffoldController`**（原生 `PanelFocus`）。
- 这是用户原话指向的「原生能力」，但改动面最大（`AdaptiveScaffold` 自带 nav rail / bottom nav，需重做导航集成）。
- **若候选 A/B 都不成立，优先评估 C**，并在报告中说明改动面。

- [ ] **Step 4: 运行确认通过**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test test/native_panel_test.dart`
Expected: PASS

- [ ] **Step 5: 提交（需确认）**

```bash
git add lib/src/wetland.dart
git commit -m "feat: bodyRatio 连续插值驱动单⇄双栏过渡"
```

---

### Task 3: 清理与已删机制绑定的测试

**Files:**
- Delete/Modify: `example/test/expand_backfill_test.dart`、`example/test/shrink_no_extra_push_test.dart`

**Interfaces:**
- Consumes: Task 1/2 的新行为
- Produces: 测试集与新架构一致

- [ ] **Step 1: 确认这两个文件测的是已删机制**

`expand_backfill_test.dart` 断言「变宽后自动回填 secondary」——新方案下 secondary 本就常驻，无需回填。
`shrink_no_extra_push_test.dart` 断言「不迁移到根栈」——新方案已完全移除迁移。

- [ ] **Step 2: 改写为验证新行为的等价断言**

例如 `expand_backfill_test` 改为：变宽后 `detail 宽度 > 0` 且 `list 宽度 > 0`（双栏），而不是验证「回填」动作。
`shrink_no_extra_push_test` 改为：缩窄后根栈长度不变（本就该不变）。

- [ ] **Step 3: 运行确认通过**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`

- [ ] **Step 4: 提交（需确认）**

```bash
git add example/test/
git commit -m "test: 对齐新架构，改写原迁移/回填相关用例"
```

---

### Task 4: 全量验证与对比结论

**Files:**
- 无（验证任务）

- [ ] **Step 1: 库测试**

Run: `cd /Users/bookshiyi/repos/wetland && /opt/homebrew/share/flutter/bin/flutter test`
Expected: 全绿

- [ ] **Step 2: example 测试**

Run: `cd example && /opt/homebrew/share/flutter/bin/flutter test`
Expected: 全绿

- [ ] **Step 3: 静态分析**

Run: 两个目录分别 `/opt/homebrew/share/flutter/bin/flutter analyze`
Expected: No issues（既有 4 条 Material2 弃用除外）

- [ ] **Step 4: 逐帧对比（回答用户的核心质疑）**

写一个探针测试，在「横→竖」与「竖→横」过渡中**每 100ms 记录一次** `body`/`secondary` 的实际宽度，输出时间线。用于向用户证明：
- 旧方案：primary 独占约 1.3s，详情等到动画结束才出现
- 新方案：宽度连续插值，详情全程可见（或仅极短交接帧）

- [ ] **Step 5: 产出结构化报告（返回 Lead）**

必须包含：实测时间线对比、每个 Task 的改动与测试结果、**是否值得替换现有实现**的结论与依据。

---

## Self-Review

**1. Spec coverage:**
- 问题1（双→单 push 动作）→ Task 1 + Task 2
- 问题2（单→双不连贯）→ Task 2
- 「用 adaptive_scaffold 原生能力」→ Task 2 候选 C 明确评估
- 「单独分支尝试」→ 分支已建

**2. 风险提示（执行者必读）:**
- **`navigatorKey.currentState` 必须始终可用**（Task 1 的核心约束）。任何「移除子树」的优化都会导致竖屏 push 误入 primary。
- `internalAnimations: false` 会让 `animatedSize` 失活 —— 这是 Task 2 要解决的核心障碍。
- 判断可见性用**宽度**，不是 finder 命中（0 宽 widget 仍在树上）。
- 若最终评估认为**原生方案改动面不值得**，请如实报告并给出保留现有补丁方案的建议 —— 用户明确说「效果好就用」，即效果不好可以不采用。
