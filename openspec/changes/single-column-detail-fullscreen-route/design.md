# Design

## Context

Motivation is in `proposal.md` — Why; requirements are in `specs/adaptive-detail-navigation/spec.md`. This section records only the current state and constraints that shape the approach.

**Current wiring (verified against the code at HEAD `47875d4`).**

- `lib/src/wetland.dart` builds `AdaptiveLayout` with `bodyRatio: ratio` driven by `TweenAnimationBuilder<double>`. `_targetBodyRatio(mode, hasDetail)` returns `0.35` (dual) / `0.0` (single + detail) / `1.0` (single, no detail).
- `secondaryBody` is mounted at `Breakpoints.standard` for **both** modes, wrapped by `_mountedSlot`. Its content is an `IndexedStack` over one `SecondaryBody` per destination; each `SecondaryBody` is a bare `AutoRouter` with its own `navigatorKey`.
- Single vs dual is therefore expressed **only** as a width ratio. Entering a detail in single mode narrows the primary region to 0 and widens the secondary region — an interpolation, not a push.
- `lib/src/utils/navigator.dart` resolves a target navigator from the bloc's current index and calls `AutoRouter.of(context).push`, or `AutoRouter.of(secondaryKey.currentState!.context)` when the secondary navigator exists. `pop` targets the secondary key when available.

**Constraints discovered by measurement (each independently reproduced with widget tests).**

1. **`root.push(DetailRoute)` does not reach the root.** auto_route's `StackRouter.push` resolves the target via `_findStackScope` → the topmost inner `StackRouter` whose route collection `_canHandleNavigation(route)` (i.e. `routeCollection.containsKey(route.routeName)`). With four per-destination `NestedStackRouter`s present — which share identical `key`/`matchId`, so resolution always selects the **last** one — a `DetailRoute` that is also registered under the destination subtree is captured by that nested router. Measured: the root stack stayed `[HomeRoute]` while `nested[3]` became `[PlaceholderRoute, DetailRoute]`, and the detail's title landed at `(462, 180)` on a 390-wide screen (off-screen).
2. **Explicit root resolution works and is fully test-verified.** `root.matcher.matchByRoute(route)` (using the collection that contains the route) → `RouteData(route: match, router: root, stackKey: root.key, pendingChildren: const [], type: match.type ?? root.defaultRouteType)` → `root.navigatorKey.currentState!.push(data.buildPage<Object?>().createRoute(context))`. Measured: detail `Scaffold` at `Rect.fromLTRB(0.0, 0.0, 390.0, 844.0)`, bottom navigation hit-testable count `0`, pop returns to the list, layout round-trip (portrait→landscape→portrait) keeps the route alive, `takeException() == null`.
3. **The matching collection does not need to be the root's.** Matching via the destination's nested collection and pushing onto the root navigator works identically to (2). This is what lets the caller keep **one** route declaration. `RouteData`, `AutoRoutePage`, and `RouteMatcher.matchByRoute` are all public exports of auto_route 11.1.0.
4. **The nested stack's bottom entry is the empty shell page** (`PlaceholderRoute`, `hasEmptyPath`). In single mode that shell is the second entry from the top while a detail is open. This is why a true pop driven by the nested navigator would reveal the logo — the decisive reason the single-mode host must **not** be the nested navigator.
5. **A route cannot be confined to a layout slot.** A `ModalRoute` always occupies the whole navigator and installs a `ModalBarrier` that absorbs full-screen pointer events even when `opaque: false` and `barrierColor: null` (verified: overriding `buildModalBarrier()` to shrink restores hit-testability, while leaving it absorbs it). Emulating "a route that only paints the right third" is therefore possible but structurally wrong; dual mode keeps using the slot-mounted navigator instead.
6. **Widget-tree shape must stay constant for the mounted slot.** `_mountedSlot` always returns `LayoutBuilder → ClipRect → Offstage → OverflowBox → child` and changes parameters only. Switching shape by width re-runs `AutoRouter.didChangeDependencies` → `setupInitialRoutes()`, which wipes pushed details (measured `stack = [/, detail]` → `[/]`).
7. **An *opaque* root route disables the tickers of everything beneath it.** Flutter's `Overlay` marks every entry below the top-most opaque entry offstage, and offstage entries get `TickerMode(enabled: false)`. Measured: after pushing an opaque detail onto the root navigator, `TickerMode.of` for a context inside Wetland flips from `true` to `false`, and `AdaptiveLayout`'s transition **freezes permanently at the mid-animation geometry** (`body` stuck at `110.6` instead of `390`), jumping to the final value only when the detail is popped, a user-visible glitch. The root-hosted detail therefore uses a **non-opaque** `RouteType` (`_nonOpaque` in `root_detail_stack.dart`), which keeps the subtree onstage: measured `111 → 390` smooth. The detail's own full-screen `Scaffold` still covers the screen visually.
   - Consequence for tests: a non-opaque detail does not remove the layer beneath from the tree, so "the list is hidden" must be asserted by **geometric coverage**, not by width being 0.
   - Consequence for waiting on the route: `Route.completed` completes only on `dispose` (`routes.dart:637`), so migration waits on the entrance **animation status** instead (`RootDetailStack.topRouteEntered`); awaiting `completed` deadlocks migration.

## Goals / Non-Goals

**Goals:**

- Single-column detail becomes a genuine full-screen route: full-screen coverage (satisfying the bottom-navigation requirement) and native push/pop transitions (satisfying the transition requirement) with no empty placeholder ever revealed.
- Dual-column behavior — secondary-region detail, per-destination detail history, primary navigation interactivity — is preserved unchanged.
- An open detail survives single⇄dual mode changes with no empty intermediate state, and repeated switches do not lose it.
- The caller declares a detail route once; no duplicate full-screen route is required.
- The library's public API (`Wetland`, `WetlandNavigator` signatures) does not change.

**Non-Goals:**

- Preserving Web URL / deep-link synchronization for single-column details. Explicit root-navigator pushes bypass auto_route's `NavigationHistory`; URL-synced single-column details would require a separate change with its own spec. Mobile and desktop are unaffected.
- Removing the `secondaryBody` slot or the per-destination nested navigators. They remain the dual-column host and the storage of per-destination detail history.
- Eliminating the `bodyRatio` interpolation used for dual-column layout margins. It stays as the dual-column layout mechanism.
- Reworking the unrelated dead code identified earlier (`primaryNavigatorKey`, `PrimaryBody`, `IWetlandTabPage`, `useDrawer`, `default_placeholder_page.dart`, `theme.dart`).

## Decisions

### D1: Single-column detail is hosted by the root navigator; dual-column keeps the per-destination nested navigator

Single mode pushes the detail onto the **root** navigator, so the route covers the entire Wetland subtree (content + bottom navigation) and animates as a push/pop. Dual mode leaves the detail in the `secondaryBody` navigator, where side-by-side rendering and per-destination history already work.

*Alternatives considered:*

- **A single always-root route rendered into the secondary region in dual mode** — rejected: constraint 5; the route occupies the whole navigator and its `ModalBarrier` blocks the primary region, so "only the right third" is emulation, and the primary content would lay out at full width underneath.
- **Move the always-mounted nested navigator into a `Stack` above the layout, sized per mode** (so single mode is genuinely full-screen and the nested navigator itself animates push/pop) — rejected: constraint 4. The nested stack's bottom entry is the empty shell, so a true pop reveals the logo; and the shell must be hidden exactly when no detail is open, which cannot be reconciled with the pop animation's frames. This was the "乙'" candidate and it fails the spec's "no empty placeholder during pop" requirement.
- **A library-owned overlay `Navigator`** — rejected for this change: it would take over page construction from auto_route's route system (the caller's `PageRouteInfo` would have to be turned into widgets by the library), enlarging the internal surface and concentrating exactly the patchwork this change is meant to avoid.

### D2: Resolve the root explicitly instead of by route name

`WetlandNavigator` resolves its target by matching the route against the current destination's collection and constructing `RouteData` bound to the root router, then pushing on `root.navigatorKey.currentState`. It must not call `root.push(route)` (constraint 1) and must not fall back to `AutoRouter.of(context).push` in single mode.

*Rationale:* name-based resolution is ambiguous the moment the same route name is reachable from more than one collection — which is exactly the normal case here. Explicit construction removes the ambiguity without requiring the caller to add a second, differently named route.

*Alternatives considered:* requiring the caller to declare a root-unique route name and using `root.push` (works, verified, but pushes declaration burden and a naming convention onto callers — rejecting on the "declare once" requirement); `pushWidget` (bypasses the caller's route type/transitions and their `PageRouteInfo` arguments).

### D3: The `scope == null` branch resolves to the root, not to `AutoRouter.of(context)`

When a detail is hosted by the root navigator and the caller drills down from inside it, no destination scope is in the ancestor chain (`scope == null` is the observed state). That branch must target the root navigator; the old `AutoRouter.of(context).push` fallback would resolve by name and re-enter the nested-router capture trap (constraint 1).

### D4: Mode changes migrate the open detail with push-then-remove, and without top-most polling

Entering dual mode: push the detail into the destination's nested navigator first, then remove the corresponding root route. Entering single mode: push onto the root first, then pop/remove from the nested navigator. Removal only after the target host has the route avoids an empty intermediate frame.

The historical implementation polled `rootRouter.isTopMost` for up to 300 frames before pushing (`_pushToRootWhenTopMost`, see `docs/research/2026-09-27-legacy-stack-migration-archaeology.md` §7.2). **This design drops that polling**: the root push in D2 goes to the root navigator directly and does not need the router to be top-most first. Dropping it removes the measured "primary fills the screen, detail appears ~1s later" symptom.

*Alternatives considered:* keeping the polling loop (retains a known-latency patch); no migration at all (violates the widening scenarios in the spec — the user explicitly chose to keep widening-to-dual behavior).

### D5: Migration targets are selected by the destination's detail depth, not by a shell-page predicate

The migration must skip the nested navigator's bottom shell entry (constraint 4) so that an empty state never migrates. The historical rule ("skip index 0, skip auto-filled entries") is the correct semantics; the current helper `secondaryIsShellOnly` (stack length 1 + empty path) is not a sufficient selection input for migration because a stack can be `[shell]` or `[shell, detail...]` and the migration must move only the detail entries. The existing helpers may be re-expressed on top of the same predicate rather than replaced wholesale.

### D6: Single mode does not drive `bodyRatio` to 0

With the detail gone from the secondary slot in single mode, `_targetBodyRatio` must not be pulled to `0.0` by "has detail". The ratio in single mode reflects the layout, not the detail's presence; the secondary slot is hidden because no route lives there, not because its width was animated to zero.

*Rationale:* leaving the ratio coupled to detail presence would re-introduce an invisible-but-animating region and would keep the old "layout interpolates while detail opens" behavior alive in the transition frames, contradicting the spec's "surrounding layout SHALL NOT resize during the transition".

### D7: Keep the mounted-slot shape constant

Any change to how the secondary slot is hidden must preserve the fixed `LayoutBuilder → ClipRect → Offstage → OverflowBox → child` shape and keep the nested navigator in the tree (constraint 6), because `WetlandNavigator` relies on `navigatorKey.currentState != null` to decide the detail's dual-mode host, and shape changes wipe pushed details.

## Risks / Trade-offs

- **[Pop ownership]** A detail can exist in the root stack and, after a migration, in the nested stack; a naive `pop` could pop the destination itself → Mitigation: pop resolves the owner explicitly (root route present and top-most → root pop; otherwise nested pop), and the spec asserts that popping a detail never dismisses the destination. Covered by dedicated scenarios ("Popping the last detail returns to the destination root").
- **[Empty frame during migration]** Removing from the source before the target has the route shows a blank or shell frame → Mitigation: strict push-then-remove ordering (D4), plus regression tests that assert no placeholder is visible across the transition timeline.
- **[Duplicate route declaration confusion]** The example currently declares a root-level `DetailRoute` for full-screen presentation; leaving it in place while the library changes resolution would suggest it is required → Mitigation: remove it from `example/lib/router/router.dart` as part of this change (D2 makes it unnecessary) and assert single-declaration behavior in the example tests.
- **[Web URL regression]** Explicit root pushes bypass `NavigationHistory`, so single-column details are not reflected in the URL → Mitigation: recorded as an explicit non-goal and as an impact in the proposal; no behavior change for mobile/desktop. A future change can add URL-synced single-column details behind the same spec if required.
- **[Legacy tests encode the old architecture]** A large group of existing tests assert "detail lives in the secondary slot" and "`bodyRatio == 0.0` in single mode", including `panel_transition_timeline_test.dart`, which is an explicit old-architecture discriminator → Mitigation: the tasks phase enumerates each affected test and redefines its assertion target against the new spec scenarios (rather than deleting coverage).
- **[Hidden coupling to `navigatorKey.currentState`]** If the nested navigator is ever taken out of the tree in single mode, the dual-mode host decision breaks and details get misrouted → Mitigation: D7 plus a test asserting the nested navigator remains mounted (key resolvable) in single mode while no detail is routed there.
- **[Animation timing between outer push and layout change]** If the outer push and the layout ratio change are not sequenced, the old symptom (layout finishes, detail appears later) can return → Mitigation: D6 keeps the ratio independent of detail presence, so the two no longer race; the transition tests assert layout geometry is stable during the push.
- **[Stale migration code reuse]** Reusing the deleted migration wholesale would re-import the polling patch and its assumptions → Mitigation: reuse is limited to the entry-selection predicate (D5); the orchestration is rewritten around push-then-remove without polling.

## Migration Plan

Delivered as library-internal behavior change; no data or configuration migration.

1. Land the resolution change (D2/D3) with tests, keeping dual-mode routing intact — single mode still renders through the old path until the host switch lands, so the two concerns can be verified independently.
2. Switch the single-mode host to the root navigator (D1) and decouple `bodyRatio` (D6); update the affected tests to the new spec scenarios.
3. Add mode-change migration (D4/D5) with push-then-remove ordering, and the no-empty-frame regression tests.
4. Remove the now-unnecessary duplicate root-level detail route from the example, and verify the example end-to-end (single, dual, rotate, repeated switches, pop chains).

**Rollback:** each step is a self-contained commit; reverting step 4, then 3, then 2, then 1 restores the previous behavior. No persisted state is introduced, so rollback needs no cleanup.

## Open Questions

- Whether the `Wetland` public API should later expose a hook to opt into URL-synced single-column details. Deferrable: it cannot affect the current specs, approach, or task breakdown, since this change explicitly does not sync the URL.
