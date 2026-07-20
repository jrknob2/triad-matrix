import 'dart:async';

import 'package:flutter/foundation.dart';

import '../midi/led_frame_command_encoder.dart';
import '../midi/midi_input_models.dart';
import '../midi/serial_led_controller.dart';
import 'pattern_audio_service.dart';
import 'playback_drum_voice_mapper.dart';

typedef PlayAlongInputFeedbackEnabled = bool Function();

typedef PlayAlongFeedbackTimerFactory =
    PlayAlongFeedbackTimer Function(Duration duration, VoidCallback callback);

abstract class PlayAlongFeedbackTimer {
  bool get isActive;
  void cancel();
}

bool _enabledByDefault() => true;

class PatternPlayAlongInputFeedbackOutput
    implements PatternPlaybackCueOutputV1 {
  static const Duration defaultEarlyWindow = Duration(milliseconds: 90);
  static const Duration defaultLateWindow = Duration(milliseconds: 150);

  final Stream<DrumInputEvent> drumEvents;
  final SerialLedController controller;
  final PlayAlongInputFeedbackEnabled isEnabled;
  final LedFrameCommandEncoder encoder;
  final Duration earlyWindow;
  final Duration lateWindow;
  final PlayAlongFeedbackTimerFactory timerFactory;

  final List<_ActivePlayAlongWindow> _activeWindows =
      <_ActivePlayAlongWindow>[];
  StreamSubscription<DrumInputEvent>? _subscription;
  bool _running = false;

  PatternPlayAlongInputFeedbackOutput({
    required this.drumEvents,
    required this.controller,
    this.isEnabled = _enabledByDefault,
    this.encoder = const LedFrameCommandEncoder(),
    this.earlyWindow = defaultEarlyWindow,
    this.lateWindow = defaultLateWindow,
    PlayAlongFeedbackTimerFactory? timerFactory,
  }) : assert(earlyWindow >= Duration.zero),
       assert(lateWindow >= Duration.zero),
       timerFactory = timerFactory ?? _defaultTimerFactory;

  @override
  Duration get leadTime {
    if (!_canMonitor) return Duration.zero;
    return earlyWindow;
  }

  @override
  bool get gatesPlaybackStart => _canMonitor;

  @override
  void start(PatternAudioPlanV1 plan, {Duration phase = Duration.zero}) {
    stop();
    if (!_canMonitor || plan.cues.isEmpty) return;
    _running = true;
    _subscription = drumEvents.listen(_handleDrumInput);
  }

  @override
  Future<void> waitForStartCueGroup(List<PatternAudioCueV1> cues) {
    if (!_canMonitorRunning || cues.isEmpty) return Future<void>.value();
    final _ActivePlayAlongWindow window = _activateWindow(
      cues,
      startGate: true,
    );
    if (window.expectedMatchVoices.isEmpty) {
      return Future<void>.value();
    }
    return window.startGateCompleter?.future ?? Future<void>.value();
  }

  @override
  void triggerCue(PatternAudioCueV1 cue) {
    triggerCueGroup(<PatternAudioCueV1>[cue]);
  }

  @override
  void triggerCueGroup(List<PatternAudioCueV1> cues) {
    if (!_canMonitorRunning || cues.isEmpty) return;
    final _ActivePlayAlongWindow window = _activateWindow(cues);
    window.closeTimer ??= timerFactory(
      lateWindow,
      () => _handleWindowExpired(window),
    );
  }

  @override
  void triggerLeadCueGroup(List<PatternAudioCueV1> cues) {
    if (!_canMonitorRunning || cues.isEmpty || earlyWindow <= Duration.zero) {
      return;
    }
    _activateWindow(cues);
  }

  @override
  void stop() {
    _running = false;
    final StreamSubscription<DrumInputEvent>? subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    for (final _ActivePlayAlongWindow window in _activeWindows) {
      window.closeTimer?.cancel();
      window.completeStartGate();
    }
    _activeWindows.clear();
  }

  bool get _canMonitor => isEnabled() && controller.isConnected;
  bool get _canMonitorRunning => _running && _canMonitor;

  _ActivePlayAlongWindow _activateWindow(
    List<PatternAudioCueV1> cues, {
    bool startGate = false,
  }) {
    final String key = _windowKeyFor(cues);
    for (final _ActivePlayAlongWindow window in _activeWindows) {
      if (window.key == key && startGate) {
        window.ensureStartGate();
      }
      if (window.key == key) return window;
    }

    final Map<DrumVoice, LedCue> cueByMatchVoice = <DrumVoice, LedCue>{};
    for (final PatternAudioCueV1 cue in cues) {
      final DrumVoice voice = midiDrumVoiceForPlaybackVoice(cue.voice);
      final DrumVoice matchVoice = guidedPracticeMatchVoice(voice);
      if (matchVoice == DrumVoice.unknown) continue;
      cueByMatchVoice.putIfAbsent(
        matchVoice,
        () => LedCue(voice, sticking: cue.sticking),
      );
    }

    final _ActivePlayAlongWindow window = _ActivePlayAlongWindow(
      key: key,
      cueByMatchVoice: cueByMatchVoice,
    );
    if (startGate) {
      window.ensureStartGate();
    }
    _activeWindows.add(window);
    return window;
  }

  void _handleDrumInput(DrumInputEvent event) {
    if (!_canMonitorRunning || event.velocity <= 0) return;
    final DrumVoice playedVoice = canonicalGuidedPracticeVoice(event.voice);
    final DrumVoice matchVoice = guidedPracticeMatchVoice(playedVoice);
    if (matchVoice == DrumVoice.unknown) return;

    for (final _ActivePlayAlongWindow window in List<_ActivePlayAlongWindow>.of(
      _activeWindows,
    )) {
      if (!window.expectedMatchVoices.contains(matchVoice)) continue;
      if (window.isStartGate) {
        _handleStartGateHit(window, matchVoice);
        return;
      }
      window.receivedMatchVoices.add(matchVoice);
      return;
    }

    _sendFeedback(encoder.feedbackCommand('ERROR', LedCue(playedVoice)));
  }

  void _handleStartGateHit(
    _ActivePlayAlongWindow window,
    DrumVoice matchVoice,
  ) {
    final bool firstHitInAttempt = window.receivedMatchVoices.isEmpty;
    window.receivedMatchVoices.add(matchVoice);
    if (window.missingMatchVoices.isEmpty) {
      _completeStartGate(window);
      return;
    }
    if (firstHitInAttempt) {
      window.closeTimer ??= timerFactory(
        lateWindow,
        () => _handleStartGateWindowExpired(window),
      );
    }
  }

  void _handleStartGateWindowExpired(_ActivePlayAlongWindow window) {
    if (!_running || !window.isStartGate) return;
    window.closeTimer = null;
    if (_canMonitor) {
      for (final DrumVoice missingVoice in window.missingMatchVoices) {
        final LedCue? cue = window.cueByMatchVoice[missingVoice];
        if (cue == null) continue;
        _sendFeedback(encoder.feedbackCommand('MISSING', cue));
      }
    }
    window.receivedMatchVoices.clear();
  }

  void _completeStartGate(_ActivePlayAlongWindow window) {
    _activeWindows.remove(window);
    window.closeTimer?.cancel();
    window.closeTimer = null;
    window.completeStartGate();
  }

  void _handleWindowExpired(_ActivePlayAlongWindow window) {
    if (!_running) return;
    _activeWindows.remove(window);
    window.closeTimer = null;
    if (!_canMonitor) return;
    for (final DrumVoice missingVoice in window.missingMatchVoices) {
      final LedCue? cue = window.cueByMatchVoice[missingVoice];
      if (cue == null) continue;
      _sendFeedback(encoder.feedbackCommand('MISSING', cue));
    }
  }

  void _sendFeedback(String? command) {
    if (command == null || !controller.isConnected) return;
    controller.sendCommand(command);
  }

  String _windowKeyFor(List<PatternAudioCueV1> cues) {
    return <String>[
      '${cues.first.offset.inMicroseconds}',
      for (final PatternAudioCueV1 cue in cues)
        '${cue.tokenIndex}:${cue.voice.name}:${cue.sticking?.protocolValue ?? ''}',
    ].join('|');
  }

  static PlayAlongFeedbackTimer _defaultTimerFactory(
    Duration duration,
    VoidCallback callback,
  ) {
    return _DartPlayAlongFeedbackTimer(Timer(duration, callback));
  }
}

class _ActivePlayAlongWindow {
  final String key;
  final Map<DrumVoice, LedCue> cueByMatchVoice;
  final Set<DrumVoice> receivedMatchVoices = <DrumVoice>{};
  PlayAlongFeedbackTimer? closeTimer;
  Completer<void>? startGateCompleter;

  _ActivePlayAlongWindow({required this.key, required this.cueByMatchVoice});

  bool get isStartGate => startGateCompleter != null;

  Set<DrumVoice> get expectedMatchVoices => cueByMatchVoice.keys.toSet();

  Iterable<DrumVoice> get missingMatchVoices sync* {
    for (final DrumVoice voice in cueByMatchVoice.keys) {
      if (!receivedMatchVoices.contains(voice)) yield voice;
    }
  }

  void ensureStartGate() {
    startGateCompleter ??= Completer<void>();
  }

  void completeStartGate() {
    final Completer<void>? completer = startGateCompleter;
    startGateCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }
}

class _DartPlayAlongFeedbackTimer implements PlayAlongFeedbackTimer {
  final Timer _timer;

  const _DartPlayAlongFeedbackTimer(this._timer);

  @override
  bool get isActive => _timer.isActive;

  @override
  void cancel() {
    _timer.cancel();
  }
}
