# Pattern and Practice Context Contract

This is the active contract for Drumcabulary pattern text and practice behavior.

## Architecture

- `Pattern` = what to play.
- `PracticeContext` = how to practice selected pattern(s).
- `Flow` = how selected patterns live musically in sequence.
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

Pattern authoring fields must behave as normal text fields. Cursor navigation,
selection, paste, and arrow keys must not insert grouping spaces or otherwise
rewrite the pattern. Any formatting helper must run only from explicit text
changes or explicit helper actions.

Pattern authoring fields normalize playable notation to uppercase. Lowercase
entry is accepted while typing, but the stored/displayed pattern text is
uppercase.

Grouping is a two-way helper, not an owner of pattern text:

- Editing spaces in the pattern may update the grouping metadata.
- Editing grouping metadata may update visual grouping only through an explicit
  formatting action or a clearly scoped grouping-field edit handler.
- Grouping metadata must never continuously override free text entry.

Pattern text fields must not be controlled by grouping metadata. Arrow keys,
cursor movement, paste, and text selection are plain text-editing operations and
must never insert grouping spaces or rewrite text. Pattern text is normalized to
uppercase at the editor boundary and before saving.

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

## Screen Responsibilities

### Pattern Screen

The old `Practice Item` screen is now the `Pattern` screen. It is reached from
Library `New Pattern` and `Edit Pattern`.

This is a full replacement surface, not a relabeled Practice Item editor. The
screen must not reuse the old control-panel model or any UI structure that
mixes pattern authoring with practice behavior.

Allowed here:

- large, dominant pattern text editor
- sheet-music preview of the current pattern
- pattern validation
- header `?` icon that opens a `Notation Grammar` modal
- lightweight selected-text helpers visible together: accent, ghost, and
  simultaneous hit
- compact undo control
- save modal for title, tags, and notes
- optional preview/playback of the pattern only
- `Save`

Not allowed here:

- `Practice Item` terminology
- `Build`, `Dynamics`, or `Voices` segmented control panels
- duration override controls or any per-note duration UI
- grouping controls
- insert-rest action buttons
- tempo plans
- subdivision drill controls
- cycle/routine controls
- groove context
- flow builder
- practice session controls
- Working On membership controls

Pattern text must remain visible and editable at all times. It must behave like
a normal text field: paste, arrow keys, selection, and cursor movement cannot
rewrite spaces or invoke grouping logic. Spaces are authored phrasing breaks and
should be preserved in saved pattern text.

Pattern details live in the save modal. They should not crowd the always-visible
authoring surface.

The Pattern screen should not use context filters. Its few helper controls stay
visible together and disable when the current selection cannot use them.

Saving a pattern must parse and validate the corrected pattern grammar used by
the editor and preview. It must not route through stale sequence-only parsers
that reject valid pattern text such as accents, ghosts, overrides, or
simultaneous hits.

### Practice Screen

The Practice screen owns active training work:

- selected saved patterns
- playback/session controls
- subdivision, tempo, loop, beat alignment, and cycle practice context
- optional groove context
- optional flow builder
- session completion and self-assessment

Practice must not silently edit saved pattern text. It may offer an explicit
`Edit Pattern` action that navigates to the Pattern screen.

### Library Screen

The Library screen shows authored saved patterns. Its default view is all saved,
non-warmup, non-built-in patterns. Built-in Matrix/catalog material may exist in
runtime state so Matrix, Coach, and practice recommendations can work from a
cleared app, but that seed catalog must not appear as user library content.
The Library must not expose `All`, `Single Surface`, or `Flow` filters; those
are practice/context concepts, not library ownership filters. Search narrows
the same authored-pattern library.

## Practice Context

`PracticeContext` is optional and belongs to selected pattern(s) as practice
behavior. It is not stored inside normal pattern text.

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

Controls are organized by context pills when a screen has too many controls for
one view. Context pills show the controls for that context. Controls that do not
apply to the current selection may be disabled with clear state, but they should
not disappear in a way that breaks the user’s mental model.
