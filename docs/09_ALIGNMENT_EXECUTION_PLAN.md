# 09 — Alignment Execution Plan

## Purpose

This document resets implementation around the current product direction.

It exists because the app improved locally but drifted globally. The product now needs explicit screen contracts, mock states, and acceptance criteria before more feature work.

This plan is the bridge from the current app to a tighter v1.

---

## What Went Wrong

The team made progress, but several things happened at once:

- old specs stayed in the repo
- new behaviors were layered onto outdated screen assumptions
- local fixes landed before screen purposes were frozen
- UI consistency improved in pieces, not as a locked system

Result:

- screens started overlapping in purpose
- wording drifted
- counts and labels lost trust
- the app began to feel assembled rather than designed

---

## Locked Reset Decisions

These are now the baseline assumptions.

### 1. App navigation

Primary tabs:

1. `Coach`
2. `Matrix`
3. `Practice`
4. `Focus`
5. `Progress`

### 2. Screen purposes

- `Coach` = what to do next
- `Matrix` = the triad map and phrase builder
- `Practice` = direct entry plus execution
- `Focus` = current-work CRUD
- `Progress` = measurement

### 3. Warmup

Warmup is:

- optional
- untracked
- disposable

Warmup is not part of the coached curriculum state.

### 4. Progress

Progress must move away from recommendation cards and toward actual measurement:

- trends
- per-item progress
- per-group progress
- coverage

### 5. Coach

Coach must be designed against explicit states, not only live organic data.

### 6. Mock data

Named mock scenarios are required product infrastructure, not debugging scaffolding.

---

## Required Mock Scenarios

These scenarios must be supported so the main screens can be designed and tested properly.

1. `first_light`
2. `starter_items_selected`
3. `early_struggle`
4. `steady_progress`
5. `phrase_ready`
6. `flow_ready`

Each scenario should produce meaningful states for:

- Coach
- Practice
- Focus
- Progress

---

## Phase Plan

### Phase 1. Freeze product contracts

Goal:

- stop coding against stale or overlapping assumptions

Tasks:

- update `01`, `06`, and `07` to the new product model
- add detailed screen content and app-flow contracts
- remove reliance on the old `Home / Library / Routine / Practice Setup` architecture
- lock screen purposes
- lock screen-level acceptance criteria

Status:

- current phase

### Phase 2. Add mock-state infrastructure

Goal:

- make screen design testable

Tasks:

- create named app-state fixtures
- make them selectable in dev/debug builds
- ensure they fully exercise Coach, Practice, Focus, and Progress

Outcome:

- the team can design and QA stateful UI without corrupting live data
- mock scenarios can be exposed on-device through a dev-tools build flag without becoming normal release UI

### Phase 3. Rebuild navigation around Practice as a tab

Goal:

- make practice entry explicit

Tasks:

- add `Practice` to bottom nav
- move direct-entry options there
- remove any hidden dependence on reaching practice only through other screens

### Phase 4. Simplify Focus

Goal:

- make Focus clearly about current work

Tasks:

- strip summary/dashboard behavior
- keep add/remove/edit/practice
- make item actions obvious
- keep `Working On` broad enough to support different practice-day slices
- move session-size guidance into Practice session setup rather than Focus

### Phase 4A. Practice Session Setup

Goal:

- distinguish the broad `Working On` pool from today's smaller session slice

Tasks:

- make `Start Practice` the entry into normal tracked practice
- move `From Working On` inside that setup flow
- add derived filters for session slicing:
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
- add soft scope guidance for oversized sessions and overly broad active rotation

### Phase 5. Rebuild Progress

Goal:

- turn Progress into a measurement surface

Tasks:

- replace internal/explanatory cards
- add:
  - overall progress
  - per-item progress
  - per-group progress
  - trend views
- ensure labels match scope

### Phase 6. Rebuild Coach against explicit states

Goal:

- make Coach useful after first light, not just plausible

Tasks:

- design each Coach state against mock data
- rewrite block structure and copy
- ensure each state has a clear primary action

### Phase 7. Visual polish pass

Goal:

- make the app feel designed, not assembled

Tasks:

- tighten shared controls
- remove repeated or redundant signals
- review spacing, contrast, hierarchy, and empty states
- verify every surface against its acceptance criteria

### Phase 8. Audio assessment

Goal:

- add onset/timing evidence later

Note:

- explicitly deferred until after the structural/product reset is stable

### Phase 9. Remove compatibility residue

Goal:

- keep the v1 codebase aligned to the current app instead of adapting to abandoned paths

Tasks:

- remove dead compatibility shims
- remove onboarding state and screen residue
- remove obsolete Matrix and Progress vocabulary from the active model
- keep persistence plain and current instead of carrying compatibility scaffolding that no longer serves the product

Outcome:

- active code and active docs describe the same app
- refactors do not leave behind transitional behavior as permanent baggage

### Phase 10. Communication style rewrite

Goal:

- make the app sound like one coherent teacher-led product

Tasks:

- lock a communication-style contract
- distinguish UI voice from teaching voice
- rewrite Coach, Practice, Practice Item, Session Summary, and Matrix context text against that contract
- keep instructional guidance separate from authored notation or voice data

Outcome:

- the app's wording matches the product model and the teaching source material
- copy no longer drifts between framework language, UX filler, and teacher voice

---

## Recommended Execution Order

Do not resume feature churn immediately.

Recommended order:

1. finish and accept the rewritten specs
2. implement mock-state infrastructure
3. add `Practice` tab and direct-entry screen
4. simplify `Focus`
5. redesign `Progress`
6. redesign `Coach` with mock states
7. do one full visual polish pass
8. remove compatibility residue introduced during the reset
9. lock the communication-style contract
10. do a batched copy rewrite pass by screen
11. then resume forward feature work

---

## Definition Of Done For This Reset

The reset is complete when:

- no active core spec still describes the old app architecture
- each main screen has a clear purpose and anti-purpose
- each main screen has defined states
- each main screen is testable through mock scenarios
- Progress no longer feels like Coach
- Focus no longer feels like a dashboard
- Practice is no longer hidden
- Coach no longer relies on improvised copy to bridge missing state design
