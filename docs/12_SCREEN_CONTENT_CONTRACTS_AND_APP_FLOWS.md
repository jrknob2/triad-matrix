# 12 — Screen Content Contracts And App Flows

## Purpose

This document defines:

- what content belongs on each core screen
- what content does not belong there
- which controls exist on each screen
- which flows those controls serve
- how screens hand off to each other

This is the missing contract between product structure and UI structure.

If a control or block cannot be justified by a defined flow in this document, it should not exist.

The bottom app navigation must remain visible across primary and detail flows.
Detail screens and session flows should live inside the shell, not cover it.

iPad-specific shell and fullscreen session exceptions are deferred until after MVP.

Communication rules for all student-facing text are defined in:

- [13_COMMUNICATION_STYLE_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/traid_trainer/docs/13_COMMUNICATION_STYLE_CONTRACT.md)

---

## Core Rule

Every screen needs:

1. a clear job
2. a small set of valid states
3. a small set of valid actions
4. evidence that supports those actions

No screen should contain:

- filler cards
- internal/explanatory copy for the team
- controls that belong to another screen
- duplicate information with no new value

Canonical pattern-model rule:

- the app has one canonical playable-pattern model: an ordered token sequence
- each token represents one timed position in the pattern
- canonical tokens must support note tokens and a first-class rest/pause token
- triads, 4-note patterns, 5-note patterns, phrases, flow, and single-surface may still appear as product language, tags, filters, or pedagogy cues, but they must not define parsing, storage structure, renderer choice, playback shape, or session stepping
- grouping is optional metadata for readability and teaching only
- grouping may affect display spacing and labels, but it must not create a separate runtime model
- timing metadata is optional playback structure and must remain separate from grouping metadata
- if a pattern needs visible grouping, that grouping should be stored explicitly on the item; controller/runtime code should not infer grouping from family, mode, or tags outside localized legacy migration boundaries
- item family and practice mode may remain persisted as metadata for labels, filtering, pedagogy, and legacy compatibility, but they must not define canonical structure, grouping defaults, or non-warmup session behavior
- non-warmup sessions are generic pattern sessions; they should not become different runtime species based on whether the current item reads as triad, phrase, 4-note, 5-note, flow, or single-surface
- `Flow` and `Single Surface` should be treated as derived orchestration metadata for labels, filters, and recommendations, not as separate session engines
- when a session is explicitly launched in `Flow` or `Single Surface`, that chosen session-mode metadata should be preserved in setup, logging, replay, and history rather than being recomputed later from changed item state
- the shared notation renderer should consume canonical token data directly
- rest/pause must render explicitly as a timed position in normal notation readouts
- voice rows should omit labels for rest positions even when the surrounding pattern shows voices

List item rule:

- overall metadata inside list items should be rendered as concise subtext
- separate metadata values with dots
- do not use chips for list-item metadata unless the chip itself is the action the user is taking
- list items should use one shared formatting model across screens by default
- typography, spacing, metadata treatment, and action placement should stay consistent unless a specific exception is documented

Notation rule:

- the app should use one canonical notation renderer everywhere notation is shown
- screens may wrap that renderer for selection or editing, but they should not fork the visual notation language
- the canonical renderer must support independent display options for authored dynamics and authored voices
- notation readouts should be center-justified everywhere by default
- if a notation surface also wraps, each wrapped line group should remain visually centered
- left alignment for notation needs an explicit exception, not ad hoc local styling
- notation may wrap only between note cells or documented group boundaries, never inside a marked token
- marked tokens like `^R` and `(R)` must remain visually intact as one unit
- `R`, `L`, and `K` are the anchor glyphs and must always render at the exact same size within a notation readout
- the shared renderer owns notation token geometry; screens may size the overall readout, but they must not introduce local per-screen character spacing or ornament positioning rules
- shared notation geometry should use a character-slot model rather than overlaying symbols inside one note box
- each visible notation character should occupy its own padded slot in the rendered string, including `^`, `(`, `)`, note letters, and phrase separators
- ornament character slots such as `^`, `(`, and `)` may be narrower than note-letter slots so the readout stays compact without collapsing the character order
- ornament glyphs may be biased within their own slots to tune visual proximity: `^` should sit a little away from the note, while ghost parens should sit a little toward the note
- implementation should stay simple and adjustable: each notation token should be a rectangle layout with explicit ornament widths, note width, and internal gaps, so spacing changes are direct and predictable
- note cells should be visually compact enough that adjacent notes read as one pattern rather than isolated glyphs with oversized gaps
- wrappers such as editable/selectable notation surfaces may expand tap targets, but they must not introduce a second independent note-spacing model on top of the shared renderer
- the note glyph must remain horizontally centered in its own character slot regardless of accents, ghosts, voices, or phrase separators
- all non-accent notation characters should align to the same note-row centerline
- `^` should render in its own slot immediately before the accented note rather than being overlaid on the note slot
- ghost notation should keep the note letter at normal size and weight; only the parentheses should step back visually
- ghost parentheses must render in their own slots around the note, leave a small consistent breathing gap, and stay vertically centered with the note, with the same visual amount above and below
- dynamics are part of the pattern token presentation; accent marks should render beside the note, not over the note
- accented notes should read as adjacent character slots, so the accent-plus-note unit stays visually balanced without an abnormal trailing gap
- phrase separators must leave a small clear gap from adjacent marked tokens, including accented notes, so `-` never visually touches the neighboring notation
- voice rows should align to the same note-slot centers as the pattern row, without changing the pattern token rendering
- phrase separators like `-` belong to the notes row and must align with that row's centerline, not visually drift between the notes row and the voice row
- if a pattern has authored dynamics or authored voices, that authored state should render consistently everywhere the pattern is shown
- screens that need a compact structural view, such as the Matrix grid, may suppress dynamics and voices while still using the canonical renderer
- suppressing dynamics or voices is a display choice only; it must not mutate or discard authored item data
- when grouped phrase notation wraps, the group separator should stay at the end of the row it belongs to
- long player phrases may wrap on phone, but that wrapping must occur on practical group boundaries rather than by raw character position

Pattern editing source-of-truth rule:

- the Matrix triad basis is a structural in-memory view used only to render and filter the Matrix grid
- the Matrix triad basis is not the canonical source of editable practice-item identity
- a saved pattern or phrase is one authored item
- the authored item owns its complete edit state:
  - its own token sequence
  - triad sequence / phrase structure
  - accents
  - ghosts
  - voices
  - practice defaults
- a rest/pause inside that sequence is a real stored timed position, not a separator and not missing data
- once a practice item exists, it stands on its own rather than being derived from or rebound to a hard-coded base triad record
- once triads are saved as part of a phrase item, the phrase item's authored state is the source of truth for that phrase
- Matrix structural triads may be used as templates for newly added material, but they must not overwrite or reinterpret an authored practice item's existing notes, accents, ghosts, or voices
- editing may be split across screens, but the draft must be shared:
  - `Practice Item` owns item authoring and orchestration edits
  - `Matrix` owns structure edits when entered from `Practice Item`
  - both screens must operate on the same authored item draft, not on separately recomposed data
- when Matrix edits the structure of an existing authored item:
  - unchanged triad occurrences keep their authored dynamics and voices
  - removed triad occurrences lose their segment data
  - newly added triads start from their own authored/default template data
  - the visible Matrix phrase readout must render the current item draft, not the current global state of the child triad records
- after a structure edit, returning to `Practice Item` should continue editing the same authored item when possible, or the resulting replacement phrase item when a single triad has become a phrase

## Layout Rule

Use horizontal space before adding more vertical stacking.

Interpretation:

- vertical space is for sequence, reading flow, and truly primary sections
- horizontal space is for comparison, compact controls, metrics, legends, and summaries
- avoid turning short values or short explanations into full-height stacked cards when they can sit side by side
- when a screen feels tall before it feels clear, the layout is probably wrong
- charts and summaries should prefer row-based composition when the viewport allows it

Tablet rule:

- tablet-specific layout work is deferred until after MVP
- current active contracts should optimize the phone experience first

Filter row rule:

- any UI surface that exposes filters should label that section `Filters`
- filter pills should live in one horizontally scrollable row
- do not wrap filter pills into multiple lines
- if a horizontal control row extends off-screen, show a standard page-position dot indicator beneath it so the user knows there is more to swipe to
- the number of dots should reflect the number of viewport-width pages in that control strip
- the current page should be visually distinct from the other dots

## Control Affordance Rule

Interactive controls must look interactive without helper text.

Rules:

- buttons must have a visible container, border, fill, or elevation separation from their background
- text alone is not enough to signal a button
- primary and secondary actions must remain visually distinct on both light and dark surfaces
- if a surface is dark or visually busy, action controls must use stronger contrast and edge definition than they use on light surfaces
- the user should not have to tap to discover whether a label is actionable
- passive labels, scope labels, legends, and other non-interactive markers must not use button-like containers or button-like affordances
- non-interactive labels should read as labels immediately, not as tappable pills or chips
- passive displays such as credit, earned reps, scope, legend, and status must remain visually distinct from action buttons even when they share rounded shapes
- if passive informational surfaces use pill-like containers, they must step back through tone, border, contrast, and icon treatment so they cannot be mistaken for tappable controls
- on high-focus screens like the player, primary and secondary transport buttons should avoid soft pill silhouettes when nearby passive displays also use rounded containers
- transport buttons should read as controls first; passive displays should read as instrumentation or status first
- top-level launch panels and primary entry surfaces should not be shown as dead disabled blocks when their source is unavailable
- when a launch surface cannot perform its primary action yet, it should explain why and point to the next valid action instead of only dimming the whole surface
- button sizing should stay proportional to the surrounding UI and shared control system
- one screen should not introduce oversized buttons that visually dominate the app without a specific contract reason

---

## Primary App Flows

### Startup Flow

Goal:

- give the app a clear branded first frame before the shell appears

Path:

1. `Startup Splash`
2. app initialization completes
3. minimum splash duration completes
4. `Coach`

Screens involved:

- Startup Splash
- Coach

Required controls:

- none

Rules:

- startup splash is display-only, not interactive
- startup splash should show the app icon as the primary visual
- startup splash should stay visible for 3 seconds
- startup splash should not show shell navigation or other app controls
- startup splash should transition directly into the normal app shell when ready

### Flow A: First Light Start

Goal:

- help a new user start correctly without wandering

Path:

1. `Coach`
2. `Add to Working On` or `Open Matrix`
3. `Library` or `Matrix`
4. `Practice`

Screens involved:

- Coach
- Library
- Matrix
- Practice

Required controls:

- Coach starter CTA
- Matrix open CTA
- Library item play CTA
- Practice direct-entry CTA

### Flow B: Direct Practice Start

Goal:

- let a user start practicing without needing another screen first

Path:

1. `Practice`
2. `Choose Patterns to Practice` or `Repeat a Previous Session`
3. choose source, previous session, or session scope
4. `Practice Session`
5. `Session Summary`

Screens involved:

- Practice
- session setup inside Practice
- Practice Session
- Session Summary

Required controls:

- `Repeat a Previous Session`
- `Choose Patterns to Practice`
- `Warm Up`
- `From Working On`

Rules:

- `From Working On` belongs inside `Choose Patterns to Practice`, not as a separate top-level reason to use Practice
- `Working On` may be broader than one day's session
- session setup is where the player narrows that broader pool into today's slice
- the current Practice setup flow remains valid; experience-layer work should make it feel more guided, not replace it with a different top-level flow
- guided default behavior belongs inside the existing Practice setup flow
- `Repeat a Previous Session` should browse recent sessions, not only repeat the single most recent one
- previous-session rows must show enough session content to be recognizable, including the patterns practiced
- low-value metadata like practice mode should not appear there unless it changes a real choice
- previous-session browsing may start short and offer `Load More`
- `From Working On` should not show duplicate count chips when the same information is already expressed by the start action

### Flow C: Coach-Driven Practice

Goal:

- move from guidance to action quickly

Path:

1. `Coach`
2. `Practice` or `Matrix`
3. `Practice Session`
4. `Session Summary`

Screens involved:

- Coach
- Matrix optionally
- Practice Session
- Session Summary

Required controls:

- primary CTA on each Coach block
- optional `See in Matrix`

Rules:

- if Coach is pointing toward phrase building, it should hand off into `Matrix`, not a separate builder screen
- that handoff should preload the suggested triad selection when the advice depends on specific triads

### Flow D: Matrix Discovery And Phrase Building

Goal:

- browse the triad system
- isolate slices
- build phrases

Path:

1. `Matrix`
2. filters / selections
3. phrase editor
4. `Try It Out` or `Add to Working On`

Screens involved:

- Matrix
- Practice Session
- Focus optionally

Required controls:

- view/filter controls
- phrase editor
- action pills

Rules:

- `Try It Out` from Matrix is a try-it-now preview flow
- Matrix preview practice is untracked
- Matrix preview practice must not silently save the current selection as an item
- Matrix preview practice must return to `Matrix` when ended
- Matrix preview practice must not open `Session Summary`
- Matrix phrase-building state must not expose a separate `Save` action when `Add to Working On` already hands off into explicit item authoring

### Flow E: Active Work Management

Goal:

- manage the current working set

Path:

1. `Focus`
2. play / edit / remove
3. `Practice Item` or `Practice Session`

Screens involved:

- Focus
- Practice Item
- Practice Session

Required controls:

- play
- edit
- remove

Rules:

- `Working On` is a broad active pool, not a forced tiny queue
- the app must not hard-cap the length of `Working On`
- overload guidance belongs in session setup and active-rotation guidance, not in the existence of the list itself
- removing an item from `Working On` must require explicit confirmation
- the confirmation must show the item's notation so the player can verify the exact item being removed

### Flow F: Progress Review

Goal:

- inspect development over time
- inspect assessment trends visually

Path:

1. `Progress`
2. drill into item or category
3. optionally continue into `Practice Item` or `Matrix`

Screens involved:

- Progress
- Practice Item optionally
- Matrix optionally

Required controls:

- view switcher
- filter scope
- drill-down rows
- selected-item graph/detail panel

### Flow G: Flow Preparation

Goal:

- assign voices and prepare a phrase for kit application

Path:

1. `Matrix` for phrase structure if needed
2. `Practice Item` for authored voices if needed
3. `Practice` session setup from `Working On`
4. `Practice Session`

Screens involved:

- Practice Item
- Matrix
- Practice Session

Required controls:

- voice assignment editor in Practice Item
- `Flow`-derived filters or metadata where they help session selection

Rules:

- `Flow` is a derived practice capability, not a user-declared item type
- an item is considered `Flow` only when it has user-authored off-snare voices on non-kick notes
- no voice assignments and all-default voices are the same single-surface state
- flow preparation does not add direct `Practice in Flow` buttons to `Practice Item`; session launch belongs to `Practice`
- default kick placement on `K` does not make an item `Flow`
- `Single Surface` is the universal baseline practice mode, not an item classification
- free-built phrases remain allowed in v1
- curated phrase guidance is a later product layer and should not constrain current free-building behavior

### Flow H: Warmup

Goal:

- do short optional prep without contaminating coached data

Path:

1. `Practice`
2. `Warm Up`
3. `Warmup Session`
4. return to `Practice`

Screens involved:

- Practice
- Practice Session in warmup mode

Required controls:

- `Warm Up`
- prev/next
- `End Warmup`

---

## Screen Content Contracts

## 1. Coach

### Screen Job

Coach answers:

- how is my practice going overall
- what should I do next
- why now
- what is the shortest useful path into practice

### Allowed Content

- 1 to 2 cards
- one summary-first lead card
- short evidence lines
- at most one follow-up action card
- one primary CTA per card
- optional secondary `See in Matrix`

### Forbidden Content

- dashboards
- charts
- long lists
- static motivational text
- status explanation cards
- controls for editing items

### Allowed Card Types

Internal only:

- `Summary`
- `Getting Started`
- `Focus`
- `Needs Work`
- `Momentum`
- `Next Unlock`
- `Resume` later

Visible card identity should be a coaching move, not the internal type.

### Required Information On A Card

- title
- short body
- one concrete reason
- one primary CTA

Coach structure rule:

- the first card should read as a progress-aware summary
- Coach may include one concrete next action beneath that summary
- Coach should not feel like a stack of drill commands
- Coach should not open with a pattern-specific command unless the user is in first-light or no-history states
- when real practice history exists, the lead card should summarize momentum, consistency, or scope before naming a specific pattern
- when a second card exists, it should be the single clearest next action, not another summary
- summary cards should avoid raw notation and specific triad names in prose
- action cards should not lead with raw notation as the main sentence shape
- if a specific pattern must be identified, prefer a lightweight pattern strip or supporting line over building the whole sentence around the notation
- Coach should read like a progress report first and advice second
- Coach must not sound like it is listening live unless the app actually has listening capability
- beginner-facing instruction should prefer `pad` or `snare` instead of `one surface`
- Coach summary time should read in plain language like `logged 16 hours` or `logged 37 minutes`, rounded down
- recommendation titles, bodies, and CTA labels should switch cleanly between `this` and `these` based on whether one item or a small set is being recommended

Preferred visible title shapes:

- `Try this`
- `Think about`
- `Put more attention on...`
- `Slow it down`
- `Speed it up now`
- `You are ready for...`
- `Spend more time here`
- `Keep this going`
- `Clean this up`
- `Move this around the kit`
- `Spend more time on this`
- `Spend more time on these`

### Forbidden Wording

- `baseline`
- `signal`
- `active work`
- `status language`
- `this view shows`
- `reference point`
- robotic diagnostic phrases like `the weak spot is`
- visible category labels that read like framework buckets
- template-like statements that sound machine-assembled from item names and status flags
- pseudo-observational phrases that imply the app directly heard the rep when it did not
- developer-like action phrasing such as `assign one change`

### Primary Controls

- `Practice`
- `See in Matrix`
- `Add to Working On`
- `Open Matrix`

### Control Rules

- every CTA must map to a real flow
- every card must be actionable
- no display-only chips with no action value
- each card should feel like observation plus advice, not category plus label

### Coach State Matrix

#### First Light

Show:

- one starter card
- recommended starter triads
- `Add to Working On` or `Open Working On`
- `Open the Matrix`

Hide:

- needs work
- momentum
- next unlock

Rules:

- any no-history state should collapse to this same single starter card
- no separate `Start Here` or `You are ready to start` card should appear before the first logged practice session
- if the recommended starter set has already been added, keep the same starter card and change only the available action state
- the card may reference the full starter set, not collapse immediately to one pattern unless the user explicitly narrowed the set
- beginner-facing starter copy should use `pad` or `snare`
- the starter actions should help the user either add the starter set or begin from Matrix
- the starter card should use the shared Coach/app panel motif, not a one-off blue hero treatment
- the starter card body should lead with a brief welcome and simple first-step coaching, not workflow explanation
- starter copy should not explain `Working On`, loop mechanics, or other app/process details inside the coaching body
- beginner starter advice should stay simple: repeat each item slowly and evenly with a relaxed posture and grip
- starter copy may feel encouraging, but it should not drift into generic marketing language
- starter copy may briefly explain what Drumcabulary helps the player build before naming the first step

#### Early Struggle

Show:

- one summary lead card
- one follow-up action card if needed

Rule:

- first visible card should summarize the slowdown or inconsistency before naming the next action

#### Steady Progress

Show:

- one summary lead card
- one follow-up action card if needed

Rule:

- lead with progress summary
- follow with one next action only when it adds value

#### Phrase Ready

Show:

- one summary lead card
- one follow-up action card if needed

Rule:

- summary should state readiness before pointing to phrase work

#### Flow Ready

Show:

- one summary lead card
- one follow-up action card if needed

Rule:

- summary should state readiness before pointing to flow work

---

## 2. Matrix

### Screen Job

Matrix answers:

- what is in the system
- what slice am I looking at
- what am I selecting
- what phrase am I building

### Allowed Content

- filter controls
- grouped matrix grid
- lightweight context text
- phrase editor
- action row
- progress legend

### Forbidden Content

- Coach cards
- progress storytelling
- per-cell delete controls for phrase editing
- large top-of-screen explainer walls

### Required Regions

1. filter / lens controls
2. optional short context text
3. matrix grid
4. phrase editor when selection exists
5. action row when selection exists

### Control Inventory

#### Filter Controls

Serve:

- Flow D
- Coach deep-link flow

Rules:

- Matrix has one exclusive `View` chooser:
  - `Progress`
  - `Characteristics`
- each view exposes only the filters that belong to that view
- row and column selectors are structural slicers, not part of the main filter bar
- row and column selectors must look interactive on touch screens
- interactive labels must read as controls through shape, contrast, spacing, or iconography rather than relying on helper text
- Coach may deep-link Matrix into a preset state, but Coach lane labels do not remain as a persistent Matrix control
- conflicting filters resolve by replacement, not disablement
- selecting a conflicting filter clears the incompatible one and applies the new one
- Matrix should almost never show disabled filters inside an active view
- if a filter becomes irrelevant because the view changes, it should be cleared rather than shown as disabled

Examples:

- `Characteristics` view:
  - `Right`
  - `Left`
  - `Hands Only`
  - `Has Kick`
  - `Starts w/ Kick`
  - `Ends w/ Kick`
  - `Doubles`
- `Progress` view:
  - `Not Practiced`
  - `Actively Working On`
  - `Needs Work`
  - optional secondary:
    - `In Working On`
    - `In Phrases`
    - `Recent`

Rules:

- `never seen` is not a valid product state label
- until `Toolbox` exists, membership-style states should use plain labels like `In Working On`
- `Strong` is already visible through the matrix progress color and should not also appear as a separate progress filter
- generic Matrix entry should default to `Progress`
- generic Matrix entry should default to `In Working On` when Working On is not empty
- with no active Progress filters, the grid should show the full progress color map
- with an active Progress filter, filter match should become the primary visual signal
- when a Progress filter is active, non-matching cells should step back to a neutral treatment rather than competing equally with matching cells
- when a status filter is active, only matching cells should retain strong status color
- when a secondary Progress filter is active, matching cells may retain status color but non-matches should still step back clearly
- Progress view should show a short active-scope line above the grid, such as `Showing: Needs Work + Recent`
- progress coloring belongs to `Progress` view only
- the progress legend should appear only once in a given Matrix state and should render after the grid, not before the grid or inside the phrase panel
- horizontal page indicators must reflect the real count of viewport pages, and the last dot must become active before the user reaches the hard end of the strip
- Matrix grid cells should render as structural cells only; they must not show authored dynamics or voice rows
- Matrix phrase panels and sequence chips may show authored dynamics and voices because they represent the selected phrase, not the structural grid

#### Phrase Editor

Serve:

- Flow D

Rules:

- a single selected triad is direct item selection
- selecting a second triad turns the editor into phrase-building mode
- shows a readable notation line for the whole phrase
- shows exact ordered sequence
- owns exact occurrence removal
- notation readout and removable chips serve different jobs and should both be visible
- grid reflects membership only
- additional triads may be added freely while building a phrase
- if a phrase includes triads that are not ready, Matrix should show inline guidance instead of blocking selection
- that guidance should explain readiness in relation to building a longer phrase, not as an undefined generic gate
- adding material from Matrix must not inject accents, ghosts, or flow voices automatically
- phrase-building mode defaults to flow-oriented practice actions
- phrase chips in the editor should size to their phrase content and wrap as compact rows
- phrase chips must not stretch to the full panel width unless the phrase content actually requires it
- in generic phrase-building mode, Matrix may compose the phrase readout from selected triad items
- in item-edit mode from `Practice Item`, Matrix must render and edit the current authored item draft as the source of truth
- item-edit Matrix must not rebuild the phrase display from child triad records when doing so would change existing authored accents, ghosts, or voices

#### Action Row

Serve:

- direct practice
- add to Working On
- clear selection

Rules:

- with one selected triad:
  - show `Try It Out`
  - show `Add to Working On`
  - do not show `Remove from Working On`
- with more than one selected triad:
  - show `Try It Out`
  - route that action to flow practice
  - show `Add to Working On`
  - do not show `Open Item`
  - do not show `Remove from Working On`
- `Add to Working On` must not silently create or persist a new item
- Matrix `Try It Out` should convert the current triad selection into a generic ephemeral pattern item before opening Practice Session
- Matrix `Add to Working On` should convert the current triad selection into a generic authored pattern item immediately; no downstream screen should depend on combo metadata to understand that phrase
- base sticking alone is not the unique identity of saved work
- a practice item's identity is the item record itself, including its owned notes and authored state
- exact authored duplicates should resolve to the existing saved item only when the user is explicitly saving or duplicating a new item on purpose
- for an existing item or saved phrase, `Add to Working On` should prompt the user to open that item instead of creating a duplicate of the same authored item
- for a new phrase, `Add to Working On` should open `Practice Item` as a draft authoring handoff
- top-level new-item authoring should not begin in Matrix
- Matrix may still create a draft authoring handoff when the user explicitly builds from triad selection, but that is a helper flow rather than the primary `New` path
- when Matrix is entered from `Practice Item`, the primary return action should return the updated structure to the same editing flow instead of adding, saving, or opening a separate item

### Matrix States

#### Browse State

Show:

- filters
- grid
- optional context text

Hide:

- phrase editor
- action row

#### Build/Helper State

Show:

- filters
- grid
- phrase editor
- action row

Rules:

- this state exists for triad selection and triad-based structure editing
- it is not the primary generic new-item builder for the app
- when it creates new material, it should hand off to `Practice Item` as the universal authoring surface

#### Deep-Link State

Show:

- same as browse or build
- incoming filter context applied

### Matrix Wording Rules

- top-level Matrix controls must use concrete drummer-facing language
- context text must explain the current slice
- context text must not sound like Coach
- action labels must stay imperative and short
- Matrix must not expose abstract pedagogy labels as primary controls
- Matrix should prefer compact horizontal control groupings before adding more stacked rows

---

## 3. Practice

### Screen Job

Practice answers:

- how do I start right now
- what source do I want to practice from

### Allowed Content

- direct-entry cards or rows
- recent/last-session actions
- working-set launch actions
- warmup action

### Forbidden Content

- large analytics
- coaching copy
- item-edit controls
- matrix-like filtering

### Required Entry Options

- `Repeat a Previous Session`
- `Choose Patterns to Practice`
- `Warm Up`

Optional later:

- `Choose From Recent`
- `Choose From Matrix`

### Direct-Entry Rules

- this screen must exist as a primary tab
- each entry option must clearly indicate what session source it uses
- this screen should reduce choice friction, not add setup friction
- `Guided` should be the default emphasis inside Practice, not a replacement for Practice setup
- the player may still manually narrow or customize the session inside the current setup flow
- this does not create a separate user-facing `Advanced Mode` unless a later contract explicitly adds one
- `Choose Patterns to Practice` is the entry into normal tracked practice
- `From Working On` belongs inside `Choose Patterns to Practice`, not as a separate peer card
- if a direct-entry Practice source is unavailable, its entry tile should stay informative and should offer the next valid action instead of rendering as a dead disabled block
- single-item practice should use saved BPM and duration defaults without storing them as authored notation/item data
- `Warm Up` remains separate because it is a distinct prep mode, not a slice of current work
- `Repeat a Previous Session` should open a recent-session browser, not silently assume the last session is the right one
- `Practice` should not contain helper navigation actions that bounce the user sideways into `Focus`

### Session Setup From `Working On`

Must allow:

- practicing all of `Working On`
- narrowing `Working On` into a smaller session slice
- selecting exact items for today's session
- starting the session from that chosen slice

Rules:

- `Working On` is the pool
- session setup is the slice
- the player should load selected items in the order the user selected them, not re-sort them by their position in `Working On`
- ideal session scope is `1-4` items
- `5-6` items is allowed but should trigger soft guidance
- guidance should be advisory, not blocking
- preferred soft guardrail copy:
  - `This is a big session. Pick 3 or 4 if you want cleaner reps.`
- the setup surface may also advise when the actively trained rotation has grown too wide
- active-rotation guidance should treat roughly `4-8` actively pushed items as the normal zone
- if the current action selects every item in the visible filtered slice, the label should be `Select All`
- selection actions like `Select All` and `Clear` are not filters and should live in their own labeled `Actions` row
- when the player has already selected one or more items, the start-practice action should appear in that same `Actions` row instead of sitting as a separate bottom button
- `From Working On` should not expose a `Mode` toggle such as `One Surface / Flow`
- session display mode should be derived from the selected items:
  - if every selected item has authored flow voices, launch with the flow voice row visible
  - otherwise use the baseline single-surface display
- when recent active rotation grows beyond that, the app may advise shrinking the core rotation, but must not hard-block it
- long visible item lists should default to 5 rows and use `Show More` for the rest
- per-pattern BPM and duration do not belong on this list-based setup surface
- `visible` counts should not be surfaced here unless they change a decision the user can make

### Category And Filter Derivation For `From Working On`

Rules:

- categories must be derived from actual item properties and recent progress state
- categories must help the player define a practice day or session scope
- categories must not be abstract pedagogy buckets

Good derived filters:

- `Hands Only`
- `Has Kick`
- `Flow`
- `Flow Ready`
- `Needs Work`
- `Active`
- `Strong Review`
- `Right Lead`
- `Left Lead`
- `Doubles`

Guidance:

- these filters are for session slicing, not for redefining the meaning of `Working On`
- a player may keep a broad `Working On` list while using tight session slices like:
  - doubles day
  - kick day
  - flow day
  - cleanup day

### Previous Session Browser

Must allow:

- browsing a short recent list first
- searching previous sessions by practiced pattern
- seeing date, duration, mode, and practiced patterns on each row
- loading more rows
- quickly repeating a chosen previous session

Rules:

- this is a recognition flow, not a memory test
- rows must show enough pattern detail that the player can tell sessions apart
- search should work alongside the recent list, not replace it

### Practice Wording Rules

- no teaching prose here
- no “why this matters” cards
- just clear launch choices

---

## 4. Practice Session

### Screen Job

Practice Session is execution only.

### Allowed Content

- notation
- repeat marker
- timer
- BPM
- BPM tick ring
- click toggle
- pulse toggle
- play/pause
- prev/next when source has multiple items
- end control

### Forbidden Content

- coaching cards
- item management
- matrix controls
- progress explanation
- large setup panels

### Required Regions

1. player header / stepper
2. notation block
3. pulse / click / BPM / timer transport
4. end control

### Player Display Rules

- the player should read like an execution instrument, not a settings form
- the default stopped Practice Session layout should remain the established non-focus layout
- focus mode should apply only while the player is running and should return to the default stopped layout on pause or end
- when `Play` is pressed, the session header and phone bottom nav should fade/collapse out while the player region expands into the reclaimed space
- when `Pause` is pressed, the same transition should reverse smoothly back to the default session layout
- it is acceptable for focus mode to use a distinct running layout as long as the transition feels continuous and the default stopped layout is left intact
- focus-mode transition timing should stay subtle and smooth, around `280–340ms`, with no bouncy or playful motion
- focus-mode transitions should read as regions sliding and settling into place, not as a flip, pop, or abrupt subtree swap
- pattern, gauge, and timer should keep their visual anchor during the transition and must not jump abruptly
- the gauge may grow slightly in focus mode, but it should still feel anchored inside the same player card
- Practice Session utility controls should live in a settings modal opened from the header-right settings icon rather than in a persistent utility card
- that settings modal should own BPM, click, pulse, and pattern-highlighting controls
- BPM should sit inside an integrated circular display when the full player treatment is shown
- the BPM core should read as a three-part stack: BPM core, inner solid pulse ring, outer tick gauge
- the inner pulse ring and outer tick gauge must be visually separated by a small clear gap
- the pulse display should use a solid inner ring around the BPM core
- the outer tick gauge should remain visually static apart from cycle-progress color change and must not flash on the beat
- tick-ring treatment should represent cycle progress, not a separate beat engine
- gauge ticks should render as clean rectangular marks with squared ends, not rounded hand-drawn strokes
- completed gauge ticks should use one green progression color as the session advances
- inactive gauge ticks should remain neutral
- gauge tick color should communicate cycle completion progress, not rep quality
- minor-tick density should be defined by physical spacing, not a fixed count: the gap between two minor ticks should equal one minor-tick width regardless of gauge size
- major tick count should represent the current pattern cycle target, not the total multi-pattern session span
- major ticks should turn green in sync with the current cycle timer rather than lagging behind it
- overall gauge tick density should stay visually consistent across durations; shorter targets should change major tick placement, not make the whole ring sparse
- major ticks may use a stronger contrast color than minor ticks so the interval structure remains readable at a glance
- major ticks may use a light high-contrast treatment relative to minor ticks so the interval structure remains readable at a glance
- when the outer gauge uses major and minor ticks, the visual distinction should come mainly from thickness and weight rather than much longer major marks
- decorative player visuals must remain subordinate to synchronization and readability
- if tick-ring treatment and synchronization conflict, the player must keep the simpler synchronized behavior and reduce decoration
- session credit or rep credit may appear in the player as a passive display surface, not as a transport action
- earned reps in the player should be a passive display, not a button
- the earned-reps readout should render as a passive pill and should read `N Reps Earned`
- MVP earned-rep rule: `1 rep = 60 seconds` of active tracked practice time
- earned reps should update as tracked active time crosses each 60-second threshold
- paused time does not earn reps
- warmup and Matrix `Try It Out` preview sessions do not earn reps
- multi-item tracked sessions may earn reps across the session, but rep credit should only be claimable for patterns that were actually practiced

### Warmup Mode Rules

- title changes to warmup
- rudiment label visible
- use `End` for the warmup exit control
- warmup is not logged
- warmup is entered from `Practice` only
- warmup is not launched from inside an active session
- manual prev/next in warmup should change the visible exercise without rewriting the deck timer elapsed value

### Normal Session Rules

- target reached may cue, but not force-end
- reaching target duration must not silently stop the session
- `End` leads to summary
- in multi-item sessions, BPM is per-item runtime state
- in multi-item tracked sessions, the target duration applies per current pattern rather than once across the whole slice
- in single-pattern tracked practice, reaching the target duration should chime and restart the gauge cycle while total elapsed time keeps running
- in multi-item tracked practice, reaching the current pattern's target duration should chime and automatically move to the next pattern
- when auto-forward moves to the next pattern, the player should stay running and carry straight into that next pattern's timing state
- after the final pattern reaches its target duration, the player should chime, wrap back to the first pattern, and continue running with total elapsed time preserved
- in multi-item tracked practice, each current pattern should use its own saved launch duration when available rather than one shared slice-wide timer preset
- changing BPM during a multi-item session must apply to the currently shown item only
- when the player moves between items, the item's current runtime BPM must be restored
- Practice Session stepping/highlighting should operate over canonical token positions rather than triad chunks or family-specific groupings
- rest/pause tokens should consume one full timed slot in Practice Session and should participate in player stepping/highlighting exactly like note positions
- audible pattern playback should be driven by canonical token positions plus timing metadata
- audible pattern playback should remain optional and must not change timer flow, earned-rep logic, or session completion behavior when enabled
- the pattern-audio toggle should live directly beneath the notation readout as a dedicated ear button, not in the settings modal
- when the ear toggle is turned on, the current pattern should begin sounding immediately and continue looping until the ear toggle is turned off
- pattern highlighting should use the same switch treatment and settings location as click and pulse, not a separate notation-row button
- grouping may supply a default simple timing interpretation for straightforward drills, but explicit timing metadata must be able to override grouping cleanly for advanced phrases or fills without creating a new runtime mode
- default simple timing interpretation:
  - compatible grouping size -> one grouping per beat
  - otherwise -> one token per beat
- in a multi-item session, only patterns that were actually practiced should be recorded into the completed tracked session
- viewing a pattern without playing it should not make it part of the tracked assessed set
- when a tracked multi-item session ends, Session Summary should open on the first practiced pattern

### Control Rules

- prev/next appears only for multi-item sources
- notation is the primary visual signal
- pulse/click/BPM/timer support the playing, not the screen narrative
- the metronome engine should be the source of truth for beat phase when click playback is active
- pulse timing should derive from the native audio playback phase when the native metronome is running, not from a separate beat-event timer or an independent Dart beat clock
- once native beat onset is detected, the visual pulse may stay on briefly for readability, but beat onset itself must still come from the native playback phase
- pulse animation should be local to the pulse widget and should not require rebuilding the whole player on every beat
- pulse animation should stay restrained and should not visually overpower the notation or timer
- if pulse timing clarity is at risk, prefer a simple synchronized flash over decorative animation
- when pulse synchronization is under verification, use a plain border on/off effect rather than glow, easing, or expanding-band treatments
- once synchronization is solid, the pulse may add a few static concentric rings inside the main circle during the flash window, but those rings must be driven by the same on/off beat state rather than their own animation timeline
- any tick-ring or segmented pulse treatment must still be driven by the same synchronized beat state rather than a separate animation clock
- click playback should use a preloaded low-latency one-shot trigger path rather than repeatedly retriggering one media player instance
- the player must not contain controls that switch the session into a different source type
- default stopped transport state should present `Play` and `End`
- running transport state should present `Pause` and `Reset`
- for normal tracked sessions, `End` should not appear alongside `Pause` and `Reset` in the running transport row
- `End` should stay disabled until the session has actually started and session data exists
- transport buttons shown together should use the same height and visual weight
- peer transport buttons shown together should use consistent icon treatment

---

## 5. Session Summary

### Screen Job

Session Summary closes a tracked session and collects limited useful feedback.

Early-exit rule:

- if a tracked session ends with zero earned reps, skip Session Summary and return directly to `Practice`

### Allowed Content

- practiced item/pattern
- duration
- BPM
- session check
- conditional tempo check when BPM changed during the session
- next-step recommendation after meaningful assessment input exists
- practice again
- prev/next when the session includes multiple assessed items

### Forbidden Content

- warmup summary
- long analytics
- multiple unrelated CTAs
- work-management actions like `Add to Working On`
- session-level metadata that confuses the currently assessed item
- low-value detail like click state when it does not change the next decision
- inert buttons with no effect

### Required Controls

- session check choices
- `Practice Again`
- close/back
- `Submit`
- `Skip`

### Rules

- one summary per tracked session
- multi-item sessions must allow the user to navigate and assess each item individually inside the same summary flow
- Session Summary remains the main assessment surface
- `Claim Your Work` is an extension of assessment, not a replacement for existing self-report assessment
- rep credit may serve both as motivational feedback and as claimed-work data that feeds the app's progress logic
- a rep-credit/claim layer must not silently remove or overwrite the existing self-report assessment layer unless a later contract explicitly replaces it
- earned reps should be presented as claimed work, not inferred mastery
- Session Summary may ask whether the student wants to keep the earned reps from the session or current practiced item
- earned-rep claim should stay local until `Submit`, so the player can still change their mind before finalizing that assessment
- Session Summary must not assume `new to the app` means `new to the skill`
- in early or no-history assessment, attempted BPM should carry real weight as a current-skill calibration signal
- BPM weighting should be scaled by pattern complexity
- simpler patterns may earn stronger positive recommendation language at higher BPM even without app history
- strongly positive self-assessment should not fall through to a generic discouraging message only because BPM changed during the session
- when BPM changed, the recommendation message and the BPM save decision should be treated as separate concerns
- if self-assessment is mixed but BPM is strong for the pattern type, the message should read as calibration or edge-work, not failure
- each item in a multi-item session should have its own assessment state for that session
- Session Summary should only include patterns that were actually practiced in that session
- assessment choices should stay local to the current rep until the user presses `Submit`
- each practiced pattern should have its own explicit `Submit` action
- each practiced pattern should also allow `Skip` so the user can leave that rep unassessed
- recommendation copy should respond to both control and tension, not only one of them
- wording must stay action-oriented
- top metadata should describe the assessed item and the session clearly without mixing item-level and session-level labels in misleading ways
- if BPM did not change during the session, the summary should not ask a tempo question
- if BPM did change for the current item during the session, the summary should offer one explicit BPM save choice for that current item
- the BPM save choice should live inside the BPM sub-card, not as a separate detached action
- the BPM save card should remain visible after it is checked so the saved decision stays legible
- BPM save copy should name both the starting and ending BPM values
- BPM save choice should stay local until `Submit`, so the user can still change their mind before submitting the rep
- recommendation copy should not duplicate the instructional text already visible above the controls
- if session BPM differs from the item's saved practice BPM, Session Summary should offer a way to save the BPM back to that current item
- session completion itself must not silently overwrite the item's saved practice BPM
- back navigation from Session Summary should return to the player screen for that session
- back navigation from the player should return to Practice
- the final completion action should be labeled `Submit`
- `Practice Again` should remain a stable replay action, not change label by recommendation state

---

## 6. Library

### Screen Job

Library is the current working set and searchable working library.

### Allowed Content

- current items list
- search field
- derived item filter if it serves item selection
- add entry point
- play/edit/remove controls

### Forbidden Content

- milestone cards
- near-toolbox cards
- progress summaries
- teacher guidance blocks

### Required Per-Item Controls

- play
- edit
- remove

### Optional Controls

- reorder
- mode filter
- search results

### Empty State

Must show:

- what Library is for
- where items come from

Must not show:

- fake stats
- long philosophy copy

### Library Rules

- `Working On` may be broader than today's session scope
- Library must not imply that every item in the list should be practiced in one sitting
- `Working On` is for active development
- `Maintain` is a separate bucket for refresh and retention of already-strong material
- Practice session setup is where the player chooses today's slice
- search on this screen should look across all practice items, not only items already in `Working On`
- search results that are not in `Working On` should support add/open behavior
- search results that are already in `Working On` should use the normal current-work controls
- filter state must always have an explicit `All` path or equivalent clear state
- long visible item lists should default to 5 rows and use `Show More` for the rest
- do not repeat the screen title inside a second hero/card heading when no new information is added
- this screen should default to less verbose presentation
- if explanatory/help content is needed, it should live in optional help, not as a permanent top card
- the add entry point may sit inline with search as a compact `New` / `+` control
- `New` from Library should open a new `Practice Item` draft rather than opening Matrix directly
- that draft should start as a blank generic token-sequence item and expose triad insertion as a helper from inside the editor
- flow voice assignments remain user-authored item data and must not add extra list-level per-item launch buttons
- any `Flow` filter on this screen must be derived from authored off-snare voices on non-kick notes
- `Single Surface` may appear as a derived list filter and must mean the item has no authored off-snare voices on non-kick notes
- do not present `Single Surface / Flow` as an authored item mode toggle; they are derived list states
- per-item play controls should use a neutral `Practice` label/tooltip and derive voice display from the item data rather than exposing `Practice on One Surface`
- removing an item from this screen should confirm first and show the item's notation in the confirmation

---

## 7. Progress

### Screen Job

Progress measures development.

### Allowed Content

- overview metrics
- charts
- item-level progress rows
- item-level graph panels
- grouped/category summaries
- filters for scope and time

### Forbidden Content

- Coach cards
- teacher guidance
- internal status explanations
- current-work CRUD

### Required Views

#### Overview

- total time
- recent trend
- overall coverage
- rolled-up assessment graph
- graph scope must be explicit
- time-based bar graphs should make the unit explicit, not leave raw numbers floating without context

#### By Item

- item progress state
- time logged
- recent work
- selected-item assessment graph
- selected-item BPM graph
- selected-item session-time graph
- graph labels must read in the correct improvement order

#### By Group

- hands-only vs kick
- right-lead vs left-lead
- later phrase/flow groupings

#### Trend

- time over time

### Metric Rules

- every metric label must match the scope it counts
- visible counts must never surprise the user because of hidden scope
- if the count includes more than Focus items, the label must make that clear
- use clear measurement phrasing over slash shorthand when slash notation creates ambiguity

### Progress Wording Rules

- use measurement language
- avoid recommendation language
- avoid system explanation language
- chart titles must say what is being measured and over what time window

Bad example:

- `This is the same status language used by Coach and Matrix`

Good example:

- `29 tracked items`
- `12 active this month`

Only if those counts are actually correct for the visible scope.

### Progress Graph Rules

- rolled-up graphs must visibly communicate status differences, not just technically encode them
- if a status-mix graph is shown, the status colors must be visually distinct at a glance
- stacked status graphs must render visible colored segments, not pale empty containers
- chart geometry should support comparison before decoration
- vertical comparison bar graphs should use flat bottoms with only modest top-corner rounding, not pill/capsule silhouettes
- non-stacked bar graphs should use a lighter fill with a darker border instead of a heavy dark fill
- graph legends must read as legends, not as extra filters

### Coverage Snapshot Rules

- coverage wording should use plain language like `covered` or `practiced`, not vague terms like `seen`
- `seen` should not appear as active app language for progress or coverage
- coverage values should read clearly without forcing the user to decode slash notation or awkward shorthand
- when the row label already carries the category meaning, the value column should stay numeric rather than repeating words like `covered`

---

## 8. Practice Item

### Screen Job

Practice Item lets the user inspect and edit one item cleanly.

### Allowed Content

- pattern display
- concise work summary
- accent/ghost controls
- flow voice controls
- session setup controls for BPM and duration
- open in matrix CTA

### Forbidden Content

- player transport
- redundant pattern chips repeating the same value
- extra badges that restate obvious information

### Required Control Rules

- editing controls appear under the pattern
- mode control changes editing context
- tapping the notation selects one or more assignable notes
- selection and assignment are separate actions
- `Accents & Ghosts` assigns the marking for the selected note set
- `Flow Voices` assigns the voice for the selected note set
- practice default controls may live here even though session launch happens elsewhere
- last BPM and duration for a single item should be remembered outside the authored item data
- Practice Item owns its notes as part of the authored item record
- accents, ghosts, and flow voice assignments are user-authored edit layers
- base material enters the app plain unless the user has explicitly edited it
- no voice assignments and all-default voices must collapse to the same single-surface state
- voice displays outside the editor should only appear when the item has authored off-snare voices on non-kick notes
- Practice Item should have one primary notation block at the top of the screen
- when flow voices exist, that top block should become the unified two-row pattern/voice display
- the `Flow Voices` section should contain voice editing controls only, not a second notation preview
- rest positions should keep `_` as the canonical stored token but render as `•` in user-facing notation
- `Practice Item` may wrap the shared notation renderer with selection affordances, but it should not introduce a separate notation rendering style
- the `Practice Item` selection wrapper may add only a small tap-target halo around each rendered note; it must not widen note slots or separator spacing into a second independent layout model
- any `Practice Item` note-selection wrapper must derive its slot and separator measurements from the shared renderer geometry rather than fixed local spacing constants
- the notation block should be the note-selection surface, so the screen does not need a per-note chip grid for editing
- `Practice Item` should also contain a `Pattern Structure` section for direct token-sequence editing
- `Practice Item` should contain an explicit `Grouping` control for visible separator metadata
- a new blank `Practice Item` draft should open with a stable empty notation row already visible so the layout does not jump on first insertion
- when entering voice editing, effective default voices remain `snare` for hand notes and `kick` for `K` notes unless the user assigns something else
- selection should toggle on tap so the user can build or reduce a note set before applying an edit
- applying a marking or voice assignment should clear the current note selection
- kick notes should not be assignable through this editing surface
- non-hand positions may still be selected for structure editing even though they are not assignable through the dynamics/voice controls
- structure editing should support replace, insert, delete, rest insertion, and triad-helper insertion inside the same `Practice Item` surface
- triad-helper insertion should allow selecting one or more triads and should insert them in the order selected
- the `Grouping` control should affect only visible separator metadata, not runtime behavior or family labels
- the `Grouping` control should expose only group sizes compatible with the current token count, plus `None`
- deleting the entire current token sequence should be allowed and should return the draft to that stable empty-row state
- when direct structure edits break an inherited grouping shape, the stale grouping hint should clear instead of continuing to render separators that no longer fit the edited pattern
- triad-helper insertion inside `Practice Item` should use the same shared triad-grid rendering language as Matrix, even if the insert modal or sheet carries a reduced control set
- triad-helper insertion should establish explicit triad grouping metadata when the resulting draft is fully triad-grouped and contains no rests
- Matrix selection and phrase building must not inject authored markings automatically
- item edits should live in a local draft until the user explicitly saves them
- navigating away with unsaved item changes should prompt the user to save, discard, or keep editing
- normal editing must not silently split one item into a hidden base item plus authored variant
- `Open in Matrix` must reuse the Matrix screen in an item-edit context when the material can be expressed as a triad or triad phrase
- any generic item whose current canonical token sequence can be losslessly split into triads may still use `Open in Matrix`; this should be based on the token sequence, not only on combo metadata
- in that context, Matrix should preload the current sequence from the authored item draft, preserve the authored item state through the round trip, and replace `Add to Working On` with a return action back to `Working On`
- `Open in Matrix` must treat the current `Practice Item` draft as authoritative; it must not render the phrase from global child-triad state if that would scramble or replace authored markings or voices
- unsaved phrase drafts may still reopen Matrix for structure edits; `Open in Matrix` should not be disabled solely because the item has not been saved to `Working On` yet
- adding a triad in Matrix should append a new segment with that triad's structural/default template data, while existing segments retain their current authored notes, markings, and voices
- removing a triad in Matrix should remove that occurrence and its attached authored segment data
- when Matrix editing expands a single triad into a phrase, returning should continue in `Practice Item` on the resulting phrase item instead of silently keeping the old single-triad item
- `Practice Item` should not offer direct practice-launch buttons when that pulls the screen away from its editing job
- `Practice Item` is the primary screen for creating a new pattern from scratch
- Matrix is not the default place to start generic pattern creation; it remains a triad-specific teaching, discovery, insertion, and triad-structure-editing helper

---

## 9. Editable Screen Save Rule

Editable screens should not auto-save field-level changes while the user is still editing.

This applies to screens like:

- `Practice Item`
- `Settings`
- `Custom Pattern`

Rules:

- edits should stay local to the screen until the user explicitly saves
- leaving a dirty screen should trigger an unsaved-changes prompt
- the prompt should offer:
  - save
  - discard
  - keep editing
- the unsaved-changes prompt should use the app's own paper/surface motif, not a default tinted dialog color that feels foreign to the rest of the app
- all popup dialogs should use the app's own paper/surface motif, border, and button styling instead of default tinted Material dialog treatment
- screens that are already explicit-save screens must still guard against losing unsaved edits on back navigation

---

## Shared Control Contract

### A control is valid only if:

1. it serves a defined flow
2. it belongs to the screen’s job
3. it uses the correct scope
4. it does not duplicate another control’s job

### Repeated signal rule

Do not show the same information twice in different forms unless the second form adds meaning.

Examples of bad repetition:

- notation line plus chip with the same pattern
- status text plus explanation card explaining that same status
- card title plus chip repeating the same lane with no action

---

## Rebuild Acceptance Checklist

Before a rebuilt screen is accepted:

1. every visible block must map to a flow in this document
2. every visible control must map to a flow in this document
3. forbidden content must be absent
4. wording must match the screen job
5. the screen must be tested against the mock scenarios in:
   [11_SCREEN_STATE_AND_MOCK_SCENARIOS.md](/Users/terryknoblock/Development/flutter-projects/traid_trainer/docs/11_SCREEN_STATE_AND_MOCK_SCENARIOS.md)

If a block cannot survive this checklist, remove it.
