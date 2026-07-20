# 28 - App Flow Contract

## Purpose

This is the active navigation and app-flow contract for UI improvement work.

Use this document when deciding:

- where a screen belongs
- which actions should be globally reachable
- whether a feature is part of the normal student flow, hardware setup, authoring, or developer diagnostics
- which older screens are active, deferred, or orphaned

This document is intentionally narrower than the visual style guides. It should
be included in chat context whenever the work is about app flow, screen
ownership, information architecture, or navigation.

## Related Docs

Read these as supporting context:

- `docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md`
- `docs/07_SCREEN_SPEC.md`
- `docs/06_APP_SPEC.md`
- `docs/25_DRUMMER_EDGE_UI_STYLE_GUIDE.md`
- `docs/26_ART_DIRECTION_GUIDE.md`

Current warning: some older docs still describe Settings, Library, Practice,
Matrix, and Progress as deferred MVP systems. That is historically useful, but
not sufficient for current UI work because hardware setup, Guided Practice,
LEDs, and MIDI capture now exist in the working app. This document is the
flow-level tie-breaker until the older product docs are reconciled.

## Product Flow Principle

Drumcabulary should feel like:

```text
Choose what to learn -> understand it -> hear it -> practice it -> configure hardware only when needed
```

Hardware, MIDI, serial LEDs, capture, diagnostics, and editing are supporting
systems. They should not become the first thing a drummer has to understand.

## Current Top-Level Shape

The implemented app currently opens into a single shell:

```text
AppShell
  -> Coach
      -> Choose Level
      -> Choose Skill
      -> Choose Lesson
      -> Lesson Detail
  -> Settings
      -> Hardware & MIDI
      -> temporary MIDI Capture panel
```

There is no active bottom navigation, tab bar, or navigation rail.

The current first screen is `Coach`, backed by `TodayScreen`.

## Active Normal Student Flow

### Flow A: Open App

```text
Launch app -> Coach / Choose Level
```

The user should immediately see lesson choices, not setup, diagnostics, or
authoring.

Allowed global actions:

- Settings

Not allowed as primary first-screen content:

- raw MIDI diagnostics
- serial logs
- notation source editing
- pattern capture
- hardware setup dashboards

### Flow B: Choose Lesson

```text
Choose Level -> Choose Skill -> Choose Lesson or open single lesson directly
```

The lesson browsing path should stay linear and low-decision.

Rules:

- Level answers "where am I in the curriculum?"
- Skill answers "what kind of vocabulary do I want?"
- Lesson answers "which specific lesson do I want now?"
- A skill with one lesson may open that lesson directly.
- A skill with multiple lessons should show an ordered lesson list.

### Flow C: Read, Hear, And Practice Lesson

```text
Lesson Detail -> Hear It
Lesson Detail -> Practice It
Lesson Detail -> Guided Practice
Lesson Detail -> Print Lesson
```

Lesson Detail is the main work surface.

It owns:

- lesson explanation
- rendered notation
- Hear It playback
- Practice It handoff
- Guided Practice handoff
- completion/progress action where present
- print/export

It must not own:

- hardware device selection
- raw MIDI logs
- serial port discovery
- pattern authoring
- note-map editing as normal content

### Flow D: Guided Practice

```text
Lesson Detail -> Guided Practice -> Stop Guided Practice
```

Guided Practice is entered from a specific exercise, not from Settings or a
generic player.

Prerequisites:

- MIDI input connected
- LED controller connected
- exercise can produce expected events

Rules:

- Starting Guided Practice stays in Lesson Detail.
- The current expected event is shown through the shared notation selection.
- LEDs cue the same current event.
- The flow continues until the user stops it or hardware disconnects.
- Hardware disconnect should stop the guided session without taking the user out
  of the lesson.

## Settings Flow

Settings is a support area, not a student practice destination.

```text
Coach app bar -> Settings
Settings -> Hardware & MIDI
```

Settings owns:

- default BPM
- default timer
- click preference
- sheet-music display preference
- app data reset
- mock scenarios when enabled
- desktop-only hardware setup entry
- temporary MIDI Capture panel while authoring flow is being refined

Settings should not become:

- a pattern library
- a normal practice launcher
- a raw diagnostic dashboard
- a long-term MIDI capture workspace

## Hardware & MIDI Flow

Hardware setup is desktop-only.

```text
Settings -> Hardware & MIDI
```

Hardware & MIDI owns:

- MIDI input discovery
- MIDI input connection
- concise MIDI input test
- serial LED controller discovery
- serial LED connection
- concise LED test
- LED orientation settings

It must not show normal-user raw diagnostic cards:

- discovery internals
- latest raw event
- event log
- raw note-map inspection
- raw serial command log

Those belong behind a developer diagnostic route or debug-only mode.

## Temporary MIDI Capture Flow

Current temporary placement:

```text
Settings -> MIDI Capture panel at the end
```

Purpose:

- recover and verify the working capture path while the Pattern Editor flow is
  being redesigned

Current behavior:

- visible only on desktop-capable platforms
- uses the shared MIDI input service
- requires the MIDI device to be connected first
- records mapped MIDI hits
- ignores Note Off and velocity-zero Note On events
- emits voice-first notation such as `[HH K]`, `[OHH]`, and `[S]`
- writes generated notation into an editable text field
- renders the edited/generated notation with the shared notation preview
- can Hear It from the current valid notation using the existing playback engine
- can Play Along from the same playback engine, using LED lead cues when the
  shared LED controller is connected
- can start Guided Practice from the current valid notation when MIDI input and
  the shared LED controller are connected
- does not infer hand sticking from MIDI velocity

The temporary capture panel must not create its own playback or guided-practice
timeline. Hear It, Play Along, and Guided Practice are entry points into the
same playback, MIDI, notation-selection, and LED services used elsewhere.
- estimates BPM from grouped onset intervals

This is not the final product location. The intended future home is the Pattern
Editor or a Pattern authoring flow.

## Pattern Authoring Flow - Intended Direction

The Pattern Editor exists in code, but it is not currently reachable from normal
navigation.

Intended future flow:

```text
Coach or Library/Patterns -> Pattern Editor
Pattern Editor -> manual notation editing
Pattern Editor -> optional desktop MIDI Capture
Pattern Editor -> save/cancel
```

Rules:

- Pattern Editor should be cross-platform.
- Manual notation editing should work on iPhone.
- MIDI capture should be desktop-only and optional.
- Capture should feed the same editor source string, not a separate pattern
  system.
- Replace and Append should be explicit actions.

Do not create a separate desktop-only Pattern Editor just for MIDI capture.

## Developer Diagnostic Flow

Developer diagnostics are not normal production navigation.

Developer-only tools may include:

- raw MIDI bytes
- latest raw event
- bounded event log
- note-map inspection
- serial discovery details
- raw serial command logs

Rules:

- Keep diagnostics useful for hardware troubleshooting.
- Do not expose them as normal student cards.
- Do not make diagnostics the only way to access production hardware setup.

## Implemented But Not Active In Normal Flow

These screens or systems exist in code but should not be treated as active
normal navigation until their flow is explicitly restored:

- `PatternScreen`
- `FocusScreen` / saved pattern library surface
- `MatrixScreen`
- detailed `ProgressScreen`
- full `PracticeScreen`
- `PracticeSessionScreen`
- `SessionSummaryScreen`
- raw `MidiDiagnosticScreen`

When reintroducing any of these, update this flow contract first.

## Known Flow Gaps

1. Pattern authoring exists in code but has no normal entry point.
2. MIDI Capture is temporarily in Settings instead of its intended authoring
   flow.
3. Settings is reachable from the root app shell, but child screens need a clear
   rule for whether global settings should remain visible from nested routes.
4. Raw MIDI diagnostics need an intentional developer-only access rule.
5. Older product docs need reconciliation with the current hardware and guided
   practice reality.

## Decision Rules For UI Work

Use these when improving the UI:

- If the user is trying to learn or practice, keep them in Coach and Lesson
  Detail.
- If the user is connecting hardware, send them to Settings -> Hardware & MIDI.
- If the user is authoring notation, send them to Pattern Editor once that route
  is restored.
- If the user is troubleshooting bytes or device internals, send them to
  developer diagnostics.
- If a screen mixes these jobs, split the flow before polishing the layout.
- If a control cannot name its destination clearly, the flow contract is missing
  a decision.

## Chat Context Pack For Flow Work

For app-flow UI work, include:

```text
docs/28_APP_FLOW_CONTRACT.md
docs/12_SCREEN_CONTENT_CONTRACTS_AND_APP_FLOWS.md
docs/25_DRUMMER_EDGE_UI_STYLE_GUIDE.md
docs/26_ART_DIRECTION_GUIDE.md
lib/features/app/app_shell.dart
lib/features/today/today_screen.dart
lib/features/coach/lesson_detail_screen.dart
lib/features/settings/app_settings_screen.dart
lib/features/settings/hardware_midi_settings_screen.dart
```

Add feature-specific files only when needed:

```text
lib/features/library/pattern_screen.dart
lib/features/midi/midi_pattern_capture.dart
lib/features/midi/midi_pattern_capture_panel.dart
lib/features/practice/widgets/sheet_notation_display.dart
```
