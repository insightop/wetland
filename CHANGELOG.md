## 0.2.1

A navigation-safety release. Several defects could crash or silently break a
caller's app with no exception to point at the cause; they are fixed here.

### Breaking

- **`context.wetland.pop()` no longer pops the destination.** It now only pops a
  detail the library owns, and is a **no-op** when no detail is open. Previously,
  calling it on a destination's root page in single-column mode popped the whole
  `Wetland` off the navigator (blank screen, no exception), and in dual-column
  mode it popped the destination's shell page, after which no detail could ever
  become visible. If you were relying on `pop()` to exit the app, handle that in
  your host app instead. Use `canPop` / `maybePop()` to guard a back button.
- **`await context.wetland.push<T>(route)` now returns the detail's pop result in
  dual-column mode too.** Previously the dual-column "replace" path completed
  immediately with `null` even though the detail was on screen, so the same call
  behaved differently depending on screen orientation. It now completes when the
  detail is popped, with its result, in both modes.

### Fixed

- `Wetland` with a single destination no longer crashes in single-column mode
  (Flutter's `BottomNavigationBar` requires at least two items); the bottom bar is
  simply not built when there is nothing to switch between.
- `Wetland(destinations: [])` now fails an assertion at the construction site
  instead of throwing `RangeError` during layout.
- The layout mode is now derived from the actual layout rather than from whichever
  slot builder happened to run. This fixes an app that starts wide never having its
  system UI (status bar / navigation bar) applied.

### Added

- `WetlandNavigator.canPop` and `WetlandNavigator.maybePop()` for safe back-button
  handling.
- `hasRequiredShellPage` — a public predicate to validate the empty-path shell-page
  convention each destination's nested routes must follow.
- A real README: install, quick start (including the required
  `AutoRoute(path: '', ...)` shell entry), full API tables, single- vs dual-column
  behaviour, and known limitations.

### Known limitation (documented, not fixed)

- `primaryBody` does not support details. With no `destinations` there is no
  secondary region and therefore no nested navigator to host one; details pushed in
  this mode are never visible. Use `destinations` if you need details. Hosting
  details in `primaryBody` mode was never implemented and remains a future feature.

## 0.2.0

- **Breaking:** In single-column mode, a detail page is now a genuine full-screen
  route pushed onto the root navigator, instead of the secondary slot being
  widened to fill the screen. This fixes three user-visible problems at once:
  - the bottom navigation bar is now covered while a detail is open;
  - opening a detail no longer animates the outer layout ratio (no more
    "scaffold scaling" look);
  - popping a detail no longer flashes the secondary stack's empty placeholder.
- **New:** Details migrate between their two hosts when the layout mode changes:
  widening moves an open detail back into the current tab's secondary slot,
  narrowing moves it onto the root navigator. Both directions are continuous,
  and repeated switching never loses the detail.
- **Fix:** Single-column push/pop uses the platform page transition again
  (iOS/macOS Cupertino, Android Material) rather than switching instantly.
- **Fix:** Changing layout mode while a detail is open no longer freezes the
  panel transition at a mid-animation geometry.
- **Removed:** `lib/src/utils/secondary_stack.dart` (no consumers; its
  predicates were insufficient for migration selection).
- **Note:** Apps no longer need a duplicate root-level route declaration for
  portrait full-screen details; a single declaration per detail route suffices.

### Known limitation

Single-column details are pushed through `NavigatorState.push` with an explicit
`RouteData`, which bypasses auto_route's `NavigationHistory`. Deep links and
browser-URL sync therefore do not reflect single-column details on web.
Mobile and desktop are unaffected.

## 0.1.0

- **New:** `WetlandNavigator.push` now distinguishes the call origin: tapping a list item in the primary body replaces the current tab's secondary detail stack, while tapping inside a detail page drills down (stacks) on top of it.
- **New:** When rotating from landscape to portrait, the current tab's secondary detail stack is migrated to the portrait root stack, so the detail page stays on top and can be popped back to the tab page.
- **Fix:** In portrait mode, tapping a list item no longer pushes a duplicate list page; it now opens the detail page full-screen (root-level `DetailRoute`).
- **Docs:** Added dartdoc comments to the public API.

## 0.0.1

- Initial release.
- Adaptive navigation framework built on `custom_adaptive_scaffold` and `auto_route`.
- Landscape three-column layout: primary tab navigation on the left, main content in the middle, detail panel on the right.
- Each primary tab keeps its own independent right-hand detail navigation stack; switching tabs preserves the detail stack (WeChat desktop / iPad behavior).
- Provides the `Wetland` widget, `TabDestination` configuration, and the `context.wetland.push/pop` navigation extension.
