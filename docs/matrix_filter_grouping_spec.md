
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
- `Phrases`

If no explicit view is selected, Matrix defaults to `Traits`.

## Traits View

Purpose:

- help the user isolate the kind of triad they want to work on

Filter families:

### Lead

- `Right`
- `Left`
- `Kick`

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
- `Recent`

but those are not required in the base contract.

## Phrases View

Purpose:

- help the user inspect saved phrases and build new ones

Controls:

- phrase selector / saved phrase selector
- current phrase builder

Rules:

- trait filters are hidden
- progress filters are hidden
- the grid still reflects phrase membership

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

## Invalid Combination Rules

- `Hands Only` disables `Has Kick`
- `Hands Only` disables `Starts w/ Kick`
- `Hands Only` disables `Ends w/ Kick`
- selecting `Has Kick` clears `Hands Only`
- selecting `Starts w/ Kick` clears `Hands Only`
- selecting `Ends w/ Kick` clears `Hands Only`
- `Progress` view hides `Traits` filters
- `Phrases` view hides `Traits` and `Progress` filters

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

## Selection
- multi-select allowed
- ordered sequence stored
- grid cells show membership only
- exact occurrence removal happens in the ordered phrase header, not inside cells
- matrix cells must not show per-cell remove buttons or `x` badges

## Rules
- do not collapse grid into simple heatmap
- preserve structural layout always
- grid is the primary surface; filters support it, not the other way around
