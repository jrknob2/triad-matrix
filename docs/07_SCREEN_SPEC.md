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

Detailed content inventory, control ownership, and end-to-end flow mapping now live in:

- [12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md](/Users/terryknoblock/Development/flutter-projects/traid_trainer/docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md)

---

## Navigation Model

V1 uses a persistent shell with five primary tabs:

1. `Coach`
2. `Matrix`
3. `Practice`
4. `Focus`
5. `Progress`

Secondary routes:

- `Practice Item`
- `Session Summary`
- `Settings`

No `Practice Setup` screen exists in this model.

---

## 1. Coach

### Purpose

Coach tells the player what to do next and why.

### Must Do

- give a clear first action on first light
- respond to whether the user has selected work but not practiced yet
- point the player back to current work when momentum matters
- surface cleanup needs
- surface next-step opportunities

### Must Not Do

- act like a dashboard
- list all possible recommendations
- explain internal ranking logic
- duplicate Progress

### Primary States

#### State A: First Light

Condition:

- no meaningful practice history
- no working-set items selected

Must show:

- one getting-started card
- recommended starter triads
- `Add to Working On`
- `Open the Matrix`

#### State B: Working Set Selected, No Sessions Yet

Condition:

- Focus contains items
- no logged practice sessions yet

Must show:

- one start-here card
- clear instruction to begin first session
- direct CTA to practice current work

Must not say things like:

- `set the reference point`
- `baseline`
- `signal`

#### State C: Early Work, Still Unstable

Condition:

- some sessions logged
- little stable material

Must show:

- one or two cards max
- clear next action
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
- no internal/framework wording may appear
- no static filler cards may appear once real data exists
- the screen should feel sparse, not busy

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
- phrase editor visible above grid
- action row visible

#### State C: Deep-Linked From Coach

- specific view/filter preset already active
- context visible but lightweight

### Primary Actions

- `Single Surface`
- `Flow`
- `Add to Working On`
- `Save Phrase`
- `See Item`
- `Clear`

### Interaction Rule

The grid shows membership.  
The phrase editor shows order.

If an item appears anywhere in the phrase, its matrix cell is selected.  
Exact removal happens in the phrase editor, not inside the cell.

Matrix filters follow this structure:

- one exclusive `View`
- one contextual filter row for that view
- row and column slicers built into the grid

Coach `lane` is translated into a Matrix preset, not shown as a persistent Matrix control.

Phrase rule:

- one triad may always be selected for direct practice
- adding a second or later triad requires phrase-ready material

### Acceptance Criteria

- grid remains the dominant surface
- selected state is clear without being noisy
- progress state and filter scope are visually distinct
- deep links from Coach land in a meaningful matrix view
- invalid filter combinations are prevented by design, not explained after the fact
- compact horizontal controls are preferred before adding more stacked filter rows

---

## 3. Practice

### Purpose

Practice gives the user a direct way to start playing and then executes the session cleanly.

### Must Do

- exist as a primary tab
- support direct-entry practice choices
- support repeat-last-session
- support practice-from-Focus
- support warmup
- run the session player with minimal friction

### Must Not Do

- act like another Coach screen
- hide behind other surfaces
- overload the player with setup UI

### Primary States

#### State A: Direct Entry

Must show:

- `Repeat Last Session`
- `Practice Working On`
- `Warm Up`
- `Choose From Working On`

Optional later:

- `Recent Sessions`

#### State B: Normal Session

Must show:

- player panel
- notation
- pulse / click / BPM / timer
- prev/next when source contains multiple items
- `End Session`

#### State C: Warmup Session

Must show:

- warmup title
- current rudiment name
- notation
- pulse / click / BPM / timer
- prev/next
- `End Warmup`

Warmup rules:

- 1 minute per exercise
- continuous deck timer
- auto-advance
- untracked

### Acceptance Criteria

- user can reach practice directly from nav
- session player feels like an execution surface, not a config form
- warmup behaves like temporary prep, not core curriculum

---

## 4. Focus

### Purpose

Focus is the current working set.

### Must Do

- show the active items cleanly
- support play
- support edit/open
- support remove
- support add from Coach/Matrix

### Must Not Do

- behave like Coach
- behave like Progress
- contain internal teaching philosophy copy

### Primary States

#### State A: Empty

Must show:

- what Focus is for
- how to add items

#### State B: Active Working Set

Must show:

- current items
- simple item controls

Optional:

- section toggle between single-surface and flow-friendly items

### Per-Item Controls

- play
- edit
- remove

### Acceptance Criteria

- Focus should read as CRUD for current work
- the user should never wonder whether an item is “saved”, “mastered”, or “current”
- there should be no fake summary cards trying to turn this into a dashboard

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

---

## 6. Practice Item

### Purpose

Practice Item is the detail/edit screen for one piece of material.

### Must Do

- show the pattern clearly
- show competency/assessment summary
- allow accent/ghost editing
- allow flow voice assignment
- allow launch into `Single Surface` or `Flow`
- allow opening that item in Matrix

### Must Not Do

- duplicate session execution UI
- contain unnecessary supporting chips that repeat the visible pattern

### Acceptance Criteria

- the pattern display is the primary signal
- controls under it are clearly for editing the item, not playing it

---

## Mock-State QA Requirement

Before major UI work is considered done, each main screen must be checked against its required states using explicit mock scenarios.

No screen should be judged “done” only by looking at a happy-path live state.
