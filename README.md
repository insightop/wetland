# Wetland

An adaptive navigation framework for Flutter. It gives a phone app a single-column layout with a
bottom navigation bar, and gives a tablet or desktop window a three-column layout — left
navigation rail, main content, and a right-hand detail panel — from the same widget tree. Each
destination keeps its own independent detail stack, so switching tabs and coming back restores
the detail you had open.

Built on [`auto_route`](https://pub.dev/packages/auto_route) and
[`custom_adaptive_scaffold`](https://pub.dev/packages/custom_adaptive_scaffold).

## Install

```yaml
dependencies:
  wetland: ^0.2.1
  auto_route: ^11.1.0

dev_dependencies:
  auto_route_generator: ^10.0.0
  build_runner: ^2.16.0
```

## Quick start

### 1. Declare your routes

Every destination's nested route collection **must** begin with an empty-path shell page. The
shell keeps the nested `Navigator` alive and is what the right-hand panel shows before a detail is
opened.

```dart
@AutoRouterConfig()
class AppRouter extends RootStackRouter {
  @override
  RouteType get defaultRouteType => const RouteType.adaptive();

  @override
  List<AutoRoute> get routes => [
        AutoRoute(
          page: HomeRoute.page,
          initial: true,
          children: [
            // Required: the empty-path shell page, first in the list.
            AutoRoute(path: '', page: PlaceholderRoute.page),
            AutoRoute(page: MessagesRoute.page),
            AutoRoute(page: ContactsRoute.page),
            // Declare each detail route ONCE. Wetland picks the right host
            // (root navigator in single-column, this tab's secondary stack in
            // dual-column) from the current layout — no duplicate declaration.
            AutoRoute(page: DetailRoute.page),
          ],
        ),
      ];
}
```

### 2. Configure destinations

```dart
Wetland(
  destinations: [
    TabDestination(
      label: 'Messages',
      icon: const Icon(Icons.chat_bubble_outline_rounded),
      selectedIcon: const Icon(Icons.chat_bubble_rounded),
      page: const MessagesPage(),
    ),
    TabDestination(
      label: 'Contacts',
      icon: const Icon(Icons.group_outlined),
      page: const ContactsPage(),
    ),
  ],
)
```

### 3. Navigate

`context.wetland` is available anywhere inside the `Wetland` subtree.

```dart
// Open a detail. Tapping from a destination's content page replaces the tab's
// current detail; tapping from inside a detail drills down (stacks).
final result = await context.wetland.push(DetailRoute(id: 42));

// Guard a back button safely — never destroys the app.
if (context.wetland.canPop) {
  context.wetland.pop();
}
// or, unconditionally safe:
await context.wetland.maybePop();
```

## API

### `Wetland`

| Parameter | Type | Notes |
|---|---|---|
| `destinations` | `List<TabDestination>?` | The destinations. Must be non-empty when provided. Mutually exclusive with `primaryBody`. |
| `primaryBody` | `Widget?` | A single main body instead of `destinations`. **Details are not supported in this mode** (see Limitations). |
| `transitionDuration` | `Duration` | Layout transition duration. Defaults to 1000ms. |
| `primaryNavigationRailLeading` | `Widget?` | Optional widget above the landscape navigation rail. |
| `primaryNavigationRailTrailing` | `Widget?` | Optional widget below the landscape navigation rail. |
| `useDrawer` | `bool` | Reserved; currently has no effect. |

### `TabDestination`

| Field | Type | Notes |
|---|---|---|
| `label` | `String` | Label shown in the navigation UI. |
| `icon` | `Widget` | Icon when unselected. |
| `selectedIcon` | `Widget?` | Icon when selected; falls back to `icon`. |
| `page` | `Widget` | The destination's content page. |

### `context.wetland`

| Member | Signature | Notes |
|---|---|---|
| `push` | `Future<T?> push<T>(PageRouteInfo route)` | Completes with the detail's pop result, **in both layout modes**. |
| `pop` | `void pop<T>([T? result])` | Pops a detail the library owns. A **no-op** when no detail is open — it never pops the destination or its shell page. |
| `canPop` | `bool` | Whether a detail is currently open. |
| `maybePop` | `Future<bool> maybePop<T>([T? result])` | Pops only if possible; reports whether it popped. |

## Behaviour

**Single-column** (narrower than the 840dp breakpoint): bottom navigation plus full-screen
content. Opening a detail pushes a genuine full-screen route onto the root navigator, so it covers
the bottom navigation and uses the platform's push/pop transition. Popping reveals the content
page — no empty placeholder is shown.

**Dual-column** (840dp and wider): navigation rail, main content, and the detail in the
right-hand panel. Each destination has its own detail stack, preserved across tab switches.

**Changing layout mode with a detail open** migrates the detail between the two hosts (root
navigator ↔ the current destination's secondary stack), continuously in both directions.

## Limitations

- **Web URL / deep links do not reflect single-column details.** In single-column mode a detail is
  pushed through `NavigatorState.push` with an explicit `RouteData`, which bypasses auto_route's
  `NavigationHistory`. Mobile and desktop are unaffected.
- **`primaryBody` does not support details.** With `destinations == null` no secondary region is
  built, so there is no nested navigator to host a detail. Use `destinations` if you need details.
- **`useDrawer` is not implemented.**
- Release build artifacts are unsigned in CI (no certificates configured); the example's Android
  build uses debug signing.

## Example

See [`example/`](example/) for a complete app demonstrating per-tab detail stacks, drill-down,
`pop`, custom transition durations, and rotation behaviour.

## License

MIT — see [LICENSE](LICENSE).
