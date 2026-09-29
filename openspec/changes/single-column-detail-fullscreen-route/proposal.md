# Proposal

## Why

单栏（竖屏/窄屏）模式下，详情页目前**不是一条真正的路由**，而是被塞在主布局右侧的 `secondaryBody` 槽里、靠 `bodyRatio` 在 `1.0 ↔ 0.0` 之间做**宽度插值**来「进出」。这带来两个用户可见的缺陷：

1. **进入/退出详情不像 push/pop，而像一次缩放**：能看到 scaffold 在切换比例；退出时还会先闪出栈底的空白外壳页（logo），随后才是 layout 归位。
2. **单栏有详情时底部导航仍然存在**：因为「底部导航槽」与「占满屏幕的详情槽」是并排的两个槽位，详情盖不住它。

根因是同一个架构选择：**单栏详情住在常驻的 `secondaryBody` 嵌套 navigator 里**。只要详情不是外层 navigator 上的一条真路由，就无法同时获得「真 push/pop」与「盖住底部导航」。此外，`secondaryBody` 的嵌套栈栈底是空态外壳页（logo），因此真 pop 会露出空态页而非列表页——这也是「退出时闪空白」的来源。

## What Changes

- **单栏模式下，详情改为推入根 navigator 的真路由**：全屏覆盖（包含底部导航），进入/退出是标准的 push / pop 滑动动画。
- **双栏模式保持现状**：详情继续住在各 tab 的 `secondaryBody` 嵌套 navigator 中，右侧双栏、per-tab 详情栈保留。
- **模式切换时在「两个家」之间迁移详情**（单⇄双），采用 **先 push 到目标家、再从源家移除** 的顺序，避免中间态空白；且**不使用**旧实现里 `isTopMost` 轮询（那是「先占满、1s 后才出现详情」的病根）。
- **`WetlandNavigator` 增加显式的根解析路径**：不再依赖 `AutoRouter.of(context).push` 的路由名解析（它在根下存在 4 个同构 `NestedStackRouter` 时会被错误截获），改用「用当前 tab 的 route collection 匹配 → 构造 `RouteData(router: root)` → `root.navigatorKey.currentState.push`」。
- **BREAKING（内部 API 层面）**：`WetlandNavigator` 在单栏下的 pop/push 归属语义变更，`scope == null` 分支的行为也随之变更。
- **BREAKING（行为层面）**：单栏下详情不再出现在 `secondaryBody` 槽内；依赖「单栏详情在 secondary 槽 / `bodyRatio == 0.0`」这一旧架构的测试必须改写。
- **不再要求 / 不再需要** example 中为「竖屏全屏详情」而额外声明的根级 `DetailRoute`——库改用 nested 集合匹配后，app 对同一页面**只需声明一次**。该重复声明应移除，以免误导。

## Capabilities

### New Capabilities

- `adaptive-detail-navigation`：定义 Wetland 的「详情导航」契约——单栏与双栏各自的详情宿主、模式切换时的迁移语义、旋转/尺寸变化时的状态保持、pop/push 的归属判定，以及「单栏详情必须全屏且覆盖底部导航」等可验收行为。

### Modified Capabilities

（无。`openspec/specs/` 当前为空，本项目尚无既有 capability；本次为该行为的首次规格化。）

## Impact

- **库代码**
  - `lib/src/utils/navigator.dart`：`WetlandNavigator.push` / `pop` 的解析与归属逻辑（单栏走根、双栏走 secondary），`scope == null` 分支。
  - `lib/src/wetland.dart`：`_targetBodyRatio`（单栏不再因 `hasDetail` 被拉到 `0.0`）、`_currentTabHasDetail` 的使用、模式切换时的迁移接线、`secondaryBody` 槽在单栏下的处置。
  - `lib/src/utils/secondary_stack.dart`：`secondaryIsShellOnly` / `secondaryHasDetail` 的语义与消费点随迁移规则调整。
  - 可能新增一个「详情迁移」内部模块（承载单⇄双的 push/remove 编排）。
- **示例**
  - `example/lib/router/router.dart`：移除为竖屏全屏详情额外声明的根级 `DetailRoute`。
- **测试**
  - 单栏详情改为根路由后，下列既有测试断言旧架构，需改写或替换：`portrait_test`、`native_panel_test`、`portrait_rotate_keeps_detail_test`、`panel_transition_*`（3 个）、`expand_backfill_test`、`shrink_no_extra_push_test`、`shrink_no_primary_flash_test`、`secondary_shell_is_empty_state_test`、`empty_vs_shell_test`、`landscape_push_secondary_test`、`multi_detail_test`、`bottom_nav_exit_direction_test`；其中 `panel_transition_timeline_test` 是**显式的旧架构判别器**（断言详情留在 secondary 槽），必须重新定义其判别目标。
- **依赖与平台**：不新增第三方依赖。已知代价：根 navigator 的显式 push 绕过 auto_route 的 `NavigationHistory`，因此 **Web URL / 深链不会随单栏详情更新**（移动端与桌面端不受影响）；若未来必须保留 URL 同步，需另立变更。
- **公开 API**：`Wetland` / `WetlandNavigator` 的对外签名不变；变更集中在内部行为与语义。
