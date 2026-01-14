# 04 — Modes & Defaults (V1)

This document defines **practice modes** in Triad Trainer.

Modes are not labels.
Modes are **contracts**.

Choosing a mode sets expectations for:
- how patterns feel
- how repetition behaves
- how accents are applied
- how randomness is constrained

The user should never have to “tune” a mode to understand it.

---

## Why Modes Exist

Drummers practice for different reasons at different times.

Sometimes the goal is:
- control
- consistency
- repetition

Other times the goal is:
- flow
- musical continuity
- vocabulary expansion

Modes encode those intentions so the user doesn’t have to.

---

## V1 Modes

V1 ships with **two modes** only:

- **Training**
- **Flow**

No more until these are nailed.

---

## Training Mode

### Purpose
Deliberate skill building.

This mode should feel:
- predictable
- repeatable
- focused

Training mode answers:
> “Help me internalize this.”

Training mode should feel like:
> “Stay here and make this automatic.”

---

### Training Mode Defaults

| Setting | Default |
|------|-------|
| Phrase length | Short |
| Repeats | Higher |
| ∞ loop | Encouraged |
| Accent behavior | Strongly patterned |
| Randomness | Constrained |
| BPM range | Lower-biased |

---

### Training Mode Rules

- Patterns repeat enough to *sink in*
- Accent placement favors clarity over surprise
- Coverage bias is allowed (and later encouraged)
- Canonical patterns are favored over novel ones
- Sudden structural changes are avoided

Training mode should never feel chaotic.

---

### When Training Mode Is Right
- Pad practice
- Pad + kick coordination
- Working on weak limbs
- Locking in accent placement
- Slower tempos

---

## Flow Mode

### Purpose
Musical continuity and movement.

This mode should feel:
- fluid
- musical
- less predictable

Flow mode answers:
> “Help me make this feel like music.”

Flow mode should feel like:
> “Let this move and breathe.”

---

### Flow Mode Defaults

| Setting | Default |
|------|-------|
| Phrase length | Longer |
| Repeats | Lower |
| ∞ loop | Optional |
| Accent behavior | Phrase-based |
| Randomness | Looser (but safe) |
| BPM range | Neutral-to-higher |

---

### Flow Mode Rules

- Patterns should connect naturally
- Accents should imply phrasing
- Abrupt transitions are discouraged
- Canonical patterns may appear as anchors, not drills
- Repetition exists, but does not dominate

Flow mode should feel playable, not instructional.

---

### When Flow Mode Is Right
- Full kit practice
- Orchestration movement
- Groove development
- Musical exploration
- Medium to higher tempos

---

## What Modes Do NOT Control (V1)

Modes do **not**:
- Change instrument context
- Change kit configuration
- Add UI elements
- Expose more controls

Modes operate **under the hood**.

**V1 guardrail:** Modes must never introduce mode-specific UI controls in v1.

---

## Instrument Context vs Mode (Important)

These are separate axes.

### Instrument Context answers:
> *What am I physically playing on?*

- Pad Only
- Pad + Kick
- Kit

This determines:
- limb availability
- voice assignment logic

**V1 default at app launch:** **Pad** (hands only).

---

### Mode answers:
> *What kind of practice am I doing?*

- Training
- Flow

This determines:
- pattern shape
- repetition behavior
- accent logic
- randomness constraints

Either axis can change independently.

---

## Why There Is No “Beginner / Intermediate / Advanced” Mode (Yet)

Skill level is:
- subjective
- tempo-dependent
- context-dependent

For v1:
- BPM is the difficulty knob
- Mode defines *intent*, not skill

Future versions may layer skill profiles on top of modes.

---

## Canonical Vocabulary Integration

Both modes may use canonical triad vocabulary, but differently.

### Training
- Canonical patterns appear frequently
- Repetition is explicit
- Names may be surfaced later

### Flow
- Canonical patterns act as anchors
- Variations may emerge organically
- Labels are less important than feel

---

## V1 Mode Success Criteria

A mode is successful if:
- A drummer can predict how it will *feel*
- Switching modes immediately changes the experience
- No explanation is needed after a few uses

If a mode needs a tooltip to make sense, it’s wrong.

---

## Final V1 Contract

- Two modes
- Clear intent
- Locked defaults
- No UI sprawl

Everything else is a future problem.

V1 wins by being **obvious, musical, and calm**.
