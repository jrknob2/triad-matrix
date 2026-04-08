# Notation Grouping And Warmups

## Purpose

Warmups and future rudiment-style material should not be forced into triad notation just because triads are the first teaching focus.

The app now supports **display-only grouping** for pattern notation and a small
built-in warmup deck.

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
- use a standard 1-minute timer per exercise
- carry the current BPM and click setting when launched from a practice session
- be excluded from Matrix coverage, Toolbox readiness, and Coach priority scoring unless deliberately changed later

Candidate warmup phrases considered earlier:

- `LLLL-LLLL-LLLL`
- `RRRR-RRRR-RRRR`
- `LRLR-RLRL-LRLR-RLRL`
- `RLLR-RRLL-LRRL-LLRR`

Implemented MVP warmups:

- `warmup_right_hand_singles`: `RRRR-RRRR-RRRR-RRRR`
- `warmup_left_hand_singles`: `LLLL-LLLL-LLLL-LLLL`
- `warmup_singles`: `RLRL-RLRL-RLRL-RLRL`
- `warmup_doubles`: `RRLL-RRLL-RRLL-RRLL`
- `warmup_paradiddles`: `RLRR-LRLL-RLRR-LRLL`
- `warmup_paradiddle_diddles`: `RLRRLL-RLRRLL-RLRRLL-RLRRLL`
- `warmup_left_paradiddle_diddles`: `LRLLRR-LRLLRR-LRLLRR-LRLLRR`

Warmups use `MaterialFamilyV1.warmup` so they can be practiced without becoming
coached curriculum. They are excluded from:

- Coach "has logged practice" gating
- Matrix coverage and progress status
- Toolbox readiness
- Working On / tracked-item progress analysis
- session logging and Session Summary

## Practice Source

The practice session can now receive more than one item in its setup. Prev/next
navigation is driven by the setup's `practiceItemIds`.

Current multi-item sources:

- `Working On`
- `Warmup`

Single-item practice still uses the same session screen, so the execution view
does not fork by source.

Warmup mode switches the current practice surface in place instead of pushing a
new route. If launched from an active practice session, ending warmup returns to
that practice session. If launched directly from Focus, ending warmup returns to
Focus.

The exact grouping should reflect the exercise intention:

- isolation/stamina work can use 4-note grouping
- triad vocabulary work should use 3-note grouping
- paradiddle-diddles use 6-note grouping
- future rudiments can use the grouping that matches the rudiment structure

## MVP Boundary

Do not expose grouping as a user-facing setting yet.

For now, grouping is an argument used by renderers and built-in material definitions. Add UI controls only after warmups/rudiments become a real product lane.
