
# Matrix Filter + Grouping Spec

## Purpose
Define how triads are grouped, filtered, and displayed.

## Primary Filters
- control
- balance
- dynamics
- integration
- phrasing
- flow
- combos

## Secondary Filters
- rightLead
- leftLead
- handsOnly
- all

## Behavior
- filters reduce visible triads
- selection persists across filters
- grouping is structural (rows/columns)

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
