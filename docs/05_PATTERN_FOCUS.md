# 05 — Pattern Focus (V1)

This document defines how Triad Trainer explains **why a pattern is valuable**.

The goal of Pattern Focus is **orientation, not instruction**.

If a drummer understands *why they are practicing a pattern*, they are far more likely to:
- commit time to it
- stay with it
- play it musically instead of mechanically

---

## Core Principle

> A pattern without context feels random.  
> A pattern with purpose invites commitment.

Pattern Focus exists to answer one question:

> “What am I developing by staying with this pattern?”

---

## What Pattern Focus Is (and Is Not)

### Pattern Focus **is**
- One short, drummer-readable sentence
- Shown before and during practice
- Aligned with physical and musical reality

### Pattern Focus **is not**
- A lesson
- A tutorial
- A breakdown of technique
- A theory explanation

If it takes more than one sentence, it does not belong in v1.

---

## Where Focus Appears in the UI

Pattern Focus appears:
- **Above the notation**
- **Below the kit/pad graphic**

It must be visible **before Play** and remain visible **during practice**.

The focus text is part of the Pattern Card’s identity.

---

## Inputs Used to Generate Focus

Pattern Focus is derived from **known properties** of the pattern:

1. **Limb distribution**
   - Lead hand vs non-lead hand
   - Kick involvement or absence

2. **Presence of doubles**
   - RR or LL patterns
   - Internal vs external doubles

3. **Phrase structure**
   - Repetition
   - Alternation
   - Directional movement

4. **Instrument context**
   - Pad
   - Pad + Kick
   - Kit

5. **User handedness**
   - Right-handed
   - Left-handed

Focus must respect handedness to maintain trust.

---

## Handedness Rules (Mandatory)

Handedness is set once in Settings and used globally.

### Example
For a right-handed drummer:
- LLR → “Develops left-hand control”

For a left-handed drummer:
- LLR → “Develops right-hand control”

Focus must never contradict the drummer’s lived experience.

---

## Focus Categories (V1)

V1 uses a **small, finite set** of focus categories.

Patterns may map to one category only.

### 1) Weak-Hand Development
Triggered by:
- Doubles or density favoring the non-dominant hand
- Non-lead hand initiating phrases

Examples:
- “Develops left-hand control”
- “Strengthens weak-hand doubles”

---

### 2) Internal Double Control
Triggered by:
- LLR / RRL structures
- Doubles occurring mid-cell

Examples:
- “Internal double control”
- “Clean double placement inside phrases”

---

### 3) Lead Control & Alternation
Triggered by:
- Frequent lead switching
- Alternating initiations

Examples:
- “Alternating lead development”
- “Lead-hand awareness”

---

### 4) Hand-to-Kick Coordination
Triggered by:
- Kick interleaved with hand phrases
- Non-obvious kick placement

Examples:
- “Hand-to-kick coordination”
- “Kick integration within phrases”

---

### 5) Flow & Movement (Kit Only)
Triggered by:
- Voice assignment changes
- Phrase motion across kit surfaces

Examples:
- “Moving phrases around the kit”
- “Orchestrated flow development”

---

## Focus Selection Rules

- Every pattern must resolve to **exactly one** focus line
- If multiple categories apply, choose the **most physically dominant**
- If no category is clear, default to:
  - “Triad vocabulary development”

No pattern should ship without a focus.

---

## Static vs Dynamic Focus (V1)

In v1:
- Focus is **static per pattern**
- Focus does not change mid-loop
- Focus does not react to BPM or timer state

Dynamic coaching belongs to later versions.

---

## Voice Labels & Focus Alignment

When instrument context is **Kit**:
- The kit graphic must show **voice labels**
- These labels reinforce the focus visually

Example:
- If focus is “Flow around the kit”
- The diagram shows multiple labeled surfaces

Pattern Focus, voice labels, and the kit graphic must **agree**.

If they contradict each other, the UI has failed.

---

## Language Rules (V1)

Pattern Focus language must be:
- Drummer-native
- Short
- Neutral (not motivational fluff)

Avoid:
- “Improves your chops”
- “Boosts independence”
- “Unlocks mastery”

Prefer:
- “Develops left-hand control”
- “Internal double control”
- “Hand-to-kick coordination”

---

## What Focus Must Never Do

Pattern Focus must never:
- Lecture
- Shame
- Over-promise
- Explain technique

Its job is to **point**, not teach.

---

## V1 Guardrail

If a drummer reads the focus line and thinks:

> “Yeah — that’s what this feels like.”

Then Pattern Focus is working.

If they think:

> “Huh?”

It’s wrong.

---

## Forward Compatibility (Not V1)

Pattern Focus is intentionally compatible with:
- Progress insights
- Pattern tagging
- Session summaries
- DraftX-driven visual feedback

None of those are required to ship v1.

This document defines the minimum bar.
