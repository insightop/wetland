# Tasks

Notes for the implementer:

- Test command is `/opt/homebrew/share/flutter/bin/flutter test` (bare `flutter` is not on PATH). Library tests run from the repo root; example tests run from `example/`.
- Baselines before starting: library `+8` tests pass, example `+30` tests pass, `flutter analyze` clean in both root and `example`.
- Write the test first (TDD) for every task that changes behavior. Where a task says "verify X test passes", that test must exist and fail before the implementation.
- Do not reintroduce top-most polling, `internalAnimations: false`, a `secondaryPlaceholder` overlay, or any width-dependent widget-tree shape change (see design.md D4/D6/D7 and Risks).

## 1. Root navigation resolution (design D2/D3)

- [x] 1.1 Add a test proving that opening a detail in single-column mode lands on the **root** navigator: assert the detail's `Scaffold` covers the full screen (`Rect` equals the screen size) and that popping once returns to the destination content, not to a shell page. Verify it fails against current code.
- [x] 1.2 Implement explicit root resolution in `lib/src/utils/navigator.dart`: match the route against the current destination's route collection, build `RouteData` bound to the root router, and push on the root navigator's state. Verify 1.1 passes and `test/wetland_navigator_test.dart` still passes (update that test only where it encodes name-based resolution).
- [x] 1.3 Add a test that drilling down from inside a root-hosted detail (the `scope == null` path) pushes onto the root navigator and stacks correctly (two details deep, pop once → previous detail, pop again → destination root). Verify it passes after implementing the `scope == null` branch.
- [x] 1.4 Implement the `scope == null` branch to target the root navigator instead of `AutoRouter.of(context).push`, then verify 1.3 passes.
- [x] 1.5 Add a test that popping a detail never changes the selected destination and never pops the destination root; implement the pop-ownership rule (root route present and top-most → root pop, else the dual-mode host) until it passes.

## 2. Single-column full-screen host (design D1/D6)

- [x] 2.1 Add a test asserting that while a detail is open in single-column mode the bottom navigation is not hit-testable, and that it is hit-testable again after popping. Verify it fails before the host switch.
- [x] 2.2 Add a test asserting that opening a detail in single-column mode does **not** resize the surrounding layout regions: sample the layout region geometry across the transition and assert it is stable, while the detail enters through a route transition. Verify it fails before the host switch.
- [x] 2.3 Switch single-column detail hosting to the root navigator in `lib/src/wetland.dart`, and decouple `_targetBodyRatio` from detail presence in single mode, until 2.1 and 2.2 pass.
- [x] 2.4 Add a test that no empty placeholder page is visible at any sampled frame while popping a single-column detail, and that the revealed page is the destination content that opened it. Verify it passes; fix the host wiring if it does not.
- [x] 2.5 Add a test asserting the nested secondary navigator remains mounted (its key resolves) while in single-column mode with no detail routed to it, so the dual-mode host decision stays sound. Verify it passes without changing the mounted-slot shape.

## 3. Dual-column regression safety (design D1/D7)

- [x] 3.1 Verify `example/test/widget_test.dart` (per-destination detail history across destination switches) still passes unchanged; if it fails, fix the dual-mode path rather than the test.
- [x] 3.2 Add a test asserting that in dual-column mode the detail renders in the secondary region while the primary content remains rendered and the primary navigation remains hit-testable. Verify it passes.
- [x] 3.3 Rewrite the tests that encode the old single-column architecture so they assert the new spec scenarios instead: `portrait_test`, `native_panel_test`, `portrait_rotate_keeps_detail_test`, `panel_transition_animation_test`, `panel_transition_no_black_test`, `panel_transition_symmetry_test`, `panel_transition_timeline_test`, `secondary_shell_is_empty_state_test`, `empty_vs_shell_test`, `landscape_push_secondary_test`, `multi_detail_test`, `bottom_nav_exit_direction_test`. For `panel_transition_timeline_test.dart`, redefine its discriminator to assert the new architecture (detail hosted by the root navigator in single mode, no layout resizing during the transition) rather than deleting its coverage. Verify the whole example suite passes.

## 4. Mode-change migration (design D4/D5)

- [x] 4.1 Add a test for widening with a detail open: the same detail becomes visible in the secondary region and retains its content state. Verify it fails before migration is implemented.
- [x] 4.2 Add a test for narrowing with a detail open: the same detail becomes visible full-screen, with no placeholder visible at any sampled frame. Verify it fails before migration is implemented.
- [x] 4.3 Implement push-then-remove migration for both directions, selecting only the destination's detail entries (skip the bottom shell entry so an empty state never migrates), until 4.1 and 4.2 pass. Do not add top-most polling.
- [x] 4.4 Add a test for repeated single⇄dual switches while a detail is open, asserting the detail remains open after every switch; verify it passes.
- [x] 4.5 Rewrite `example/test/expand_backfill_test.dart`, `shrink_no_extra_push_test.dart`, and `shrink_no_primary_flash_test.dart` to assert the new migration semantics (preserved detail, no extra push, no primary flash, no empty frame), and verify they pass.
- [x] 4.6 Update `test/secondary_shell_empty_state_test.dart` and `test/wetland_scope_test.dart` where they assume the old single-mode host, and verify the library suite passes (`+8` baseline, adjusted for any new cases).

## 5. Example simplification and integration verification

- [x] 5.1 Remove the now-unnecessary root-level `DetailRoute` declaration from `example/lib/router/router.dart` and verify the example still builds and all example tests pass with a single declaration (design D2).
- [x] 5.2 Run `flutter analyze` from both the repo root and `example/` and confirm "No issues found!" in both.
- [x] 5.3 Run the full suite from both the repo root and `example/` and record the final pass counts as evidence in the change notes.
- [x] 5.4 Manually verify the example end-to-end (single open/close, dual open/close, widen and narrow with a detail open, repeated rotation, pop chains) and record the observations; confirm no placeholder flash and no layout resize during single-mode entry/exit.
