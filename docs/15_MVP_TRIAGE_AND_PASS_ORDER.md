# 15 - MVP Triage And Pass Order

## Purpose

This document keeps current work aligned to the lesson-plan MVP.

Use this document when deciding what to work on next.

---

## Triage Rules

An item belongs in `Consider Now` when it affects:

- lesson content trust
- notation rendering trust
- print/share output
- YAML validation
- the clarity of the lesson path

An item belongs in `Decision Needed Soon` when the implementation can wait, but the lesson content model needs a choice before more content is authored.

An item belongs in `Post-MVP` when it introduces practice sessions, progress, personalization, authoring, audio, or broader app navigation.

---

## Consider Now

### 1. Lesson YAML validation

Why now:

- authored lesson content is the MVP source of truth
- broken assets should fail loudly during development

Initial thought:

- keep validation simple and field-based
- include enough error detail to identify the broken lesson and field

### 2. Shared sheet notation rendering

Why now:

- notation quality determines whether lesson content feels credible
- app and PDF output must use the same rendering expectations

Initial thought:

- keep using the existing renderer path
- remove fallbacks that silently replace broken rendering with raw notation strings
- add focused tests around lesson notation examples if gaps appear

### 3. Print/share export fidelity

Why now:

- print-first is part of the MVP identity
- exported lessons must not degrade into plain notation text

Initial thought:

- verify rendered notation in PDF output
- keep PDF layout clean and close to the lesson detail contract

### 4. Lesson content pass

Why now:

- the app is only as useful as the authored lesson path
- content gaps will be more visible now that navigation is intentionally narrow

Initial thought:

- keep `Flow Foundations` as the first content spine
- add or revise lessons through YAML only
- avoid creating a CMS or editor for MVP

---

## Decision Needed Soon

### 1. Lesson plan naming

Decision needed:

- whether the app-visible home surface should be called `Lessons`, `Coach`, or `Flow Foundations`

Current implementation:

- app opens directly to the lesson plan content without a tab label

### 2. Pattern row detail

Decision needed:

- whether pattern rows should show role labels only, rendered notation only, or both

Current contract:

- raw notation strings are not user-facing when sheet rendering is expected

### 3. Print target

Decision needed:

- whether MVP print output should optimize for one lesson per page, compact handouts, or full lesson notes

Current implementation:

- use the existing print/share infrastructure and preserve rendered notation

---

## Post-MVP

- live practice sessions
- start/stop player
- BPM timing engine
- audio playback
- progress tracking
- assessment evaluator
- user-specific recommendation engine
- Matrix phrase builder
- editable user notation
- Working On / Maintain model
- warmup flows
- iPad-specific shell
- full curriculum editor or CMS
