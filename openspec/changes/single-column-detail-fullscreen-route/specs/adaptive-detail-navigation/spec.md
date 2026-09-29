# Spec Delta

## Purpose

Defines how Wetland hosts and transitions "detail" pages across single-column (narrow/portrait) and dual-column (wide/landscape) layouts: which navigator owns a detail, how entering and leaving it animates, and how it survives mode changes, so that callers get native push/pop semantics in both layouts without managing two copies of a route.

## ADDED Requirements

### Requirement: Single-column detail is full-screen and covers the bottom navigation

In single-column mode, when a detail page is open, it SHALL occupy the entire screen area, and the bottom navigation SHALL NOT be visible or interactive beneath or beside it.

#### Scenario: Detail covers the bottom navigation in single-column mode
- **WHEN** the user opens a detail page in single-column mode
- **THEN** the detail page's content area SHALL span the full screen height and width
- **AND** the bottom navigation SHALL NOT be hit-testable while the detail page is open

#### Scenario: Bottom navigation is restored after leaving a detail
- **WHEN** the user leaves the detail page and returns to the destination's content
- **THEN** the bottom navigation SHALL be visible and hit-testable again

### Requirement: Entering and leaving a single-column detail uses route transition semantics

In single-column mode, opening a detail SHALL be presented as a route push and closing it SHALL be presented as a route pop, using the same transition behavior a platform route would use, rather than an in-place size interpolation of the surrounding layout.

#### Scenario: Opening a detail animates as a push
- **WHEN** the user taps an item that opens a detail in single-column mode
- **THEN** the detail SHALL enter through a route transition
- **AND** the surrounding layout SHALL NOT resize or interpolate its region widths during the transition

#### Scenario: Leaving a detail animates as a pop and reveals the content page
- **WHEN** the user pops a detail in single-column mode
- **THEN** the detail SHALL exit through the reverse route transition
- **AND** the page revealed underneath SHALL be the destination's content page that opened the detail
- **AND** no empty placeholder page SHALL be shown at any point during or after the transition

### Requirement: Dual-column detail occupies the secondary region and keeps per-destination stacks

In dual-column mode, a detail SHALL be shown in the secondary region alongside the primary content, and each destination SHALL retain its own detail history such that switching destinations and returning restores the previously open detail.

#### Scenario: Detail is shown beside the primary content
- **WHEN** a detail is open in dual-column mode
- **THEN** the detail SHALL be rendered in the secondary region while the primary content remains rendered
- **AND** the primary navigation SHALL remain hit-testable

#### Scenario: Per-destination detail history is preserved across destination switches
- **WHEN** the user opens a detail for a destination, switches to another destination, and switches back
- **THEN** the first destination's detail SHALL still be open

### Requirement: Mode changes migrate an open detail without an empty intermediate state

When the layout changes between single-column and dual-column while a detail is open, the detail SHALL be preserved and re-hosted in the region appropriate to the new mode, and at no point during the change SHALL an empty placeholder page be visible.

#### Scenario: Widening moves an open detail into the secondary region
- **WHEN** a detail is open in single-column mode and the layout becomes dual-column
- **THEN** the same detail SHALL become visible in the secondary region
- **AND** the detail's content SHALL be the same page instance state as before the change

#### Scenario: Narrowing moves an open detail to full screen
- **WHEN** a detail is open in dual-column mode and the layout becomes single-column
- **THEN** the same detail SHALL become visible full-screen
- **AND** no empty placeholder page SHALL be visible at any point during the change

#### Scenario: Repeated mode changes do not lose the detail
- **WHEN** the layout switches between single-column and dual-column multiple times while a detail is open
- **THEN** the detail SHALL remain open at the end of every switch

### Requirement: Popping a detail never dismisses the destination itself

Popping a detail SHALL remove only the detail and SHALL NOT pop the destination's root content or leave Wetland without a destination.

#### Scenario: Popping the last detail returns to the destination root
- **WHEN** the user pops the only open detail
- **THEN** the destination's root content SHALL be shown
- **AND** the destination selection SHALL be unchanged

#### Scenario: Pushing a detail from within a detail stacks correctly
- **WHEN** the user opens a further detail from within an already open detail and then pops once
- **THEN** the previously open detail SHALL be shown
- **AND** popping again SHALL return to the destination root

### Requirement: A detail route is declared once by the caller

The caller SHALL declare a detail route a single time, and Wetland SHALL present that same route in whichever region the current mode requires, without the caller declaring a duplicate route for full-screen presentation.

#### Scenario: One declaration serves both modes
- **WHEN** the caller declares a detail route once and opens it in single-column mode and again in dual-column mode
- **THEN** both openings SHALL succeed without requiring an additional route declaration

### Requirement: State preservation across layout changes

Layout changes SHALL NOT discard the state of the destination content, the bottom or primary navigation, or an open detail.

#### Scenario: Rotating preserves the destination content state
- **WHEN** the layout changes while the user is on a destination's content
- **THEN** the content SHALL retain its scroll position and widget state
- **AND** the currently selected destination SHALL be unchanged
