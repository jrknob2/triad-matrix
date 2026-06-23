# 06 - App Spec

## Purpose

This document defines the current MVP app architecture.

The current MVP replaces the previous five-tab practice product with a single lesson-plan surface. Historical Practice, Matrix, Library, Progress, Working On, and assessment concepts are deferred until the lesson product is stable.

---

## Product Definition

Drumcabulary is currently a drummer-first lesson plan app for curated vocabulary, notation examples, exercise guidance, and printable practice material.

The MVP source of truth is bundled lesson YAML plus the shared sheet-notation renderer.

---

## App Map

MVP uses one primary surface:

1. `Lessons`

Secondary routes:

- `Lesson Detail`
- system print/share sheet when requested by export infrastructure

Deferred routes:

- `Matrix`
- `Practice`
- `Library`
- `Progress`
- `Practice Item`
- `Session Summary`
- `Settings`
- `Startup Splash`

---

## Form Factors

Phone is the baseline layout.

iPad-specific navigation and split-pane behavior are deferred. The current lesson surface should remain usable on larger screens, but no dedicated tablet product model is required for MVP.

---

## Screen Responsibilities

### Lessons

Purpose:

- show the ordered lesson path
- let the user select a lesson

Responsible for:

- lesson plan title
- lesson plan subtitle
- ordered lesson rows
- lesson number
- lesson title
- short objective
- estimated minutes
- primary pattern label when useful

Not responsible for:

- practice launch
- progress status
- recommendations
- authoring notation
- Matrix entry

### Lesson Detail

Purpose:

- present the full lesson as a printable teaching handout

Responsible for:

- lesson title
- objective
- skill focus
- estimated time
- required notation concepts
- pattern list
- rendered pattern notation
- exercise list
- coaching notes
- mastery target
- print/share action

Not responsible for:

- live player controls
- session logging
- completion state
- BPM engine behavior
- assessment

---

## Product State Model

### 1. Lesson Asset

Bundled YAML defines the current lesson plan.

### 2. Lesson Plan

The loaded, validated plan shown by the Lessons surface.

### 3. Lesson

A single ordered teaching unit.

### 4. Pattern

Authored notation content rendered as sheet notation.

### 5. Exercise

Text guidance with optional subdivision, tempo, and flow metadata.

---

## Core User Flows

### Flow A: Open App

1. App opens directly to Lessons.
2. Lessons load the bundled YAML plan.
3. If the YAML fails validation, the screen shows a clear load error.

### Flow B: Read Lesson

1. User taps a lesson row.
2. Lesson Detail opens.
3. The lesson shows all authored content and rendered notation examples.

### Flow C: Print Lesson

1. User taps `Print`.
2. The app uses the existing print/share export path.
3. Rendered notation should appear in the exported lesson.
4. Renderer failures should be visible instead of silently replaced with raw Drumcabulary notation.

---

## Deferred Systems

The following systems remain available as historical implementation or future work only. They are not MVP navigation or user-facing scope:

- live practice player
- progress model
- Matrix phrase builder
- Working On / Maintain state
- recommendation logic
- assessment and session summary
- audio and timing engine
- user notation authoring
