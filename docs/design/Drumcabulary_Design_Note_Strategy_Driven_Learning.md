# Drumcabulary Design Note

## Subject

**From Static Lessons to Strategy-Driven Learning**

**Status:** Concept Exploration (July 2026)

---

# Background

While designing the next-generation MIDI Pattern Capture workflow, a broader architectural idea emerged.

Originally, the discussion centered around capturing repeatable drum patterns from MIDI input. As we explored how to accurately recognize triplets, sticking patterns, and other musical concepts, it became clear that the recorder should not attempt to infer every aspect of a performance.

Instead, the author should provide musical context, allowing the recorder to verify and capture the intended performance rather than guess it.

That realization led to a much larger question:

> **Should Drumcabulary be built around stored drum patterns, or around the strategies used to teach drumming?**

---

# Key Insight

Patterns are examples.

They are **not** the curriculum.

The true authored asset is the **teaching strategy**.

Exercises become generated realizations of that strategy.

Instead of authoring hundreds of individual patterns, the author defines:

- what concept is being taught
- how it should be introduced
- how difficulty progresses
- what variations are acceptable
- how mastery is evaluated

The system then generates practice material from those rules.

---

# Current Model

Current thinking:

```text
Lesson
    ↓
Exercise
    ↓
Pattern
```

Every variation must be authored individually.

---

# Proposed Model

```text
Technical Skill
        ↓
Teaching Strategy
        ↓
Exercise Generator
        ↓
Generated Pattern
```

The generator produces an unlimited number of exercises while preserving the educational objective.

Patterns become output rather than authored content.

---

# Vocabulary Model

The discussion naturally separated drumming into three complementary vocabularies.

## Musical Vocabulary

Describes **what is being played.**

Examples:

- Money Beat
- Shuffle
- Train Beat
- Four-on-the-Floor
- Bossa Nova
- Jazz Ride Pattern
- Linear Groove

These are musical ideas.

---

## Technical Vocabulary

Describes **how it is physically executed.**

Examples:

- Alternating sticking
- Doubles
- Paradiddle
- Double Paradiddle
- Triple Paradiddle
- Six Stroke Roll
- RLL
- LRR
- Flam
- Drag
- Buzz Roll

These are execution techniques.

---

## Expressive Vocabulary

Describes **how the music is shaped.**

Examples:

- Ghost notes
- Accents
- Dynamics
- Open hi-hat
- Rimshots
- Cross-stick
- Orchestration

These modify the musical expression without fundamentally changing the underlying groove.

---

# Lessons Teach Concepts, Not Patterns

Consider the Money Beat.

A lesson might teach:

- backbeat
- eighth-note subdivision
- alternating sticking

Exercises may include:

- standard Money Beat
- additional kick notes
- open hi-hat variations
- crash on beat one
- ghost-note variations
- tom orchestrations

These are different exercises.

They are **not** different lessons.

The learning objective remains unchanged.

The variation exists to build fluency rather than introduce a new concept.

---

# Implications for MIDI Pattern Capture

The MIDI recorder should become a guided authoring assistant rather than a transcription engine.

The author supplies framing information such as:

- time signature
- pattern length
- tempo
- count-in
- optionally technique vocabulary

Examples:

```text
4/4
4 measures
90 BPM
Alternating sticking
Measure 4 uses RLL Triplets
```

The recorder then verifies and captures the performance.

It no longer needs to infer information that cannot be reliably determined from MIDI alone.

---

# Technique Vocabulary Library

Instead of asking authors to enter arbitrary sticking strings, Drumcabulary could maintain a reusable Technique Vocabulary.

Example entries:

- Alternating
- Doubles
- Paradiddle
- Double Paradiddle
- Triple Paradiddle
- Six Stroke Roll
- RLL Triplet
- LRR Triplet
- Flam
- Drag
- Buzz Roll

Each technique defines canonical information such as:

- sticking
- default subdivision
- default accent pattern
- aliases
- difficulty
- teaching metadata

Lessons, generators, capture, search, and assessment all reference the same vocabulary.

---

# Strategy-Driven Lesson Generation

Rather than storing:

```text
Exercise 1
Exercise 2
Exercise 3
Exercise 4
```

store:

```text
Teaching Strategy
```

For example:

```text
Money Beat

Strategy

• introduce quarter-note hats
• add backbeat
• introduce kick
• increase subdivision
• vary kick placement
• introduce open hats
• introduce ghost notes
• randomize kick placement while preserving the backbeat
```

The system generates exercises automatically.

---

# The Lesson Becomes an Algorithm

Instead of authoring:

```text
Pattern
Pattern
Pattern
Pattern
```

the author creates:

```text
Teaching progression
```

Exercises become generated instances.

This dramatically reduces authored content while increasing variety and replay value.

---

# Learning Philosophies

Separate:

**What is taught**

from

**How it is taught**

Every drum educator generally teaches similar concepts:

- grooves
- rudiments
- dynamics
- fills
- timing
- coordination

The primary difference lies in the instructional progression.

Examples:

One philosophy may teach:

- paradiddles first
- then grooves
- then fills

Another may teach:

- grooves first
- rudiments later
- song application throughout

Both teach the same vocabulary.

Only the progression changes.

---

# Learning Philosophy Engine

Conceptually:

```text
Drumming Vocabulary
        ↓
Learning Philosophy
        ↓
Exercise Generator
        ↓
Student
```

A Learning Philosophy determines:

- sequencing
- progression
- repetition
- tempo advancement
- randomness
- mastery thresholds
- review cadence
- remediation

The Drumcabulary engine provides:

- notation
- MIDI
- LED guidance
- assessment
- rendering
- exercise generation

The philosophy determines how these capabilities are used.

---

# Commercial Possibility

A long-term opportunity emerged during the discussion.

Instead of distributing static lesson libraries, respected educators could distribute their **Learning Philosophy**.

Conceptually:

```text
Teacher's Learning Philosophy
        ↓
Drumcabulary Engine
        ↓
Personalized Generated Exercises
```

Students receive the teacher's instructional approach while benefiting from dynamically generated practice material.

This would allow educators to distribute methodology rather than collections of fixed exercises.

**Note:** Any implementation involving real educators would require their participation and appropriate licensing or partnership agreements. The architectural concept is independent of any specific instructor.

---

# Relationship to the Curriculum Compass

This architecture aligns naturally with the Curriculum Compass.

Vocabulary becomes prerequisite knowledge.

Example:

```text
Money Beat

Requires

✓ Backbeat
✓ Alternating Sticking
✓ Eighth Notes
```

Another lesson may require:

```text
Requires

✓ Money Beat
✓ Ghost Notes
✓ Open Hi-Hat
```

The curriculum engine can therefore recommend future lessons based upon mastered vocabulary rather than static lesson completion.

---

# Future Architecture

A possible long-term architecture:

```text
Vocabulary
        ↓
Teaching Strategy
        ↓
Exercise Generator
        ↓
Pattern
        ↓
Notation
        ↓
MIDI
        ↓
LED Guidance
        ↓
Assessment
```

Patterns are no longer the authored source.

They become generated artifacts.

---

# Open Questions

- How should a Teaching Strategy be represented?
  - DSL?
  - JSON?
  - Dart objects?
- What concepts are immutable?
- What concepts are generated?
- How much randomness is appropriate before an exercise no longer teaches the intended skill?
- Can learning strategies adapt automatically to student performance?
- How should vocabulary integrate with Curriculum Compass progression?
- How should authors create and test new learning philosophies?
- What tooling is required to author generators rather than static lessons?

---

# Guiding Principle

Drumcabulary should evolve from:

> **A library of drum patterns**

into:

> **A drum learning engine.**

The enduring authored content is not notation.

It is:

- vocabulary
- teaching strategy
- learning philosophy

From those foundations, the system generates:

- notation
- exercises
- MIDI playback
- LED guidance
- assessment
- personalized practice

The goal is not to teach students to memorize patterns.

The goal is to help them acquire the vocabulary, grammar, and creative fluency of the language of drumming.