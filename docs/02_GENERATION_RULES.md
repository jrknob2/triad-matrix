# 02 — Generation Rules (V1)

This document defines **what makes a generated pattern valid** in Triad Trainer v1.

If a pattern violates any rule in this document, it is **invalid**, even if it is mathematically correct.

These rules exist to preserve **physical realism**, **musical sense**, and **drummer trust**.

---

## Core Principle

> The generator must behave like a drummer would think — not like a combinatorics engine.

Randomness is allowed **only within boundaries that preserve intent**.

---

## Fundamental Definitions

### Triad Cell
A triad cell is a 3-note limb sequence:
- Examples: `RLR`, `LLR`, `RKK`
- A pattern is built from **cells**, not isolated notes

All generation operates at the *cell* level first, not note-by-note.

---

### Phrase
A phrase is an ordered list of triad cells:
- Example: `(RLL → LRR)`
- Phrases may repeat or loop

Phrasing is intentional and mode-driven — not arbitrary.

---

## Limb Scope Rules

Limb scope is determined by **instrument context**, not by mode or random choice.

### Hands Only
- Allowed limbs: `R`, `L`
- Kick (`K`) must never appear
- All generation logic must respect this scope

### Hands + Kick
- Allowed limbs: `R`, `L`, `K`
- Kick may appear anywhere unless restricted by other rules

Violating limb scope immediately invalidates a pattern.

---

## Non-Negotiable Musical Rules

These rules are **hard constraints**.

### 1) No Voice Hopping on Doubles
If two adjacent notes use the same limb:
- They **must remain on the same voice**

Examples:
- `RR` → same surface
- `LL` → same surface
- `KK` → same surface

Any pattern that violates this rule is invalid.

---

### 2) Consistent Limb → Voice Mapping Within a Phrase
Within a single phrase:
- Limb-to-voice mapping must be coherent
- Voice changes must feel intentional, not random

This does **not** mean voices never change.
It means they must change in a way that a drummer could physically execute and understand.

If the UI implies impossible or confusing motion, the pattern is invalid.

---

### 3) Accents Are Musical, Not Decorative
Accents exist to imply phrasing.

Rules:
- Accents may apply to **any limb**, including kick
- Accents must align with phrase structure
- Accent density is controlled by mode defaults

Random or excessive accenting invalidates a pattern.

---

### 4) Every Note Has a Voice (Internally)
Even if the UI does not render every label:
- Every note maps to a voice in the model
- This guarantees deterministic behavior for future audio and visualization

Rendering is optional. Assignment is not.

---

## Phrase Construction Rules (V1)

### Cell Selection
- Cells must respect limb scope
- Cell repetition is allowed when it serves phrasing
- Excessive repetition without musical intent is discouraged

Cells are chosen to support *practice value*, not novelty.

---

### Phrase Length
Phrase length is a **mode responsibility**.

- **Training Mode**
  - Shorter phrases
  - Higher repetition
  - Stability over surprise

- **Flow Mode**
  - Longer phrases
  - Fewer hard resets
  - Encourages motion and continuity

Phrase length must never be purely random.

---

## Canonical Vocabulary (V1 Lite)

V1 supports a **small embedded vocabulary** of known, musically useful triad patterns.

Examples (illustrative, not exhaustive):
- `RLL RRL`
- `LRR LLR`
- Alternating doubles
- Paradiddle-adjacent triad groupings

Rules:
- Canonical patterns may be injected directly
- Generated patterns may be derived from canonical ones
- Canonical material should appear often enough to feel familiar

These patterns may be unnamed in v1, but they must be recognizable to experienced drummers.

---

## Random Generation (Constrained)

Random generation is allowed only if:
- All rules above are satisfied
- The result does not feel arbitrary
- The pattern could plausibly be practiced or played musically

Randomness explores **variation**, not invention.

If a pattern feels like it needs explanation, it failed.

---

## Repetition & Looping

### Finite Repeats
- Shown as `× N`
- Used primarily in Flow Mode

### Infinite Loop
- Shown as `∞`
- Used primarily in Training Mode
- Indicates “stay here and work”

Looping is a **practice signal**, not a playback trick.

---

## Things the Generator Must Never Do

The generator must never:
- Assign different voices to a double
- Accent everything
- Produce patterns that imply impossible limb motion
- Treat kick as a special-case “non-musical” limb
- Generate patterns that require explanation to justify

If a pattern needs justification, it is invalid.

---

## V1 Guardrail

When in doubt, prefer:
- simpler
- more repetitive
- more musical
- more familiar

A boring pattern that makes sense is better than a clever one that doesn’t.

---

## Forward Compatibility (Not V1 Scope)

This rule set is intentionally compatible with:
- Animated kit visualization
- DraftX integration
- Audio rendering
- Pattern tagging and naming

None of those are required to ship v1.

The rules above are.
