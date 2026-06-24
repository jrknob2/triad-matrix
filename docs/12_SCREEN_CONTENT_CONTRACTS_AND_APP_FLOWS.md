# 12 - Screen Content Contracts And App Flows

## Purpose

This document defines the active screen/content/flow contract for the lesson-plan MVP.

If a control or block cannot be justified by a defined MVP flow in this document, it should not be reachable in the app.

Communication rules for student-facing text are defined in:

- [13_COMMUNICATION_STYLE_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/13_COMMUNICATION_STYLE_CONTRACT.md)

---

## Current MVP Rule

The current product is a content-first, print-first lesson plan.

Active app-owned screens:

1. `Lessons`
2. `Lesson Detail`

Deferred screens and systems:

- Matrix
- Practice
- Library
- Progress
- Practice Item
- Session Summary
- Settings
- Startup Splash
- live practice sessions
- assessment
- progress tracking
- recommendations
- user notation authoring

---

## Core Rule

Every active screen needs:

1. a clear job
2. a small set of valid states
3. a small set of valid actions
4. evidence that supports those actions

No active screen should contain:

- filler cards
- internal implementation copy
- controls that belong to deferred practice/product systems
- duplicate lesson metadata with no new value
- raw notation strings where rendered sheet notation is expected

---

## Notation Rules

- lesson YAML stores authored Drumcabulary notation strings
- users do not author or edit notation strings in MVP
- lesson content may use existing explicit voice override notation when an example depends on specific kit voices
- pattern-level timing metadata may include `subdivision`, `time_signature`, and `repeat_count`
- omitted pattern time signatures default to `4/4`
- `subdivision: triplet` is a timing/display feel and should render standard triplet grouping marks without creating new Drumcabulary text tokens
- repeated written patterns should render with repeat bars and an `Nx` repeat-count label when `repeat_count` is authored
- the shared sheet-notation renderer is the display path for lesson notation examples
- rendered notation may expose an ear-icon preview that plays the displayed notes through the existing sample engine
- while notation preview is playing, the notation surface should show an animated vertical playhead aligned to the rendered note positions and continue through each line/bar end before wrapping or looping
- notation preview uses a fixed preview BPM for now; authored exercise tempo is lesson guidance, not an active preview speed control
- notation preview timing should preserve written bar speed across eighth, sixteenth, and triplet-eighth subdivisions
- notation preview playback and playhead movement should honor pattern `repeat_count`
- notation preview audio should use an explicit mixer config for relative sample levels; default preview levels are kick `1.0`, normal non-cymbal hits `0.8`, and ghosts `0.1`, with kick hits ignoring ghost marking
- notation preview audio must stop on app inactive, hidden, paused, or detached lifecycle states instead of catching up missed notes on return
- renderer failures must be visible
- raw notation strings must not silently replace failed sheet rendering in app or PDF output
- PDF/export output should use the same notation rendering contract as the on-screen lesson detail

---

## Flow A: Open Lesson Plan

1. User opens the app.
2. App opens directly to `Lessons`.
3. `Lessons` loads the bundled YAML asset.
4. If the asset validates, the ordered lesson list appears.
5. If the asset fails, a visible load/validation error appears.

Owning screens:

- Lessons

Required content:

- lesson plan title
- lesson plan subtitle
- lesson number
- lesson title
- short objective
- estimated minutes

Forbidden content:

- bottom tabs
- Matrix handoff
- Practice handoff
- progress state
- completion state
- personalized recommendations

---

## Flow B: Read Lesson

1. User taps a lesson row.
2. `Lesson Detail` opens.
3. The full lesson content renders.
4. User can go back to the lesson list.

Owning screens:

- Lessons
- Lesson Detail

Required content:

- lesson title
- objective
- skill focus
- estimated time
- required concepts
- patterns
- rendered notation examples
- notation audio preview action
- animated notation playhead while preview audio runs
- exercises
- coaching notes
- mastery target

Forbidden content:

- live practice playback controls
- live BPM controls
- assessment prompts
- completion toggles
- editable notation fields

---

## Flow C: Print Lesson

1. User opens `Lesson Detail`.
2. User taps `Print`.
3. App uses existing print/share export infrastructure.
4. Exported content includes rendered notation where possible.
5. If notation rendering fails, the failure is visible during development.

Owning screens:

- Lesson Detail
- platform print/share handoff

Required content:

- lesson identity
- objective
- patterns
- rendered notation examples
- exercises
- coaching notes
- mastery target

Forbidden content:

- raw notation fallback in place of failed rendering
- practice-session data
- progress data
- recommendation copy

---

## Lessons Contract

Lessons answers:

- what is the current lesson plan?
- what lessons are in it?
- what should I open to read or print?

Lessons must show:

- plan title
- plan subtitle
- one ordered list of lessons
- compact lesson rows
- clear load errors

Lessons must not show:

- five-tab navigation
- settings controls
- practice controls
- progress controls
- Matrix entry
- notation authoring

---

## Lesson Detail Contract

Lesson Detail answers:

- what does this lesson teach?
- what patterns and exercises are part of it?
- what should be printed?

Lesson Detail must show:

- title
- objective
- skill focus
- estimated time
- required concepts
- patterns with rendered notation
- ear-icon preview controls for rendered notation
- animated vertical playhead over rendered notation during preview
- exercises with authored metadata
- coaching notes
- mastery targets
- print action

Lesson Detail must not show:

- player transport
- timer
- session logging
- progress or completion state
- assessment language
- fallback raw notation when sheet rendering fails
