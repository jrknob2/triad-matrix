
# Matrix Filter + Grouping Spec

## Purpose
Define how triads are grouped, filtered, and displayed.

## Matrix Control Model

Matrix should not expose three competing control layers.

Matrix has:

1. one exclusive `View`
2. one contextual filter row for that view
3. structural row/column slicers built into the grid

`Lane` is not a first-class Matrix control.
It exists as a Coach-to-Matrix preset only.

## View

Exactly one view can be active at a time:

- `Traits`
- `Progress`

If no explicit view is selected, Matrix defaults to `Traits`.

## Traits View

Purpose:

- help the user isolate the kind of triad they want to work on

Filter families:

### Lead

- `Right`
- `Left`

Rules:

- multi-select allowed
- same-family selections broaden with `OR`
- example: `Right + Left` means show either hand-led slice

### Content

- `Hands Only`
- `Has Kick`

Rules:

- mutually exclusive
- selecting one turns the other off

### Kick Placement

- `Starts w/ Kick`
- `Ends w/ Kick`

Rules:

- can be combined
- same-family selections narrow with `AND`
- selecting either one clears `Hands Only`
- selecting either one implies kick material

### Shape

- `Doubles`

Rules:

- independent narrowing filter
- combines with other families using `AND`

## Progress View

Purpose:

- help the user inspect how a slice of the matrix is going

Filter family:

### Status

- `Not Trained`
- `Active`
- `Needs Work`
- `Strong`

Rules:

- exclusive
- only one status can be active at a time

Progress view may later add optional secondary scope filters like:

- `In Working On`
- `In Phrases`
- `Recent`

but those are not required in the base contract.

## Structural Slicers

Row and column selectors belong to the grid structure, not to the view filter bar.

### Rows

Rules:

- multi-select allowed
- row selections broaden with `OR`

### Columns

Rules:

- multi-select allowed
- column selections broaden with `OR`

### Combination Rule

Row slicers and column slicers always narrow the current view/filter result with `AND`.

Final in-scope set:

- current view filters
- and selected rows
- and selected columns

Touch rule:

- row and column slicers must look interactive on touch screens
- they may use pill, button, segmented, or chip styling, but they must not read as plain static labels

## Invalid Combination Rules

- `Hands Only` conflicts with `Has Kick`
- `Hands Only` conflicts with `Starts w/ Kick`
- `Hands Only` conflicts with `Ends w/ Kick`
- selecting `Has Kick` clears `Hands Only`
- selecting `Starts w/ Kick` clears `Hands Only`
- selecting `Ends w/ Kick` clears `Hands Only`
- `Progress` view hides `Traits` filters

Interaction rule:

- conflicting filters should resolve by replacement, not disablement
- if the user selects a conflicting filter, the previous incompatible filter is turned off automatically
- disabled controls should be avoided inside the active view unless a state is truly impossible

## Phrase Eligibility Rule

Matrix may be used to start phrase building, but phrase growth is gated.

Rules:

- a single triad may always be selected for direct practice
- adding a second or later triad to a phrase requires phrase-ready material
- a triad is phrase-ready when it has reached at least `Comfortable`
- only phrase-ready triads may be appended to a phrase sequence
- this same rule applies anywhere else the app builds phrases from triads
- one selected triad behaves like direct item selection
- once more than one triad is selected, the Matrix is in phrase-building mode
- phrase-building mode defaults the `Practice` action to Flow

## Deep-Link Rules

Coach may open Matrix with a preset state.

Examples:

- `Balance` deep-link -> `Traits` view with `Right + Left`
- `Integration` deep-link -> `Traits` view with `Has Kick`
- `Needs Work` deep-link -> `Progress` view with `Needs Work`

Once the user changes Matrix controls manually, the Coach lane/preset is no longer shown as a persistent Matrix control.

## Visual Layers
1. filter scope (visible/muted)
2. progress state (color)
3. selection state (border/order)

Progress colors:

- `Not Practiced` = white
- `Active` = blue
- `Needs Work` = red
- `Strong` = green

Persistent decoration rule:

- progress-state background color remains visible in every Matrix view
- filters and scope controls may add borders, muting, or emphasis, but should not remove the base progress decoration
- muted out-of-scope cells should still retain a readable trace of their progress state

## Selection
- multi-select allowed
- ordered sequence stored
- grid cells show membership only
- exact occurrence removal happens in the ordered phrase header, not inside cells
- matrix cells must not show per-cell remove buttons or `x` badges
- out-of-scope cells remain visible but are not tappable
- the action row must not show `Remove from Working On`

## Rules
- do not collapse grid into simple heatmap
- preserve structural layout always
- grid is the primary surface; filters support it, not the other way around
- prefer compact horizontal control groups before adding more stacked vertical filter rows

## Progress View Interaction Rules

- status filters are exclusive
- secondary progress filters such as `Working On`, `In Phrases`, `Light Time`, and `Recent` are independent narrowing filters
- selecting a new status replaces the previous status
- secondary filters may be combined with status filters using `AND`
- progress filter behavior should feel as explicit and predictable as Traits filter behavior
