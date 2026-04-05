# 07 — Screen Spec

## Purpose

This document turns the app spec into a concrete screen map for v1.

It answers:

- what screens exist
- how they connect
- what each screen must show
- what each screen must not do

This is a wire spec, not a visual design spec.

---

## Navigation Model

V1 uses a persistent app shell with four primary tabs:

1. `Home`
2. `Library`
3. `Routine`
4. `Progress`

Full-screen routes launched from the shell:

- `Practice Setup`
- `Practice Session`
- `Session Summary`
- `Settings`
- `Combination Builder`
- `Custom Pattern Editor`
- `Item Detail`

Suggested route map:

- `/` -> `AppShell`
- `/practice/setup`
- `/practice/session`
- `/practice/summary`
- `/settings`
- `/builder/combination`
- `/editor/custom-pattern`
- `/item/:id`

---

## Screen List

### 1) App Shell

Purpose:
- provide stable top-level navigation

Persistent UI:
- top app bar
- current tab title
- settings entry point
- bottom navigation with 4 tabs

Tabs:
- `Home`
- `Library`
- `Routine`
- `Progress`

Rules:
- switching tabs must preserve tab state where practical
- `Practice Session` should not live as a tab

---

### 2) Home

Route:
- `/`

Purpose:
- start quickly
- show what matters now

Top-to-bottom wire:

1. App bar
   - title: `Triad Trainer`
   - settings icon

2. Quick start section
   - primary button: `Start Practice`
   - secondary button: `Generate For Me`
   - tertiary button: `Continue Routine`

3. Current focus section
   - heading: `Currently Working On`
   - up to 3 routine items
   - action: `View Routine`

4. Recent sessions section
   - last 3 to 5 sessions
   - each row shows:
     - item name
     - duration
     - context
     - date

5. Quick stats section
   - total time this week
   - single-surface time
   - kit time
   - triad time
   - 5-note time

Primary actions:
- `Start Practice`
- `Generate For Me`
- `Continue Routine`

Secondary actions:
- tap recent session -> open `Item Detail`
- tap focus item -> open `Item Detail`

Empty states:
- no routine -> show `Build your first routine`
- no sessions -> show `Start your first session`

Must not include:
- full generator controls
- full competency editing UI
- large analytics

---

### 3) Library

Route:
- shell tab

Purpose:
- browse all practice material

Top-to-bottom wire:

1. App bar
   - title: `Library`
   - search icon optional in v1

2. Family filter segmented control
   - `Triads`
   - `5s`
   - `Custom`
   - `Combos`

3. Optional secondary filters
   - `All`
   - `In Routine`
   - `Needs Practice`

4. Item list
   - card or list row per item
   - row fields:
     - item name or sticking
     - family badge
     - competency badge
     - total time
     - context split indicator
     - routine indicator

5. Floating or inline create actions
   - `Build Combo`
   - `New Custom Pattern`

Primary actions on item:
- tap row -> `Item Detail`
- overflow:
  - `Practice Now`
  - `Add to Routine`
  - `Rate Competency`
  - `Build Combo`
  - `Edit` for custom

Must not include:
- session transport
- long-form analytics

---

### 4) Item Detail

Route:
- `/item/:id`

Purpose:
- show one item as a first-class practice target

Applies to:
- triad
- 5-note grouping
- custom pattern
- saved combo

Top-to-bottom wire:

1. App bar
   - back
   - item name

2. Identity block
   - sticking or combination
   - family
   - source
   - tags

3. Competency block
   - current level
   - `Edit Competency`

4. Practice history block
   - total time
   - single-surface time
   - kit time
   - recent sessions count

5. Actions block
   - `Practice Now`
   - `Add to Routine` or `Remove from Routine`
   - `Build Combo`
   - `Edit` if custom

6. Optional notes block for later

Must not include:
- full routine editor
- multi-item builder UI

---

### 5) Routine

Route:
- shell tab

Purpose:
- manage active work

Top-to-bottom wire:

1. App bar
   - title: `Routine`

2. Routine header
   - current routine name
   - total items
   - quick duration summary from recent practice

3. Primary actions row
   - `Start Routine`
   - `Start Random Item`
   - `Edit Order`

4. Routine item list
   - drag handles for reorder
   - each row shows:
     - name
     - family
     - competency
     - last practiced
     - context badges if useful

5. Archived or inactive section optional later

Item actions:
- tap row -> `Item Detail`
- swipe or overflow:
  - `Practice`
  - `Remove`
  - `Archive`

Empty state:
- message explaining routine purpose
- button: `Add Items from Library`

Must not include:
- library browsing for all items

---

### 6) Progress

Route:
- shell tab

Purpose:
- show tracked development

Top-to-bottom wire:

1. App bar
   - title: `Progress`

2. Section switcher
   - `Competency`
   - `Time`
   - `Coverage`
   - `Contexts`

3. Content area depends on active section

#### Competency view

Shows:
- overall self-ranked level
- per-item competency list
- filter by family

#### Time view

Shows:
- total time this week
- total time by family
- total time by item
- recent trends if simple

#### Coverage view

Shows:
- under-practiced routine items
- items never practiced on kit
- items not practiced recently

#### Contexts view

Shows:
- single-surface time vs kit time
- core-skills time vs flow time
- family split inside each context

Actions:
- tap item row -> `Item Detail`
- edit competency from competency view

Must not include:
- session transport

---

### 7) Settings

Route:
- `/settings`

Purpose:
- global preferences

Top-to-bottom wire:

1. App bar
   - back
   - title: `Settings`

2. Player section
   - handedness
   - overall self-ranked level

3. Practice defaults section
   - default BPM
   - default timer target
   - click default

4. Flow defaults section
   - default fill length
   - landing behavior summary

5. Future section if needed
   - export/import later

Must not include:
- per-item competency editing
- practice session content

---

### 8) Practice Setup

Route:
- `/practice/setup`

Purpose:
- configure one practice session

Entry points:
- `Start Practice`
- `Generate For Me`
- `Practice Now`
- `Start Routine`

Top-to-bottom wire:

1. App bar
   - back
   - title: `Practice Setup`

2. Material source section
   - selected item summary if prefilled
   - or source selector:
     - `Library Item`
     - `Routine Item`
     - `Generated`

3. Material family section
   - `Triad`
   - `5-Note`
   - `Custom`

4. Intent section
   - `Core Skills`
   - `Flow`

5. Context section
   - `Single Surface`
   - `Kit`

6. Session controls
   - BPM
   - timer target
   - click toggle

7. Generator options
   - visible only if source is `Generated`
   - fields:
     - `Weak Items`
     - `Under-Practiced`
     - `Routine-Based`
     - combo length

8. Flow options
   - visible only if intent is `Flow`
   - fields:
     - fill length
     - landing behavior summary
     - groove frame summary

9. Primary CTA
   - `Start Session`

Rules:
- this is the only place where setup knobs belong
- if entering from a known item, prefill as much as possible

---

### 9) Practice Session

Route:
- `/practice/session`

Purpose:
- run the active practice session with minimal friction

Top-to-bottom wire:

1. App bar or minimal header
   - back only if safe
   - title may collapse to item name

2. Item identity block
   - item name
   - family
   - intent
   - context

3. Main notation block
   - sticking or sequence
   - for flow:
     - show landing marker
     - show return-to-groove marker if supported

4. Transport row
   - play / pause
   - BPM controls
   - click toggle
   - timer

5. Sequence controls if needed
   - previous
   - next
   - only for combos or routines

6. Session utility row
   - `Add to Routine`
   - `End Session`

Rules:
- no deep configuration panels
- no large analytics
- notation must remain dominant

---

### 10) Session Summary

Route:
- `/practice/summary`

Purpose:
- close the session and save useful information

Top-to-bottom wire:

1. App bar
   - close
   - title: `Session Summary`

2. Session stats block
   - practiced item(s)
   - duration
   - BPM
   - intent
   - context

3. Reflection block
   - segmented:
     - `Easy`
     - `Okay`
     - `Hard`

4. Competency prompt
   - optional:
     - `Update Competency`

5. Routine prompt
   - `Keep in Routine`
   - `Add to Routine`

6. Primary actions
   - `Done`
   - `Practice Again`

Rules:
- summary must be fast
- reflection must stay optional

---

### 11) Combination Builder

Route:
- `/builder/combination`

Purpose:
- assemble saved material into a named sequence

Top-to-bottom wire:

1. App bar
   - back
   - title: `Build Combo`

2. Combo metadata
   - name field
   - intent tag:
     - `Core Skills`
     - `Flow`
     - `Both`

3. Source picker area
   - choose from:
     - triads
     - 5-note groupings
     - custom patterns

4. Selected sequence area
   - ordered chips or list
   - remove
   - reorder
   - duplicate

5. Preview area
   - resulting sticking display

6. Primary action
   - `Save Combo`

Rules:
- builder must be explicit and ordered
- no hidden auto-generation inside a user-built combo

---

### 12) Custom Pattern Editor

Route:
- `/editor/custom-pattern`

Purpose:
- let the user define non-triad material

Top-to-bottom wire:

1. App bar
   - back
   - title: `Custom Pattern`

2. Name field

3. Pattern input field
   - sticking text

4. Metadata fields
   - tags
   - notes optional

5. Validation block
   - show if syntax is invalid

6. Primary action
   - `Save Pattern`

Rules:
- custom material must become a first-class library item

---

## Screen-to-Screen Flow Summary

### Home

- `Start Practice` -> `Practice Setup`
- `Generate For Me` -> `Practice Setup` with source=`generated`
- `Continue Routine` -> `Routine` or direct `Practice Setup`
- recent/focus item -> `Item Detail`

### Library

- item row -> `Item Detail`
- `Build Combo` -> `Combination Builder`
- `New Custom Pattern` -> `Custom Pattern Editor`

### Item Detail

- `Practice Now` -> `Practice Setup`
- `Build Combo` -> `Combination Builder`
- `Edit` -> `Custom Pattern Editor`

### Routine

- `Start Routine` -> `Practice Setup`
- item row -> `Item Detail`

### Practice Setup

- `Start Session` -> `Practice Session`

### Practice Session

- `End Session` -> `Session Summary`

### Session Summary

- `Done` -> previous shell tab or `Home`
- `Practice Again` -> `Practice Setup`

---

## V1 Guardrails

### Guardrail 1

`Practice Setup` owns configuration.
`Practice Session` owns execution.

Do not blur them.

### Guardrail 2

`Routine` is not `Favorites`.

Routine means:
- currently working on
- intentionally tracked

### Guardrail 3

`Progress` must keep competency separate from time logged.

Time is history.
Competency is self-assessment.

### Guardrail 4

`Flow` requires visible phrase closure.

If a flow session cannot show where the phrase lands, the feature is incomplete.

### Guardrail 5

Custom patterns must behave like first-class items, not hidden notes.

---

## First Wireframe Slice To Build

The recommended first end-to-end slice is:

1. `App Shell`
2. `Home`
3. `Library`
4. `Routine`
5. `Progress`
6. `Settings`
7. `Practice Setup`
8. `Practice Session`
9. `Session Summary`

The recommended second slice is:

1. `Item Detail`
2. `Combination Builder`
3. `Custom Pattern Editor`

This keeps the rebuild on a usable practice loop before adding editors and advanced builders.
