# 01 — V1 Product Definition

## V1 Goal (Locked)

> Ship a **simple, focused triad practice tool** that a drummer can open, press play, and immediately practice something that makes musical and physical sense.

If a feature does not directly support this goal, it does not belong in v1.

---

## The Job To Be Done

“When I sit down to practice, I want:
- a clear sticking pattern,
- a tempo I control,
- a click,
- and a reason to keep playing it for a while.”

V1 exists to serve that exact moment — not exploration, curation, or configuration.

---

## What V1 Must Do

### Core capabilities (non-negotiable)

V1 **must** provide:

1. **Triad pattern generation**
   - Hands-only and hands+kick
   - Musically valid constraints (no physical nonsense)
   - Clear phrase structure (not endless randomness)

2. **Clear visual communication**
   - Stickings are always the primary signal
   - Accents clearly marked with `^`
   - No ambiguity about what limb is playing what

3. **Play control**
   - Play / Stop
   - BPM – / +
   - Simple metronome (click)

4. **Practice timer**
   - Optional
   - Starts when Play starts
   - Stop / Reset
   - Presets: none, 5, 10, 30 minutes

5. **Modes with intent**
   - Modes define *why* you are practicing
   - Modes set defaults instead of exposing knobs

---

## V1 Modes (Locked)

V1 supports **two modes only**.

### Training Mode
Purpose: deliberate development and control.

Defaults:
- Shorter phrases
- More repetition
- Stable orchestration
- Supports infinite looping (∞)

Use case:
> “I want to drill this until it’s automatic.”

---

### Flow Mode
Purpose: musical continuity and movement.

Defaults:
- Longer phrases
- Fewer hard resets
- Encourages motion and phrasing

Use case:
> “I want this to feel like something I could actually play in music.”

---

## Instrument Context (Not a Mode)

Instrument setup describes **what you are practicing on**, not your goal.

V1 supports three contexts:

1. **Pad**
   - Hands only
   - Single surface
   - Visually treated as snare (`S`)

2. **Pad + Kick**
   - Hands + kick
   - Still a single hand surface
   - No orchestration complexity

3. **Kit**
   - Hands + kick
   - Voice assignment enabled
   - Designed for movement and flow

Instrument context affects rendering and generator rules — **not mode**.

---

## Visual Language (V1)

### Stickings
- Always primary
- Always fully opaque
- No fading in v1

### Accents
- Marked with `^`
- Can apply to **any limb**, including kick

### Ghost notes (conceptual)
Unaccented notes are *conceptually* ghosted, but **not visually faded** in v1.

Footer copy (exact text):

> **Accents are marked with `^` ○ Unaccented notes are ghost notes**

(The separator is a mid-dot / divider — not the letter “O”.)

---

## Voice Assignment Rules (V1)

These rules are mandatory for drummer trust:

1. **Every note has a voice internally**
   - Even if not every label is rendered

2. **No voice hopping on doubles**
   - RR or LL must stay on the same surface

3. **Consistent mapping within a phrase**
   - The UI must never imply impossible movement

4. **Pad modes use snare (`S`)**
   - No “P” voice in v1

---

## Generator Guardrails (V1)

The generator must favor **musical validity over permutation coverage**.

Rules:
- Patterns should feel intentional
- Accents should imply phrasing, not decoration
- Randomness is acceptable only within physical and musical constraints

V1 may include:
- A **small set of canonical / well-known triad sequences**
- Safe variations derived from them

V1 should *not* attempt exhaustive permutation coverage.

---

## What Is Explicitly Out of Scope for V1

V1 does **not** include:

- Genre selection
- Favorites or pattern saving
- Pattern naming or tagging UI
- Advanced rule editors
- Animated drum kits
- DraftX rendering
- Coverage analytics beyond basic use

These are documented separately to avoid scope creep.

---

## Success Criteria for V1

V1 is successful if:

- A drummer can open the app and start practicing in under **5 seconds**
- Patterns feel intentional, not random
- Nothing on screen feels like “settings for the sake of settings”
- The app encourages *playing*, not tweaking

If a drummer forgets they are using an app and just practices, v1 succeeded.

---

## Guardrail

If a future idea requires explanation longer than:

> “This helps you practice triads better”

…it does not belong in v1.
