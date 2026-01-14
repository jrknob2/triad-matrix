// lib/core/practice_models.dart
//
// Triad Trainer — Core Practice Models (v1)
//
// Purpose:
// - Centralize the “domain” types used across UI + controller + generator.
// - Prevent circular edits where PracticeScreen and PracticeController keep
//   redefining enums and drifting.
// - Keep v1 intentionally small: two practice modes + three instrument contexts.
//
// This file should NOT import Flutter UI (no widgets). Pure Dart types only.

import 'package:flutter/foundation.dart';
import 'package:traid_trainer/core/instrument/instrument_context_v1.dart';

/// The user’s *intent* for the current practice session.
///
/// V1 ships with exactly two modes.
enum PracticeModeV1 {
  training,
  flow,
}

/// The user’s *physical setup*.
///
/// This is separate from mode:
/// - Instrument answers “what am I practicing on?”
/// - Mode answers “what kind of practice do I want?”
// enum InstrumentContextV1 {
//   /// Hands only, single surface. Treated as snare in UI (“S”).
//   pad,

//   /// Hands + kick pad. Still a single hand surface (“S”), plus kick.
//   padKick,

//   /// Full kit: voice assignment / orchestration enabled.
//   kit,
// }

extension InstrumentContextText on InstrumentContextV1 {
  String get label => switch (this) {
        InstrumentContextV1.pad => 'Pad only',
        InstrumentContextV1.padKick => 'Pad + Kick',
        InstrumentContextV1.kit => 'Kit',
      };
}

enum Handedness {
  right,
  left,
}

enum Brass {
  none,
  hh,
  hhRide,
}

/// V1 kit configuration. Only meaningful when [InstrumentContextV1.kit].
@immutable
class KitPreset {
  final int pieces; // 2..7
  final Handedness handedness;
  final Brass brass;

  const KitPreset({
    required this.pieces,
    required this.handedness,
    required this.brass,
  });

  KitPreset copyWith({
    int? pieces,
    Handedness? handedness,
    Brass? brass,
  }) {
    return KitPreset(
      pieces: pieces ?? this.pieces,
      handedness: handedness ?? this.handedness,
      brass: brass ?? this.brass,
    );
  }

  static const KitPreset defaultKit = KitPreset(
    pieces: 4,
    handedness: Handedness.right,
    brass: Brass.hh,
  );
}

/// A short “why this pattern matters” message.
///
/// This is the minimal v1 version of “the card should tell me why this pattern is valuable”.
@immutable
class PatternFocus {
  final String title;
  final String detail;

  const PatternFocus({
    required this.title,
    required this.detail,
  });

  static const PatternFocus defaultFocus = PatternFocus(
    title: 'Triad vocabulary',
    detail: 'Build comfort chaining triad cells at a controlled tempo.',
  );
}

/// Metronome/click state (v1: on/off only).
@immutable
class ClickState {
  final bool enabled;

  const ClickState({required this.enabled});

  ClickState copyWith({bool? enabled}) => ClickState(enabled: enabled ?? this.enabled);

  static const ClickState off = ClickState(enabled: false);
  static const ClickState on = ClickState(enabled: true);
}

/// Practice timer state (v1: optional target, start/stop/reset).
@immutable
class PracticeTimerState {
  final Duration elapsed;
  final Duration? target;
  final bool running;

  const PracticeTimerState({
    required this.elapsed,
    required this.target,
    required this.running,
  });

  PracticeTimerState copyWith({
    Duration? elapsed,
    Duration? target,
    bool? running,
  }) {
    return PracticeTimerState(
      elapsed: elapsed ?? this.elapsed,
      target: target ?? this.target,
      running: running ?? this.running,
    );
  }

  static const PracticeTimerState initial = PracticeTimerState(
    elapsed: Duration.zero,
    target: null,
    running: false,
  );
}

/// Root practice session state. Controller owns this; UI reads it.
@immutable
class PracticeSessionState {
  final PracticeModeV1 mode;
  final InstrumentContextV1 instrument;

  /// Only used when instrument == kit. Still stored always to keep state simple.
  final KitPreset kit;

  final int bpm;
  final bool isPlaying;
  final ClickState click;
  final PracticeTimerState timer;

  /// “Why this pattern matters” hint shown above the pattern card.
  final PatternFocus focus;

  const PracticeSessionState({
    required this.mode,
    required this.instrument,
    required this.kit,
    required this.bpm,
    required this.isPlaying,
    required this.click,
    required this.timer,
    required this.focus,
  });

  PracticeSessionState copyWith({
    PracticeModeV1? mode,
    InstrumentContextV1? instrument,
    KitPreset? kit,
    int? bpm,
    bool? isPlaying,
    ClickState? click,
    PracticeTimerState? timer,
    PatternFocus? focus,
  }) {
    return PracticeSessionState(
      mode: mode ?? this.mode,
      instrument: instrument ?? this.instrument,
      kit: kit ?? this.kit,
      bpm: bpm ?? this.bpm,
      isPlaying: isPlaying ?? this.isPlaying,
      click: click ?? this.click,
      timer: timer ?? this.timer,
      focus: focus ?? this.focus,
    );
  }

  static PracticeSessionState v1Default() {
    return const PracticeSessionState(
      mode: PracticeModeV1.training,
      instrument: InstrumentContextV1.pad, // per your request: default pad
      kit: KitPreset.defaultKit,
      bpm: 92,
      isPlaying: false,
      click: ClickState.off,
      timer: PracticeTimerState.initial,
      focus: PatternFocus.defaultFocus,
    );
  }
}
