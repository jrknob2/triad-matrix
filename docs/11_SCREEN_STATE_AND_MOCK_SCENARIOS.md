# 11 - Screen State And Mock Scenarios

> Historical scenario pack: this file describes the early lesson-plan MVP mock
> states. Current app flow is defined by `docs/28_APP_FLOW_CONTRACT.md`, Home
> behavior by `docs/30_HOME_SCREEN_UX_CONTRACT.md`, and lesson/exercise metadata
> by `docs/29_LESSON_METADATA_CONTRACT.md`.

## Purpose

This document captures early MVP scenarios for historical design, QA, and
implementation context.

The current MVP does not require mock practice history, progress graphs, Working On state, assessment data, or recommendation scenarios.

---

## Scenario 1: `lesson_plan_loaded`

### Description

The bundled Flow Foundations lesson plan loads successfully.

State:

- YAML asset exists
- all required lesson fields validate
- lessons have ordered `number` values
- at least one lesson contains multiple patterns and exercises

### Expected Screen States

#### Lessons

- plan title visible
- plan subtitle visible
- every lesson row visible in numeric order
- each row shows lesson number, title, objective, and estimated minutes
- no Matrix, Practice, Library, Progress, or Settings navigation

#### Lesson Detail

- selected lesson opens
- objective, skill focus, concepts, patterns, exercises, notes, and mastery targets are visible
- notation examples render as sheet notation
- `Print` action is visible

---

## Scenario 2: `lesson_plan_validation_error`

### Description

The YAML asset is missing a required top-level or lesson field.

State:

- loader encounters invalid lesson content

### Expected Screen States

#### Lessons

- load failure is visible
- error contains enough detail to identify the missing field
- no empty or partial lesson list is shown as if it were valid

---

## Scenario 3: `notation_render_failure`

### Description

A lesson pattern contains notation that cannot be rendered by the shared sheet renderer.

State:

- lesson content loads
- one or more pattern notation examples fail rendering

### Expected Screen States

#### Lesson Detail

- affected pattern shows a visible render failure
- raw Drumcabulary notation is not used as a silent substitute for sheet notation
- unaffected notation examples still render

#### Print Export

- export failure or affected notation failure is visible during development
- exported content must not silently replace broken sheet notation with raw Drumcabulary notation

---

## Scenario 4: `print_requested`

### Description

The user opens a lesson and requests print/share export.

State:

- lesson content is valid
- sheet notation rendering succeeds

### Expected Screen States

#### Lesson Detail

- print action calls the existing print/share infrastructure
- export includes lesson title, objective, patterns, exercises, notes, mastery targets, and rendered notation
- the app remains on the lesson detail after print/share handoff returns
