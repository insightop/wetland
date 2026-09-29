# Design: fix-adaptive-navigation-safety

## Context

The audit found four navigation-safety defects in 0.2.0, all reproduced by probe against
`7d3fea2`. Each is a distinct root cause, so each gets its own decision below. The guiding
constraint is that `wetland`'s public API must be safe to use without the caller knowing
internal layout details.

## D1 — `pop` must be ownership-aware

**Problem.** `WetlandNavigator.pop` fell through to `context.router.pop()` when it owned no
detail — popping the destination itself (blank app, verified `Wetland` alive `1 → 0`) or the
destination's shell page (making later details permanently invisible).

**Decision.** `pop` resolves an *owner first* and acts only on that owner:

- Single-column: if `rootDetails.hasDetail`, pop the root-hosted detail. Otherwise **no-op**.
- Dual-column: if the current destination's secondary stack has entries above its shell page,
  pop the top one. Otherwise **no-op**.

**Rejected alternative: delegate to auto_route's `maybePop`.** `RoutingController.maybePop`
recurses into `_parent` when its own navigator declines
(`routing_controller.dart:1215-1225`), so it would still climb out of Wetland and pop the
destination. It answers "can anything pop?", not "does Wetland own something to pop?" — the
wrong question.

**Rejected alternative: throw when nothing is owned.** A back button wired to `pop()` on a
destination root is legitimate; a no-op plus an explicit `canPop` is friendlier and matches how
route-based APIs behave.

**Consequence.** `pop` on a destination root changes from "destroys the app" to "does nothing".
This is the **BREAKING** part of this change and is recorded in the CHANGELOG.

## D2 — Add `canPop` / `maybePop` so callers can guard

`canPop` (bool) and `maybePop()` (Future<bool>) share D1's ownership resolution: `canPop` is
"does an owned detail exist?", `maybePop` pops only when true and reports whether it popped.
This gives callers the safety net they currently lack, without exposing which mode is active.

## D3 — Validate `destinations`, and support one destination

**Problem.** `destinations: []` reached `widget.destinations![0]` →
`RangeError (length): Invalid value: Valid value range is empty: 0`. One destination reached
Flutter's `BottomNavigationBar` assert `items.length >= 2`.

**Decision.** Two separate fixes, because they are different errors:

- **Empty list: assert in the constructor.** An empty destination list is a caller mistake, not
  a runtime condition to degrade around. `assert(destinations == null || destinations.isNotEmpty)`
  fails loudly at the construction site, which is where the fix belongs.
- **One destination: degrade the widget, not the API.** A single-tab app is legitimate. The
  `BottomNavigationBar` constraint is Flutter's, not a library requirement, so
  `BottomNavigation` SHALL not build a `BottomNavigationBar` when there are fewer than two
  destinations. The destination content still renders; there is simply nothing to switch between.

**Rejected alternative: reject `destinations.length == 1` in the constructor.** That would trade
a crash for a ban on a valid app shape.

## D4 — Make `push`'s future consistent across modes

**Problem.** The dual-column "replace" path used `replaceAll([shell, route])` and `return null`.
`replaceAll` → `_pushAll` creates pages **without** a `popCompleter`
(`routing_controller.dart:787-805`), so `RouteData.popped` resolves immediately to `null` — the
detail's result can never be delivered. Single-column and dual-column drill-down go through
`_addNewPage`, which *does* create a completer (`:1688`) and returns `data.popped`.

**Decision.** Replace the `replaceAll` call with an explicit two-step that uses the
result-carrying path:

1. remove the current destination's detail entries above the shell page
   (`router.removeRoute(entry)`), then
2. `router.push<T>(route)` and **return that future**.

This makes the replace case behave exactly like drill-down and like single-column mode: the
future completes when the detail is popped, with its result. Semantics no longer vary by
orientation. The shell page is preserved because step 1 only removes entries above index 0.

**Consequence.** Callers who relied on dual-column `push` completing immediately with `null` see
a different timing. **BREAKING**, recorded in the CHANGELOG with a migration note.

## D5 — Derive layout mode from the layout

**Problem.** `mode` was written by whichever slot builder happened to run
(`wetland.dart:317/359/376` → `_setMode`). Two consequences:

- `primaryBody` mode builds neither the rail nor the bottom navigation, so `_setMode` never ran
  and `mode` stayed at its `dual` default → details were invisible in **both** orientations
  (verified: detail present in tree = false).
- `_applySystemUi` is called only from `BlocListener`, which fires only on state *change*. An app
  that starts wide never changed mode, so the status/navigation bars were never hidden
  (verified with a mocked `SystemChrome`).

**Decision.** Compute the mode from the viewport and own it as an explicit input:

- Derive it with the framework's own breakpoint activation
  (`Breakpoint.activeBreakpointIn(context, [Breakpoints.mediumLargeAndUp])` or equivalent), so
  the result matches what `AdaptiveLayout` actually does.
- **Important detail:** `Breakpoint.isActive` (`breakpoints.dart`) evaluates width **and**
  height, and is not a plain `width >= 840` test. Deriving from raw `MediaQuery.sizeOf().width`
  would disagree with the layout in some viewports. Use the framework's predicate.

**Rejected alternative: keep the slot-builder write-back and patch `primaryBody`.** That leaves
the mode as a side effect of widget construction and would need a second fix for the startup
system-UI case; deriving it removes both at the source.

**Scope correction (found while implementing).** Deriving the mode fixes the *mode* being wrong
for `primaryBody`, but it does **not** make details work in that mode, because `primaryBody`
builds no secondary slot and therefore no nested navigator at all
(`secondaryBody: widget.destinations != null`; measured `root.childControllers == 0`). A detail
has nowhere to render. Hosting details in `primaryBody` mode is a capability that was **never
implemented**, not a regression — so this change documents it as unsupported (dartdoc + README)
and defers the feature rather than growing this bug-fix change into a layout feature.

**Rejected alternative: `MediaQuery` width compared to a hardcoded 840.** Rejected because
`AdaptiveLayout` selects slots using the full breakpoint predicate including height, so a
hardcoded width test can diverge from the rendered layout. Reusing the predicate keeps the mode
and the layout consistent by construction.

**Follow-on:** `_applySystemUi` is invoked when the derived mode differs from the last applied
one, which now also covers the first frame.

## D6 — Document and defend the shell-page convention

**Problem.** Each destination's nested routes must lead with a `path: ''` shell page. Violating
it makes details permanently invisible **with no error** (verified: detail in tree = 1,
visible = 0). It was documented only in source comments; README and CHANGELOG never mentioned it.
Worse, `_detailEntriesOf` skips `stack[0]` unconditionally, so a destination whose first child is
a real page would silently lose that page during migration.

**Decision.**

- Document the convention in the README's quick-start, with the `AutoRoute(path: '', ...)` line.
- Emit a diagnostic (`Log.w`) when a destination's nested stack has no empty-path shell page, so
  the misconfiguration is visible instead of silent. A warning rather than an assert, because the
  check runs during layout where throwing would be hostile and the fallback path still renders.

## Risks

| Risk | Mitigation |
|---|---|
| D1 changes `pop` on a destination root from "destroys app" to "no-op"; a caller may have relied on it to exit | It was never a supported way to exit; exiting is the host app's concern. Documented in CHANGELOG. |
| D4 changes dual-column `push` timing | Documented as BREAKING with a migration note. New tests pin the new semantics. |
| D5 changes the source of `mode`; a regression here breaks every mode-dependent behavior | Comprehensive tests already exist (rotation, migration, transitions). Derivation must keep them green — that is the acceptance gate. |
| D5's breakpoint predicate may disagree with `AdaptiveLayout` in exotic viewports | Reuse the framework predicate rather than reimplementing it. |

## Migration / rollback

Rollback is a revert of this change; no data or persisted state is involved. Existing tests that
encode the old `pop` and `push` behavior must be updated as part of the change, and the diff will
show exactly which expectations moved.

## Open question

Whether `pop` should fall back to popping the destination when the host app has no other way to
exit (e.g. desktop without a system back gesture). Left out of scope: the library should not
decide how an app exits. Recorded for a future change if a real need appears.
