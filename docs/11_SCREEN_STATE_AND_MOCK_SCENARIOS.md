# 11 — Screen State And Mock Scenarios

## Purpose

This document defines the named mock scenarios the app must support for design, QA, and implementation.

These scenarios are not optional test data. They are required to keep Coach, Practice, Focus, and Progress aligned with the product model.

---

## Scenario 1: `first_light`

### Description

Brand-new user.

State:

- no practice history
- no Focus items
- no saved phrases
- no assessment data

### Expected Screen States

#### Coach

- one getting-started card only
- recommended starter triads
- `Add to Working On`
- `Open the Matrix`

#### Practice

- direct-entry view
- no `Repeat Last Session`
- `Warm Up` available
- `Practice Working On` disabled or absent

#### Focus

- empty-state explanation
- add guidance only

#### Progress

- measurement placeholders only
- no fake totals
- no coaching language

---

## Scenario 2: `starter_items_selected`

### Description

User selected starter triads, but has not logged practice yet.

State:

- Focus contains 4 starter items
- no sessions yet
- no assessment data

### Expected Screen States

#### Coach

- one start-here card
- clear instruction to begin first session
- CTA to practice current work

#### Practice

- direct-entry view
- `Practice Working On` active
- `Warm Up` active

#### Focus

- 4 active items
- play / edit / remove visible on each

#### Progress

- still mostly empty
- counts reflect selected items only if that is the intended scope

---

## Scenario 3: `early_struggle`

### Description

User has practiced a little, but nothing is stable yet.

State:

- several short sessions logged
- low confidence / cleanup needed
- no strong items

### Expected Screen States

#### Coach

- `Needs Work` and `Focus` style guidance
- no fake momentum
- no premature flow unlock

#### Practice

- `Repeat Last Session` available
- `Practice Working On` available

#### Focus

- active items
- no milestone storytelling

#### Progress

- visible early activity
- item and group progress
- no misleading “mastery” summaries

---

## Scenario 4: `steady_progress`

### Description

User has an active working set and regular sessions.

State:

- several items active
- some improvement visible
- no strong phrase/flow unlock yet

### Expected Screen States

#### Coach

- `Focus`
- `Needs Work`
- `Momentum`

#### Practice

- repeat-last-session meaningful
- choose-from-working-on meaningful

#### Focus

- stable current-work list

#### Progress

- time trend visible
- per-item and per-group measurement visible

---

## Scenario 5: `phrase_ready`

### Description

User has stable single-surface material ready to be connected into phrases.

State:

- at least a few strong single items
- phrase work now makes sense

### Expected Screen States

#### Coach

- `Next Unlock` should point toward phrase building
- CTA may open Matrix or practice a phrase

#### Matrix

- phrase-building state should feel relevant and populated

#### Progress

- strong items visible
- group progress should show meaningful coverage

---

## Scenario 6: `flow_ready`

### Description

User has strong enough phrase work to begin or deepen flow.

State:

- stable phrase material
- voice assignment ready

### Expected Screen States

#### Coach

- `Next Unlock` points toward Flow

#### Practice Item

- voice assignment setup feels justified

#### Progress

- later can surface flow readiness and flow history

---

## Requirements For The Mock System

1. Each scenario must be deterministic.
2. Each scenario must fully populate all required screens.
3. Scenarios must be easy to switch in debug builds.
4. The mock state layer must not require destructive data resets to use.
5. Designers and QA should be able to test a screen state without recreating it manually.

Current implementation rule:

- debug builds expose a runtime-only scenario switch
- activating a scenario must not overwrite persisted user data
- leaving mock mode restores the live app state from before the scenario was activated

---

## Acceptance Rule

No major screen redesign should be accepted until it has been checked against the scenarios in this document.
