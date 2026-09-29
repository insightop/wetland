# Spec Delta

## Purpose

Defines the safety and consistency contract for wetland's navigation entry points. A caller
must be able to wire a back button, run a single-destination app, and consume a `push` result
without risking a crash, a blank screen, or behavior that silently changes with screen
orientation. This spec exists because the audit found all three classes of defect reachable
from ordinary usage in 0.2.0.

## ADDED Requirements

### Requirement: `pop` only affects routes the library owns

`WetlandNavigator.pop()` SHALL only pop a detail page that the library owns (a single-column
root-hosted detail, or a detail above the destination's shell page in dual-column mode). It
SHALL NOT pop the destination itself, and it SHALL NOT pop a destination's shell page. When
there is no owned detail to pop, `pop()` SHALL be a no-op.

#### Scenario: Popping with no open detail in single-column mode leaves the app intact
- **WHEN** the user invokes `context.wetland.pop()` in single-column mode while no detail is open
- **THEN** the `Wetland` widget SHALL remain mounted
- **AND** the destination's content page SHALL remain visible
- **AND** no exception SHALL be thrown

#### Scenario: Popping with no open detail in dual-column mode preserves the shell page
- **WHEN** the user invokes `context.wetland.pop()` in dual-column mode while the destination's
  secondary stack holds only its shell page
- **THEN** the shell page SHALL remain in the secondary stack
- **AND** a subsequently pushed detail SHALL still become visible

#### Scenario: Popping an open detail still returns the caller to the content page
- **WHEN** a detail is open and the user invokes `context.wetland.pop()`
- **THEN** the detail SHALL close and the page underneath SHALL be revealed
- **AND** the popped route's result SHALL be delivered to the `push` future

### Requirement: Callers can query whether a pop is possible

`WetlandNavigator` SHALL expose `canPop` and `maybePop()` so a caller can guard a back button
without risking the app. `maybePop()` SHALL pop only when a pop is possible, and SHALL report
whether it popped.

#### Scenario: `canPop` reports false when no detail is open
- **WHEN** no detail is open in either layout mode
- **THEN** `context.wetland.canPop` SHALL be `false`

#### Scenario: `canPop` reports true when a detail is open
- **WHEN** a detail is open in either layout mode
- **THEN** `context.wetland.canPop` SHALL be `true`

#### Scenario: `maybePop` is safe to call unconditionally
- **WHEN** the user invokes `context.wetland.maybePop()` with no detail open
- **THEN** no route SHALL be popped
- **AND** `maybePop()` SHALL complete with `false`
- **AND** the `Wetland` widget SHALL remain mounted

#### Scenario: `maybePop` pops and reports success
- **WHEN** a detail is open and the user invokes `context.wetland.maybePop()`
- **THEN** the detail SHALL close
- **AND** `maybePop()` SHALL complete with `true`

### Requirement: Layout mode is derived from the layout, not from slot construction

The active layout mode SHALL be derived from the current viewport against the library's
breakpoints, and SHALL be correct on the very first frame and for every supported
configuration, including `primaryBody` mode. It SHALL NOT depend on which slot builder
happened to run.

#### Scenario: Mode is available on the first frame
- **WHEN** the app starts in a narrow viewport
- **THEN** the mode SHALL be single-column without requiring a resize or user interaction
- **AND** mode-dependent behavior (such as applying system UI) SHALL take effect at startup

#### Scenario: An app that starts wide applies dual-column behavior immediately
- **WHEN** the app starts in a wide viewport
- **THEN** dual-column behavior SHALL apply at startup
- **AND** the status and navigation bars SHALL be hidden as dual-column mode specifies

#### Scenario: `primaryBody` mode is documented as not hosting details
- **WHEN** a caller reads the documentation for `primaryBody`
- **THEN** it SHALL state that details are not supported in this mode
- **AND** it SHALL direct callers who need details to configure `destinations` instead

> Note: `primaryBody` provides no detail host at all — with `destinations == null` the
> secondary slot is not built, so there is no nested navigator to push a detail into
> (verified: `root.childControllers == 0`). Hosting details in this mode is a capability
> that was never implemented, so this change documents the limitation rather than
> building the feature. Implemented in a follow-up if needed.

### Requirement: `push` behaves the same in both layout modes

The future returned by `WetlandNavigator.push` SHALL complete with the pushed route's pop
result, and its behavior SHALL NOT depend on the current layout mode.

#### Scenario: A push result is delivered in dual-column mode
- **WHEN** a caller awaits `push<T>(route)` in dual-column mode and the detail is later popped
  with a result
- **THEN** the awaited value SHALL be that result

#### Scenario: A push result is delivered in single-column mode
- **WHEN** a caller awaits `push<T>(route)` in single-column mode and the detail is later popped
  with a result
- **THEN** the awaited value SHALL be that result

#### Scenario: Replacing a detail from the content page still reports its result
- **WHEN** the caller pushes from a destination's content page while a detail is already open,
  and the new detail is later popped with a result
- **THEN** the awaited value SHALL be that result

### Requirement: Constructor input is validated and small destination sets work

`Wetland` SHALL reject an empty `destinations` list with an assertion, because an empty list is
a caller error rather than a blank app. A single destination SHALL be a supported configuration
in both layout modes.

#### Scenario: An empty destinations list is rejected
- **WHEN** `Wetland` is constructed with `destinations: []`
- **THEN** an assertion SHALL fail describing the invalid argument

#### Scenario: A single destination works in single-column mode
- **WHEN** `Wetland` is configured with exactly one destination in a narrow viewport
- **THEN** the app SHALL render without throwing
- **AND** that destination's content SHALL be visible
- **AND** opening and closing a detail SHALL work

#### Scenario: A single destination works in dual-column mode
- **WHEN** `Wetland` is configured with exactly one destination in a wide viewport
- **THEN** the app SHALL render without throwing
- **AND** opening and closing a detail SHALL work

### Requirement: The shell-page convention is documented and defended

The library requires each destination's nested route collection to lead with an empty-path
shell page. This convention SHALL be documented where callers will find it, and a violated
configuration SHALL be reported rather than failing silently.

#### Scenario: The convention is documented for callers
- **WHEN** a caller reads the package documentation
- **THEN** the requirement that each destination's nested routes lead with a `path: ''` shell
  page SHALL be stated, with an example

#### Scenario: A missing shell page is detected as a configuration error
- **WHEN** a destination's nested route collection has no empty-path shell page
- **THEN** the nested navigator SHALL NOT mount, so no detail can be pushed into it
- **AND** the library SHALL expose a predicate (`hasRequiredShellPage`) by which callers can
  validate their configuration

> Implementation note (measured): with no empty-path route, the nested `Navigator` never mounts
> (`navigatorKey.currentState == null`), so this is not a state the library can silently
> mis-handle at runtime; it fails by having nowhere to push rather than by pushing invisibly.
> An earlier draft of this change added a runtime warning, which was removed as unreachable
> dead code once the behaviour was measured. The predicate plus documentation is the contract.
