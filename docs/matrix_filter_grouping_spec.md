
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

## Rules
- do not collapse grid into simple heatmap
- preserve structural layout always
