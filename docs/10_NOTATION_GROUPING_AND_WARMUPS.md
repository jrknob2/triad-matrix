# Notation Grouping And Warmups

## Purpose

Warmups and future rudiment-style material should not be forced into triad notation just because triads are the first teaching focus.

The app now supports **display-only grouping** for pattern notation.

This means:

- the stored pattern does not change
- Coach, Matrix, Progress, and assessment logic do not change
- the renderer can choose how notes are grouped for readability
- future warmups/rudiments can be printed in the grouping that matches the exercise

## Display Grouping

`PatternGroupingV1` is the internal notation contract.

Current built-in grouping presets:

- `PatternGroupingV1.none`
- `PatternGroupingV1.spaced`
- `PatternGroupingV1.triads`
- `PatternGroupingV1.fourNote`

Examples:

- spaced: `L L L L L L L L`
- triads: `LLL-LLL-LL`
- four-note: `LLLL-LLLL`

The default rich pattern display remains spaced so existing screens do not visually change unless a grouping is explicitly passed.

The aligned voice display defaults to no extra separators because it already uses fixed-width note cells. When a grouping is passed, the pattern and voice rows both reserve separator space so the two rows remain aligned.

## Warmup Direction

Warmups should be optional preparation, not coached curriculum.

Warmups should:

- use built-in exercise phrases
- be launched optionally before or during a practice session
- use the current BPM, timer, and click settings
- be excluded from Matrix coverage, Toolbox readiness, and Coach priority scoring unless deliberately changed later

Candidate warmup phrases:

- `LLLL-LLLL-LLLL`
- `RRRR-RRRR-RRRR`
- `LRLR-RLRL-LRLR-RLRL`
- `RLLR-RRLL-LRRL-LLRR`

The exact grouping should reflect the exercise intention:

- isolation/stamina work can use 4-note grouping
- triad vocabulary work should use 3-note grouping
- future rudiments can use the grouping that matches the rudiment structure

## MVP Boundary

Do not expose grouping as a user-facing setting yet.

For now, grouping is an argument used by renderers and built-in material definitions. Add UI controls only after warmups/rudiments become a real product lane.
