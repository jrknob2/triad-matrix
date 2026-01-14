// lib/state/practice_controller.dart
//
// Triad Trainer — Practice Controller (v1)
//
// IMPORTANT (stability contract):
// This controller intentionally exposes the exact API that PracticeScreen
// is currently calling (per your build errors):
// - getters: pattern, focus, instrument, mode, timer, bpm, clickEnabled
// - methods: generateNext(), restartSame(), bpmStep(), toggleClick()
// - types: InstrumentContextV1, PracticeModeV1, PatternFocus, PracticeTimerState
//
// This keeps PracticeScreen stable while we modularize UI in follow-up files.
//
// NOTE: This controller does NOT rely on non-existent helpers like
// GenrePreset.v1Core() or PhraseType.cells().

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/pattern/pattern_engine.dart';

/* ----------------------------- v1 UI Domain Types -------------------------- */

/// v1: Mode is intent (Training vs Flow).
enum PracticeModeV1 { training, flow }

/// v1: Instrument context is physical setup (Pad default).
enum InstrumentContextV1 { pad, padKick, kit }

/// Small “why this matters” copy that the card/header can show.
class PatternFocus {
  final String title;
  final String detail;

  const PatternFocus({required this.title, required this.detail});

  static const PatternFocus padDefault = PatternFocus(
    title: 'Pad fundamentals',
    detail: 'Lock in hands-only triad motion with clean phrasing.',
  );
}

/// Timer model the UI can read.
class PracticeTimerState {
  final Duration? target;
  final Duration elapsed;
  final bool running;

  const PracticeTimerState({
    required this.target,
    required this.elapsed,
    required this.running,
  });

  PracticeTimerState copyWith({
    Duration? target,
    Duration? elapsed,
    bool? running,
  }) {
    return PracticeTimerState(
      target: target ?? this.target,
      elapsed: elapsed ?? this.elapsed,
      running: running ?? this.running,
    );
  }

  static const PracticeTimerState idle =
      PracticeTimerState(target: null, elapsed: Duration.zero, running: false);
}

/* ------------------------------ Controller -------------------------------- */

class PracticeController extends ChangeNotifier {
  PracticeController() {
    _engine = PatternEngine();
    _genres = GenrePreset.builtIns();
    _genre = _genres.values.isNotEmpty ? _genres.values.first : null;

    // v1 defaults (per docs + your “Pad should be default”):
    _instrument = InstrumentContextV1.pad;
    _mode = PracticeModeV1.training;

    _focus = PatternFocus.padDefault;
    _timerState = PracticeTimerState.idle;

    _bpm = 92;
    _clickEnabled = true;
    _coverageMode = true;

    // generator tuning defaults (kept simple for v1)
    _infiniteRepeat = true; // training leans ∞

    generateNext();
  }

  /* ---------------------------- Engine + Genre ---------------------------- */

  late final PatternEngine _engine;
  late final Map<String, GenrePreset> _genres;
  GenrePreset? _genre;

  /* ---------------------------- Public Read API ---------------------------- */

  PracticeModeV1 get mode => _mode;
  InstrumentContextV1 get instrument => _instrument;

  int get bpm => _bpm;
  bool get clickEnabled => _clickEnabled;

  PracticeTimerState get timer => _timerState;

  /// Current pattern (what PracticeScreen expects).
  Pattern? get pattern => _last?.pattern;

  /// Current focus copy (what PracticeScreen expects).
  PatternFocus get focus => _focus;

  /// For restartSame()
  int? get lastSeed => _lastSeed;

  /* ---------------------------- Internal State ----------------------------- */

  PracticeModeV1 _mode = PracticeModeV1.training;
  InstrumentContextV1 _instrument = InstrumentContextV1.pad;

  int _bpm = 92;
  bool _clickEnabled = true;

  bool _coverageMode = true;

  PhraseType? _phraseType;
  int? _repeats;
  int? _chainCells;
  AccentRule? _accentRule;
  bool _infiniteRepeat = false;

  PatternResult? _last;
  int? _lastSeed;

  PatternFocus _focus = PatternFocus.padDefault;

  PracticeTimerState _timerState = PracticeTimerState.idle;
  Timer? _timerTicker;

  /* -------------------------- Mode / Instrument ---------------------------- */

  void setMode(PracticeModeV1 next) {
    if (_mode == next) return;
    _mode = next;

    // v1 default behavior: training encourages ∞, flow does not.
    if (_mode == PracticeModeV1.training) {
      _infiniteRepeat = true;
    } else {
      _infiniteRepeat = false;
    }

    _updateFocus();
    generateNext();
    notifyListeners();
  }

  void setInstrument(InstrumentContextV1 next) {
    if (_instrument == next) return;
    _instrument = next;

    // v1: Pad default implies hands-only. Others allow kick.
    _updateFocus();
    generateNext();
    notifyListeners();
  }

  /* ------------------------------ Transport -------------------------------- */

  void bpmStep(int delta) {
    final int next = (_bpm + delta).clamp(30, 260);
    if (next == _bpm) return;
    _bpm = next;
    notifyListeners();
  }

  void toggleClick() {
    _clickEnabled = !_clickEnabled;
    notifyListeners();
  }

  /* ------------------------------- Timer ----------------------------------- */

  void setTimerTarget(Duration? target) {
    _timerState = _timerState.copyWith(
      target: target,
      elapsed: Duration.zero,
      running: false,
    );
    _ensureTickerStopped();
    notifyListeners();
  }

  void resetTimer() {
    _timerState = _timerState.copyWith(elapsed: Duration.zero);
    notifyListeners();
  }

  void startTimer() {
    if (_timerState.running) return;
    _timerState = _timerState.copyWith(running: true);
    _ensureTickerStarted();
    notifyListeners();
  }

  void stopTimer() {
    if (!_timerState.running) return;
    _timerState = _timerState.copyWith(running: false);
    // keep ticker allocated; it’s cheap and gated by running flag
    notifyListeners();
  }

  void toggleTimerRunning() {
    if (_timerState.running) {
      stopTimer();
    } else {
      startTimer();
    }
  }

  void _ensureTickerStarted() {
    _timerTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_timerState.running) return;

      final Duration nextElapsed =
          _timerState.elapsed + const Duration(seconds: 1);

      bool stillRunning = true;
      final Duration? target = _timerState.target;
      if (target != null && nextElapsed >= target) {
        stillRunning = false;
      }

      _timerState = _timerState.copyWith(
        elapsed: nextElapsed,
        running: stillRunning,
      );

      notifyListeners();
    });
  }

  void _ensureTickerStopped() {
    _timerTicker?.cancel();
    _timerTicker = null;
  }

  /* ---------------------------- Pattern Generation -------------------------- */

  void generateNext() {
    _generate(seed: null);
    notifyListeners();
  }

  void restartSame() {
    final int? seed = _lastSeed;
    _generate(seed: seed);
    notifyListeners();
  }

  void setCoverageMode(bool enabled) {
    if (_coverageMode == enabled) return;
    _coverageMode = enabled;
    generateNext();
  }

  void setGeneratorTuning({
    PhraseType? phraseType,
    int? repeats,
    int? chainCells,
    AccentRule? accentRule,
    bool? infiniteRepeat,
  }) {
    _phraseType = phraseType;
    _repeats = repeats;
    _chainCells = chainCells;
    _accentRule = accentRule;
    if (infiniteRepeat != null) _infiniteRepeat = infiniteRepeat;

    generateNext();
  }

  void clearTuningOnly() {
    _phraseType = null;
    _repeats = null;
    _chainCells = null;
    _accentRule = null;
    // keep _infiniteRepeat as current mode preference
    generateNext();
  }

  void _generate({required int? seed}) {
    final GenrePreset? g = _genre;
    if (g == null) {
      _last = null;
      _lastSeed = null;
      return;
    }

    final int computedSeed = seed ?? DateTime.now().microsecondsSinceEpoch;

    final GeneratorConstraints tunedConstraints = _effectiveConstraints(g.constraints);

    final GenrePreset tunedGenre = g.copyWith(constraints: tunedConstraints);

    final PatternRequest req = PatternRequest(
      genre: tunedGenre,
      coverageMode: _coverageMode,
      seed: computedSeed,
      phraseType: _phraseType,
      repeats: _repeats,
      chainCells: _chainCells,
      accentRule: _accentRule,
      infiniteRepeat: _infiniteRepeat,
    );

    _lastSeed = computedSeed;
    _last = _engine.generateNext(req);

    _updateFocus();
  }

  GeneratorConstraints _effectiveConstraints(GeneratorConstraints base) {
    // Derive limb scope from instrument context (per docs)
    final LimbScope scope = switch (_instrument) {
      InstrumentContextV1.pad => LimbScope.handsOnly,
      InstrumentContextV1.padKick => LimbScope.handsAndKick,
      InstrumentContextV1.kit => LimbScope.handsAndKick,
    };

    final bool requireKick = (scope == LimbScope.handsAndKick) && base.requireKick;

    return base.copyWith(scope: scope, requireKick: requireKick);
  }

  /* ------------------------------ Focus Copy -------------------------------- */

  void _updateFocus() {
    // v1: safe copy only; later we’ll drive from canonical tags.
    if (_instrument == InstrumentContextV1.pad) {
      _focus = const PatternFocus(
        title: 'Pad fundamentals',
        detail: 'Hands-only triads to build clean internal motion and phrasing.',
      );
      return;
    }
    if (_instrument == InstrumentContextV1.padKick) {
      _focus = const PatternFocus(
        title: 'Coordination',
        detail: 'Add kick without breaking hand flow. Keep it controlled.',
      );
      return;
    }

    // kit
    _focus = const PatternFocus(
      title: 'Kit movement',
      detail: 'Move the idea around the kit while staying physically honest.',
    );
  }

  /* ------------------------------- Cleanup ---------------------------------- */

  @override
  void dispose() {
    _ensureTickerStopped();
    super.dispose();
  }
}
