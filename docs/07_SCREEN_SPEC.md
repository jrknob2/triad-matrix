# 07 — Screen Spec

## Purpose

This document turns the app spec into explicit screen contracts.

It answers:

- what each main screen is for
- what state each screen must support
- what content belongs there
- what content does not belong there
- what mock scenarios are needed to test it properly

This is the screen-contract spec the UI should now be built against.

Phase-1 architecture rule:

- all downstream playable material should be treated as one canonical token-sequence pattern model
- Matrix may remain triad-specific internally, but anything it emits into the rest of the app must be generic token-sequence material immediately
- rest/pause is part of the canonical token model even if some authoring and rendering surfaces are still catching up in later phases
- groupings such as triads, 4-note chunks, 5-note chunks, and phrase separators are display/pedagogy hints, not alternate runtime species
- if a screen needs to show grouping, it should read the item's explicit grouping metadata rather than inferring grouping from family or other runtime metadata
- non-warmup Practice sessions should behave as generic pattern sessions rather than triad/combo/4-note/5-note runtime variants
- `Flow` and `Single Surface` may still appear as labels or filters, but they should be derived metadata, not separate session engines
- when a session is explicitly launched in `Flow` or `Single Surface`, that chosen session-mode metadata should be preserved in setup, logging, replay, and history rather than being recomputed later from changed item state
- item family and practice mode may remain persisted as metadata for labels, filtering, pedagogy, and legacy compatibility, but they should not define canonical structure, grouping defaults, or non-warmup session behavior
- the shared notation renderer should consume canonical tokens directly rather than reparsing ad hoc screen strings
- rest/pause positions should render explicitly in normal notation readouts and should not generate a voice-row label

Detailed content inventory, control ownership, and end-to-end flow mapping now live in:

- [12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md](/Users/terryknoblock/Development/flutter-projects/traid_trainer/docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md)

Communication voice and wording rules now live in:

- [13_COMMUNICATION_STYLE_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/traid_trainer/docs/13_COMMUNICATION_STYLE_CONTRACT.md)

Visual control-affordance rules now live in:

- [12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md](/Users/terryknoblock/Development/flutter-projects/traid_trainer/docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md)

---

## Navigation Model

V1 uses a persistent shell with five primary tabs:

1. `Coach`
2. `Matrix`
3. `Practice`
4. `Library`
5. `Progress`

Secondary routes:

- `Practice Item`
- `Session Summary`
- `Settings`
- `Startup Splash`

No `Practice Setup` screen exists in this model.

Phone is the only MVP layout target.

iPad is deferred until after MVP.

Rules:

- phone uses bottom navigation

---

## 0. Startup Splash

### Purpose

Startup Splash gives the app a clear branded first frame while startup finishes.

### Must Do

- show the app icon as the dominant visual
- remain visible for 3 seconds
- transition into the normal shell when startup is ready

### Must Not Do

- show navigation
- show settings
- expose actions or decisions

### Acceptance Criteria

- the first frame is the branded splash, not a blank scaffold or delayed shell
- the splash is display-only
- the splash leads directly into the normal app shell
- the app icon is the largest visual element on the screen

---

## 1. Coach

### Purpose

Coach gives a progress-aware summary first, then one concrete next action.

### Must Do

- give a clear first action on first light
- respond to whether the user has selected work but not practiced yet
- point the player back to current work when momentum matters
- surface cleanup needs
- surface next-step opportunities
- sound like a teacher reading progress and responding to it
- lead with summary, then one concrete next action

### Must Not Do

- act like a dashboard
- list all possible recommendations
- explain internal ranking logic
- duplicate Progress
- expose internal block types as visible card identity

### Primary States

#### State A: First Light

Condition:

- no meaningful practice history
- any no-history startup state

Must show:

- one getting-started card
- recommended starter triads
- `Add to Working On` or `Open Working On`
- `Open the Matrix`

Must not:

- split no-history Coach into multiple different starter cards
- collapse the starter state into one arbitrary active pattern
- show progress-summary language before the first logged practice session

#### State B: Early Work, Still Unstable

Condition:

- some sessions logged
- little stable material

Must show:

- one or two cards max
- summary-first guidance
- one clear next action
- evidence that feels concrete, not theoretical

#### State D: Active Development

Condition:

- active items with recent practice

Must show blocks from:

- `Focus`
- `Needs Work`
- `Momentum`
- `Next Unlock`

#### State E: Phrasing / Flow Readiness

Condition:

- strong enough material exists for phrase or flow expansion

Must show:

- next unlock toward phrase-building or flow
- direct CTA to practice or open Matrix

### Primary Actions

- `Practice`
- `See in Matrix`
- `Add to Working On`
- `Open the Matrix`

### Mock Scenarios Required

- `first_light`
- `starter_items_selected`
- `early_struggle`
- `steady_progress`
- `phrase_ready`
- `flow_ready`

### Acceptance Criteria

- user should always know the next best action
- user should first understand how practice is going overall
- no internal/framework wording may appear
- no static filler cards may appear once real data exists
- the screen should feel sparse, not busy
- visible card titles should read like coaching advice, not loose categories

---

## 2. Matrix

### Purpose

Matrix is the structural map of the triad system and the main phrase-building surface.

### Must Do

- show the grid as the primary surface
- support one exclusive view plus contextual filters
- support structural row/column slicing
- support assessment/progress overlays
- support selection and phrase building
- start practice directly
- send material to Focus
- resolve conflicting filters by replacement, not disablement

### Must Not Do

- become a coaching feed
- hide the grid behind too much supporting UI
- use per-cell editing controls for exact sequence editing

### Primary States

#### State A: Browsing

- filters active or inactive
- no phrase being built

#### State B: Selection / Phrase Building

- one or more items selected
- phrase notation readout visible
- phrase editor visible above grid
- action row visible

#### State C: Deep-Linked From Coach

- specific view/filter preset already active
- context visible but lightweight

### Primary Actions

- `Single Surface`
- `Flow`
- `Add to Working On`
- `Clear`

### Interaction Rule

The grid shows membership.  
The phrase notation readout shows the whole phrase.  
The phrase editor shows exact ordered occurrences.

Matrix grid cells are structural cells. They should use an in-memory structural triad basis to render the grid and may suppress authored dynamics and voice rows. Phrase readouts and phrase-editor chips may show those authored layers because they represent the selected phrase rather than the structural grid catalog.

Matrix outputs should hand off generic token-sequence practice material downstream. No downstream practice, list, or session surface should require matrix-cell identity once the item exists.

Shared notation geometry should remain renderer-owned across screens and should use a simple adjustable token-rectangle model: each visible notation character gets its own explicit box, ornament widths and internal gaps are direct constants, note spacing stays compact, ghost parens keep consistent breathing room and vertical centering around the note, accent marks sit in their own box before the note, and phrase separators keep a small clear gap from adjacent marked tokens.

If an item appears anywhere in the phrase, its matrix cell is selected.  
Exact removal happens in the phrase editor, not inside the cell.

Matrix filters follow this structure:

- one exclusive `View`
- one contextual filter row for that view
- row and column slicers built into the grid

Coach `lane` is translated into a Matrix preset, not shown as a persistent Matrix control.

Phrase rule:

- one triad may always be selected for direct practice
- additional triads may be appended freely while building a phrase
- once more than one triad is selected, Matrix should behave like phrase-building mode and default practice from that selection to Flow
- if selected phrase material includes triads that are not ready, Matrix should show guidance instead of blocking phrase building
- Matrix `Try It Out` should be a try-it-now preview action, not a tracked-session entry
- Matrix `Try It Out` should convert the current triad selection into a generic ephemeral pattern item before opening Practice Session
- Matrix preview practice should be untracked
- Matrix preview practice should return to Matrix on end and should not open Session Summary
- `Add to Working On` should open authoring/edit flow, not silently create duplicates or save immediately
- `Add to Working On` should convert the current triad selection into a generic authored pattern item immediately; downstream screens should not depend on combo metadata or matrix-cell structure
- Matrix phrase-building state should not expose a separate `Save` action when `Add to Working On` already hands off into explicit item authoring
- when Matrix is opened from `Practice Item`, it should reuse Matrix in edit mode instead of routing to a separate builder screen
- Matrix edit mode must preload the item's current triad sequence on first render
- Matrix edit mode must treat the current `Practice Item` draft as the source of truth for phrase readout, accents, ghosts, and voices
- Matrix edit mode may use Matrix structural triads as templates for newly added segments, but it must not rebuild the existing phrase from child-triad records or hard-coded base-item records
- Matrix edit mode should replace `Add to Working On` with a return action back to `Working On`
- moving from `Practice Item` into Matrix and back must preserve authored markings and voice assignments unless the user explicitly changes and saves them
- unchanged phrase occurrences should keep their authored segment data through the Matrix round trip
- newly added phrase occurrences should start with the added triad's default/authored template data
- removed phrase occurrences should remove that segment's authored data
- the phrase panel should show both a readable notation line for the whole phrase and removable chips for exact occurrence editing
- phrase-building state should not show `Open Item`
- phrase-editor chips should size to their content and wrap as compact rows instead of stretching across the panel

### Acceptance Criteria

- grid remains the dominant surface
- selected state is clear without being noisy
- progress state and filter scope are visually distinct
- deep links from Coach land in a meaningful matrix view
- invalid filter combinations are prevented by design, not explained after the fact
- compact horizontal controls are preferred before adding more stacked filter rows
- row and column slicers must look touchable, not like passive labels
- Matrix action controls should change meaningfully between single-triad selection and phrase-building selection
- filter controls should be labeled `Filters` and rendered in a single horizontally scrollable row
- if a horizontal control row overflows, it should show a standard page-position dot indicator beneath it
- the dot indicator should reflect the real number of horizontal viewport pages, and the last dot must become active before the user reaches the far-right edge
- Progress-filtered Matrix states should make the filtered slice more visually dominant than non-matching cells
- Matrix should default to `Progress` for generic entry, with `In Working On` selected when that pool exists
- the Matrix progress legend should appear once per state, not repeat when the phrase panel is open

---

## 3. Practice

### Purpose

Practice gives the user a direct way to start playing and then executes the session cleanly.

### Must Do

- exist as a primary tab
- support direct-entry practice choices
- support previous-session repeat from a browsable recent list
- support practice from `Working On`
- support warmup
- support session setup that narrows `Working On` into today's slice
- run the session player with minimal friction

### Must Not Do

- act like another Coach screen
- hide behind other surfaces
- overload the player with setup UI

### Primary States

#### State A: Direct Entry

Must show:

- `Repeat a Previous Session`
- `Choose Patterns to Practice`
- `Warm Up`

Must support:

- guided-default emphasis inside the existing Practice setup flow
- manual/custom session slicing without introducing a separate user-facing advanced-mode split
- `From Working On` inside `Choose Patterns to Practice`
- exact item selection for a session
- derived session-scope filters based on actual item properties and progress state
- saved single-item practice BPM and duration defaults without storing them as authored notation/item data
- a short recent-session list with enough pattern detail to recognize the session
- search within that recent-session list by practiced pattern
- `Load More` for older sessions
- any filter controls should be labeled `Filters` and rendered in a single horizontally scrollable row
- `From Working On` should not show duplicate count chips when the same count is already carried by the start action
- list-item metadata should use concise subtext with dot separators, not chip-style badges, unless the chip itself is the primary interaction
- list rows in `Practice` and `Working On` should follow the same shared formatting rules unless an explicit exception is documented
- selection actions like `Select All` and `Clear` should be separated from `Filters` under an `Actions` label
- when one or more items are selected, the start-practice action should appear in that same `Actions` row
- selected items should load into the player in the same order they were selected
- if the current action selects every item in the visible filtered slice, the label should be `Select All`, not `Select Visible`
- if a direct-entry source is not available yet, its launch tile should explain why and offer the next valid action instead of appearing as a dead disabled card

Optional later:

- `Recent Sessions`

#### State B: Normal Session

Must show:

- player panel
- notation
- pulse / click / BPM / timer
- integrated BPM core display with tick-ring treatment when the full player treatment is active
- the BPM display should read as BPM core, inner solid pulse ring, and outer tick gauge
- the inner pulse ring and the outer tick gauge should remain visually separated by a small clear gap
- the outer tick gauge should stay visually static apart from cycle-progress color change and should not flash on the beat
- gauge ticks should render as squared rectangular marks rather than rounded strokes
- passive `+N Reps` earned-work display for tracked sessions
- prev/next when source contains multiple items
- `Play`
- `End`

Must do:

- preserve the established stopped Practice Session layout exactly; focus mode should apply only while the player is running
- when `Play` is pressed, collapse/fade the session header and phone bottom nav while the player region expands into the reclaimed space
- when `Pause` is pressed, reverse the same transition smoothly
- a distinct running focus layout is acceptable as long as the transition remains continuous and the stopped layout is not redesigned
- keep focus-mode motion subtle and smooth, roughly `280–340ms`, with no bouncy motion
- the transition should feel like regions sliding into place rather than flipping between layouts
- Practice Session utility controls should live in a settings modal opened from a header-right settings icon rather than in a persistent utility card
- the settings modal should own BPM adjustment plus click, pulse, and pattern-highlighting toggles
- reaching the target duration should cue the cycle boundary without force-ending the session
- in multi-item sessions, BPM changes should belong to the currently shown item, not the whole session globally
- in multi-item tracked sessions, the target duration applies per current pattern, not once across the entire slice
- in multi-item tracked sessions, each current pattern should use its own saved launch duration when available
- in single-pattern tracked practice, reaching the target duration should chime and restart the gauge cycle while total elapsed time keeps running
- in multi-item tracked practice, reaching the current pattern's target duration should chime and auto-forward into the next pattern
- after the final pattern reaches its target duration, the player should chime, wrap back to the first pattern, and continue running with total elapsed time preserved
- Practice Session stepping/highlighting should follow canonical token positions rather than triad chunks or family labels
- rest/pause positions should occupy one full timed slot in the player and participate in stepping/highlighting the same way as note positions
- Practice Session audible pattern playback should use canonical token positions plus timing metadata rather than grouping or family labels as timing truth
- audible pattern playback should be optional, and its toggle belongs directly under the pattern notation as a dedicated ear button
- when the ear toggle is turned on, pattern audio should begin immediately and continue looping until the toggle is turned off
- pattern highlighting should use the same switch treatment and settings location as click and pulse rather than a separate notation-row button
- enabling or disabling pattern audio or highlighting must not change timer, rep, or session-end behavior
- grouping may provide a default simple timing interpretation for drills, but explicit timing metadata must be able to override grouping for advanced fills or phrases without introducing a new runtime mode
- the default simple timing interpretation should be:
  - compatible grouping size -> one grouping per beat
  - otherwise -> one token per beat
- click playback should use a preloaded low-latency trigger path rather than repeatedly retriggering one shared media player instance
- when native metronome playback is active, the visual pulse should derive from the native audio playback phase rather than an event-channel beat callback or an independent Dart beat clock
- after native beat onset is detected, the player may hold the visual pulse briefly for readability, but the beat onset itself must still come from the native playback phase
- any tick-ring or segmented pulse treatment must still be driven by that same synchronized beat state, not by a separate animation clock
- completed gauge ticks in the player should use one green progression color as the session advances
- inactive gauge ticks in the player should remain neutral
- gauge tick color in the player communicates cycle completion progress, not rep quality
- minor-tick density should be based on physical spacing, with the gap between minor ticks equal to one minor-tick width regardless of gauge size
- major tick count in the player should represent the current pattern cycle target, not the total session span
- major tick progression should stay visually in sync with the current cycle timer
- overall gauge tick density should stay visually consistent across durations
- major ticks may use a higher-contrast color treatment than minor ticks to preserve hierarchy
- major ticks may use a light high-contrast treatment relative to minor ticks to preserve hierarchy
- when the outer gauge uses major and minor ticks, the hierarchy should read primarily through thickness and weight, not by making the major ticks much longer than the minor ticks
- earned reps should advance from active tracked practice time at `1 rep = 60 seconds`
- the earned-reps readout should remain a passive pill and should read `N Reps Earned`
- warmup and Matrix preview practice do not earn reps
- player pulse treatment should stay visually restrained relative to notation and timer
- if pulse clarity and pulse decoration conflict, the player should prefer a simple synchronized flash treatment
- when pulse synchronization is being verified or debugged, the player should use a plain border on/off effect instead of glow or eased animation
- once synchronization is proven stable, the player may add a small number of static concentric rings during the flash state, but they must follow the same on/off beat state instead of introducing a separate animation path

#### State C: Warmup Session

Must show:

- warmup title
- current rudiment name
- notation
- pulse / click / BPM / timer
- prev/next
- `End`

Warmup rules:

- 1 minute per exercise
- continuous deck timer
- auto-advance
- untracked
- entered from `Practice` only
- manual prev/next should change the visible warmup without changing elapsed timer progress

Running transport rules:

- while running, primary transport controls are `Pause` and `Reset`
- `End` remains the session-exit control for normal tracked sessions
- in normal tracked sessions, `End` should not appear in the same running transport row as `Pause` and `Reset`
- `End` stays disabled until the session has actually started and has session data
- transport buttons shown together should share the same visual weight and size
- action buttons shown together in shared rows should use the same vertical size whenever their labels allow it

### Acceptance Criteria

- user can reach practice directly from nav
- the current Practice setup flow remains intact while still supporting a stronger guided-default experience
- the app should distinguish between a broad `Working On` pool and a smaller session slice
- `From Working On` should not exist as a separate top-level card
- `Repeat a Previous Session` should not assume the most recent session is always the intended one
- session size guidance should be advisory, not blocking
- session player feels like an execution surface, not a config form
- warmup behaves like temporary prep, not core curriculum
- the player must not contain an in-session `Warm Up` entry point
- Practice should not contain helper navigation actions that just open `Focus`
- back from Session Summary returns to the player
- back from the player returns to Practice
- multi-item sessions should preserve item-specific runtime BPM while the player moves between items
- multi-item tracked sessions should only carry practiced patterns into Session Summary
- Session Summary should open on the first practiced pattern, not the last viewed pattern
- when a pattern's BPM changed during the session, Session Summary should present one BPM save choice for that pattern
- Session Summary should use explicit per-pattern `Submit` and `Skip`, not implicit auto-save on every selection
- Session Summary should remain the main assessment surface even if a later `Claim Your Work` layer is added
- rep credit may operate as both motivational feedback and claimed-work data for progress logic
- Session Summary may ask the student whether to keep earned reps before final submission
- if a tracked session ends with zero earned reps, skip Session Summary and return directly to Practice
- the player's running transport controls should fit in one row on phone without wrapping
- Session Summary recommendations should influence the message, not rename the replay action
- Session Summary should not contain work-management actions like `Add to Working On`
- player notation on phone must never break inside a marked token
- player phrase wrapping should break on group boundaries, with the separator staying at the end of the row

---

## 4. Library

### Purpose

Library is the current working set and searchable working library.

### Must Do

- show the active items cleanly
- support play
- support edit/open
- support remove
- support add from Coach/Matrix
- allow the list to be broader than a single day's session
- support searching across all practice items when the player wants to add or find something quickly

### Must Not Do

- behave like Coach
- behave like Progress
- contain internal teaching philosophy copy

### Primary States

#### State A: Empty

Must show:

- what Library is for
- how to add items

#### State B: Active Working Set

Must show:

- current items
- simple item controls

#### State C: Search / Add

Must show:

- a search field
- results from all practice items, not just current `Working On`
- clear add/open behavior for results that are not already in `Working On`
- normal current-work controls for results already in `Working On`

Optional:

- section toggle between single-surface and flow-friendly items

### Per-Item Controls

- play
- edit
- remove

Per-item play should read as `Practice`, not as `Practice on One Surface`; voice display is derived from authored item data.

### Acceptance Criteria

- Library should read as CRUD for current work plus quick access to the broader working library
- Library should feel like the broad active pool, not today's forced checklist
- search must help the player find and add practice items quickly without turning Library into a second Matrix
- filter state must always have a clear way back to `All`
- the user should never wonder whether an item is “saved”, “mastered”, or “current”
- the screen should not duplicate its own title with a second visible `Working On` heading
- the add entry point may live inline with search as a compact `New` / `+` control
- `New` from Library should open a new `Practice Item` draft rather than opening Matrix
- that draft should begin as a blank generic token-sequence item and may offer triad insertion as a helper from inside the editor
- no extra per-item flow-launch button should appear in the list
- there should be no fake summary cards trying to turn this into a dashboard
- removing an item should require confirmation with the item's notation visible in the prompt

---

## 5. Progress

### Purpose

Progress measures development.

### Must Do

- show overall trends
- show item-level progress
- show group/category progress
- show coverage
- show useful summaries over time
- if a status-mix graph is shown, it should render as visibly stacked colored segments rather than pale containers

### Must Not Do

- sound like Coach
- repeat Focus
- explain internal status systems to the user

### Recommended Views

#### Overview

- total time
- recent activity trend
- coverage summary
- rolled-up assessment graph
- visible graph scope
- time-based bar graphs should make their unit explicit

#### By Item

- item list with progress state
- logged time
- recent work
- selected-item assessment graph
- selected-item BPM graph
- selected-item time graph
- status labels in improvement order

#### By Group

- hands-only vs kick-containing
- right-lead vs left-lead
- later, phrase families

#### Trend

- practice over time
- maybe time by week

### Acceptance Criteria

- Progress should feel like measurement, not recommendation
- counts and labels must match the visible scope
- no copy like “this is the same status language used by Coach and Matrix”
- graph titles must say what is being measured
- status differences must be visually obvious in graphs
- passive scope labels and legends should not look like buttons
- vertical bar charts should use flat bottoms with only modest top-corner rounding instead of pill silhouettes
- non-stacked bar charts should use a lighter fill with a darker border
- coverage summary wording should use clear `covered` or `practiced` language instead of `seen`
- coverage value columns should stay numeric when the row label already carries the category meaning

---

## 6. Practice Item

### Purpose

Practice Item is the detail/edit screen for one piece of material.

### Must Do

- show the pattern clearly
- show concise work history / settings context where it helps
- allow accent/ghost editing
- allow flow voice assignment
- allow per-item BPM and duration defaults
- allow opening that item in Matrix
- use explicit save for edits
- warn before leaving with unsaved changes

### Must Not Do

- duplicate session execution UI
- contain unnecessary supporting chips that repeat the visible pattern

### Acceptance Criteria

- the pattern display is the primary signal
- tapping the notation selects one or more assignable notes; it does not directly assign markings or voices
- controls under it are clearly for editing the item, not playing it
- accent/ghost controls act on the current selected note set
- voice controls act on the current selected note set
- the authored item owns its own notes; the screen is not editing a projection of a separate built-in base item
- practice defaults should feel like saved setup values, not authored pattern data
- no voice assignments and all-default voices should be treated as the same single-surface state
- default kick placement on `K` should not make an item read as Flow
- list filters may still expose `Single Surface` and `Flow` as derived item states
- accents, ghosts, and flow voice assignments only appear when they were authored by the user
- saved triad phrases / combo items should render with visible triad grouping by default
- Practice Item should show one primary notation block
- the editing UI should avoid rendering one chip per note when the notation itself can serve as the selection surface
- unsaved-changes prompts should stay visually aligned with the app's own dialog motif rather than default tinted Material styling
- popup dialogs across the app should stay visually aligned with the app's own dialog motif rather than default tinted Material styling
- when the item has flow voices, that primary notation block should render as a unified two-row pattern/voice display
- the `Flow Voices` section should contain editing controls, not a second notation preview
- rest positions should keep `_` as the canonical stored token but render as `•` in user-facing notation
- Practice Item may later expose timing controls, but grouping and timing must remain separate concepts in the data model and playback path
- the `Practice Item` note-selection affordance may add only a small tap-target halo around the shared renderer; it should not create a wider second spacing model for note slots or separators
- the `Practice Item` note-selection affordance should derive its slot and separator sizing from the shared renderer geometry instead of fixed local constants
- `Practice Item` should contain a `Pattern Structure` section for direct token-sequence editing
- `Practice Item` should contain an explicit `Grouping` control for visible separator metadata
- a new blank `Practice Item` draft should open with a stable empty notation row already visible so the editor does not jump when the first token is inserted
- edits should not write through immediately while the user is still working on the screen
- selection should toggle on tap so the user can add and remove notes from the current selected set
- applying a marking or voice assignment should clear the current selection
- kick notes should not be assignable in this editor flow
- non-hand positions may still be selected for structure editing even though they are not assignable for dynamics or voices
- structure edits should stay in the local draft until save, just like dynamics, voices, BPM, and duration
- the structure editor should support replace, insert, delete, rest insertion, and triad-helper insertion without switching to a different editor mode
- triad-helper insertion should allow selecting one or more triads and should insert them in the order selected
- the `Grouping` control should affect only visible separator metadata, not runtime behavior or family labels
- the `Grouping` control should expose only group sizes compatible with the current token count, plus `None`
- deleting the entire current token sequence should be allowed and should return the draft to that stable empty-row state
- when direct structure edits break an inherited grouping shape, the stale grouping hint should clear instead of continuing to render separators that no longer fit the edited pattern
- triad-helper insertion inside `Practice Item` should use the same shared triad-grid rendering language as Matrix, even if the modal or sheet wrapper is simpler
- triad-helper insertion should establish explicit triad grouping metadata when the resulting draft is fully triad-grouped and contains no rests
- `Practice Item` should stay authoring-focused and should not contain direct practice-launch buttons
- `Practice Item` is the primary screen for creating a new pattern from scratch
- Matrix is not the primary generic new-item builder; it remains a triad-specific teaching, discovery, insertion, and triad-structure-editing helper
- when Matrix editing expands a single triad into a phrase, returning should continue on the resulting phrase item instead of dropping the added triads

Practice screen session setup:

- `From Working On` should not expose a `Mode` toggle like `One Surface / Flow`
- flow display is derived from selected authored voice assignments, not chosen as a visible setup mode
- `Practice Item` owns authored item editing; `Matrix` only edits phrase structure when launched from this screen
- `Open in Matrix` must hand off the current item draft rather than asking Matrix to infer authored state from child triad records
- `Open in Matrix` should remain available for unsaved phrase drafts that can be represented as triad sequences
- any generic item whose current token sequence can be losslessly split into triads may still use `Open in Matrix`
- normal editing should not create a hidden authored variant of a separate built-in base item
- when Matrix returns, Practice Item should continue on the same authored item draft when possible, or on the resulting replacement phrase item when the structure changed from one triad to a phrase

### Session Summary Rules

- Session Summary should use self-report first, but it must also account for attempted BPM and pattern complexity
- a player who is new to the app may still be advanced on the instrument; the recommendation logic must not treat no app history as beginner evidence by default
- positive self-report on a simple pattern at a strong BPM may produce congratulatory language even with little or no app history
- BPM-save prompts should not suppress a positive recommendation when the rep itself was strong

---

## Mock-State QA Requirement

Before major UI work is considered done, each main screen must be checked against its required states using explicit mock scenarios.

No screen should be judged “done” only by looking at a happy-path live state.
