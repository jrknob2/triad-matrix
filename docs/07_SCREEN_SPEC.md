# 07 - Screen Spec

## Purpose

This document describes the early MVP screen contracts and remains useful
historical context.

Current app flow and metadata ownership have evolved. For current navigation,
Home, Explore, Lesson Detail, Settings, and Author flow ownership, use
`docs/28_APP_FLOW_CONTRACT.md`. For lesson/exercise metadata, use
`docs/29_LESSON_METADATA_CONTRACT.md`. If this file conflicts with those newer
contracts, treat those newer contracts as authoritative.

The early MVP had two app-owned screens:

1. `Lessons`
2. `Lesson Detail`

That no longer describes the current normal app shell. Home, Explore, Author,
Settings, hardware setup, Guided Practice, Play Along, and MIDI capture are now
covered by newer contracts.

Detailed content inventory and wording rules also live in:

- [28_APP_FLOW_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/28_APP_FLOW_CONTRACT.md)
- [12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md)
- [13_COMMUNICATION_STYLE_CONTRACT.md](/Users/terryknoblock/Development/flutter-projects/drumcabulary/docs/13_COMMUNICATION_STYLE_CONTRACT.md)

---

## Navigation Model

MVP opens directly to `Lessons`.

Rules:

- no bottom navigation
- no navigation rail
- no hidden practice-session chrome
- no primary tabs
- lesson rows push `Lesson Detail`
- `Lesson Detail` returns with normal back navigation

---

## 1. Lessons

### Purpose

Lessons shows the ordered lesson plan and lets the user choose what to read or print.

### Must Do

- load the bundled YAML lesson plan
- show the plan title
- show the plan subtitle
- show every lesson in numeric order
- keep rows compact enough to scan
- show lesson number, title, objective, and estimated minutes
- open lesson detail on row tap
- show a clear error if the lesson plan cannot load or validate

### Must Not Do

- launch a practice session
- show progress or completion state
- recommend personalized next steps
- expose Matrix, Practice, Library, Progress, or Working On
- show raw notation strings in list rows
- let users edit notation

### Primary States

#### State A: Loading

Shows a progress indicator while the YAML asset loads.

#### State B: Lesson Plan Loaded

Shows the ordered lesson list.

#### State C: Lesson Plan Error

Shows a visible load or validation error.

### Acceptance Criteria

- the first useful app surface is the lesson plan
- every bundled lesson appears once
- lesson order follows the YAML `number` field
- no deferred app section is reachable from this screen

---

## 2. Lesson Detail

### Purpose

Lesson Detail presents one lesson as a clean printable handout.

### Must Do

- show lesson title
- show objective
- show skill focus
- show estimated time
- show pattern rows
- render pattern notation with the shared sheet-notation renderer
- render authored pattern timing metadata, including subdivision, triplet feel, time signature, and repeat count when present
- provide an ear-icon action for lightweight notation audio preview
- animate a vertical playhead line over rendered notation while preview audio runs, including line/bar ends before wrapping or looping
- keep preview cursor speed tied to the written bar, so eighths, sixteenths, and triplet eighths share the same measure-level timing at the fixed preview BPM
- show exercise rows
- show tempo, subdivision, subdivision sequence, and flow metadata when authored
- show coaching notes
- show mastery targets
- provide a primary `Print` action

### Must Not Do

- start a live practice playback session
- run a BPM clock
- log completion
- assess user performance
- replace missing sheet notation with raw notation as a silent fallback
- expose notation editing

### Primary States

#### State A: Lesson Loaded

Shows all authored lesson content.

#### State B: Notation Render Failure

Shows a visible rendering error for the affected notation example.

#### State C: Print Requested

Hands off to the existing print/share export path.

#### State D: Notation Audio Preview

Plays or stops the selected notation example through the lightweight sample-preview path. While playing, a vertical line moves across the rendered notation in time with the preview, continues through each line/bar end before wrapping or looping, and stops if the app leaves the foreground.
Triplet examples render with standard triplet grouping marks. Repeated patterns render with an end-repeat bar only, and preview playback follows the authored repeat count.

### Acceptance Criteria

- all lesson YAML fields are represented clearly
- notation examples render on screen
- notation examples can be previewed with the ear icon
- notation preview shows a moving playhead aligned to the rendered notes and line/bar ends before wrapping or looping
- print/share output includes rendered notation
- renderer or export failures are visible during development
- no practice, progress, or assessment state appears
