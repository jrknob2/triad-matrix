
# Coach Decision Engine Spec

## Purpose
Translate assessment + history into actionable guidance.

## Inputs
- PracticeAssessmentAggregate
- recent sessions
- workingOn list

## Outputs
Coach Blocks:
- Focus
- Needs Work
- Momentum
- Resume
- Next Unlock

## Rules

### Focus
- active items
- recent unfinished work

### Needs Work
- unstable or slipping items

### Momentum
- recently strong items

### Resume
- interrupted recent session

### Next Unlock
- strong → combo or flow suggestion

## Priority Order
1. Resume
2. Needs Work
3. Focus
4. Momentum
5. Next Unlock

## Tone
Direct, actionable, no fluff.
