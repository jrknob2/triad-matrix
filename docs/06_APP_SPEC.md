# 06 — App Spec

## Purpose

This document defines the current product architecture for v1.

It replaces the older `Home / Library / Routine / Progress` model.

The goal of this spec is to lock:

- the app map
- the product model
- the main user flows
- the boundaries between screens

---

## Product Definition

Drumcabulary is a drummer-first practice app for turning sticking patterns into usable musical vocabulary.

V1 remains triad-first pedagogically, but the canonical playable-material model is now:

- one ordered token sequence
- one timed position per token
- support for note tokens and first-class rest/pause tokens
- support for the core alphabet `R`, `L`, `K`, `F`, `X`, and `_`
- support for bracketed simultaneous hits such as `[RL]` and `[XK]`
- optional grouping hints as display/pedagogy metadata, not structure
- optional timing metadata as playback truth, separate from grouping

The app is not a neutral pattern bucket. It is a guided practice system.

Active v1 data-model rule:

- the canonical pattern model is a linear token sequence, not a family-specific runtime shape
- triad / 4-note / 5-note / phrase / flow / single-surface may remain as labels, filters, or pedagogy cues, but they must not define parsing, storage shape, playback shape, or renderer choice
- non-warmup practice sessions are generic pattern sessions regardless of whether the practiced material is triad-rooted, longer, orchestrated, or phrase-like
- the Matrix triad set is a structural in-memory basis used to render and filter the Matrix grid
- Matrix structural triads are not the canonical persisted source of editable practice items
- practice items are standalone persisted records
- a practice item owns its own token sequence plus its authored state
- normal editing should update that authored item directly rather than silently splitting it into a base item plus variant
- rest/pause is a first-class timed token, not whitespace or a display hack
- `F` and `X` are single-position expressive tokens and must not expand into multiple stored or timed events
- `B` is not valid vocabulary; both-hands/unison or multi-voice hits must be authored as simultaneous hits such as `[RL]` or `[XK]`
- grouping is optional metadata for readability and teaching, not runtime structure
- timing metadata is optional playback structure; when present, it overrides grouping-derived defaults for playback without creating a new pattern type
- default playback timing for simple drills should be:
  - if grouping has a compatible group size, one grouping = one beat and token duration = beat / group size
  - otherwise, one token = one beat as the legacy-safe fallback
- if an item needs visible grouping, that grouping should be stored explicitly on the item; runtime/controller code should not infer grouping from family or other metadata outside localized legacy migration
- flow / single-surface should be derived from authored orchestration state or explicit UI intent as metadata, not as a separate runtime engine shape
- when a session is explicitly launched in `Flow` or `Single Surface`, that chosen session-mode metadata should be preserved in setup, logging, replay, and history rather than being recomputed later from changed item state
- item family and practice mode may remain persisted as metadata for labels, filtering, pedagogy, and legacy compatibility, but they should not define canonical structure, grouping defaults, or non-warmup session behavior

Post-MVP architecture direction:

- v1 intentionally treats triads as the teaching root
- a later domain-model refactor may generalize that root into a configurable pattern grammar
- in that future model, triads would become one configured slice of a broader system defined by:
  - symbol alphabet
  - grouping size
  - grouping/display rules
  - optional rest support
- this future architecture should not weaken the clarity of the current triad-first product surface during MVP

---

## App Map

V1 uses five primary tabs:

1. `Coach`
2. `Matrix`
3. `Practice`
4. `Library`
5. `Progress`

Secondary routes:

- `Practice Item`
- `Session Summary`
- `Settings`

Optional later routes:

- `Dedicated Flow Setup`
- `Audio Assessment Detail`

## Form Factors

Phone remains the baseline layout.

iPad rules:

- use the same product model, but not the same visual structure
- use wide layouts deliberately instead of centering phone-width content
- keep related working surfaces visible together when that reduces navigation friction
- allow immersive fullscreen practice on iPad without changing phone behavior

---

## Screen Responsibilities

### Coach

Purpose:

- interpret the player's state
- recommend what to do next

Coach is responsible for:

- first-light start direction
- early-session guidance
- active work guidance
- cleanup recommendations
- momentum and next-step suggestions

Coach is not responsible for:

- browsing all material
- being the practice player
- being the progress dashboard

### Matrix

Purpose:

- expose the triad system
- support filtering and analysis
- build phrases

Matrix is responsible for:

- structural browsing
- filter-driven discovery
- phrase construction
- sending material to practice or focus

On iPad, Matrix should prefer split composition:

- grid and structural browsing on the left
- phrase editor and phrase actions on the right

Matrix is not responsible for:

- direct progress narrative
- coaching copy
- exact occurrence editing inside the grid itself

### Practice

Purpose:

- give the player a direct way to start practicing
- execute a session with minimal friction

Practice is responsible for:

- direct-entry choices
- session setup from `Working On`
- warmup entry
- repeat-last-session entry
- working-set entry
- the execution player

On iPad, Practice should prefer split composition:

- launch choices on the left
- previous-session browser or session-setup surface on the right

Practice is not responsible for:

- broad coaching
- progress explanation
- long-form item management

### Library

Purpose:

- manage the working library and active working set

Library is responsible for:

- showing what the player is working on now
- add/remove
- simple edit/open
- launch practice

On iPad, Library should use the available width for denser row composition and clearer separation of search, filters, and list controls.

Library is not responsible for:

- coaching
- progress analysis
- toolbox/milestone storytelling

### Progress

Purpose:

- measure development

Progress is responsible for:

- overall time trends
- item-level progress
- group-level progress
- coverage
- lead balance
- flow readiness later

On iPad, Progress should prefer multi-column graph and metric composition before reverting to tall phone-style stacks.

Progress is not responsible for:

- telling the player what to do today
- duplicating Focus
- explaining internal status systems

---

## Product State Model

### 1. Material

Material can be:

- triad
- saved phrase
- custom pattern
- warmup exercise

Important rule:

Warmup exercises are runtime-only practice material. They are not part of the persistent teaching catalog.

### 2. Practice Mode

Any practice item can open in:

- `singleSurface`
- `flow`

The item is neutral.  
The mode determines the practice context.

### 3. Practice Source

Sessions can be launched from:

- `Coach`
- `Matrix`
- `Practice`
- `Focus`
- `Warmup`

This source matters for UI and navigation, but not for the meaning of the material.

### 4. Working Set

The working set is the current list of items the player intends to develop now.

It should be:

- explicit
- editable
- broad enough to support different practice-day slices

It should not be treated as:

- favorites
- long-term storage
- earned vocabulary

Important rule:

- the app should not hard-cap the size of `Working On`
- session scope should usually stay smaller than the full pool
- ideal session scope is usually `1-4` items
- active rotation is usually healthiest around `4-8` actively pushed items
- larger scopes may be allowed, but should trigger soft guidance rather than hard limits

### 5. Assessment

Assessment is how the app understands whether material is:

- `notTrained`
- `active`
- `needsWork`
- `strong`

Assessment comes from:

- logged time
- session completion
- manual session check
- later, onset/audio data

Clarifications:

- Session Summary remains the main assessment surface in MVP
- a future `Claim Your Work` layer extends assessment rather than replacing self-report
- rep credit may function both as motivational feedback and as a progress/data input
- MVP earned-rep rule starts at `1 rep = 60 seconds` of active tracked practice time

### 6. Coach Blocks

Coach should build from explicit block types:

- `Getting Started`
- `Focus`
- `Needs Work`
- `Momentum`
- `Next Unlock`

### 7. Progress Views

Progress should be measurement-first:

- overview
- by item
- by group
- by time range

---

## Core User Flows

### Flow A: First Light

1. User opens app
2. Lands on `Coach`
3. Sees a simple getting-started card
4. Can:
   - add recommended starters to `Focus`
   - open `Matrix`
5. Begins first practice from `Focus`, `Matrix`, or `Practice`

### Flow B: Direct Practice

1. User opens `Practice`
2. Sees direct-entry options
3. Chooses one:
   - `Repeat a Previous Session`
   - `Choose Patterns to Practice`
   - `Warm Up`
4. If choosing patterns, narrows `Working On` into today's session slice
5. If repeating, chooses from a recent-session list
6. Enters session player

### Flow C: Matrix-Driven Practice

1. User opens `Matrix`
2. Filters or selects cells
3. Builds a phrase or chooses one item
4. Starts `Single Surface` or `Flow`
5. Optionally adds to `Focus`

### Flow D: Focus CRUD

1. User opens `Focus`
2. Reviews working set
3. Practices, edits, removes, or reorders items

### Flow E: Progress Review

1. User opens `Progress`
2. Reviews time, coverage, and trend views
3. Optionally drills into an item
4. Returns to `Coach`, `Matrix`, `Practice`, or `Focus`

---

## Mock Data Requirement

The app must support named mock/seed scenarios so Coach, Practice, Focus, and Progress can be designed and tested against real screen states.

Required scenarios:

- `first_light`
- `starter_items_selected`
- `early_struggle`
- `steady_progress`
- `phrase_ready`
- `flow_ready`

These scenarios are part of the product spec, not a debugging convenience.

---

## Acceptance Guardrails

1. `Coach` must never show internal/process language to the user.
2. `Practice` must be reachable directly from the bottom nav.
3. `Focus` must read primarily as current-work CRUD.
4. `Progress` must not contain coaching cards.
5. Labels and counts must match the scope the user sees.
6. Warmups must remain optional, untracked, and disposable.
