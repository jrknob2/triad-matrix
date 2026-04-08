
# Onset Detection Spec (Single Surface)

## Purpose
Detect hit events from microphone input for timing analysis.

## Input
- mono audio stream (float32)
- sample rate: 44.1kHz

## Steps
1. High-pass filter (~40Hz)
2. Envelope detection (rectify + low-pass)
3. Peak detection:
   - threshold = adaptive (rolling average * factor)
   - minimum spacing = 35ms

## Output
HitEvent:
- timestampMs
- confidence (based on peak amplitude vs threshold)

## Rules
- suppress double hits within 35ms
- ignore low amplitude noise
- adaptive threshold adjusts to room level

## Goal
Reliable onset timing, not perfect transcription.
