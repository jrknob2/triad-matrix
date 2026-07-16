import 'dart:async';

import 'package:flutter/foundation.dart';

import '../midi/drum_voice_led_command_mapper.dart';
import '../midi/midi_input_models.dart';
import '../midi/serial_led_controller.dart';
import '../practice/playback_drum_voice_mapper.dart';

typedef GuidedPracticeTimerFactory =
    GuidedPracticeWindowTimer Function(
      Duration duration,
      VoidCallback callback,
    );

abstract class GuidedPracticeWindowTimer {
  bool get isActive;
  void cancel();
}

enum GuidedPracticeStatus { idle, running, completed, stopped, error }

@immutable
class GuidedPracticeExpectedEvent {
  final List<DrumVoice> voices;
  final int sectionIndex;
  final Set<int> selectedIndexes;

  factory GuidedPracticeExpectedEvent(
    Iterable<DrumVoice> voices, {
    int sectionIndex = 0,
    Iterable<int> selectedIndexes = const <int>[],
  }) {
    final Set<DrumVoice> seen = <DrumVoice>{};
    for (final DrumVoice voice in voices) {
      final DrumVoice canonical = canonicalGuidedPracticeVoice(voice);
      if (canonical == DrumVoice.unknown) continue;
      seen.add(canonical);
    }
    return GuidedPracticeExpectedEvent._(
      List<DrumVoice>.unmodifiable(seen),
      sectionIndex: sectionIndex,
      selectedIndexes: Set<int>.unmodifiable(selectedIndexes),
    );
  }

  const GuidedPracticeExpectedEvent._(
    this.voices, {
    required this.sectionIndex,
    required this.selectedIndexes,
  });

  bool get isEmpty => voices.isEmpty;
  bool get isSimultaneous => voices.length > 1;
  Set<DrumVoice> get voiceSet => voices.toSet();
}

@immutable
class GuidedPracticeState {
  final GuidedPracticeStatus status;
  final int currentIndex;
  final int totalEvents;
  final GuidedPracticeExpectedEvent? currentEvent;
  final Set<DrumVoice> receivedVoices;
  final String? message;

  const GuidedPracticeState({
    required this.status,
    required this.currentIndex,
    required this.totalEvents,
    required this.currentEvent,
    this.receivedVoices = const <DrumVoice>{},
    this.message,
  });

  int get completedEvents {
    return switch (status) {
      GuidedPracticeStatus.completed => totalEvents,
      GuidedPracticeStatus.running => currentIndex,
      _ => 0,
    };
  }

  bool get isActive => status == GuidedPracticeStatus.running;

  static const GuidedPracticeState idle = GuidedPracticeState(
    status: GuidedPracticeStatus.idle,
    currentIndex: 0,
    totalEvents: 0,
    currentEvent: null,
  );
}

class GuidedPracticeLedCommandBuilder {
  final DrumVoiceLedCommandMapper mapper;

  const GuidedPracticeLedCommandBuilder({
    this.mapper = const DrumVoiceLedCommandMapper(),
  });

  static const String clearCommand = 'CLEAR\n';

  String? cueCommandFor(DrumVoice voice) => _command('CUE', voice);
  String? errorCommandFor(DrumVoice voice) => _command('ERROR', voice);
  String? missingCommandFor(DrumVoice voice) => _command('MISSING', voice);

  String? _command(String action, DrumVoice voice) {
    final String? name = mapper.voiceNameFor(
      canonicalGuidedPracticeVoice(voice),
    );
    return name == null ? null : '$action,$name\n';
  }
}

class GuidedPracticeController extends ChangeNotifier {
  static const Duration simultaneousCompletionWindow = Duration(
    milliseconds: 150,
  );

  final List<GuidedPracticeExpectedEvent> expectedEvents;
  final Stream<DrumInputEvent> drumEvents;
  final SerialLedController ledController;
  final GuidedPracticeLedCommandBuilder commandBuilder;
  final GuidedPracticeTimerFactory timerFactory;

  GuidedPracticeState _state;
  StreamSubscription<DrumInputEvent>? _subscription;
  GuidedPracticeWindowTimer? _completionTimer;
  final Set<DrumVoice> _receivedVoices = <DrumVoice>{};
  bool _disposed = false;

  GuidedPracticeController({
    required Iterable<GuidedPracticeExpectedEvent> expectedEvents,
    required this.drumEvents,
    required this.ledController,
    this.commandBuilder = const GuidedPracticeLedCommandBuilder(),
    GuidedPracticeTimerFactory? timerFactory,
  }) : expectedEvents = List<GuidedPracticeExpectedEvent>.unmodifiable(
         expectedEvents.where(
           (GuidedPracticeExpectedEvent event) => !event.isEmpty,
         ),
       ),
       timerFactory = timerFactory ?? _defaultTimerFactory,
       _state = GuidedPracticeState(
         status: GuidedPracticeStatus.idle,
         currentIndex: 0,
         totalEvents: expectedEvents
             .where((GuidedPracticeExpectedEvent event) => !event.isEmpty)
             .length,
         currentEvent: null,
       );

  GuidedPracticeState get state => _state;
  bool get isRunning => _state.status == GuidedPracticeStatus.running;

  bool start() {
    if (_disposed || expectedEvents.isEmpty || !ledController.isConnected) {
      return false;
    }
    _cancelSession();
    _subscription = drumEvents.listen(_handleDrumInput);
    return _activateExpectedEvent(0);
  }

  void stop() {
    if (_disposed || !isRunning) return;
    _cancelSession();
    _sendClearIfConnected();
    _setState(
      GuidedPracticeState(
        status: GuidedPracticeStatus.stopped,
        currentIndex: _state.currentIndex,
        totalEvents: expectedEvents.length,
        currentEvent: null,
      ),
    );
  }

  void handleMidiDisconnected() {
    if (_disposed || !isRunning) return;
    _cancelSession();
    _sendClearIfConnected();
    _setState(
      GuidedPracticeState(
        status: GuidedPracticeStatus.error,
        currentIndex: _state.currentIndex,
        totalEvents: expectedEvents.length,
        currentEvent: null,
        message: 'MIDI input disconnected.',
      ),
    );
  }

  void handleSerialDisconnected() {
    if (_disposed || !isRunning) return;
    _stopForLedFailure(
      ledController.lastError ?? 'LED controller disconnected.',
    );
  }

  void _handleDrumInput(DrumInputEvent event) {
    if (!isRunning || event.velocity <= 0) return;
    final DrumVoice playedVoice = canonicalGuidedPracticeVoice(event.voice);
    if (playedVoice == DrumVoice.unknown) return;

    final GuidedPracticeExpectedEvent? expected = _state.currentEvent;
    if (expected == null) return;
    final Set<DrumVoice> expectedVoices = expected.voiceSet;
    if (!expectedVoices.contains(playedVoice)) {
      _sendFeedback(commandBuilder.errorCommandFor(playedVoice));
      return;
    }

    if (!expected.isSimultaneous) {
      _completeCurrentEvent();
      return;
    }

    final bool firstExpectedVoice = _receivedVoices.isEmpty;
    _receivedVoices.add(playedVoice);
    if (firstExpectedVoice) {
      _completionTimer = timerFactory(
        simultaneousCompletionWindow,
        _handleCompletionWindowExpired,
      );
    }
    if (_receivedVoices.length == expectedVoices.length) {
      _completionTimer?.cancel();
      _completionTimer = null;
      _completeCurrentEvent();
      return;
    }
    _publishRunningState(message: null);
  }

  void _handleCompletionWindowExpired() {
    if (!isRunning) return;
    _completionTimer = null;
    final GuidedPracticeExpectedEvent? expected = _state.currentEvent;
    if (expected == null) return;
    final List<DrumVoice> missing = <DrumVoice>[
      for (final DrumVoice voice in expected.voices)
        if (!_receivedVoices.contains(voice)) voice,
    ];
    for (final DrumVoice voice in missing) {
      if (!_sendFeedback(commandBuilder.missingCommandFor(voice))) return;
    }
    _receivedVoices.clear();
    _publishRunningState(message: 'Try that group again.');
  }

  bool _activateExpectedEvent(int index) {
    if (index < 0 || index >= expectedEvents.length) return false;
    _completionTimer?.cancel();
    _completionTimer = null;
    _receivedVoices.clear();
    _state = GuidedPracticeState(
      status: GuidedPracticeStatus.running,
      currentIndex: index,
      totalEvents: expectedEvents.length,
      currentEvent: expectedEvents[index],
    );
    if (!_sendLedCommand(GuidedPracticeLedCommandBuilder.clearCommand)) {
      return false;
    }
    for (final DrumVoice voice in expectedEvents[index].voices) {
      if (!_sendFeedback(commandBuilder.cueCommandFor(voice))) return false;
    }
    notifyListeners();
    return true;
  }

  void _completeCurrentEvent() {
    final int nextIndex = _state.currentIndex + 1;
    if (nextIndex >= expectedEvents.length) {
      _activateExpectedEvent(0);
      return;
    }
    _activateExpectedEvent(nextIndex);
  }

  bool _sendFeedback(String? command) {
    if (command == null) return true;
    return _sendLedCommand(command);
  }

  bool _sendLedCommand(String command) {
    if (!ledController.isConnected) {
      _stopForLedFailure(
        ledController.lastError ?? 'LED controller disconnected.',
      );
      return false;
    }
    ledController.sendCommand(command);
    if (!ledController.isConnected) {
      _stopForLedFailure(ledController.lastError ?? 'LED command failed.');
      return false;
    }
    return true;
  }

  void _sendClearIfConnected() {
    if (ledController.isConnected) {
      ledController.sendCommand(GuidedPracticeLedCommandBuilder.clearCommand);
    }
  }

  void _stopForLedFailure(String message) {
    _cancelSession();
    _setState(
      GuidedPracticeState(
        status: GuidedPracticeStatus.error,
        currentIndex: _state.currentIndex,
        totalEvents: expectedEvents.length,
        currentEvent: null,
        message: message,
      ),
    );
  }

  void _publishRunningState({String? message}) {
    _setState(
      GuidedPracticeState(
        status: GuidedPracticeStatus.running,
        currentIndex: _state.currentIndex,
        totalEvents: expectedEvents.length,
        currentEvent: _state.currentEvent,
        receivedVoices: Set<DrumVoice>.unmodifiable(_receivedVoices),
        message: message,
      ),
    );
  }

  void _setState(GuidedPracticeState state) {
    _state = state;
    notifyListeners();
  }

  void _cancelSession() {
    _completionTimer?.cancel();
    _completionTimer = null;
    _receivedVoices.clear();
    final StreamSubscription<DrumInputEvent>? subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    if (isRunning) {
      stop();
    }
    _disposed = true;
    _cancelSession();
    super.dispose();
  }

  static GuidedPracticeWindowTimer _defaultTimerFactory(
    Duration duration,
    VoidCallback callback,
  ) {
    return _DartGuidedPracticeWindowTimer(Timer(duration, callback));
  }
}

class _DartGuidedPracticeWindowTimer implements GuidedPracticeWindowTimer {
  final Timer _timer;

  const _DartGuidedPracticeWindowTimer(this._timer);

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() {
    _timer.cancel();
  }
}
