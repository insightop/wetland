# AGENTS.md — wetland

给维护者与 agent 的项目上下文。**全局**的开发风格、方法论（SDD/TDD）、子代理与 git 约定见
`~/.dsh/AGENTS.md`，此处不重复，只写本仓库特有的东西。

`wetland` 是基于 `auto_route` + `custom_adaptive_scaffold` 的自适应导航库：窄屏单栏（底部导航 +
全屏详情），宽屏双栏（导航栏 + 主内容 + 右侧详情），每个 destination 有独立详情栈。

---

## 架构：详情有两个「家」

理解这一个模型，其余代码都是它的推论。

| 模式 | 触发 | 详情宿主 | 详情形态 |
|---|---|---|---|
| 单栏 | 视口窄于 `Breakpoints.mediumLargeAndUp` | **根 navigator** | 全屏真路由，覆盖底部导航，走平台 push/pop 过渡 |
| 双栏 | 宽于等于该断点 | 当前 tab 的 **secondary 嵌套栈** | 右侧槽内并排展示 |

模式切换时详情在两个家之间**迁移一次**（`lib/src/wetland.dart` 的
`_migrateSecondaryToRoot` / `_backfillRootToSecondary`），双向都必须无空白帧。

三条独立机制支撑这个模型，改动前务必先读对应实现：

- `lib/src/utils/root_detail_stack.dart` — 把详情推入**根 navigator**。因按名 push 会被嵌套
  router 截获，它用**显式匹配** `RouteMatch` → 自建 `RouteData` → `navigator.push`。
- `lib/src/utils/navigator.dart` — `context.wetland` 的门面，按模式与调用来源路由到正确的家。
- `lib/src/widgets/secondary_body.dart` — 每个 tab 一个 `AutoRouter`，详情栈因此互不干扰。

---

## 不可违反的约束

每条都有实测依据；破坏它们会出现**静默**故障（无异常、白屏或详情消失），极难排查。

**根级详情必须是非不透明路由。**
不透明根路由会把其下整棵 Wetland 子树 offstage，停用其 ticker，`AdaptiveLayout` 的过渡会
**永久冻结在中间几何**（实测 body 卡在 110.6、pop 时才突跳）。见 `RootDetailStack._rootDetailRouteType`。
同时它必须显式提供过渡：auto_route 的 `CustomRouteType` 在 `transitionsBuilder` 为 null 时
原样返回 child（零动画=硬切换），故过渡委托给 `PageTransitionsTheme`。

**等待根路由入场用 `topRouteEntered`，不要用 `Route.completed`。**
后者只在 `dispose` 时完成（Flutter `routes.dart`），等它再迁移会**死锁**。

**不要重新引入 `isTopMost` 轮询。** 旧的 300 帧轮询是「primary 先占满、约 1s 后详情才出现」的病根。

**`_mountedSlot` 返回的 widget 树形状必须恒定。**
按宽度在「直接返回 child」与「包若干层」之间切换会让 Element 无法复用、整棵子树重建，
`AutoRoute` 的 `didChangeDependencies` 重跑 `setupInitialRoutes()`，**已 push 的详情被抹掉**
（实测 `stack=[/, detail]` → `[/]`）。

**每个 destination 的嵌套路由集合首项必须是 `path: ''` 外壳页。**
它让嵌套 Navigator 存在、并作为「还没有详情」时的空态画面。缺失时嵌套 Navigator
**根本不挂载**（实测 `currentState == null`），详情无处可推。公共谓词 `hasRequiredShellPage` 可用于校验。

**`internalAnimations` 保持 `true`；`_keepOnScreen` 同时用于 in/out。**
槽位尺寸补间与过渡 widget 树形状都依赖这两点，改掉会退化成「末端突跳」或「primary 抢占地」。

**布局模式由 `_derivedMode` 从布局推导，不要由槽位 builder 写回 bloc。**
后者会让 `primaryBody` 配置永远停在 `dual`，并让「以宽屏启动」时系统 UI 永不应用。
推导必须复用 `Breakpoint.isActive`（它**还含高度条件**），用裸 `MediaQuery` 宽度比较会与
`AdaptiveLayout` 实际选择的槽位不一致。

**`pop` 只影响本库拥有的详情。**
无详情时是 no-op，绝不弹 destination 或外壳页；也不要改用 auto_route 的 `maybePop`
（它在本级拒绝后会递归到 `_parent`，仍会弹掉 destination）。

**单栏详情绕过 auto_route 的 `NavigationHistory`**，因此 Web URL / 深链不同步。
移动端与桌面端不受影响。这是已知取舍，见 CHANGELOG 的 Known limitation。

---

## 代码地图

| 路径 | 职责 |
|---|---|
| `lib/wetland.dart` | 公共 API 入口（仅 4 个 export） |
| `lib/src/wetland.dart` | 根组件 `Wetland`；布局槽位、模式推导与迁移编排 |
| `lib/src/utils/navigator.dart` | `context.wetland.push/pop/canPop/maybePop` |
| `lib/src/utils/root_detail_stack.dart` | 单栏详情宿主（根 navigator） |
| `lib/src/utils/wetland_scope.dart` | 向子树暴露 secondary keys 与详情宿主 |
| `lib/src/blocs/` | `WetlandBloc`（index + mode）；`*.freezed.dart` 是生成物 |
| `lib/src/widgets/` | `PrimaryNavigation` / `BottomNavigation` / `SecondaryBody` |
| `example/` | 完整示例应用，也是端到端测试的主战场 |

公共 API 只从 `lib/wetland.dart` 导出。内部文件用 `package:wetland/src/...` 导入是测试的
既有做法（`test/wetland_scope_test.dart` 即如此），因为 `WetlandScope` 等尚未符号级导出。

---

## 工作约定

**命令**：bash 的 PATH 不含 `/opt/homebrew/bin`，需显式加前缀。

```bash
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
flutter test                      # 库测试（在仓库根）
cd example && flutter test        # 示例测试（端到端行为主要在这里）
flutter analyze --fatal-infos     # 两个目录都要过
dart pub publish --dry-run        # 发版前
openspec validate <change> --strict
```

**语言**：代码注释与 dartdoc 用**中文**（含实测数据与「为什么」）；commit message 用**中文**；
README 与 CHANGELOG 用**英文**（面向 pub.dev 使用者）。这是现状，改动时保持一致。

**测试分层**：库测试 26 条在 `test/`；**布局、过渡、迁移这类行为主要由 `example/test/` 的 40 条
端到端 widget 测试兜底**，其中不少是帧敏感的（逐帧采样宽度/位置）。改布局或迁移时，
**先跑 `example/test/`**，它是这类回归的第一道防线。

**提交前必须全绿**：`flutter test`（根 + example）+ `flutter analyze --fatal-infos`（根 + example）。
改了 workflow 时另需 `actionlint`（本机未预装，可临时装：
`GOBIN=/tmp go install github.com/rhysd/actionlint/cmd/actionlint@latest`，再用 `/tmp/actionlint` 校验）——
它能抓出 YAML 合法但 GitHub 语义错误的写法。

**发版**：改 `pubspec.yaml` 版本 + 补 CHANGELOG → 合并到 `main` → 打 tag 并推送：

```bash
git tag -a v0.3.0 -m "wetland 0.3.0" && git push origin v0.3.0
```

tag 会同时触发 `release.yml`（复用 build.yml 的五平台产物并创建 GitHub Release）与
`publish.yml`（发布到 pub.dev）。**不要为了测试而推 tag** —— 会产生不可撤回的 pub.dev 发布；
`build.yml` 的 `workflow_dispatch` 可在不推 tag 的前提下验证构建与产物命名
（手动触发只跑构建，不会创建 Release，因为 release job 仅由 tag 触发）。

---

## CI/CD

五个阶段拆成独立 workflow，与「明确发版才跑重活」的原则对应：

| Workflow | 触发 | 职责 |
|---|---|---|
| `analyze.yml` | 每次 push / PR | `flutter analyze --fatal-infos`（根 + example）；并校验 example 生成物已提交 |
| `test.yml` | 每次 push / PR | 根包与 example 的 `flutter test` |
| `build.yml` | 每次 push / PR，**以及被 release 复用** | 五平台构建并上传 artifacts |
| `release.yml` | **仅 `v*` tag** | `uses: ./build.yml` 复用构建，消费同 run 内的 artifacts 创建 Release |
| `publish.yml` | **仅 `v*` tag** | 发布到 pub.dev（官方可复用 workflow + OIDC，无长期密钥） |

两个设计点值得知道：

- **`build.yml` 是可复用 workflow（`workflow_call`）**，因此 release 的产物落在**同一次 run** 内，
  `download-artifact` 无需 run-id / token。这比让 release 用 `workflow_run` 跨 run 取产物干净：
  后者拿不到 `ref_type`（要自行反推是不是 tag），且每个 commit 的 build 完成都会触发它。
- **`publish.yml` 必须保持 `on: push: tags`**。pub.dev 只接受 tag 推送触发的运行，这是硬约束；
  它发布的是源码包，不需要平台产物，因此与 build 解耦。

`dependabot.yml` 每周检查三类依赖并自动开 PR：根包 pub、example pub、github-actions。

---

## 深入阅读

按需查阅，不必常驻上下文：

- **行为契约**：`openspec/changes/*/specs/*/spec.md` —— 每条需求都有 WHEN/THEN 场景。
- **决策与理由**：同目录的 `design.md`（含被否决的方案与实测数据）。
- **迁移考古**：`docs/research/2026-09-27-legacy-stack-migration-archaeology.md` —— 历史上被删除的
  迁移实现及其踩坑，改动迁移逻辑前值得一读。
- **面向使用者的文档**：`README.md`（快速开始、API 表、已知限制）。
- **变更历史**：`CHANGELOG.md`（含 BREAKING 与迁移建议）。

非平凡改动先走 openspec 变更（proposal → spec → design → tasks），再实现。
