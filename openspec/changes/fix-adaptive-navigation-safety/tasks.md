# Tasks: fix-adaptive-navigation-safety

Each fix is TDD: write the failing regression test first, confirm it fails against current
code, then implement until green.

## 1. Pop ownership and safety API (D1, D2)

- [x] 1.1 Write failing regression tests in `test/navigation_safety_test.dart`:
  - single-column `pop()` with no detail leaves `Wetland` mounted and content visible
  - dual-column `pop()` with only the shell page preserves the shell page, and a following
    push is still visible
  - `canPop` is `false` with no detail, `true` with a detail (both modes)
  - `maybePop()` with no detail returns `false` and pops nothing
  - `maybePop()` with a detail returns `true` and closes it
- [x] 1.2 Confirm each new test fails against current code (`flutter test`)
- [x] 1.3 Add `canPop` and `maybePop()`; make `pop()` ownership-aware (no fall-through)
- [x] 1.4 Verify green; verify the pre-existing detail push/pop tests still pass

## 2. Constructor validation and single destination (D3)

- [x] 2.1 Write failing tests: one destination renders in single- and dual-column mode without
      throwing; empty `destinations` fails its assertion
- [x] 2.2 Confirm the one-destination test fails with the `items.length >= 2` assert
- [x] 2.3 Assert non-empty `destinations` in the `Wetland` constructor
- [x] 2.4 Make `BottomNavigation` not build a `BottomNavigationBar` below two destinations
- [x] 2.5 Verify green

## 3. Push result consistency (D4)

- [x] 3.1 Write failing tests: `await push<String>()` delivers its pop result in dual-column
      replace, single-column, and dual-column drill-down
- [x] 3.2 Confirm the dual-column replace case fails (returns `null`)
- [x] 3.3 Replace the dual-column `replaceAll` path with remove-above-shell + result-carrying
      `push<T>`
- [x] 3.4 Verify green, including that the shell page is still preserved after the pop

## 4. Derive layout mode from the layout (D5)

- [x] 4.1 Write failing tests: system UI is applied on the first frame in both orientations,
      and a narrow→wide change still migrates the detail
- [x] 4.2 Confirm the startup-system-UI test fails (wide start made no system-UI call)
      - Note: the initial draft also asserted that `primaryBody` shows details. Measuring it
        showed `primaryBody` builds **no** secondary region and **no** nested navigator
        (`childControllers == 0`), so a detail has no host at all. That is an unimplemented
        capability, not a bug; those assertions were replaced and the limitation is documented
        instead (see design D5 "Scope correction" and the spec note).
- [x] 4.3 Derive the mode from the framework breakpoint predicate; stop writing it from slot
      builders; apply system UI on mode change including the first frame
- [x] 4.4 Verify green, and verify the full existing suite (rotation, migration, transitions)
      is unaffected

## 5. Shell-page convention: document and defend (D6)

- [x] 5.1 Write tests over the shell-page contract (correct config, reordered declaration,
      and no-empty-path config)
- [x] 5.2 Expose `hasRequiredShellPage` predicate; **no runtime warning** — measured that a
      missing empty-path route prevents the nested Navigator from mounting at all, so a
      warning would be unreachable dead code
- [x] 5.3 Document the convention in README quick-start with an example
- [x] 5.4 Verify green

## 6. Verification and release

- [x] 6.1 `flutter analyze --fatal-infos` clean (root + example)
- [x] 6.2 Full suites green: library and example
- [x] 6.3 Update CHANGELOG with the BREAKING notes (`pop` no-op, dual-column `push` timing)
- [x] 6.4 Bump version and update README (install / quick start / push-pop semantics /
      breakpoints / known limitations)
- [x] 6.5 Manual end-to-end check of the example in single- and dual-column mode
