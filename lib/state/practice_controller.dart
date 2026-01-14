// lib/state/practice_controller.dart
//
// Triad Trainer — Practice Controller (v1)
//
// Responsibilities:
// - Own practice session state (mode/instrument/kit/bpm/click/timer).
// - Own generator tuning state (phraseType/repeats/chainCells/accentRule/coverage).
// - Generate patterns via PatternEngine.
// - Notify listeners.
//
// IMPORTANT:
// - This file MUST NOT define PracticeModeV1 / InstrumentContextV1 / PatternFocus / PracticeTimerState.
//   Those are canonical in core/*.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/instrument/instrument_context_v1.dart';
import '../core/pattern/pattern_engine.dart';
import '../core/practice/practice_mode_defaults.dart';
import '../core/practice/practice_models.dart';

class PracticeController extends ChangeNotifier {
  PracticeController() {
    _engine = PatternEngine();
    _genres = GenrePreset.builtIns();
    _genre = _genres.values.isNotEmpty ? _genres.values.first : null;

    // Canonical v1 session defaults
    _mode = PracticeDefaultsV1.defaultMode;
    _instrument = PracticeDefaultsV1.defaultInstrument;
    _kit = KitPresetV1.defaultRightHanded;

    _timerState = PracticeTimerState.initial;
    _bpm = 92;
    _clickEnabled = true;
    _coverageMode = true;

    // v1 generator defaults per mode
    final ModeDefaultsV1 d = PracticeDefaultsV1.forMode(_mode);
    _phraseType = d.phraseType;
    _chainCells = d.chainCells;
    _repeats = d.repeats;
    _accentRule = d.accentRule;
    _infiniteRepeat = d.infiniteRepeat;

    _updateFocus();
    generateNext();
  }

  /* ---------------------------- Engine + Genre ---------------------------- */

  late final PatternEngine _engine;
  late final Map<String, GenrePreset> _genres;
  GenrePreset? _genre;

  /* ---------------------------- Public Read API ---------------------------- */

  PracticeModeV1 get mode => _mode;
  InstrumentContextV1 get instrument => _instrument;

  /// Needed by PatternCard.
  KitPresetV1 get kit => _kit;

  int get bpm => _bpm;
  bool get clickEnabled => _clickEnabled;

  PracticeTimerState get timer => _timerState;

  /// What PracticeScreen expects.
  Pattern? get pattern => _last?.pattern;

  /// What PracticeScreen expects.
  PatternFocus get focus => _focus;

  /// For restartSame()
  int? get lastSeed => _lastSeed;

  bool get coverageMode => _coverageMode;

  /* ---------------------------- Internal State ----------------------------- */

  PracticeModeV1 _mode = PracticeModeV1.training;
  InstrumentContextV1 _instrument = InstrumentContextV1.pad;
  KitPresetV1 _kit = KitPresetV1.defaultRightHanded;

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

  PatternFocus _focus = PatternFocus.defaultFocus;

  PracticeTimerState _timerState = PracticeTimerState.initial;
  Timer? _timerTicker;

  /* -------------------------- Mode / Instrument ---------------------------- */

  void setMode(PracticeModeV1 next) {
    if (_mode == next) return;
    _mode = next;

    final ModeDefaultsV1 d = PracticeDefaultsV1.forMode(_mode);
    // v1 behavior: mode switches reset “feel” knobs
    _phraseType = d.phraseType;
    _chainCells = d.chainCells;
    _repeats = d.repeats;
    _accentRule = d.accentRule;
    _infiniteRepeat = d.infiniteRepeat;

    _updateFocus();
    generateNext();
  }

  void setInstrument(InstrumentContextV1 next) {
    if (_instrument == next) return;
    _instrument = next;

    _updateFocus();
    generateNext();
  }

  void setKit(KitPresetV1 next) {
    if (_kit == next) return;
    _kit = next;
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
    _generate(seed: _lastSeed);
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
    // keep infiniteRepeat as the current mode preference
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

    final GeneratorConstraints tunedConstraints =
        _effectiveConstraints(g.constraints);

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
    final LimbScope scope = PracticeDefaultsV1.scopeForInstrument(_instrument);

    // If hands-only, requireKick must be false.
    final bool requireKick =
        (scope == LimbScope.handsAndKick) && base.requireKick;

    return base.copyWith(scope: scope, requireKick: requireKick);
  }

  /* ------------------------------ Focus Copy -------------------------------- */

  void _updateFocus() {
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
