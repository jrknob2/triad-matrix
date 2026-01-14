// lib/core/practice/practice_models.dart
//
// Triad Trainer — Core Practice Models (v1)
//
// Purpose:
// - Single source of truth for practice-domain types shared by UI + controller.
// - Keep models UI-agnostic (no Widgets). `foundation.dart` is allowed for @immutable.
//
// Canonical owners:
// - InstrumentContextV1 / KitPresetV1 / DrumSurfaceV1 live in:
//   lib/core/instrument/instrument_context_v1.dart
// - Pattern engine types live in:
//   lib/core/pattern/pattern_engine.dart

import 'package:flutter/foundation.dart';

import '../instrument/instrument_context_v1.dart';

/* -------------------------------------------------------------------------- */
/* Practice mode                                                               */
/* -------------------------------------------------------------------------- */

/// The user’s *intent* for the current practice session.
enum PracticeModeV1 {
  training,
  flow,
}

/* -------------------------------------------------------------------------- */
/* Focus / “why this matters”                                                  */
/* -------------------------------------------------------------------------- */

/// Short “why this pattern matters” message.
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

/* -------------------------------------------------------------------------- */
/* Click / timer                                                               */
/* -------------------------------------------------------------------------- */

@immutable
class ClickState {
  final bool enabled;

  const ClickState({required this.enabled});

  ClickState copyWith({bool? enabled}) =>
      ClickState(enabled: enabled ?? this.enabled);

  static const ClickState off = ClickState(enabled: false);
  static const ClickState on = ClickState(enabled: true);
}

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

/* -------------------------------------------------------------------------- */
/* Session state (optional convenience container)                              */
/* -------------------------------------------------------------------------- */

/// Root session state container. Controller may choose to use this or not.
/// Keeping it here helps avoid “random fields everywhere” in UI/Controller.
@immutable
class PracticeSessionState {
  final PracticeModeV1 mode;
  final InstrumentContextV1 instrument;

  /// Only meaningful when instrument == kit, but stored always for simplicity.
  final KitPresetV1 kit;

  final int bpm;
  final bool isPlaying;
  final ClickState click;
  final PracticeTimerState timer;

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
    KitPresetV1? kit,
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
      instrument: InstrumentContextV1.pad,
      kit: KitPresetV1.defaultRightHanded,
      bpm: 92,
      isPlaying: false,
      click: ClickState.on, // controller can override; v1 feels better with click on
      timer: PracticeTimerState.initial,
      focus: PatternFocus.defaultFocus,
    );
  }
}
