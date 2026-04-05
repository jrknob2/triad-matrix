// lib/state/practice_controller.dart
//
// Triad Trainer — Practice Controller (v1)
//
// Responsibilities:
// - Own practice state + intents for PracticeScreen.
// - Bridge PatternEngine + the baked-in Triad Matrix.
// - Provide deterministic Previous/Next traversal across the matrix.
// - Support Self-guided selection of 1+ triads (multi-phrase) via picker.
//
// Rules:
// - NO duplicate domain models.
// - Matrix length/order comes ONLY from triad_matrix.dart.

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../core/instrument/instrument_context_v1.dart';
import '../core/pattern/pattern_engine.dart';
import '../core/pattern/triad_matrix.dart';
import '../core/practice/practice_models.dart';

@immutable
class PracticeSessionLogEntryV1 {
  /// Ordered triad IDs (matrix cell IDs).
  final List<String> selectedCellIds;

  /// Back-compat alias used by some UI code.
  List<String> get triadIds => selectedCellIds;

  final Duration duration;
  final DateTime timestamp;
  final InstrumentContextV1 instrument;

  const PracticeSessionLogEntryV1({
    required this.selectedCellIds,
    required this.duration,
    required this.timestamp,
    required this.instrument,
  });
}

class PracticeController extends ChangeNotifier {
  PracticeController() {
    _engine = PatternEngine();
    _genres = GenrePreset.builtIns();
    _genre = _genres.values.isNotEmpty ? _genres.values.first : null;

    _mode = PracticeModeV1.training;
    _instrument = InstrumentContextV1.pad;
    _kit = KitPresetV1.defaultRightHanded;

    _bpm = 92;
    _clickEnabled = true;

    _timerState = PracticeTimerState.initial;

    // Defaults tuned for beginner self-guided:
    _phraseType = PhraseType.chain;
    _chainCells = 2;
    _repeats = 6;
    _accentRule = AccentRule.cellStart();
    _infiniteRepeat = true;

    _matrixIndex = 0;

    _regenerate();
  }

  /* ---------------------------------------------------------------------- */
  /* Engine / Genre                                                         */
  /* ---------------------------------------------------------------------- */

  late final PatternEngine _engine;
  late final Map<String, GenrePreset> _genres;
  GenrePreset? _genre;

  /* ---------------------------------------------------------------------- */
  /* Public Read API                                                        */
  /* ---------------------------------------------------------------------- */

  PracticeModeV1 get mode => _mode;
  InstrumentContextV1 get instrument => _instrument;

  int get bpm => _bpm;
  bool get clickEnabled => _clickEnabled;

  PracticeTimerState get timer => _timerState;

  /// The pattern shown on-screen.
  /// If the user has picked triads, we render that phrase directly.
  Pattern? get pattern => _overridePattern ?? _last?.pattern;

  PatternFocus get focus => _focus;
  KitPresetV1 get kit => _kit;

  /// Self-guided picker selection, order matters.
  List<String> get selectedCellIds => List<String>.unmodifiable(_selectedCellIds);

  /// Session Log / Recents (most recent first).
  List<PracticeSessionLogEntryV1> get recentSessions =>
      List<PracticeSessionLogEntryV1>.unmodifiable(_recentSessions);

  /* ---------------------------------------------------------------------- */
  /* Internal State                                                         */
  /* ---------------------------------------------------------------------- */

  PracticeModeV1 _mode = PracticeModeV1.training;
  InstrumentContextV1 _instrument = InstrumentContextV1.pad;

  KitPresetV1 _kit = KitPresetV1.defaultRightHanded;

  int _bpm = 92;
  bool _clickEnabled = true;

  PhraseType _phraseType = PhraseType.chain;
  int _chainCells = 2;
  int _repeats = 6;
  AccentRule _accentRule = AccentRule.cellStart();
  bool _infiniteRepeat = true;

  PatternResult? _last;

  Pattern? _overridePattern; // when picker is used

  PatternFocus _focus = PatternFocus.defaultFocus;

  PracticeTimerState _timerState = PracticeTimerState.initial;
  Timer? _timerTicker;

  int _matrixIndex = 0;

  final List<String> _selectedCellIds = <String>[];

  final List<PracticeSessionLogEntryV1> _recentSessions =
      <PracticeSessionLogEntryV1>[];
  static const int _maxRecentSessions = 25;

  /* ---------------------------------------------------------------------- */
  /* Session Log / Recents                                                  */
  /* ---------------------------------------------------------------------- */

  /// Called explicitly when the user taps "Done" in the picker.
  /// - No-op if there is no selection.
  /// - De-dupes against most recent entry (same instrument + same ordered ids).
  void logSessionOnDone() {
    if (_selectedCellIds.isEmpty) return;

    // Keep only IDs that exist in the matrix (defensive).
    final List<String> valid = <String>[];
    for (final String id in _selectedCellIds) {
      if (_indexOfCellId(id) >= 0) valid.add(id);
    }
    if (valid.isEmpty) return;

    final DateTime now = DateTime.now();
    final Duration dur = _timerState.elapsed;

    if (_recentSessions.isNotEmpty) {
      final PracticeSessionLogEntryV1 top = _recentSessions.first;
      if (top.instrument == _instrument && listEquals(top.selectedCellIds, valid)) {
        _recentSessions[0] = PracticeSessionLogEntryV1(
          selectedCellIds: valid,
          duration: dur,
          timestamp: now,
          instrument: _instrument,
        );
        notifyListeners();
        return;
      }
    }

    _recentSessions.insert(
      0,
      PracticeSessionLogEntryV1(
        selectedCellIds: valid,
        duration: dur,
        timestamp: now,
        instrument: _instrument,
      ),
    );

    if (_recentSessions.length > _maxRecentSessions) {
      _recentSessions.removeRange(_maxRecentSessions, _recentSessions.length);
    }

    notifyListeners();
  }

  /// Restore a recent selection and regenerate pattern.
  void restoreRecent(PracticeSessionLogEntryV1 entry) {
    _instrument = entry.instrument;

    final bool padMode = _instrument == InstrumentContextV1.pad;

    final List<String> filtered = padMode
        ? entry.selectedCellIds
            .where((id) => !id.toUpperCase().contains('K'))
            .toList(growable: false)
        : List<String>.from(entry.selectedCellIds);

    if (filtered.isEmpty) {
      _updateFocus();
      _regenerate();
      notifyListeners();
      return;
    }

    _selectedCellIds
      ..clear()
      ..addAll(filtered);

    final int firstIdx = _indexOfCellId(_selectedCellIds.first);
    if (firstIdx >= 0) _matrixIndex = firstIdx;

    _regenerate();
    notifyListeners();
  }

  void clearRecentSessions() {
    if (_recentSessions.isEmpty) return;
    _recentSessions.clear();
    notifyListeners();
  }

  /* ---------------------------------------------------------------------- */
  /* Self-guided selection API                                              */
  /* ---------------------------------------------------------------------- */

  void toggleSelectedCellId(String id) {
    final int idx = _selectedCellIds.indexOf(id);
    if (idx >= 0) {
      _selectedCellIds.removeAt(idx);
    } else {
      _selectedCellIds.add(id);
    }

    if (_selectedCellIds.isNotEmpty) {
      final int firstIdx = _indexOfCellId(_selectedCellIds.first);
      if (firstIdx >= 0) _matrixIndex = firstIdx;
    }

    _regenerate();
    notifyListeners();
  }

  void setSelectedCellIds(List<String> ids) {
    _selectedCellIds
      ..clear()
      ..addAll(ids);

    if (_selectedCellIds.isNotEmpty) {
      final int firstIdx = _indexOfCellId(_selectedCellIds.first);
      if (firstIdx >= 0) _matrixIndex = firstIdx;
    }

    _regenerate();
    notifyListeners();
  }

  int _indexOfCellId(String id) {
    final int len = triadMatrixLength();
    for (int i = 0; i < len; i++) {
      if (triadMatrixCellAt(i).id == id) return i;
    }
    return -1;
  }

  /* ---------------------------------------------------------------------- */
  /* Mode / Instrument                                                      */
  /* ---------------------------------------------------------------------- */

  void setMode(PracticeModeV1 next) {
    if (_mode == next) return;
    _mode = next;

    if (_mode == PracticeModeV1.training) {
      _phraseType = PhraseType.chain;
      _chainCells = 2;
      _repeats = 6;
      _accentRule = AccentRule.cellStart();
      _infiniteRepeat = true;
    } else {
      _phraseType = PhraseType.chain;
      _chainCells = 4;
      _repeats = 2;
      _accentRule = AccentRule.everyNth(3);
      _infiniteRepeat = false;
    }

    _updateFocus();
    _regenerate();
    notifyListeners();
  }

  void setInstrument(InstrumentContextV1 next) {
    if (_instrument == next) return;
    _instrument = next;
    _updateFocus();
    _regenerate();
    notifyListeners();
  }

  /* ---------------------------------------------------------------------- */
  /* Transport                                                              */
  /* ---------------------------------------------------------------------- */

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

  /* ---------------------------------------------------------------------- */
  /* Timer                                                                  */
  /* ---------------------------------------------------------------------- */

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

  void toggleTimerRunning() {
    _timerState.running ? stopTimer() : startTimer();
  }

  void stopTimer() {
    if (!_timerState.running) return;
    _timerState = _timerState.copyWith(running: false);
    notifyListeners();
  }

  void _ensureTickerStarted() {
    _timerTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_timerState.running) return;
      _timerState = _timerState.copyWith(
        elapsed: _timerState.elapsed + const Duration(seconds: 1),
      );
      notifyListeners();
    });
  }

  void _ensureTickerStopped() {
    _timerTicker?.cancel();
    _timerTicker = null;
  }

  /* ---------------------------------------------------------------------- */
  /* Regeneration (Picker-first)                                            */
  /* ---------------------------------------------------------------------- */

  void _regenerate() {
    _updateFocus();

    if (_selectedCellIds.isNotEmpty) {
      _overridePattern = _buildPatternFromSelected();
      _last = null;
      return;
    }

    _overridePattern = null;
    _generateFromMatrixIndex(_matrixIndex);
  }

  Pattern _buildPatternFromSelected() {
    final List<TriadCell> phrase = <TriadCell>[];

    for (final String id in _selectedCellIds) {
      final int idx = _indexOfCellId(id);
      if (idx < 0) continue;

      final TriadMatrixCell cell = triadMatrixCellAt(idx);
      final List<Limb> limbs = _limbsFromId(cell.id);

      phrase.add(
        TriadCell(
          id: cell.id,
          limbs: limbs,
        ),
      );
    }

    if (phrase.isEmpty) {
      final String id = triadMatrixCellAt(_matrixIndex).id;
      phrase.add(TriadCell(id: id, limbs: _limbsFromId(id)));
    }

    return Pattern(
      phrase: phrase,
      repeats: _repeats,
      infiniteRepeat: _infiniteRepeat,
      accentNoteIndices: const <int>[],
    );
  }

  List<Limb> _limbsFromId(String id) {
    Limb toLimb(String ch) {
      switch (ch) {
        case 'R':
          return Limb.r;
        case 'L':
          return Limb.l;
        case 'K':
          return Limb.k;
        default:
          return Limb.r;
      }
    }

    final String s = id.trim().toUpperCase();
    if (s.length != 3) {
      return const <Limb>[Limb.r, Limb.r, Limb.r];
    }
    return <Limb>[toLimb(s[0]), toLimb(s[1]), toLimb(s[2])];
  }

  /* ---------------------------------------------------------------------- */
  /* Pattern Generation (Engine path)                                       */
  /* ---------------------------------------------------------------------- */

  void _generateFromMatrixIndex(int idx) {
    final GenrePreset? g = _genre;
    if (g == null) return;

    final TriadMatrixCell cell = triadMatrixCellAt(idx);

    final LimbScope scope = switch (_instrument) {
      InstrumentContextV1.pad => LimbScope.handsOnly,
      _ => LimbScope.handsAndKick,
    };

    final GeneratorConstraints tuned = g.constraints.copyWith(
      scope: scope,
      requireKick:
          _instrument != InstrumentContextV1.pad && g.constraints.requireKick,
    );

    final GenrePreset tunedGenre = g.copyWith(constraints: tuned);

    final int seed = cell.id.codeUnits.fold<int>(0, (a, b) => (a * 31) ^ b);

    final PatternRequest req = PatternRequest(
      genre: tunedGenre,
      coverageMode: false,
      seed: seed,
      phraseType: _phraseType,
      repeats: _repeats,
      chainCells: _chainCells,
      accentRule: _accentRule,
      infiniteRepeat: _infiniteRepeat,
    );

    _last = _engine.generateNext(req);
  }

  /* ---------------------------------------------------------------------- */
  /* Focus Copy                                                             */
  /* ---------------------------------------------------------------------- */

  void _updateFocus() {
    _focus = switch (_instrument) {
      InstrumentContextV1.pad => const PatternFocus(
          title: 'Pad fundamentals',
          detail: 'Hands-only triads to build clean internal motion and phrasing.',
        ),
      InstrumentContextV1.padKick => const PatternFocus(
          title: 'Coordination',
          detail: 'Add kick without breaking hand flow.',
        ),
      InstrumentContextV1.kit => const PatternFocus(
          title: 'Kit movement',
          detail: 'Move ideas around the kit with control.',
        ),
    };
  }

  /* ---------------------------------------------------------------------- */
  /* Cleanup                                                                */
  /* ---------------------------------------------------------------------- */

  @override
  void dispose() {
    _ensureTickerStopped();
    super.dispose();
  }
}
