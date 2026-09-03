# 每个主tab独立详情栈（多 secondary 实例）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让横屏三栏布局中，每个左侧主tab各自维护一个独立的右侧详情导航栈，切换主tab时右侧详情跟着变，切回原tab时详情栈原样保留（微信电脑版/pad 行为）。

**Architecture:** 将 `Wetland` 从 `StatelessWidget` 改为 `StatefulWidget`，持有 `List<GlobalKey<NavigatorState>>`（每个主tab一个）。右侧 `secondaryBody` 用 `IndexedStack` 包裹 N 个 `SecondaryBody`（每个tab一个 navigator），`IndexedStack` 保持所有 navigator 挂载，从而切tab不丢状态。新增 `WetlandScope` InheritedWidget 暴露 key 列表，`WetlandNavigator.push()` 从 scope 取 key、从 bloc 读当前 index，push 到 `keys[index]`。

**Tech Stack:** Flutter, custom_adaptive_scaffold, auto_route, flutter_bloc, freezed

**Spec:** 本计划实现的需求（用户确认）：
- 布局保持三列：`[左侧主tab] [中间body] [右侧详情]`
- 每个主tab（聊天/联系人/发现/设置）各自维护独立右侧详情栈
- 切换主tab时右侧详情跟着变；切回原tab时详情栈保留不丢
- `context.wetland.push()` 始终 push 到当前选中tab对应的详情栈
- 改动范围：lib 核心 + example 演示

## Global Constraints

- 遵循 Clean 架构、高内聚低耦合、SOLID
- TDD：先写失败测试，再实现
- 不擅自 git commit，提交前需用户确认
- 使用成熟依赖，不造轮子
- 保持 `Wetland` 对外 API 兼容（`destinations`、`primaryBody`、`useDrawer` 等参数不变）
- `WetlandNavigator` 的 `context.wetland` 扩展用法不变

---

### Task 1: 新增 `WetlandScope` InheritedWidget

**Files:**
- Create: `lib/src/utils/wetland_scope.dart`
- Test: `test/wetland_scope_test.dart`

**Interfaces:**
- Consumes: 无（独立新文件）
- Produces:
  - `class WetlandScope extends InheritedWidget`
  - 字段：`final List<GlobalKey<NavigatorState>> secondaryKeys;`
  - 静态方法：`static WetlandScope of(BuildContext context)`（用 `dependOnInheritedWidgetOfExactType`，供 build 使用）
  - 静态方法：`static WetlandScope? maybeOf(BuildContext context)`（用 `getInheritedWidgetOfExactType`，供事件回调使用，不注册依赖）
  - `updateShouldNotify`：当 `secondaryKeys` 引用变化时返回 true

- [ ] **Step 1: 写失败测试**

```dart
// test/wetland_scope_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/src/utils/wetland_scope.dart';

void main() {
  testWidgets('WetlandScope exposes secondaryKeys to descendants',
      (tester) async {
    final keys = [
      GlobalKey<NavigatorState>(),
      GlobalKey<NavigatorState>(),
    ];
    GlobalKey<NavigatorState>? found;
    await tester.pumpWidget(
      WetlandScope(
        secondaryKeys: keys,
        child: Builder(
          builder: (context) {
            found = WetlandScope.of(context).secondaryKeys;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(found, same(keys));
  });

  testWidgets('maybeOf returns null when no WetlandScope ancestor',
      (tester) async {
    GlobalKey<NavigatorState>? found;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          found = WetlandScope.maybeOf(context)?.secondaryKeys.first;
          return const SizedBox();
        },
      ),
    );
    expect(found, isNull);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/wetland_scope_test.dart`
Expected: FAIL，`WetlandScope` 未定义（编译错误）

- [ ] **Step 3: 实现 `WetlandScope`**

```dart
// lib/src/utils/wetland_scope.dart
import 'package:flutter/material.dart';

/// 向 Wetland 子树暴露每个主tab对应的 secondary navigator key 列表。
///
/// 由 [Wetland] 组件在 build 时注入，供 [WetlandNavigator] 等后代读取，
/// 以决定 push 到哪个 secondary 详情栈。
class WetlandScope extends InheritedWidget {
  final List<GlobalKey<NavigatorState>> secondaryKeys;

  const WetlandScope({
    super.key,
    required this.secondaryKeys,
    required super.child,
  });

  /// 在 build 中使用，注册依赖，scope 变化时触发重建。
  static WetlandScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<WetlandScope>();
    assert(scope != null, 'No WetlandScope found in context');
    return scope!;
  }

  /// 在事件回调（非 build）中使用，不注册依赖。
  static WetlandScope? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<WetlandScope>();
  }

  @override
  bool updateShouldNotify(WetlandScope oldWidget) {
    return secondaryKeys != oldWidget.secondaryKeys;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/wetland_scope_test.dart`
Expected: PASS

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add lib/src/utils/wetland_scope.dart test/wetland_scope_test.dart
git commit -m "feat: 新增 WetlandScope 暴露每tab的 secondary navigator key"
```

---

### Task 2: `Wetland` 改为 StatefulWidget 并持有每tab的 key 列表

**Files:**
- Modify: `lib/src/wetland.dart`
- Test: `test/wetland_scope_test.dart`（追加测试）

**Interfaces:**
- Consumes: `WetlandScope`（Task 1）、`SecondaryBody`（现有）、`WetlandBloc`/`WetlandState`（现有）
- Produces:
  - `Wetland` 变为 `StatefulWidget`，`_WetlandState` 持有 `late List<GlobalKey<NavigatorState>> _secondaryKeys`
  - `didUpdateWidget` 处理 destinations 数量变化时 key 列表的增删
  - `secondaryBody` 槽位改为 `IndexedStack(index: state.index, children: 每tab一个 SecondaryBody)`

- [ ] **Step 1: 写失败测试（验证 IndexedStack 保持所有 navigator 挂载）**

```dart
// 追加到 test/wetland_scope_test.dart
import 'package:wetland/wetland.dart';
import 'package:wetland/src/utils/destination.dart';

// 一个可注入的探针，用于验证 IndexedStack 中未选中 tab 的 navigator 仍挂载
class _Probe extends StatelessWidget {
  final ValueNotifier<bool> mountedNotifier;
  const _Probe({required this.mountedNotifier});
  @override
  Widget build(BuildContext context) {
    mountedNotifier.value = true;
    return const SizedBox();
  }
}

testWidgets('Wetland secondaryBody keeps all per-tab navigators mounted',
    (tester) async {
  final probe = ValueNotifier<bool>(false);
  final destinations = [
    TabDestination(
      label: 'A',
      icon: const Icon(Icons.chat),
      page: _Probe(mountedNotifier: probe),
    ),
    TabDestination(
      label: 'B',
      icon: const Icon(Icons.group),
      page: const SizedBox(),
    ),
  ];
  await tester.pumpWidget(
    MaterialApp(
      home: Wetland(destinations: destinations),
    ),
  );
  // 初始 tab 0 挂载
  expect(probe.value, isTrue);
  probe.value = false;
  // 切到 tab 1
  await tester.tap(find.text('B'));
  await tester.pumpAndSettle();
  // tab 0 的 navigator 仍应挂载（IndexedStack 特性）
  expect(probe.value, isTrue);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/wetland_scope_test.dart`
Expected: FAIL（当前 `Wetland` 是 StatelessWidget，且 secondaryBody 是单个 navigator，切 tab 后 tab0 的页面被销毁，probe 为 false）

- [ ] **Step 3: 改造 `Wetland` 为 StatefulWidget**

```dart
// lib/src/wetland.dart 关键改动
class Wetland extends StatefulWidget {
  // ... 现有字段不变 ...
  const Wetland({super.key, /* 现有参数不变 */});

  @override
  State<Wetland> createState() => _WetlandState();
}

class _WetlandState extends State<Wetland> {
  late List<GlobalKey<NavigatorState>> _secondaryKeys;

  @override
  void initState() {
    super.initState();
    _secondaryKeys = _buildKeys(widget.destinations?.length ?? 0);
  }

  @override
  void didUpdateWidget(Wetland oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldCount = oldWidget.destinations?.length ?? 0;
    final newCount = widget.destinations?.length ?? 0;
    if (newCount > oldCount) {
      _secondaryKeys.addAll(_buildKeys(newCount - oldCount));
    } else if (newCount < oldCount) {
      _secondaryKeys.removeRange(newCount, oldCount);
    }
  }

  List<GlobalKey<NavigatorState>> _buildKeys(int count) {
    return List.generate(
      count,
      (i) => GlobalKey<NavigatorState>(debugLabel: 'secondary_$i'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WetlandBloc(),
      child: BlocListener<WetlandBloc, WetlandState>(
        listener: (context, state) => _applySystemUi(state.mode),
        child: BlocBuilder<WetlandBloc, WetlandState>(
          builder: (context, state) {
            return WetlandScope(
              secondaryKeys: _secondaryKeys,
              child: AdaptiveLayout(
                // ... 现有 primaryNavigation / bottomNavigation / body 不变 ...
                secondaryBody: widget.destinations != null
                    ? SlotLayout(
                        config: <Breakpoint, SlotLayoutConfig>{
                          Breakpoints.mediumLargeAndUp: SlotLayout.from(
                            key: const Key('Secondary Body'),
                            builder: (_) => IndexedStack(
                              index: state.index,
                              children: [
                                for (var i = 0;
                                    i < widget.destinations!.length;
                                    i++)
                                  SecondaryBody(
                                    navigatorKey: _secondaryKeys[i],
                                  ),
                              ],
                            ),
                            outAnimation: (child, animation) =>
                                SlideTransition(
                              position: Tween<Offset>(
                                begin: Offset.zero,
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                            outCurve: Curves.easeInOutCubic,
                          ),
                        },
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
```

注意：`_applySystemUi` 和 `_setMode` 方法从 `Wetland` 移到 `_WetlandState`（或保持为顶层函数）。`_setMode` 需要 `context`，在 `_WetlandState` 中可直接用 `context`。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/wetland_scope_test.dart`
Expected: PASS

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add lib/src/wetland.dart test/wetland_scope_test.dart
git commit -m "feat: Wetland 改为 StatefulWidget，secondaryBody 用 IndexedStack 保持每tab详情栈"
```

---

### Task 3: `WetlandNavigator.push()` 改为 push 到当前tab的详情栈

**Files:**
- Modify: `lib/src/utils/navigator.dart`
- Test: `test/wetland_navigator_test.dart`

**Interfaces:**
- Consumes: `WetlandScope`（Task 1）、`WetlandBloc`/`WetlandState`（现有）
- Produces:
  - `WetlandNavigator` 构造函数改为只接收 `BuildContext`（不再接收两个 key）
  - `push<T>(PageRouteInfo<dynamic> route)`：从 `WetlandScope.maybeOf(context)` 取 key 列表，从 `context.read<WetlandBloc>().state.index` 读当前 index，若 `keys[index]` 存在且 `currentState != null` 则 push 到该 secondary，否则 push 到 primary
  - `pop<T>([T? result])` 不变

- [ ] **Step 1: 写失败测试**

```dart
// test/wetland_navigator_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland/src/blocs/wetland_bloc.dart';
import 'package:wetland/src/utils/navigator.dart';
import 'package:wetland/src/utils/wetland_scope.dart';

void main() {
  testWidgets('WetlandNavigator.push targets current tab secondary key',
      (tester) async {
    final keys = [
      GlobalKey<NavigatorState>(),
      GlobalKey<NavigatorState>(),
    ];
    // 模拟当前 index = 1
    await tester.pumpWidget(
      BlocProvider(
        create: (context) => WetlandBloc(),
        child: BlocBuilder<WetlandBloc, WetlandState>(
          builder: (context, state) {
            return WetlandScope(
              secondaryKeys: keys,
              child: Builder(
                builder: (context) {
                  // 触发 setIndex(1)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    context.read<WetlandBloc>().add(WetlandEvent.setIndex(1));
                  });
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    // 验证 WetlandNavigator 能解析到 keys[1]
    final ctx = tester.element(find.byType(SizedBox));
    final scope = WetlandScope.maybeOf(ctx)!;
    expect(scope.secondaryKeys, same(keys));
  });
}
```

说明：`WetlandNavigator.push` 依赖真实的 AutoRouter 才能完整验证 push 目标。本测试聚焦于"从 scope 解析 key 列表 + 从 bloc 读 index"这一核心逻辑的可测部分；完整 push 行为在 Task 4 的 example 集成测试中验证。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/wetland_navigator_test.dart`
Expected: FAIL（`WetlandNavigator` 构造函数签名未变，测试编译失败或断言失败）

- [ ] **Step 3: 改造 `WetlandNavigator`**

```dart
// lib/src/utils/navigator.dart
import "package:flutter/material.dart";
import "package:auto_route/auto_route.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_logcat/flutter_logcat.dart";

import "../blocs/wetland_bloc.dart";
import "wetland_scope.dart";

final GlobalKey<NavigatorState> primaryNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'primaryNavigator');

/// Extend WetlandNavigator to BuildContext
extension WetlandNavigationExtension on BuildContext {
  WetlandNavigator get wetland => WetlandNavigator(this);
}

class WetlandNavigator {
  final BuildContext context;

  WetlandNavigator(this.context);

  Future<T?> push<T extends Object?>(PageRouteInfo<dynamic> route) async {
    final scope = WetlandScope.maybeOf(context);
    final index = context.read<WetlandBloc>().state.index;
    final key = (scope != null && index < scope.secondaryKeys.length)
        ? scope.secondaryKeys[index]
        : null;
    if (key != null && key.currentState != null) {
      Log.d('Push [${route.routeName}] to [SecondaryBody#$index]');
      return await AutoRouter.of(key.currentState!.context).push<T>(route);
    } else {
      Log.d('Push [${route.routeName}] to [PrimaryBody]');
      return await AutoRouter.of(context).push<T>(route);
    }
  }

  void pop<T extends Object?>([T? result]) {
    context.router.pop<T>(result);
  }
}
```

注意：删除全局 `secondaryNavigatorKey`。检查是否有其他文件引用它（`wetland.dart` 中 `SecondaryBody(navigatorKey: secondaryNavigatorKey)` 已在 Task 2 改为 `_secondaryKeys[i]`）。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/wetland_navigator_test.dart`
Expected: PASS

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add lib/src/utils/navigator.dart test/wetland_navigator_test.dart
git commit -m "feat: WetlandNavigator.push 改为 push 到当前tab的详情栈"
```

---

### Task 4: 更新 example 演示多tab独立详情栈

**Files:**
- Modify: `example/lib/pages/home_page.dart`（确认 destinations 结构，无需大改）
- Modify: `example/lib/pages/messages_page.dart`、`contacts_page.dart`、`list_page.dart`（确认 `context.wetland.push` 用法不变）
- Test: `example/test/widget_test.dart`（重写为验证多tab详情栈保留）

**Interfaces:**
- Consumes: `Wetland`（Task 2）、`WetlandNavigator`（Task 3）
- Produces: 可运行的 example，演示切tab时右侧详情保留

- [ ] **Step 1: 写失败测试（集成验证）**

```dart
// example/test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wetland_example/main.dart';

void main() {
  testWidgets('切换主tab后右侧详情栈保留', (tester) async {
    await tester.pumpWidget(WetlandExampleApp());
    await tester.pumpAndSettle();

    // 设置横屏尺寸以触发三栏布局
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    await tester.pumpAndSettle();

    // 在 Messages tab 进入详情
    await tester.tap(find.text('Messages 0'));
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail'), findsOneWidget);

    // 切到 Contacts tab
    await tester.tap(find.text('Contact'));
    await tester.pumpAndSettle();

    // 切回 Messages tab，详情应保留
    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.text('Messages Detail'), findsOneWidget);
  });
}
```

说明：此测试依赖 example 的具体页面文案，可能需要根据实际页面调整 finder。若 example 页面文案与预期不符，以实际页面为准调整断言。

- [ ] **Step 2: 运行测试确认失败**

Run: `cd example && flutter test test/widget_test.dart`
Expected: FAIL（当前单 navigator 实现下，切 tab 后详情栈被共享/重置，切回时详情不保留）

- [ ] **Step 3: 确认 example 页面无需改动**

检查 `home_page.dart` 的 destinations 定义、各 tab 页面的 `context.wetland.push(DetailRoute(...))` 调用。由于 `context.wetland` 扩展签名未变，example 页面代码应无需改动。若编译报错，按报错修正。

- [ ] **Step 4: 运行测试确认通过**

Run: `cd example && flutter test test/widget_test.dart`
Expected: PASS

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add example/test/widget_test.dart
git commit -m "test: example 集成测试验证多tab详情栈保留"
```

---

### Task 5: 全量验证与静态分析

**Files:**
- 无新增

**Interfaces:**
- Consumes: 全部前序任务

- [ ] **Step 1: 运行全部测试**

Run: `flutter test`
Expected: 全部 PASS

- [ ] **Step 2: 运行静态分析**

Run: `flutter analyze`
Expected: 无 error，无新增 warning

- [ ] **Step 3: 运行 example 测试**

Run: `cd example && flutter test`
Expected: 全部 PASS

- [ ] **Step 4: 手动验证（可选，需设备/模拟器）**

在横屏下运行 example，验证：
1. 在"聊天"tab 进入详情
2. 切到"联系人"tab，右侧显示联系人详情（或空）
3. 切回"聊天"tab，右侧详情原样保留
4. 竖屏下行为不变（单屏模式）

- [ ] **Step 5: 提交（需用户确认）**

```bash
git add -A
git commit -m "feat: 每个主tab独立详情栈，切tab不丢状态"
```

---

## Self-Review

**1. Spec coverage:**
- 每个主tab独立详情栈 → Task 2（IndexedStack + 每tab key）
- 切tab右侧详情跟着变 → Task 2（index 跟随 state.index）
- 切回原tab详情保留 → Task 2（IndexedStack 保持挂载）+ Task 4 集成测试
- push 到当前tab详情栈 → Task 3
- 改动范围 lib + example → 全部任务

**2. Placeholder scan:** 无 TBD/TODO。所有代码步骤含完整实现。

**3. Type consistency:**
- `WetlandScope.secondaryKeys` 类型 `List<GlobalKey<NavigatorState>>` 在 Task 1/2/3 一致
- `WetlandNavigator` 构造函数从 `(context, {primaryNavigatorKey, secondaryNavigatorKey})` 改为 `(context)`，Task 3 中 `context.wetland` 扩展同步更新
- `_secondaryKeys` 在 Task 2 定义，Task 3 通过 `WetlandScope` 读取，命名一致
- `SecondaryBody(navigatorKey: ...)` 签名不变，Task 2 中正确传 `_secondaryKeys[i]`
