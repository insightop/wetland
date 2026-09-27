# example 功能补全与空态优化 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 wetland 的 example 能完整演示框架核心能力：多层详情栈逐层下钻、切 tab 保留详情、横转竖迁移；同时消除三个重复列表页（DRY），并给右侧详情区补上引导空态。

**Architecture:** 抽出 `EntityListPage` 作为唯一列表实现（消息/联系人/发现共用，靠参数区分），列表项点击用 `context.wetland.push` 进详情，详情页内提供下钻入口以构造多层栈。空态由 wetland 库的 `SecondaryBody` 通过 `AutoRouter.placeholder` 提供，库层新增可选参数 `secondaryPlaceholder`，example 传入引导空态。

**Tech Stack:** Flutter, auto_route ^11.1.0, flutter_bloc, custom_adaptive_scaffold, skeletonizer

**Spec:** 本计划实现范围（用户已确认，来自本轮对话）：
- 详情页加下钻入口（演示多层详情栈 + 逐层 back）
- 拆分公共列表页组件（消除 messages/contacts/list 三处重复）
- 补齐空态与视觉细节（secondary 无详情时显示引导空态）
- 不在本次范围：接入登录流程、展示 useDrawer/primaryBody/IWetlandTabPage 等高级能力（用户未选）

## Global Constraints

- 遵循 Clean 架构、DRY、KISS、YAGNI、组合优于继承
- TDD：先写失败测试，再实现；每个 Task 结束必须有可独立验证的交付物
- 不破坏现有通过测试：`test/`（库，7 个）、`example/test/`（4 个）
- 运行命令一律用 `env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter <cmd>`（裸 flutter 会写 SDK 缓存被沙箱拒绝）
- 库逻辑保持通用，不依赖 example 具体页面；example 可依赖 wetland 公开 API
- `context.wetland.push/pop` 对外用法不变
- 新增库 API 必须带 dartdoc（保持 pub.dev 文档覆盖率）
- 不擅自 git commit，提交前需用户确认
- 代码生成（auto_route）用 `dart run build_runner build`，不手写 `router.gr.dart`

---

### Task 1: example 列表页 DRY 重构 —— 抽出 `EntityListPage`

**Files:**
- Create: `example/lib/pages/entity_list_page.dart`
- Modify: `example/lib/pages/messages_page.dart`, `example/lib/pages/contacts_page.dart`, `example/lib/pages/list_page.dart`
- Test: `example/test/portrait_test.dart`（现有，须继续通过）

**Interfaces:**
- Consumes: `wetland` 公开 API（`context.wetland.push`）、`DetailRoute`（`example/lib/router/router.gr.dart`）
- Produces: `EntityListPage`（`StatelessWidget`，构造参数 `String title`），三个现有页面改为薄封装，路由类名与 `@PathParam title` 保持不变

- [ ] **Step 1: 先确认现有测试基线**

Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test`
Expected: PASS（+4），记录基线

- [ ] **Step 2: 新建 `EntityListPage`**

```dart
// example/lib/pages/entity_list_page.dart
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:wetland/wetland.dart';
import '../router/router.gr.dart';

/// 可复用的实体列表页。
///
/// 消息 / 联系人 / 发现三个主 tab 共用此实现，仅 [title] 不同，
/// 避免三处近乎逐行相同的列表代码（DRY）。
class EntityListPage extends StatelessWidget {
  /// 列表标题，同时作为详情页标题的来源。
  final String title;

  const EntityListPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        itemBuilder: (context, index) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.accents[index % Colors.accents.length],
            ),
            trailing: const Icon(Icons.arrow_forward_ios),
            title: Skeletonizer(
              effect: const SolidColorEffect(),
              child: Text('$title $index'),
            ),
            subtitle: Skeletonizer(
              effect: const SolidColorEffect(),
              child: const Text('tap to open detail'),
            ),
            onTap: () => context.wetland.push(DetailRoute(title: title)),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 3: 三个页面改为薄封装**

`messages_page.dart` / `contacts_page.dart` / `list_page.dart` 全部改为如下形态（以 Messages 为例，其余只改类名与默认 title）：

```dart
// example/lib/pages/messages_page.dart
import 'package:flutter/material.dart';
import 'package:auto_route/auto_route.dart';

import 'entity_list_page.dart';

@RoutePage()
class MessagesPage extends StatelessWidget {
  final String title;
  const MessagesPage({
    @PathParam() this.title = 'Messages',
    super.key,
  });

  @override
  Widget build(BuildContext context) => EntityListPage(title: title);
}
```

同样：
- `ContactsPage` 默认 `title = 'Contacts'`
- `ListPage` 默认 `title = 'List'`（Discover tab 传入的是 `'Discover'`）

注意：`ContactsPage` 原来带 `@PathParam() this.title = 'Contacts'`，保留 `@PathParam` 注解不变，避免路由生成结果变化。

- [ ] **Step 4: 重新生成路由并跑测试**

Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/dart run build_runner build`
Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test`
Expected: PASS（+4），`router.gr.dart` 无实质变化

- [ ] **Step 5: 静态分析**

Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter analyze`
Expected: No issues found

- [ ] **Step 6: 提交（需用户确认）**

```bash
git add example/lib/pages/
git commit -m "refactor(example): 抽出 EntityListPage，消除三个列表页重复"
```

---

### Task 2: 详情页加下钻入口（演示多层详情栈）

**Files:**
- Modify: `example/lib/pages/detail_page.dart`
- Test: `example/test/portrait_migration_test.dart`（现有单层测试须继续通过）、`example/test/multi_detail_test.dart`（新增）

**Interfaces:**
- Consumes: `context.wetland.push`（库）、`DetailRoute(title: ...)`（生成的 `PageRouteInfo`）
- Produces: 详情页内「下钻」按钮，push 一个新的 `DetailRoute`，标题为 `'$title > $title'`

- [ ] **Step 1: 写失败测试（多层详情 + 逐层 back）**

```dart
// example/test/multi_detail_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏下详情页可逐层下钻并逐层返回', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 进入第一层详情
    await tester.tap(find.text('Messages 0'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);

    // 下钻到第二层
    await tester.tap(find.text('drill-down'));
    await tester.pumpAndSettle();
    expect(find.text('Messages > Messages Detail '), findsOneWidget);

    // back 回到第一层
    await tester.tap(find.text('pop-detail'));
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail '), findsOneWidget);
    expect(find.text('Messages > Messages Detail '), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test test/multi_detail_test.dart`
Expected: FAIL（找不到 `'drill-down'` 控件）

- [ ] **Step 3: 改造 `detail_page.dart`**

```dart
// example/lib/pages/detail_page.dart
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:auto_route/auto_route.dart';

import 'package:wetland/wetland.dart';
import '../router/router.gr.dart';

@RoutePage()
class DetailPage extends StatelessWidget {
  final String title;
  const DetailPage({
    @PathParam() this.title = 'Detail',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => context.wetland
                        .push(DetailRoute(title: '$title > $title')),
                    child: const Text('drill-down'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => context.wetland.pop(),
                    child: const Text('pop-detail'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                Skeletonizer(
                  effect: const SolidColorEffect(),
                  child: ListTile(
                    isThreeLine: true,
                    leading: const CircleAvatar(),
                    title: Text('$title Detail '),
                    subtitle: SizedBox(
                      height: 500,
                      child: Wrap(
                        children: [
                          Text('${List.generate(100, (index) => 'wetland')}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

注意：保留 `'$title Detail '`（尾随空格）文案，因为现有测试依赖它。

- [ ] **Step 4: 运行新增测试 + 现有测试**

Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test`
Expected: PASS（+5，含新增 1 个）

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add example/lib/pages/detail_page.dart example/test/multi_detail_test.dart
git commit -m "feat(example): 详情页支持逐层下钻，演示多层详情栈"
```

---

### Task 3: 库支持 secondary 空态占位（`secondaryPlaceholder`）

**Files:**
- Modify: `lib/src/widgets/secondary_body.dart`, `lib/src/wetland.dart`
- Test: `test/secondary_placeholder_test.dart`（新增）

**Interfaces:**
- Consumes: `AutoRouter.placeholder`（auto_route 公开 API）
- Produces:
  - `SecondaryBody` 新增 `final WidgetBuilder? placeholder;`
  - `Wetland` 新增 `final WidgetBuilder? secondaryPlaceholder;`（透传给每个 `SecondaryBody`）

- [ ] **Step 1: 写失败测试**

```dart
// test/secondary_placeholder_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/wetland.dart';

class _TestRouter extends RootStackRouter { /* 与 wetland_navigator_test.dart 同构的最小 router */ }

void main() {
  testWidgets('传 secondaryPlaceholder 时 secondary 显示该占位', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp.router(
      routerConfig: _TestRouter().config(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('NO_DETAIL'), findsOneWidget);
  });
}
```

（`_TestRouter` 直接复制 `test/wetland_navigator_test.dart` 中的同名类，并把 `Wetland(...)` 加上 `secondaryPlaceholder: (_) => const Center(child: Text('NO_DETAIL'))`。）

- [ ] **Step 2: 运行确认失败**

Run: `env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test test/secondary_placeholder_test.dart`
Expected: FAIL（编译失败：`secondaryPlaceholder` 未定义）

- [ ] **Step 3: 给 `SecondaryBody` 加 `placeholder`**

```dart
// lib/src/widgets/secondary_body.dart（增量改动）
class SecondaryBody extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  final void Function(int index, StackRouter router)? onRouterReady;
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
  // ...
}

// _SecondaryBodyState.build
@override
Widget build(BuildContext context) {
  return AutoRouter(
    navigatorKey: widget.navigatorKey,
    placeholder: widget.placeholder,
  );
}
```

- [ ] **Step 4: 给 `Wetland` 加 `secondaryPlaceholder` 并透传**

在 `lib/src/wetland.dart`：
1. 加字段与构造参数（带 dartdoc）：

```dart
/// 右侧详情区在详情栈为空时显示的占位（如引导文案）。
/// 仅横屏 dual 模式的 secondary 生效。
final WidgetBuilder? secondaryPlaceholder;
```

2. 构造参数加 `this.secondaryPlaceholder,`
3. `SecondaryBody(...)` 处加 `placeholder: widget.secondaryPlaceholder,`

- [ ] **Step 5: 跑测试**

Run: `env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test`
Expected: PASS（+8，含新增 1 个）

- [ ] **Step 6: 提交（需用户确认）**

```bash
git add lib/src/wetland.dart lib/src/widgets/secondary_body.dart test/secondary_placeholder_test.dart
git commit -m "feat: Wetland 支持 secondaryPlaceholder 详情空态"
```

---

### Task 4: example 使用空态 + 视觉细节打磨

**Files:**
- Modify: `example/lib/pages/home_page.dart`
- Test: `example/test/empty_state_test.dart`（新增）

**Interfaces:**
- Consumes: `Wetland.secondaryPlaceholder`（Task 3）
- Produces: example 横屏下未选详情时右侧显示引导空态

- [ ] **Step 1: 写失败测试**

```dart
// example/test/empty_state_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('横屏未选详情时右侧显示引导空态', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    expect(find.text('Select an item to see details'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test test/empty_state_test.dart`
Expected: FAIL

- [ ] **Step 3: `home_page.dart` 传入 `secondaryPlaceholder`**

```dart
// example/lib/pages/home_page.dart（build 内）
return Wetland(
  destinations: destinations,
  secondaryPlaceholder: (context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined, size: 48),
          SizedBox(height: 12),
          Text(
            'Select an item to see details',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  ),
);
```

- [ ] **Step 4: 跑全部 example 测试**

Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test`
Expected: PASS（+6）

- [ ] **Step 5: 静态分析 + 库测试**

Run: `cd example && env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter analyze`
Run: `env FLUTTER_ROOT=/tmp/flutter_sdk /tmp/flutter_sdk/bin/flutter test`
Expected: No issues；+8 PASS

- [ ] **Step 6: 提交（需用户确认）**

```bash
git add example/lib/pages/home_page.dart example/test/empty_state_test.dart
git commit -m "feat(example): 右侧详情区补引导空态"
```

---

## Self-Review

**1. Spec coverage:**
- 详情页下钻入口 → Task 2
- 拆分公共列表页 → Task 1
- 空态与视觉细节 → Task 3（库支持）+ Task 4（example 使用）

**2. Placeholder scan:** 无 TBD/TODO；Task 3 Step 1 的 `_TestRouter` 明确要求从现有测试复制同构实现，未留空。

**3. Type consistency:**
- `EntityListPage({required String title})` 在 Task 1 定义，Task 1 Step 3 三处调用一致
- `secondaryPlaceholder` 类型 `WidgetBuilder?` 在 Task 3/4 一致；`SecondaryBody.placeholder` 同为 `WidgetBuilder?`
- 测试文案 `'Messages Detail '`（含尾随空格）在 Task 2/3 测试中一致沿用，与现有测试保持同源
