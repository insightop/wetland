# 横转竖时 secondary 详情栈迁移到 portrait 全屏栈 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 横屏三栏（dual mode）下，用户在某个主 tab 的右侧详情（secondaryBody）里下钻了几层；当设备旋转为竖屏（single mode）时，要求竖屏全屏栈**顶部**展示当前的 secondary 详情页，用户可通过返回键**逐步 back 回**主 tab 底页。行为与微信一致。

**Architecture:** 在 wetland 库的 `_WetlandState` 中，当 mode 从 `dual` 切到 `single` 时，先快照当前 tab 的 secondary 详情栈（反推为 `PageRouteInfo` 序列，可保留参数与层级，State 丢失可接受），随后经 post-frame 回调将该序列迁移到**根 router 顶部**（`AutoRouter.of(...).router.root`）。根 router 顶层已有根级 `DetailRoute`（问题2 已新增），迁移命中根级 Detail，不会重复补齐 Home。

**Tech Stack:** Flutter, auto_route, flutter_bloc, custom_adaptive_scaffold

**Spec:**
- 横屏下 secondary 详情栈非空时旋转到竖屏，竖屏根栈顶部展示当前详情，可逐步 back 回 tab 页。
- 迁移逻辑放在 wetland 库内（通用能力），不局限于 example。
- 迁移目标：根 router 顶部 replaceAll/pushAll 详情序列。
- 触发时机：BlocListener 监听 mode 变化（dual→single）。
- 反向（竖转横）不做（YAGNI，仅覆盖用户确认的横→竖单方向）。

## Global Constraints

- Clean 架构、高内聚低耦合、SOLID
- TDD：先写失败测试，再实现
- `context.wetland.push` 外部用法不变
- 不破坏已有横屏「每 tab 独立详情栈」行为和既有测试
- 不擅 git commit，提交前需用户确认

---

### Task 1: 技术可行性验证（反推 PageRouteInfo + 根 router 匹配）

**Files:**
- Test: `test/portrait_migration_test.dart`（新增）
- 无库改动

**目的:** 用测试实证两件事：
1. `AutoRouter.of(secondaryContext).router.stack` 能反推出保留参数的 `PageRouteInfo` 序列。
2. 将该序列 `pushAll`/`replaceAll` 到 `router.root` 顶部时，能命中根级 `DetailRoute`（问题2 已在 example 根集合新增根级 Detail），且不会 buildPathTo 重复补齐 Home。

- [ ] **Step 1: 在 example 集成测试中复现横转竖场景**
  现有 example 路由已有根级 Detail。新增 `example/test/portrait_migration_test.dart`：横屏进入详情再旋转竖屏，断言竖屏根栈顶部为当前详情页，且可 back 到 tab 页。

- [ ] **Step 2: 运行测试确认当前失败**

Run: `cd example && flutter test test/portrait_migration_test.dart`
Expected: FAIL（当前无迁移逻辑，旋转后竖屏不显示详情）

- [ ] **Step 3: 提交前需用户确认后再进入 Task 2**

---

### Task 2: `_WetlandState` 增加 mode 迁移快照 + post-frame 迁移

**Files:**
- Modify: `lib/src/wetland.dart`
- Test: `example/test/portrait_migration_test.dart`

**Interfaces:**
- Consumes: `WetlandBloc`（mode 状态）、`_secondaryKeys`（当前 tab secondary key）
- Produces:
  - `_WetlandState` 记录 `_lastMode`
  - `_setMode` 检测 `dual→single` 时，从当前 tab secondary key 快照详情栈（反推 `List<PageRouteInfo>`），存到 `_pendingMigrationRoutes`
  - BlocListener 收到 `single` 时若快照非空，post-frame `router.root` pushAll 快照，然后清空；更新 `_lastMode`

- [ ] **Step 1: 写失败测试（example 集成）**
  横屏进入详情 → 旋转竖屏 → 断言详情页仍可见（竖屏根栈顶）→ 点击返回可回到 tab 页。

- [ ] **Step 2: 运行测试确认失败**

- [ ] **Step 3: 实现快照与迁移**

- [ ] **Step 4: 运行测试确认通过**

- [ ] **Step 5: 全量验证（库测试 + example 测试 + analyze）**

---

## Self-Review

**1. Spec coverage:**
- 竖屏根栈顶展示当前详情 → Task 2 迁移到根顶部
- 可逐步 back 回 tab → 迁移 pushAll 到根栈，详情压栈，back 逐层退
- 迁移放库内 → Task 2 改 `_WetlandState`
- 目标根 router → `router.root`
- 触发 BlocListener 监听 mode → Task 2

**2. 风险点（需在测试中验证，不过度脑内推演）:**
- secondary 槽位在 mode 变 single 的 build 中卸载、`currentState` 提前变 null → 需在 `_setMode`（build 早期）先快照，避免 post-frame 读取不到。
- 反推的 detail PageRouteInfo name 为 `DetailRoute`，根 collection 顶层需存在（问题2 已具备）→ 若不具备会 buildPathTo 补 Home（重复 tab 壳 bug），靠 Task 1 测试实证。
- `_setMode` 当前在 slot builder 中调用，需确认其 context 能访问到 secondary 栈。
