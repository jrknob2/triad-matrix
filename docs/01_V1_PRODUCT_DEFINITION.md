# 01 - V1 Product Definition

## V1 Goal

Ship a focused lesson-plan app that helps a drummer read, print, and work through curated Drumcabulary vocabulary.

V1 is content-first and print-first. It is not yet a live practice tracker, assessment system, phrase builder, or recommendation engine.

---

## Core Promise

Drumcabulary helps a drummer move from:

- a curated lesson path
- to readable pattern examples
- to concrete exercises
- to printable practice material

The app should make the lesson path clear before it tries to measure or personalize anything.

---

## What V1 Must Do

V1 must support:

1. loading an ordered lesson plan from bundled YAML
2. showing a compact lesson list
3. opening a printable lesson detail view
4. displaying objectives, skill focus, required concepts, patterns, exercises, coaching notes, and mastery targets
5. rendering authored notation examples with the shared sheet-notation renderer
6. exporting or printing lesson detail through the existing print/share path
7. validating required YAML fields so broken lesson assets fail visibly

---

## Top-Level Product Model

### Coach / Lessons

The current app home is the lesson plan. It answers:

- what lesson comes next
- what the lesson is trying to teach
- what patterns and exercises belong to the lesson
- what can be printed for offline practice

### Lesson Plan

An ordered set of lessons loaded from YAML.

### Lesson

A lesson contains:

- objective
- skill focus
- estimated time
- required concepts
- patterns
- exercises
- coaching notes
- mastery targets

### Pattern

A named musical idea using authored Drumcabulary notation. Pattern notation is source content for rendering and lightweight audio preview, not a user-editable field in MVP.

### Exercise

A practice instruction that may reference lesson patterns, tempo targets, subdivisions, and flow sequences. Exercises are content, not tracked sessions.

---

## Deferred From MVP

These features are useful later, but they are outside the current MVP:

- live practice sessions
- start/stop player
- BPM timing engine
- full practice audio playback
- progress tracking
- assessment evaluator
- user-specific recommendation engine
- Matrix phrase builder
- editable user notation
- Working On / Maintain model
- warmup flows
- iPad-specific shell
- full curriculum editor or CMS

---

## Guardrails

1. Lesson content comes from authored YAML assets.
2. MVP screens must not expose practice, Matrix, Library, Progress, assessment, or recommendation entry points.
3. Pattern notation may be stored and rendered, but users do not author notation strings in MVP.
4. Rendered notation may expose a lightweight hear-it preview using the existing sample engine.
5. Sheet notation rendering failures should be visible; fallbacks must not replace broken rendering with misleading raw notation.
6. Print/export output should match the lesson detail contract as closely as the current infrastructure allows.

---

## Success Criteria

V1 is successful if:

- a new user can open the app and see the lesson path immediately
- each lesson reads clearly on screen
- notation examples render reliably
- lesson material can be printed or shared
- broken lesson YAML or notation rendering is surfaced quickly during development
