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

Drumcabulary is a drummer-first practice app for turning grouped sticking patterns into usable musical vocabulary.

V1 begins with triads as the core system, supports longer triad-built phrases, and allows those phrases to be practiced in either:

- `Single Surface`
- `Flow`

The app is not a neutral pattern bucket. It is a guided practice system.

---

## App Map

V1 uses five primary tabs:

1. `Coach`
2. `Matrix`
3. `Practice`
4. `Focus`
5. `Progress`

Secondary routes:

- `Practice Item`
- `Session Summary`
- `Settings`

Optional later routes:

- `Dedicated Flow Setup`
- `Audio Assessment Detail`

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
- warmup entry
- repeat-last-session entry
- working-set entry
- the execution player

Practice is not responsible for:

- broad coaching
- progress explanation
- long-form item management

### Focus

Purpose:

- manage the active working set

Focus is responsible for:

- showing what the player is working on now
- add/remove
- simple edit/open
- launch practice

Focus is not responsible for:

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
- small
- editable

It should not be treated as:

- favorites
- long-term storage
- earned vocabulary

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

### 6. Coach Blocks

Coach should build from explicit block types:

- `Getting Started`
- `Start Here`
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
   - `Repeat Last Session`
   - `Practice Working On`
   - `Warm Up`
   - `Choose From Working On`
4. Enters session player

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
