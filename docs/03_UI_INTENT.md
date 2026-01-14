# 03 — UI Model (V1)

This document defines how Triad Trainer’s UI behaves in v1.

The goal is to create a practice experience that feels:
- calm
- obvious
- musical
- focused

The UI must **get out of the way once practice starts**.

---

## Core UI Principle

> The screen should reflect the drummer’s *state of mind*.

There are only two meaningful states:
1. **Preparing to practice**
2. **Actively practicing**

The UI must clearly separate these states and never blur them.

---

## Two UI States

### 1) Setup State (Before Play)

This is where **intent is chosen**.

The user is deciding:
- *What am I practicing on?*
- *What kind of practice do I want right now?*

This state may expose controls, but **only those tied to intent**, not mechanics.

#### Visible in Setup
- **Practice Mode**
  - Training
  - Flow
- **Instrument Context**
  - Pad Only
  - Pad + Kick
  - Kit
- **Kit configuration** (only if Kit)
  - Kit size
  - Handedness
  - Basic brass selection
- **Generator tuning (minimal)**
  - Phrase type
  - Accent rule
  - Repeats or ∞
- **Practice timer target** (optional)

#### Hidden in Setup
- Transport clutter
- Coverage statistics
- Pattern internals
- Debug-style toggles
- Playback tricks

Setup is about **choosing a lane**, not driving yet.

---

### 2) Practice State (After Play)

This is where learning happens.

Once Play is pressed, the UI must **collapse to essentials**.

#### Visible in Practice
- Pattern notation (primary focus)
- Play / Pause
- BPM − / +
- Click (metronome on/off)
- Timer (elapsed / target)

That’s it.

If the user needs to think about the UI while playing, the UI failed.

---

## App Bar (V1)

### What stays
- App title
- Settings (gear icon)

### What goes (v1)
- Favorites / Star
- Genre selectors
- Advanced menus

Settings is where complexity lives — **not** on the practice surface.

---

## Footer / Transport Bar

### V1 Transport Rules

The transport must:
- Feel like a metronome, not a DAW
- Support muscle memory
- Stay visually quiet

#### Allowed Controls
- Play / Pause
- BPM − / +
- Click toggle
- Timer indicator

#### Not Allowed (v1)
- Scrub bars
- Pattern history
- Multiple transport modes
- Playback effects or tricks

---

## Pattern Card

The pattern card is the **center of gravity** of the screen.

### Visual Hierarchy
1. **Triad notation** (largest, darkest)
2. Voice assignment (secondary)
3. Accents (clear but minimal)

Nothing should compete with the triads.

---

## Visual Language Rules

### Stickings
- Always primary
- Always fully opaque in v1
- No fading or dimming by default

---

### Accents
- Accents are marked with `^`
- Accents may apply to **any limb**, including kick
- Accent marks must be visually consistent

Footer copy (exact v1 text):

> **Accents are marked with `^` ○ Unaccented notes are ghost notes**

(`○` is a separator, not the letter “O”.)

---

### Ghost Notes
- Ghosting is **conceptual**, not visual, in v1
- No automatic fading or opacity changes
- Visual ghosting may be added later as an explicit option

Clarity beats cleverness.

---

## Modes vs Instrument Context

These are intentionally **separate concepts**.

### Instrument Context
Answers:
> *What am I physically playing on?*

- Pad Only
- Pad + Kick
- Kit

This controls:
- Limb scope
- Voice assignment availability
- Physical constraints

Instrument context **does not** define practice intent.

---

### Practice Mode
Answers:
> *What kind of practice do I want right now?*

#### Training Mode
- Shorter phrases
- More repetition
- ∞ encouraged
- Predictable, stable phrasing

Use case:
> “I want to drill this until it’s automatic.”

---

#### Flow Mode
- Longer phrases
- Musical continuity
- Less looping
- Phrase-first generation

Use case:
> “I want this to feel like real movement and groove.”

Modes set **defaults**, not extra UI.

---

## Coverage (V1 UI Stance)

Coverage is **not a score**.

In v1:
- Coverage is hidden or minimal
- If shown, it must imply meaning — not fractions

Examples of meaningful (future) coverage:
- “Left hand rarely starts”
- “Kick underused”
- “Doubles underrepresented”

If coverage cannot teach yet, it stays out of sight.

---

## What the UI Must Never Feel Like

The app must never feel like:
- A DAW
- A spreadsheet
- A drum machine editor
- A settings app with a metronome taped on

It is a **practice partner**, not a control panel.

---

## V1 Success Test

If a drummer can:
- Open the app
- Press Play
- Practice for 10 minutes
- Never feel distracted or confused

Then the UI is correct.

Anything that jeopardizes that experience is out of scope for v1.
