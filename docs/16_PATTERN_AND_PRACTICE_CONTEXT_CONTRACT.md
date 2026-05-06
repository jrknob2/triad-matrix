# Pattern and Practice Context Contract

This is the active contract for Drumcabulary pattern text and practice behavior.

## Architecture

- `Pattern` = what to play.
- `PracticeContext` = how to practice it.
- `PracticeSession` = what happened.
- `Progress` = calculated history.

Pattern text is the playable phrase only. It must stay drummer-readable,
text-first, and valid as a fragment by default. Practice behavior such as
tempo plans, subdivision drills, cycles, loops, and beat-alignment helpers lives
outside pattern text in `PracticeContext`.

## Core Pattern Vocabulary

Valid base tokens:

- `R` = right hand
- `L` = left hand
- `K` = kick
- `F` = flam
- `X` = accent / crash / big hit
- `_` = rest

`B` is not valid pattern vocabulary. Use `[RL]` for both hands together or a
bracketed simultaneous hit such as `[XK]` for multiple voices on the same slot.

## Pattern Grammar

Plain tokens:

```text
R L K F X _
```

Accent:

```text
^R
^L
^K
^F
^X
```

Ghost:

```text
(R)
(L)
(K)
(F)
(X)
```

Simultaneous hits:

```text
[XK]
[RK]
[RL]
[RKL]
```

A simultaneous hit occupies one beat/slot. Its contents are multiple valid
note tokens and optional note-local modifiers. `_` is not allowed inside a
simultaneous hit.

Override brackets keep their existing meaning when they contain `:`:

```text
[T1:L]
[FT:R]
[32:R]
[T1 16:L]
```

Parser rule: brackets with `:` are overrides; brackets without `:` are
simultaneous hits.

Spaces are visual/phrasing group breaks. They do not change playback timing by
themselves and must be preserved by authoring surfaces.

## Pattern Non-Goals

These are not pattern grammar:

```text
@sub=16
@tempo=70
@tempo+=10
@tempoMax=110
@cycle:
@bars=1
@time=4/4
```

Full-bar validation is not required for ordinary patterns.

## Practice Context

`PracticeContext` is optional and belongs to a pattern as practice behavior.

It may contain:

- subdivision: `eight`, `triplet`, or `sixteen`
- tempo plan: start, optional step, optional max
- loop settings
- beat alignment helper with optional anchored pattern
- cycle steps, each with its own subdivision and pattern

Beat anchors such as `|1|` are practice helpers. They may appear in
`BeatAlignment.anchoredPattern`; they must not be forced into normal
`PatternItem.pattern`.

## UI Contract

Pattern editing is primary. Practice context is optional.

Pattern editing controls should support direct text entry and simple
selection-based edits:

- accent selected notes
- ghost selected notes
- combine selected notes into simultaneous hit
- assign voice override
- insert rest

Practice context controls belong in a separate context/tab/collapsible section:

- subdivision
- tempo plan
- loop
- beat alignment
- cycle

Do not show every control at once. Do not require users to fill out practice
context before creating a pattern.
