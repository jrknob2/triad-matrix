# Triad Trainer

Triad Trainer helps drummers internalize triad stickings by practicing **physically realistic**, **musically intentional** patterns — not random permutations.

The goal is to build **usable drumming vocabulary** through focused repetition and flow, using:
- clear visual cues
- a click
- a timer
- minimal, intent-driven controls

Triad Trainer is a **practice tool**, not a composition tool.

---

## Core principles

### 1) Intent-first design (not feature-first)

The app should feel like sitting down to practice.

- **While playing:** only essentials (Play, BPM ±, Click, Timer).
- **Before playing:** choose what you’re practicing *on* and *for*.
- No deep settings panels. No configuration fatigue.

---

### 2) Musically valid generation (constraints > randomness)

All generated patterns must respect drummer reality:

- **Doubles never jump voices**  
  RR or LL always stay on the same surface.
- **No impossible orchestration**
- **Accents imply phrasing**, not decoration
- **Kick is a first-class limb** and may be accented

If a real drummer would question it, it’s wrong.

---

### 3) Vocabulary over permutations

Randomness is only useful when anchored to musical language.

- Canonical / well-known triad phrases are blended into generation.
- Variations explore *around* vocabulary, not away from it.
- Coverage is for coaching insight, not scoring (hidden in v1).

---

## Surface vs Intent (key concept)

Triad Trainer separates two ideas that are often conflated:

- **Surface** → *What am I physically practicing on?*
- **Intent** → *What am I trying to develop?*

They are related, but not interchangeable.

---

## Surface (physical reality)

Surface defines what limbs and ideas are physically available.

### Pad
- Hands only
- No kick
- No orchestration
- All notes treated as snare-equivalent

### Pad + Kick
- Hands + kick
- Still no orchestration
- Kick participates musically

### Kit
- Hands + kick
- Full orchestration
- Movement and flow enabled

Surface is always explicit and always respected.

---

## Intent (practice goal)

Intent defines *how* patterns are generated and felt.

### Training
Purpose: control, consistency, clarity.
- Shorter phrases
- More repetition (supports ∞)
- Predictable accent anchors
- Designed for deliberate practice

### Flow
Purpose: musical continuity and movement.
- Longer phrases
- Fewer hard resets
- Accent displacement
- Feels like grooves, not drills

---

## Valid Surface × Intent combinations

Not all combinations make sense, and the app enforces this.

| Surface     | Training | Flow |
|------------|----------|------|
| Pad        | ✅ Yes   | ❌ No |
| Pad + Kick | ✅ Yes   | ❌ No |
| Kit        | ✅ Yes   | ✅ Yes |

Flow requires orchestration. Orchestration requires a kit.

---

## Voice assignment rules

### Should every note have a voice?
**Yes — internally, always.**

Every R / L / K maps to a surface so patterns are unambiguous.

### Rendering rules (v1)
- Pad modes show **no voice labels**
- Kit mode assigns voices consistently
- **Doubles rule is non-negotiable**:
  - RR / LL always stay on the same voice

Pad defaults to **Snare (S)** conceptually — never “P”.

---

## Accents & ghost notes

- Accents are shown with `^`
- Unaccented notes are ghost notes
- Default rendering: **fully opaque** (no fading)
- Optional ghost-fade toggle may come later

Footer copy (v1):

**Accents are marked with `^` · Unaccented notes are ghost notes**

---

## Generator rules (non-negotiable)

These rules preserve drummer trust:

1. No voice hopping on doubles  
2. Consistent per-limb mapping within a cell  
3. Kick may be accented  
4. Canonical phrases blended into generation  
5. No ambiguous or partial voice labeling  

If something looks confusing, it’s a bug.

---

## What Triad Trainer v1 is

- A lightweight daily practice tool
- Focused on triads only
- Fast to start, easy to repeat
- Designed for pads *and* kits

## What Triad Trainer v1 is NOT

- A DAW
- A groove library
- A notation editor
- A genre simulator
- A pattern manager

---

## Transport & timing (v1)

### Transport
- Play
- BPM – / +
- Click (metronome)

Nothing else.

### Timer
Essential for beginners.
- Start / Stop / Reset
- Starts automatically with Play
- Presets: 5 / 10 / 30 minutes + ∞

---

## Roadmap (high level)

### V1 (ship)
- Pad / Pad+Kick / Kit surfaces
- Training + Flow intent
- Click + timer
- Canonical + rule-safe generation
- Clear accents and unambiguous patterns

### V1.5
- Coverage insights (hidden coaching)
- Expanded canonical vocabulary
- Better flow heuristics

### V2 concept (DraftX integration)
- Visual drum kit diagram
- Color-coded orchestration
- Animated surfaces during playback
- Pattern-driven visuals via DraftX

---

## Design ethos

- Drummer-first logic
- Physical reality before abstraction
- Constraints over options
- Clarity over cleverness

If it feels confusing, it should be simplified.
