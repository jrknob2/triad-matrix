# 06 — App Spec

## Product Definition

Triad Trainer is a drummer-first practice app for building, organizing, and tracking grouping-based sticking vocabulary.

V1 starts with **triads (3-note groupings)** as the primary material, adds support for **5-note groupings**, and distinguishes between:

- **Core Skills**
  Practice for control, consistency, and internalization.
- **Flow**
  Practice for musical phrasing, fill construction, and clean return to groove.

The app is not just a generator. It is a practice system that helps the user:

- choose material
- generate material when desired
- save routines
- log practice time
- track competency
- separate single-surface practice from kit-flow practice

---

## Core Product Goals

V1 must support:

1. Tracking a drummer’s competency with triads and related material
2. Tracking time spent on individual groupings and saved combinations
3. Allowing the user to self-rank their level
4. Allowing the user to create their own combinations
5. Allowing the app to generate combinations for them
6. Differentiating between single-surface practice and kit-flow practice
7. Tracking both contexts separately
8. Supporting user-defined non-triad patterns
9. Letting the user save what they are actively working on into a routine
10. Supporting both core-skill practice and musical flow practice
11. Supporting 5-note grouping practice
12. In flow mode, resolving incomplete grouping phrases so they land back in groove cleanly

---

## Product Model

The app is organized around four concepts:

### 1) Material

What is being practiced.

- triad cell
- 5-note grouping
- saved combination
- custom pattern

### 2) Intent

Why it is being practiced.

- `core_skills`
- `flow`

### 3) Context

Where and how it is being practiced.

- `single_surface`
- `kit`

`pad + kick` is intentionally excluded from the base v1 spec unless reintroduced explicitly later.

### 4) Progress

How the app understands development.

- self-ranked competency
- logged time
- session history
- coverage by material and context

---

## Primary Navigation

V1 uses four top-level sections:

1. `Home`
2. `Library`
3. `Routine`
4. `Progress`

Additional full-screen routes:

- `Practice Setup`
- `Practice Session`
- `Session Summary`
- `Settings`
- `Combination Builder`
- `Custom Pattern Editor`

---

## Information Architecture

### Home

Purpose:
- quick start
- resume what matters now
- show current practice focus

Content:
- `Start Practice`
- `Generate For Me`
- `Continue Routine`
- current routine preview
- recent sessions
- quick stats

Quick stats include:
- total time this week
- single-surface time
- kit-flow time
- triad time
- 5-note time

### Library

Purpose:
- browse all practice material
- inspect time and competency
- start or save material

Sections:
- `Triads`
- `5s`
- `Custom`
- `Saved Combos`

Each item should expose:
- name or sticking
- material family
- self-ranked competency
- total practice time
- single-surface time
- kit time
- routine status

Item actions:
- `Practice Now`
- `Add to Routine`
- `Build Combo`
- `Edit` if custom
- `Rate Competency`

### Routine

Purpose:
- show what the user is actively working on

Capabilities:
- add/remove items
- reorder items
- start one item
- start entire routine
- archive items no longer in active work

Routine item types:
- triads
- 5-note groupings
- saved combinations
- custom patterns

### Progress

Purpose:
- separate practice history from self-assessment

Sections:
- `Competency`
- `Practice Time`
- `Coverage`
- `Contexts`

Views should support:
- by material family
- by individual item
- by routine item
- by context

Key insights:
- items practiced often but still rated low
- items rated high but rarely practiced recently
- items only practiced on single surface
- items never practiced on kit

### Settings

Purpose:
- user preferences and defaults

Fields:
- handedness
- self-ranked overall level
- available setup
- default BPM
- default timer target
- click default
- flow defaults

---

## Core User Flows

### Flow A: Quick Start Practice

1. User opens `Home`
2. Taps `Start Practice`
3. Enters `Practice Setup`
4. Chooses material, intent, context, BPM, timer, click
5. Starts session
6. Practices in `Practice Session`
7. Finishes in `Session Summary`
8. Session is logged to history and progress

### Flow B: Generate Material

1. User taps `Generate For Me`
2. Chooses:
   - material family
   - intent
   - context
   - session length
3. App generates one item or a short combination
4. User starts practice
5. User may save generated item to `Routine`

### Flow C: Build a Combination

1. User opens `Library`
2. Chooses `Build Combo`
3. In `Combination Builder`, selects ordered cells/patterns
4. Names and saves combo
5. Combo becomes a first-class practice item
6. Combo can be practiced, routed into `Routine`, and logged

### Flow D: Work a Routine

1. User opens `Routine`
2. Starts one item or all items in order
3. Practices each item
4. Session logs reflect routine membership

---

## Practice Setup Spec

The setup screen defines one practice session.

Fields:

- `Material Source`
  - library item
  - routine item
  - generated item

- `Material Family`
  - triad
  - 5-note grouping
  - custom

- `Intent`
  - core skills
  - flow

- `Context`
  - single surface
  - kit

- `BPM`
- `Timer Target`
- `Click`

Conditional fields for generated material:
- focus on weak items
- focus on under-practiced items
- material count
- use saved favorites/routine items as seed material

Conditional fields for flow:
- fill length
  - 1 beat
  - 2 beats
  - 1 bar
  - 2 bars
- landing rule
  - resolve to beat 1
- groove frame
  - fixed to 4/4 in v1
  - fixed to 16th-note grid in v1

---

## Practice Session Spec

The practice session screen must stay minimal.

Visible UI:
- current item name
- notation / sticking
- current context
- current intent
- timer
- BPM
- click toggle
- play / pause
- next / previous only if part of a saved combo or routine
- `Add to Routine` action

Not visible:
- large configuration controls
- deep analytics
- editing tools

Behavior:
- session timer starts with play
- session timer pauses with pause
- item identity must remain visible throughout the session

---

## Session Summary Spec

Shown when a session ends.

Must show:
- practiced item(s)
- total duration
- BPM used
- context
- intent

Optional reflection prompts:
- felt easy / okay / hard
- keep in routine
- update competency

Session summary should write data into:
- session log
- time totals
- recent activity

---

## Material Spec

### Triad

A 3-note grouping.

Examples:
- `RLL`
- `RLR`
- `KRL`

Triads are first-class library items.

### 5-Note Grouping

A 5-note grouping entered or selected by the user or app.

Examples:
- `RLRLK`
- `RLLRL`

5-note groupings are first-class library items.

### Saved Combination

An ordered list of materials practiced as one unit.

Examples:
- `RLL -> RRL`
- `RLRLK -> RLL`

Combinations may be:
- user-built
- app-generated

### Custom Pattern

Any non-triad pattern the user wants to define and track.

Examples:
- sticking fragments
- fill concepts
- groove-adjacent practice figures

Custom patterns must behave like first-class library items for:
- saving
- routines
- timing
- competency

---

## Combination Builder Spec

Purpose:
- let the user assemble saved practice items into named combinations

Supported source items:
- triads
- 5-note groupings
- custom patterns

Supported actions:
- add item
- remove item
- reorder item
- duplicate item
- save combo
- name combo
- tag combo as:
  - `core_skills`
  - `flow`
  - `both`

V1 rule:
- combinations are ordered and explicit
- no hidden generation happens inside a user-built combo

---

## Competency Spec

Competency is a self-assessment, not an inferred score.

### Scope

Competency can be stored at these levels:
- overall player level
- per material item
- optionally per context

V1 requirement:
- overall level
- per-item competency

Preferred scale:
- `not_started`
- `learning`
- `comfortable`
- `reliable`
- `musical`

Rules:
- competency is user-settable
- logged time does not automatically change competency
- the UI may suggest reviewing competency after sessions, but must not auto-promote

---

## Progress Spec

Progress must track both history and self-perception without conflating them.

### Required tracked values

- total time by item
- total time by material family
- total time by context
- total time by intent
- recent sessions
- per-item competency

### Required comparisons

- single surface vs kit
- core skills vs flow
- triad vs 5-note vs custom

### Helpful derived insights

- under-practiced items
- items only practiced on single surface
- items never practiced in flow
- routine items with no recent activity

---

## Generator Spec

The generator must support:

- generating practice items for core skills
- generating practice items for flow
- generating single items or short combinations

Generation inputs:
- material family
- context
- intent
- user level
- practice history
- optionally current routine

### Core Skills Generation

Goals:
- repetition
- familiarity
- control
- internalization

Traits:
- shorter phrases
- more repetition
- less orchestration complexity
- stronger use of single-surface patterns

### Flow Generation

Goals:
- musical phrasing
- fill motion
- clean return to groove

Traits:
- phrase-length awareness
- kit movement
- resolved endings

---

## Flow Resolution Spec

This is the defining rule for `flow`.

In flow mode, the app must not simply display an unresolved grouping string. It must calculate a playable phrase that closes correctly as a fill and returns to groove.

### V1 assumptions

- time signature: `4/4`
- subdivision grid: `16th notes`
- landing target: `beat 1`

### Inputs

- source grouping length
  - 3
  - 5
  - custom length if allowed later
- selected fill length
  - 1 beat
  - 2 beats
  - 1 bar
  - 2 bars
- phrase source
  - user-built
  - app-generated

### Output

A resolved flow phrase with:
- grouping sequence
- completion math
- explicit landing point
- optional return-to-groove marker

### V1 rule

If the selected grouping length does not divide evenly into the selected fill length, the app must resolve the phrase rather than leaving it musically incomplete.

This may mean:
- partial final grouping
- appended resolution figure
- phrase truncation to reach the landing cleanly

The app should make the landing visible in the notation.

### V1 guardrail

Prefer simple, drummer-readable resolutions over mathematically clever ones.

---

## Context Rules

### Single Surface

Used for:
- core control
- repetition
- sticking familiarity

Characteristics:
- no orchestration requirement
- no kit movement requirement

### Kit

Used for:
- movement
- fill phrasing
- flow

Characteristics:
- visible orchestration
- phrase direction
- flow resolution

The app must track these contexts separately for time and progress.

---

## Data Model Summary

Suggested core records:

### UserProfile

- handedness
- selfRank
- defaultBpm
- defaultTimerTarget
- clickEnabledByDefault

### PracticeItem

- id
- family
- name
- sticking
- source
- tags
- saved

### Combination

- id
- name
- itemIds
- intentTag

### Routine

- id
- name
- itemIds

### SessionLog

- id
- startedAt
- endedAt
- duration
- practiceItemIds
- context
- intent
- bpm
- clickEnabled
- routineId optional

### CompetencyRecord

- practiceItemId
- level
- updatedAt

---

## V1 Build Priorities

### Phase 1

- app shell
- home
- library
- routine
- progress
- settings
- session logging
- competency records

### Phase 2

- triad library
- saved combinations
- combination builder
- practice setup and session flow

### Phase 3

- 5-note groupings
- custom pattern library
- generator for core skills

### Phase 4

- flow generator
- flow resolution engine
- kit-specific progress views

---

## V1 Non-Goals

Do not include in the first shipping scope:

- audio engine beyond basic click
- automatic competency scoring
- social features
- cloud sync
- exhaustive notation editing
- arbitrary time signatures
- arbitrary subdivision systems
- highly advanced flow math beyond 4/4 landing-to-1 behavior

---

## Product Guardrail

If a feature does not clearly help the user:

- choose what to practice
- practice it
- save it
- track it
- improve it

it does not belong in v1.
