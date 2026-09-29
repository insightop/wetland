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
