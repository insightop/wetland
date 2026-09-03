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
