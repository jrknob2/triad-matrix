import 'package:flutter/foundation.dart';

import '../core/instrument/instrument_context_v1.dart';

/// Legacy compatibility shim.
///
/// This file exists so older open tabs and stale IDE analysis do not break
/// while the app is being rebuilt around `AppController` and the new practice
/// domain models.
///
/// The actual app runtime no longer uses this controller.

enum PracticeModeV1 {
  training,
  flow,
}

@immutable
class PatternFocus {
  final String title;
  final String detail;

  const PatternFocus({
    required this.title,
    required this.detail,
  });

  static const PatternFocus defaultFocus = PatternFocus(
    title: 'Legacy Practice',
    detail: 'This controller is retained only for IDE compatibility.',
  );
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

@immutable
class PracticeSessionLogEntryV1 {
  final List<String> selectedCellIds;
  final Duration duration;
  final DateTime timestamp;
  final InstrumentContextV1 instrument;

  const PracticeSessionLogEntryV1({
    required this.selectedCellIds,
    required this.duration,
    required this.timestamp,
    required this.instrument,
  });

  List<String> get triadIds => selectedCellIds;
}

class PracticeController extends ChangeNotifier {
  PracticeModeV1 _mode = PracticeModeV1.training;
  InstrumentContextV1 _instrument = InstrumentContextV1.pad;
  int _bpm = 92;
  bool _clickEnabled = true;
  PracticeTimerState _timer = PracticeTimerState.initial;
  final PatternFocus _focus = PatternFocus.defaultFocus;
  final List<String> _selectedCellIds = <String>[];
  final List<PracticeSessionLogEntryV1> _recentSessions =
      <PracticeSessionLogEntryV1>[];

  PracticeModeV1 get mode => _mode;
  InstrumentContextV1 get instrument => _instrument;
  int get bpm => _bpm;
  bool get clickEnabled => _clickEnabled;
  PracticeTimerState get timer => _timer;
  PatternFocus get focus => _focus;
  Object? get pattern => null;
  Object? get kit => null;
  List<String> get selectedCellIds => List<String>.unmodifiable(_selectedCellIds);
  List<PracticeSessionLogEntryV1> get recentSessions =>
      List<PracticeSessionLogEntryV1>.unmodifiable(_recentSessions);

  void setMode(PracticeModeV1 next) {
    _mode = next;
    notifyListeners();
  }

  void setInstrument(InstrumentContextV1 next) {
    _instrument = next;
    notifyListeners();
  }

  void bpmStep(int delta) {
    _bpm = (_bpm + delta).clamp(30, 260);
    notifyListeners();
  }

  void toggleClick() {
    _clickEnabled = !_clickEnabled;
    notifyListeners();
  }

  void setTimerTarget(Duration? target) {
    _timer = _timer.copyWith(
      target: target,
      elapsed: Duration.zero,
      running: false,
    );
    notifyListeners();
  }

  void resetTimer() {
    _timer = _timer.copyWith(elapsed: Duration.zero);
    notifyListeners();
  }

  void startTimer() {
    _timer = _timer.copyWith(running: true);
    notifyListeners();
  }

  void stopTimer() {
    _timer = _timer.copyWith(running: false);
    notifyListeners();
  }

  void toggleTimerRunning() {
    _timer.running ? stopTimer() : startTimer();
  }

  void toggleSelectedCellId(String id) {
    if (_selectedCellIds.contains(id)) {
      _selectedCellIds.remove(id);
    } else {
      _selectedCellIds.add(id);
    }
    notifyListeners();
  }

  void setSelectedCellIds(List<String> ids) {
    _selectedCellIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void logSessionOnDone() {}

  void restoreRecent(PracticeSessionLogEntryV1 entry) {
    _instrument = entry.instrument;
    _selectedCellIds
      ..clear()
      ..addAll(entry.selectedCellIds);
    notifyListeners();
  }

  void clearRecentSessions() {
    _recentSessions.clear();
    notifyListeners();
  }
}
