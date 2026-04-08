
# Drum App Assessment Architecture Handoff for Codex (Upgraded)
**Supplemental implementation handoff**
**Scope:** Listening/assessment strategy, supported input modes, exact stability/drift calculations, session interview, confidence model, and product boundaries

---

# 1. Decision Summary

The app will support **embedded assessment during practice**.

Assessment is **not** a separate primary workflow. Practice sessions should naturally generate assessment data while the student plays.

However, the system should still support the reality that:
- some users are beginners
- some users are experienced drummers but new to triads
- some users will have practiced outside the app
- some users will self-calibrate immediately by selecting higher BPMs

The assessment model should therefore combine multiple signals instead of relying on a single one.

---

# 2. Supported Assessment Sources

The app should use at least these data sources:

## 2.1 Observed performance during practice
This is the primary source of truth.

Examples:
- attempted BPM
- estimated BPM / timing fit
- stability / drift
- breakdowns
- successful sustained runs
- completion of target duration

This is the most objective signal and should carry the most weight.

## 2.2 User-selected BPM
This is an implicit self-calibration signal.

Why it matters:
- beginners tend to stay low
- experienced players often push tempo immediately
- BPM choice reflects confidence and perceived readiness

This should influence interpretation, but not override observed performance.

## 2.3 End-of-session self-report
This is a secondary subjective signal.

Examples:
- Did it feel controlled?
- Any tension?
- Ready to increase tempo next time?

This captures information audio cannot infer well, such as:
- tension
- fatigue
- confusion
- perceived control

Self-report should inform guidance tone and next-step aggressiveness, but should not override poor observed performance.

---

# 3. Supported Input Modes

## 3.1 Single-surface assessment
This is the primary supported assessment mode.

It should work for:
- pad practice
- snare practice
- practice on a single consistent surface
- simple hands-only or kick-included repetitions where onset timing is still clear enough

This mode should drive the first production-ready assessment engine.

## 3.2 E-drum flow assessment
This is a future extension and should remain architecturally possible.

Reason:
- cleaner signal
- possibly discrete event or MIDI data
- higher confidence onset timing
- better chance of inferring routing/orchestration

This is the most realistic future path for multi-surface flow assessment.

## 3.3 Acoustic kit analysis
The product will **not** pursue special audio processing for acoustic kit flow analysis.

This is a deliberate boundary.

Reason:
- too much signal ambiguity
- too much bleed / decay / room dependence
- low confidence note attribution
- higher risk of false guidance
- too much complexity relative to product value

Codex should treat this as an explicit non-goal unless the product direction changes later.

---

# 4. Product Boundary

## Supported now
- Embedded assessment during Practice Session
- Single-surface listening
- Session-end interview
- Derived status classification
- Coach recommendations based on assessment results

## Future-capable but not current scope
- E-drum flow assessment
- event/MIDI-based orchestration-aware assessment

## Explicit non-goal
- special-purpose acoustic kit flow analysis
- storing raw audio from practice sessions
- long-term audio archive
- heavy forensic waveform review UI

---

# 5. Data Retention Policy

## 5.1 Raw audio
Do **not** store raw audio from practice sessions.

Reasons:
- unnecessary storage growth
- unnecessary privacy burden
- not required for the guidance loop
- increases implementation complexity

## 5.2 Buffering policy
Use a bounded **FIFO rolling window** just large enough for the relevant assessment logic.

The engine should:
- keep only the short-term signal needed for analysis
- continuously discard old raw frames
- persist only derived metrics and summaries

## 5.3 Persisted data
Persist:
- summary assessment metrics
- confidence scores
- status classification inputs/outputs
- aggregate progress values per practice item / triad / combo

Do not persist:
- full audio recordings
- long waveform history
- large raw signal buffers

---

# 6. Assessment Architecture

Recommended internal structure:

```text
core/
  assessment/
    assessment_models
    practice_assessment_service
    single_surface_assessment_engine
    session_interview_service
    assessment_classifier
    assessment_persistence
    flow_assessment_engine_stub
```

## 6.1 `practice_assessment_service`
Coordinates the full assessment lifecycle:
- start listening when session starts
- feed buffers into engine
- collect rolling metrics
- finalize session summary
- combine with session interview
- produce a single assessment result

## 6.2 `single_surface_assessment_engine`
Responsible for:
- rolling-window analysis
- onset/event timing inference
- stability / drift / continuity metrics
- success/failure/breakdown detection

This is the first real implementation target.

## 6.3 `session_interview_service`
Owns:
- end-of-session questions
- response normalization
- interview result model

## 6.4 `assessment_classifier`
Maps raw/derived metrics into:
- notStarted
- active
- needsWork
- strong

This should be shared by Coach and Matrix status logic where appropriate.

## 6.5 `flow_assessment_engine_stub`
Keep a future-facing interface boundary for e-drum flow assessment, but do not implement full acoustic flow logic.

---

# 7. Recommended Assessment Result Model

Suggested persisted result contract:

~~~ts
export interface SessionAssessmentResult {
  sessionId: string;
  practiceItemId: string;
  mode: 'singleSurface' | 'flow';
  inputType: 'singleSurfaceAudio' | 'eDrumAudio' | 'eDrumMidi';
  confidence: 'low' | 'medium' | 'high';

  attemptedBpm: number;
  estimatedBpm?: number;

  stabilityScore: number;   // 0.0–1.0, higher = better
  driftScore: number;       // 0.0–1.0, higher = worse
  jitterScore: number;      // 0.0–1.0, higher = worse local inconsistency
  continuityScore: number;  // 0.0–1.0, higher = better

  breakdownCount: number;
  successfulRunCount: number;

  completedTargetDuration: boolean;

  selfReportControl?: 'low' | 'medium' | 'high';
  selfReportTension?: 'none' | 'some' | 'high';
  selfReportTempoReadiness?: 'decrease' | 'same' | 'increase';

  assessedAt: string;
}
~~~

Suggested aggregate model:

~~~ts
export interface PracticeAssessmentAggregate {
  practiceItemId: string;

  lastAssessmentAt?: string;
  recentAttemptedBpm?: number;
  recentStableBpm?: number;
  bestStableBpm?: number;

  averageStabilityScore?: number;
  averageDriftScore?: number;
  averageJitterScore?: number;
  averageContinuityScore?: number;
  recentBreakdownRate?: number;

  confidenceWeightedStatus: 'notStarted' | 'active' | 'needsWork' | 'strong';
}
~~~

---

# 8. Assessment Weighting Model

Use a weighted blend of signals.

## 8.1 Observed performance
Primary weight.

Recommended conceptual weight:
- 70% to 80%

## 8.2 User-selected BPM
Secondary implicit weight.

Recommended conceptual weight:
- 10% to 15%

## 8.3 End-of-session self-report
Secondary subjective weight.

Recommended conceptual weight:
- 10% to 20%

Important:
- self-report does not override poor observed performance
- BPM choice informs confidence and ambition, not mastery by itself

---

# 9. Confidence Model

Assessment confidence must be explicit.

Why:
- some signals are cleaner than others
- future e-drum data may be high-confidence
- some sessions may have weak or noisy detection

Use confidence values such as:
- low
- medium
- high

Coach and classifier logic should respect confidence.

Examples:
- low confidence → softer recommendation, avoid overclaiming
- high confidence → stronger status update / next-step suggestion

---

# 10. Session Interview

## 10.1 Product guidance
Keep the session-end interview very short.

Goal:
- capture missing subjective context
- avoid annoying the user

## 10.2 Recommended questions
Use 2–3 quick prompts maximum.

Examples:
1. **How controlled did it feel?**
   - Low
   - Medium
   - High

2. **Any tension?**
   - None
   - Some
   - A lot

3. **Next time tempo?**
   - Slow down
   - Stay here
   - Speed up

## 10.3 Rules
- interview should happen at session end, not interrupt the flow mid-session
- responses should be optional but encouraged
- defaults should not silently bias toward success

---

# 11. Exact Stability / Drift / Jitter / Continuity Calculations

These calculations are for the **single-surface assessment engine**.

They are intentionally practical and robust, not research-grade. The goal is stable coaching signals, not lab-perfect music information retrieval.

## 11.1 Required engine inputs

The engine should operate on detected hit events:

~~~ts
export interface HitEvent {
  timestampMs: number;
  confidence: number; // 0.0–1.0
}
~~~

And the session target:

~~~ts
export interface SessionTarget {
  attemptedBpm: number;
  targetDurationSeconds?: number;
}
~~~

## 11.2 Pre-processing rules

Before computing metrics:

1. Sort events by `timestampMs`
2. Remove duplicate detections that occur too close together
3. Ignore very-low-confidence hits
4. Compute inter-onset intervals (IOIs)

### Recommended constants

~~~ts
export const MIN_HIT_CONFIDENCE = 0.35;
export const DUPLICATE_HIT_WINDOW_MS = 35;
export const MIN_EVENTS_FOR_SCORING = 8;
~~~

### Duplicate suppression
If two hits are within `DUPLICATE_HIT_WINDOW_MS`, keep only the one with higher confidence.

### Event sufficiency
If fewer than `MIN_EVENTS_FOR_SCORING` events remain:
- confidence should be low
- metrics may still be produced, but should be treated as weak evidence

## 11.3 Core derived series

### Inter-onset intervals (IOIs)

For sorted hit timestamps `t[0..n-1]`:

~~~ts
ioi[i] = t[i] - t[i - 1]   // for i = 1..n-1
~~~

### Target interval

~~~ts
targetIntervalMs = 60000 / attemptedBpm
~~~

This assumes one expected hit per beat for assessment purposes. That is acceptable for the MVP because the engine is evaluating stability relative to the chosen pulse, not validating the exact sticking grammar.

## 11.4 Jitter calculation

Jitter reflects **local inconsistency** from hit to hit.

### Step 1: absolute IOI error from target

~~~ts
ioiError[i] = abs(ioi[i] - targetIntervalMs)
~~~

### Step 2: normalized per-interval error

Clamp error so outliers do not explode the score:

~~~ts
normalizedIoiError[i] = min(ioiError[i] / targetIntervalMs, 1.0)
~~~

### Step 3: weighted mean jitter

Weight each interval by the lower confidence of the two adjacent hits:

~~~ts
intervalWeight[i] = min(confidence[i], confidence[i - 1])
weightedMeanJitter = sum(normalizedIoiError[i] * intervalWeight[i]) / sum(intervalWeight[i])
~~~

### Step 4: jitter score

~~~ts
jitterScore = clamp(weightedMeanJitter, 0.0, 1.0)
~~~

Interpretation:
- `0.0` = extremely even
- `1.0` = extremely uneven

## 11.5 Drift calculation

Drift reflects **tempo bias over a window**, not local hit-to-hit variation.

A player can have low jitter but still drift faster or slower than target.

### Step 1: rolling window median IOI
Use a rolling odd-sized window to smooth local variation.

Recommended window:
- 5 intervals

~~~ts
rollingMedianIoi[k] = median(ioi[k-2], ioi[k-1], ioi[k], ioi[k+1], ioi[k+2])
~~~

At edges, use smaller valid windows.

### Step 2: convert rolling median IOI to rolling BPM

~~~ts
rollingBpm[k] = 60000 / rollingMedianIoi[k]
~~~

### Step 3: normalized BPM deviation from target

~~~ts
rollingDrift[k] = min(abs(rollingBpm[k] - attemptedBpm) / attemptedBpm, 1.0)
~~~

### Step 4: weighted mean drift

Weight each rolling value by the average confidence of the hits contributing to that window.

~~~ts
driftScore = weightedMean(rollingDrift, rollingWindowConfidence)
~~~

Interpretation:
- `0.0` = locked to target pulse
- `1.0` = severe tempo drift

## 11.6 Stability calculation

Stability should reward:
- low jitter
- low drift
- decent continuity

It is the main positive score.

### Step 1: compute continuity score first
See section 11.7.

### Step 2: combine components

Recommended weighted combination:

~~~ts
stabilityScore =
  clamp(
    1.0
    - (0.50 * jitterScore)
    - (0.30 * driftScore)
    - (0.20 * (1.0 - continuityScore)),
    0.0,
    1.0
  )
~~~

Interpretation:
- `1.0` = highly stable
- `0.0` = very unstable

Why these weights:
- local evenness matters most
- tempo drift matters next
- continuity matters too, but should not dominate

## 11.7 Continuity calculation

Continuity measures whether the player sustained the pattern without large gaps or collapses.

### Step 1: define breakdown gap threshold

A likely breakdown occurs if an IOI is too large relative to target:

~~~ts
BREAKDOWN_GAP_MULTIPLIER = 1.85
isBreakdownGap(ioi) = ioi > targetIntervalMs * BREAKDOWN_GAP_MULTIPLIER
~~~

### Step 2: breakdown count

~~~ts
breakdownCount = count(ioi where isBreakdownGap(ioi))
~~~

### Step 3: successful runs
A successful run is a consecutive set of intervals between breakdowns of at least this length:

~~~ts
MIN_SUCCESSFUL_RUN_EVENTS = 8
~~~

Count contiguous segments separated by breakdowns. If a segment contains at least `MIN_SUCCESSFUL_RUN_EVENTS` hits, count it as one successful run.

### Step 4: continuity score

Use the proportion of non-breakdown intervals:

~~~ts
continuityScore =
  clamp(
    1.0 - (breakdownCount / max(ioiCount, 1)),
    0.0,
    1.0
  )
~~~

Interpretation:
- `1.0` = no major continuity collapses
- lower values = more breakdowns

## 11.8 Estimated BPM calculation

Estimated BPM should not use raw mean IOI, because outliers distort it.

Use median IOI:

~~~ts
estimatedBpm = 60000 / median(ioi)
~~~

If event count is low, still compute it, but lower confidence.

## 11.9 Confidence calculation

Confidence should reflect signal trustworthiness.

### Inputs
- event count
- mean hit confidence
- proportion of suppressed duplicates
- proportion of intervals marked as extreme outliers

### Suggested rules

#### Low confidence
Return `low` if any of these are true:
- remaining event count < 8
- mean hit confidence < 0.45
- more than 25% of candidate hits were removed as duplicates/noise
- outlier interval rate > 35%

#### High confidence
Return `high` if all of these are true:
- remaining event count >= 20
- mean hit confidence >= 0.70
- duplicate/noise removal rate < 10%
- outlier interval rate < 15%

#### Otherwise
Return `medium`

## 11.10 Outlier interval definition

Use outlier intervals for confidence only, not direct classification:

~~~ts
isOutlierInterval(ioi) =
  ioi < targetIntervalMs * 0.35 ||
  ioi > targetIntervalMs * 2.25
~~~

This prevents absurd timing artifacts from pretending to be valid hits.

## 11.11 Completed target duration

~~~ts
completedTargetDuration =
  targetDurationSeconds is defined &&
  performedDurationSeconds >= targetDurationSeconds
~~~

Where:

~~~ts
performedDurationSeconds = (lastTimestampMs - firstTimestampMs) / 1000
~~~

## 11.12 Recommended metric thresholds for classification

These values align with the broader status classification rules.

### Strong candidate
- `stabilityScore >= 0.80`
- `driftScore <= 0.40`
- `jitterScore <= 0.25`
- `continuityScore >= 0.90`
- low breakdown rate
- medium or high confidence

### Needs-work candidate
- `stabilityScore < 0.50`
- or `driftScore >= 0.45`
- or `jitterScore >= 0.40`
- or repeated breakdowns / poor continuity

### Active
Everything in between.

## 11.13 Recommended TypeScript contract

~~~ts
export interface SingleSurfaceMetrics {
  attemptedBpm: number;
  estimatedBpm: number;

  stabilityScore: number;
  driftScore: number;
  jitterScore: number;
  continuityScore: number;

  breakdownCount: number;
  successfulRunCount: number;
  completedTargetDuration: boolean;

  confidence: 'low' | 'medium' | 'high';
}

export function computeSingleSurfaceMetrics(
  events: HitEvent[],
  target: SessionTarget
): SingleSurfaceMetrics;
~~~

## 11.14 Reference pseudocode

~~~ts
function computeSingleSurfaceMetrics(
  rawEvents: HitEvent[],
  target: SessionTarget
): SingleSurfaceMetrics {
  const filtered = suppressDuplicatesAndLowConfidence(rawEvents);
  const attemptedBpm = target.attemptedBpm;
  const targetIntervalMs = 60000 / attemptedBpm;

  if (filtered.length < 2) {
    return {
      attemptedBpm,
      estimatedBpm: attemptedBpm,
      stabilityScore: 0,
      driftScore: 1,
      jitterScore: 1,
      continuityScore: 0,
      breakdownCount: 0,
      successfulRunCount: 0,
      completedTargetDuration: false,
      confidence: 'low',
    };
  }

  const iois = computeIois(filtered);
  const estimatedBpm = 60000 / median(iois);

  const jitterScore = computeJitterScore(iois, filtered, targetIntervalMs);
  const driftScore = computeDriftScore(iois, filtered, attemptedBpm);
  const { breakdownCount, successfulRunCount, continuityScore } =
    computeContinuity(iois, targetIntervalMs);

  const stabilityScore = clamp(
    1
      - (0.50 * jitterScore)
      - (0.30 * driftScore)
      - (0.20 * (1 - continuityScore)),
    0,
    1
  );

  const completedTargetDuration =
    target.targetDurationSeconds != null &&
    ((filtered[filtered.length - 1].timestampMs - filtered[0].timestampMs) / 1000) >= target.targetDurationSeconds;

  const confidence = computeConfidence(filtered, iois, targetIntervalMs);

  return {
    attemptedBpm,
    estimatedBpm,
    stabilityScore,
    driftScore,
    jitterScore,
    continuityScore,
    breakdownCount,
    successfulRunCount,
    completedTargetDuration,
    confidence,
  };
}
~~~

---

# 12. Classification Logic Principles

Do not classify mastery by time alone.

Do not define strong/needsWork merely by:
- session count
- total minutes
- calendar days

Use performance thresholds and multi-signal agreement.

## 12.1 Strong
Should generally require:
- stable observed performance
- repeated acceptable sessions
- reasonable tempo control
- no strong negative self-report contradiction

## 12.2 Needs Work
Should generally indicate:
- instability
- repeated breakdowns
- slipping from prior stability
- active struggle confirmed by data and/or self-report

## 12.3 Active
Use when:
- student is engaged and improving
- not yet clearly strong
- not purely failing
- mixed signals suggest ongoing development

Untouched material should not default to needsWork. It should remain notStarted or neutral.

---

# 13. How Coach Should Use Assessment Data

Coach should be driven by derived assessment results.

## Focus
Use:
- active current work
- balanced practice recommendation
- recent unfinished work

## Needs Work
Use:
- slipping or unstable practiced items
- repeated breakdown patterns
- underperforming active material

## Momentum / Strong
Use:
- stable recent performance
- repeated successful sessions
- rising tempo range or stability

## Next Unlock
Use:
- stable triads ready to combine
- strong single-surface work ready to expand
- right-side strength ready for balancing work, etc.

---

# 14. How Matrix Should Use Assessment Data

Matrix should project assessment state into visual cell states without losing the existing structural filter system.

Progress state mapping remains:
- neutral/off-white/gray = not trained
- blue = active
- orange-red = needs work
- green = strong

Selection state remains separate from progress state and should use:
- border
- checkmark
- ordered badge
- slight lift

Assessment aggregates should feed the progress state, not replace the matrix’s filtering/grouping model.

---

# 15. UI Guidance for Practice Session

Assessment should be embedded in the practice experience, but not dominate it.

## During session
Keep feedback subtle.

Possible micro-states:
- Listening
- Stable
- Drifting
- Good run

Avoid harsh or test-like language during active practice.

## After session
Show a short summary such as:
- Stability: improving
- Tempo: solid at 72 BPM
- Recommendation: stay here / increase slightly / clean up before pushing

Then optionally collect the interview responses.

---

# 16. Non-Goals

Codex should treat these as explicit non-goals unless told otherwise:

- acoustic-kit-specific special processing
- persistent audio recording
- waveform archive/history browser
- high-complexity audio forensics UI
- pass/fail “exam mode” as the primary learning loop

---

# 17. Recommended Build Order

1. Define assessment models and contracts
2. Implement bounded FIFO rolling-window handling
3. Implement `single_surface_assessment_engine`
4. Implement exact stability/drift/jitter/continuity metric calculations
5. Implement session-end interview service
6. Implement assessment result persistence
7. Implement assessment classifier
8. Feed assessment aggregates into Coach selectors
9. Feed assessment aggregates into Matrix progress state
10. Add subtle in-session status indicator
11. Add end-of-session summary + interview

---

# 18. Engineering Checklist

## Architecture
- [ ] Assessment service created
- [ ] Single-surface engine created
- [ ] Session interview service created
- [ ] Classifier created
- [ ] Persistence stores results only, not raw audio

## Metrics
- [ ] IOI extraction implemented
- [ ] duplicate suppression implemented
- [ ] jitter calculation implemented
- [ ] drift calculation implemented
- [ ] continuity calculation implemented
- [ ] confidence model implemented

## Data retention
- [ ] FIFO rolling analysis window used
- [ ] raw audio discarded after analysis
- [ ] only summary results persisted

## Product boundaries
- [ ] acoustic kit special analysis excluded
- [ ] future e-drum flow path left possible but not required now

## Integration
- [ ] practice session runs assessment
- [ ] session-end interview captured
- [ ] Coach uses assessment outputs
- [ ] Matrix colors reflect classified status

---

# 19. Final Summary

The assessment system should be:

- embedded in practice
- driven primarily by observed performance
- adjusted by BPM choice and short self-report
- implemented with bounded rolling analysis buffers
- persisted as metrics/results only
- explicitly non-dependent on acoustic-kit special processing

The metric layer should use:
- IOIs for timing analysis
- jitter for local evenness
- drift for tempo bias
- continuity for breakdown resilience
- stability as the combined positive signal

This gives the app a practical, privacy-light, and technically disciplined path to intelligent guidance.
