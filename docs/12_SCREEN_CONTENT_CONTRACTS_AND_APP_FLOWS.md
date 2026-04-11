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

## Layout Rule

Use horizontal space before adding more vertical stacking.

Interpretation:

- vertical space is for sequence, reading flow, and truly primary sections
- horizontal space is for comparison, compact controls, metrics, legends, and summaries
- avoid turning short values or short explanations into full-height stacked cards when they can sit side by side
- when a screen feels tall before it feels clear, the layout is probably wrong
- charts and summaries should prefer row-based composition when the viewport allows it

## Control Affordance Rule

Interactive controls must look interactive without helper text.

Rules:

- buttons must have a visible container, border, fill, or elevation separation from their background
- text alone is not enough to signal a button
- primary and secondary actions must remain visually distinct on both light and dark surfaces
- if a surface is dark or visually busy, action controls must use stronger contrast and edge definition than they use on light surfaces
- the user should not have to tap to discover whether a label is actionable

---

## Primary App Flows

### Flow A: First Light Start

Goal:

- help a new user start correctly without wandering

Path:

1. `Coach`
2. `Add to Working On` or `Open Matrix`
3. `Focus` or `Matrix`
4. `Practice`

Screens involved:

- Coach
- Focus
- Matrix
- Practice

Required controls:

- Coach starter CTA
- Matrix open CTA
- Focus item play CTA
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
- `Repeat a Previous Session` should browse recent sessions, not only repeat the single most recent one
- previous-session rows must show enough session content to be recognizable, including the patterns practiced
- previous-session browsing may start short and offer `Load More`

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

### Flow D: Matrix Discovery And Phrase Building

Goal:

- browse the triad system
- isolate slices
- build phrases

Path:

1. `Matrix`
2. filters / selections
3. phrase editor
4. `Practice`, `Add to Working On`, or `Save Phrase`

Screens involved:

- Matrix
- Practice Session
- Focus optionally

Required controls:

- view/filter controls
- phrase editor
- action pills

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

1. `Practice Item` or `Matrix`
2. adjust voice assignments if needed
3. `Practice in Flow` when the item has authored off-snare voices on non-kick notes
4. `Practice Session`

Screens involved:

- Practice Item
- Matrix
- Practice Session

Required controls:

- voice assignment editor in Practice Item
- `Practice in Flow` CTA

Rules:

- `Flow` is a derived practice capability, not a user-declared item type
- an item is considered `Flow` only when it has user-authored off-snare voices on non-kick notes
- no voice assignments and all-default voices are the same single-surface state
- default kick placement on `K` does not make an item `Flow`
- `Single Surface` is the universal baseline practice mode, not an item classification

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

- what should I do next
- why now
- what is the shortest useful path into practice

### Allowed Content

- 1 to 3 action cards
- short evidence lines
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

- `Getting Started`
- `Start Here`
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

### Forbidden Wording

- `baseline`
- `signal`
- `active work`
- `status language`
- `this view shows`
- `reference point`
- robotic diagnostic phrases like `the weak spot is`
- visible category labels that read like framework buckets

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

Hide:

- needs work
- momentum
- next unlock

#### Starter Items Selected, No Sessions

Show:

- one `Start Here` card

Hide:

- momentum
- progress-like summaries

#### Early Struggle

Show:

- `Focus`
- `Needs Work`

#### Steady Progress

Show:

- `Focus`
- `Needs Work`
- `Momentum`

#### Phrase Ready

Show:

- `Focus`
- `Momentum`
- `Next Unlock`

#### Flow Ready

Show:

- `Momentum`
- `Next Unlock`

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
  - `Traits`
  - `Progress`
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

- `Traits` view:
  - `Right`
  - `Left`
  - `Hands Only`
  - `Has Kick`
  - `Starts w/ Kick`
  - `Ends w/ Kick`
  - `Doubles`
- `Progress` view:
  - `Not Practiced`
  - `Active`
  - `Needs Work`
  - `Strong`
  - optional secondary:
    - `Working On`
    - `In Phrases`
    - `Recent`

#### Phrase Editor

Serve:

- Flow D

Rules:

- a single selected triad is direct item selection
- selecting a second triad turns the editor into phrase-building mode
- shows exact ordered sequence
- owns exact occurrence removal
- grid reflects membership only
- additional triads may be added freely while building a phrase
- if a phrase includes triads that are not ready, Matrix should show inline guidance instead of blocking selection
- adding material from Matrix must not inject accents, ghosts, or flow voices automatically
- phrase-building mode defaults to flow-oriented practice actions

#### Action Row

Serve:

- direct practice
- add to Working On
- open selected item when one triad is selected
- save phrase when multiple triads are selected
- clear selection

Rules:

- with one selected triad:
  - show `Practice`
  - show `Add to Working On`
  - show `Open Item`
  - do not show `Remove from Working On`
- with more than one selected triad:
  - show `Practice`
  - route that action to flow practice
  - show `Add to Working On`
  - show `Save`
  - do not show `Open Item`
  - do not show `Remove from Working On`
- `Add to Working On` must not silently create or persist a new item
- for an existing item or saved phrase, `Add to Working On` should prompt the user to open that item instead of creating a duplicate
- for a new phrase, `Add to Working On` should open `Practice Item` as a draft authoring handoff

### Matrix States

#### Browse State

Show:

- filters
- grid
- optional context text

Hide:

- phrase editor
- action row

#### Build State

Show:

- filters
- grid
- phrase editor
- action row

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
- `Choose Patterns to Practice` is the entry into normal tracked practice
- `From Working On` belongs inside `Choose Patterns to Practice`, not as a separate peer card
- single-item practice should remember the last BPM and duration used for that item without storing them as authored item data
- `Warm Up` remains separate because it is a distinct prep mode, not a slice of current work
- `Repeat a Previous Session` should open a recent-session browser, not silently assume the last session is the right one

### Session Setup From `Working On`

Must allow:

- practicing all of `Working On`
- narrowing `Working On` into a smaller session slice
- selecting exact items for today's session
- starting the session from that chosen slice

Rules:

- `Working On` is the pool
- session setup is the slice
- ideal session scope is `1-4` items
- `5-6` items is allowed but should trigger soft guidance
- guidance should be advisory, not blocking
- preferred soft guardrail copy:
  - `This is a big session. Pick 3 or 4 if you want cleaner reps.`
- the setup surface may also advise when the actively trained rotation has grown too wide
- active-rotation guidance should treat roughly `4-8` actively pushed items as the normal zone
- when recent active rotation grows beyond that, the app may advise shrinking the core rotation, but must not hard-block it
- long visible item lists should default to 5 rows and use `Show More` for the rest
- per-pattern BPM and duration do not belong on this list-based setup surface

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

### Warmup Mode Rules

- title changes to warmup
- rudiment label visible
- `End Warmup` replaces `End Session`
- warmup is not logged
- warmup is entered from `Practice` only
- warmup is not launched from inside an active session

### Normal Session Rules

- target reached may cue, but not force-end
- `End Session` leads to summary

### Control Rules

- prev/next appears only for multi-item sources
- notation is the primary visual signal
- pulse/click/BPM/timer support the playing, not the screen narrative
- the player must not contain controls that switch the session into a different source type

---

## 5. Session Summary

### Screen Job

Session Summary closes a tracked session and collects limited useful feedback.

### Allowed Content

- practiced item/pattern
- duration
- BPM
- mode
- family
- session check
- next-step recommendation
- practice again

### Forbidden Content

- warmup summary
- long analytics
- multiple unrelated CTAs

### Required Controls

- session check choices
- `Practice Again`
- close/back

### Rules

- one summary per tracked session
- one assessment target item per session summary
- wording must stay action-oriented

---

## 6. Focus

### Screen Job

Focus is the current working set.

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

- what Focus is for
- where items come from

Must not show:

- fake stats
- long philosophy copy

### Focus Rules

- `Working On` may be broader than today's session scope
- Focus must not imply that every item in the list should be practiced in one sitting
- Focus is where current material is maintained
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
- flow voice assignments remain user-authored item data and must not add extra list-level per-item launch buttons
- any `Flow` filter on this screen must be derived from authored off-snare voices on non-kick notes
- `Single Surface` may appear as a derived list filter and must mean the item has no authored off-snare voices on non-kick notes
- do not present `Single Surface / Flow` as an authored item mode toggle; they are derived list states

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
- chart geometry should support comparison before decoration
- prefer flatter bar bases over capsule shapes when the chart is about magnitude comparison
- graph legends must read as legends, not as extra filters

---

## 8. Practice Item

### Screen Job

Practice Item lets the user inspect and edit one item cleanly.

### Allowed Content

- pattern display
- assessment/competency summary
- accent/ghost controls
- flow voice controls
- `Practice on One Surface`
- `Practice in Flow` when the item has authored off-snare voices on non-kick notes
- session setup controls for BPM and duration
- practice CTA
- open in matrix CTA

### Forbidden Content

- player transport
- redundant pattern chips repeating the same value
- extra badges that restate obvious information

### Required Control Rules

- editing controls appear under the pattern
- mode control changes editing context
- session setup controls belong here for single-item practice
- last BPM and duration for a single item should be remembered outside the authored item data
- practice CTA launches the chosen mode
- accents, ghosts, and flow voice assignments are user-authored edit layers
- base material enters the app plain unless the user has explicitly edited it
- no voice assignments and all-default voices must collapse to the same single-surface state
- voice displays outside the editor should only appear when the item has authored off-snare voices on non-kick notes
- Matrix selection and phrase building must not inject authored markings automatically
- item edits should live in a local draft until the user explicitly saves them
- navigating away with unsaved item changes should prompt the user to save, discard, or keep editing

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
