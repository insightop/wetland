# Proposal: fix-adaptive-navigation-safety

## Why

The audit of `wetland` 0.2.0 found navigation-safety defects that crash or silently break a
caller's app, with no exception to signal the misconfiguration. They are the highest-priority
issues because they affect already-published code and are reachable from ordinary usage:
a back button on a destination's root page, a single-tab app, or an `await push<T>()` whose
result is consumed.

Verified by probe (all reproduced against HEAD `7d3fea2`; the repo was left untouched):

- `WetlandNavigator.pop()` with no open detail popped the **entire Wetland subtree** off the
  root navigator (`Wetland` alive `1 → 0`, blank screen, `takeException() == null`).
- Two destinations is a hard requirement: with one destination the app throws
  `'items.length >= 2': is not true` from `BottomNavigationBar` in single-column mode, and
  `destinations: []` throws `RangeError (length): Invalid value: Valid value range is empty: 0`.
- `await context.wetland.push<String>(route)` returned the pop result in single-column mode
  (`'RET'`) but `null` in dual-column mode even though the detail was on screen — behavior that
  changes with screen orientation.
- `Wetland(primaryBody: ...)` never updates the layout mode, so details were invisible in both
  orientations (present in the tree: false).
- When the app starts already in dual-column mode, `_applySystemUi` was never called, so the
  status and navigation bars were not hidden as intended.

## What Changes

- **`WetlandNavigator.pop()` becomes ownership-aware (BREAKING for the buggy path).** It SHALL
  only pop a detail the library actually owns, and SHALL never pop the destination itself or a
  destination's shell page. When there is nothing owned to pop it becomes a no-op instead of
  falling through to `context.router.pop()`.
- **New `WetlandNavigator.canPop` and `WetlandNavigator.maybePop()`.** Callers can distinguish
  "nothing to pop" from "popped" without risking their app, and can wire back buttons safely.
- **`Wetland` gains explicit constructor assertions.** `destinations`, when provided, SHALL be
  non-empty (an empty list is a caller error, not a blank app). A single destination SHALL be
  accepted and work.
- **Bottom navigation degrades gracefully below two destinations.** `BottomNavigationBar`
  asserts `items.length >= 2`; the library SHALL not construct one when there are fewer than two
  destinations.
- **`push` result propagation is made consistent (BREAKING).** The dual-column "replace" path
  SHALL return a future that completes with the detail's pop result, matching single-column and
  dual-column drill-down, instead of completing immediately with `null`. The behavior of
  `push` SHALL NOT depend on the layout mode.
- **Layout mode SHALL be derived from the actual breakpoint, not from which slot builder
  happened to run.** This fixes `primaryBody` mode (details currently invisible) and the
  "start in dual mode ⇒ system UI never applied" defect in one change.
- **`primaryBody` remains supported** and SHALL show details correctly in both orientations.

## Capabilities

**New Capabilities**

- `adaptive-navigation-safety` — the safety and consistency contract for navigation entry
  points: which route a `push`/`pop` may affect, what `canPop`/`maybePop` mean, what the
  constructor accepts, and the guarantee that none of this varies with layout mode.

**Modified Capabilities**

- None. `openspec/specs/` is empty, so there is no established capability to amend; the
  preceding change (`single-column-detail-fullscreen-route`) is still in-flight and owns the
  layout/transition contract, which this change does not alter.

## Impact

- **Affected code**: `lib/src/utils/navigator.dart` (pop ownership, `canPop`, `maybePop`, push
  result), `lib/src/wetland.dart` (constructor asserts, mode derivation, system UI, `primaryBody`),
  `lib/src/widgets/bottom_navigation.dart` (fewer than two destinations),
  `lib/src/blocs/wetland_bloc.dart` (mode becomes a derived input).
- **Affected APIs**: `WetlandNavigator.pop` semantics, `WetlandNavigator.push` return value in
  dual-column mode, new `WetlandNavigator.canPop`/`maybePop`, new `Wetland` assertions. All are
  additive except the two documented behavior corrections.
- **Dependencies**: none added. Uses auto_route's existing `canPop`/`removeRoute` and Flutter's
  `MediaQuery`/breakpoints.
- **Tests**: new regression tests for each defect, written to fail against the current code.
