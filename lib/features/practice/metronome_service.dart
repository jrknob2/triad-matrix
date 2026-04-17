import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

enum PracticeMetronomeEngineMode { unknown, native, fallback }

@immutable
class PracticeMetronomeDiagnostics {
  final PracticeMetronomeEngineMode mode;
  final String? lastIssue;

  const PracticeMetronomeDiagnostics({required this.mode, this.lastIssue});

  PracticeMetronomeDiagnostics copyWith({
    PracticeMetronomeEngineMode? mode,
    String? lastIssue,
    bool clearIssue = false,
  }) {
    return PracticeMetronomeDiagnostics(
      mode: mode ?? this.mode,
      lastIssue: clearIssue ? null : (lastIssue ?? this.lastIssue),
    );
  }
}

@immutable
class PracticeMetronomePulseState {
  final bool active;
  final int beatIndex;

  const PracticeMetronomePulseState({
    required this.active,
    required this.beatIndex,
  });
}

class PracticeMetronomeService {
  static const MethodChannel _methodChannel = MethodChannel(
    'drumcabulary/metronome',
  );

  final String assetPath;
  final ValueNotifier<PracticeMetronomeDiagnostics> diagnostics =
      ValueNotifier<PracticeMetronomeDiagnostics>(
        const PracticeMetronomeDiagnostics(
          mode: PracticeMetronomeEngineMode.unknown,
        ),
      );
  final ValueNotifier<bool> pulseActive = ValueNotifier<bool>(false);
  late final _FallbackMetronomeEngine _fallback;

  bool _prepared = false;
  bool _usingNative = false;
  bool _running = false;
  bool _clickEnabled = true;
  bool _pulseEnabled = true;
  int _bpm = 120;
  Timer? _nativePulsePoller;
  Timer? _pulseOffTimer;
  int _lastNativeBeatIndex = -1;

  PracticeMetronomeService({required this.assetPath}) {
    _fallback = _FallbackMetronomeEngine(
      assetPath: assetPath,
      onBeat: _handleFallbackBeat,
    );
  }

  Future<void> prepare() async {
    if (_prepared) return;
    try {
      await _methodChannel.invokeMethod<void>('prepare', <String, Object?>{
        'assetPath': assetPath,
      });
      _usingNative = true;
      _updateDiagnostics(
        mode: PracticeMetronomeEngineMode.native,
        clearIssue: true,
      );
    } on MissingPluginException {
      await _fallback.prepare();
      _usingNative = false;
      _recordIssue('Native metronome plugin missing. Using fallback engine.');
      _updateDiagnostics(mode: PracticeMetronomeEngineMode.fallback);
    } catch (error, stackTrace) {
      await _fallback.prepare();
      _usingNative = false;
      _recordIssue(
        'Native metronome prepare failed. Using fallback engine.',
        error: error,
        stackTrace: stackTrace,
      );
      _updateDiagnostics(mode: PracticeMetronomeEngineMode.fallback);
    }
    _prepared = true;
  }

  Future<void> start({
    required int bpm,
    required bool clickEnabled,
    required bool pulseEnabled,
  }) async {
    _bpm = bpm;
    _clickEnabled = clickEnabled;
    _pulseEnabled = pulseEnabled;
    _running = true;
    await prepare();
    if (_usingNative) {
      try {
        await _methodChannel.invokeMethod<void>('start', <String, Object?>{
          'bpm': bpm,
          'clickEnabled': clickEnabled,
        });
        _updateDiagnostics(
          mode: PracticeMetronomeEngineMode.native,
          clearIssue: true,
        );
        _startNativePulsePollingIfNeeded();
        return;
      } catch (error, stackTrace) {
        _recordIssue(
          'Native metronome start failed. Switching to fallback engine.',
          error: error,
          stackTrace: stackTrace,
        );
        await _switchToFallback(startImmediately: true);
        return;
      }
    }
    await _fallback.start(bpm: bpm, clickEnabled: clickEnabled);
  }

  Future<void> stop() async {
    _running = false;
    _stopPulseTracking();
    if (_usingNative) {
      try {
        await _methodChannel.invokeMethod<void>('stop');
        return;
      } catch (error, stackTrace) {
        _recordIssue(
          'Native metronome stop failed. Switching to fallback engine.',
          error: error,
          stackTrace: stackTrace,
        );
        await _switchToFallback();
      }
    }
    await _fallback.stop();
  }

  Future<void> updateBpm({required int bpm}) async {
    _bpm = bpm;
    if (!_running) return;
    if (_usingNative) {
      try {
        await _methodChannel.invokeMethod<void>('setBpm', <String, Object?>{
          'bpm': bpm,
        });
        return;
      } catch (error, stackTrace) {
        _recordIssue(
          'Native metronome BPM update failed. Switching to fallback engine.',
          error: error,
          stackTrace: stackTrace,
        );
        await _switchToFallback(startImmediately: true);
        return;
      }
    }
    await _fallback.updateBpm(bpm: bpm);
  }

  Future<void> setClickEnabled(bool value) async {
    _clickEnabled = value;
    if (!_running) return;
    if (_usingNative) {
      try {
        await _methodChannel.invokeMethod<void>(
          'setClickEnabled',
          <String, Object?>{'enabled': value},
        );
        return;
      } catch (error, stackTrace) {
        _recordIssue(
          'Native metronome click toggle failed. Switching to fallback engine.',
          error: error,
          stackTrace: stackTrace,
        );
        await _switchToFallback(startImmediately: true);
        return;
      }
    }
    await _fallback.setClickEnabled(value);
  }

  Future<void> setPulseEnabled(bool value) async {
    _pulseEnabled = value;
    if (!_running) {
      _setPulseActive(false);
      return;
    }
    if (_usingNative) {
      if (value) {
        _startNativePulsePollingIfNeeded();
      } else {
        _stopNativePulsePolling();
        _setPulseActive(false);
      }
      return;
    }
    if (!value) {
      _pulseOffTimer?.cancel();
      _setPulseActive(false);
    }
  }

  Future<void> playCompletionChime() async {
    await prepare();
    if (_usingNative) {
      try {
        await _methodChannel.invokeMethod<void>('playCompletionChime');
        return;
      } catch (error, stackTrace) {
        _recordIssue(
          'Native completion chime failed. Switching to fallback engine.',
          error: error,
          stackTrace: stackTrace,
        );
        await _switchToFallback();
      }
    }
    await _fallback.playCompletionChime();
  }

  Future<void> dispose() async {
    _stopPulseTracking();
    if (_usingNative) {
      try {
        await _methodChannel.invokeMethod<void>('stop');
      } catch (error, stackTrace) {
        _recordIssue(
          'Native metronome dispose stop failed.',
          error: error,
          stackTrace: stackTrace,
        );
        // Ignore native teardown errors during dispose.
      }
    }
    await _fallback.dispose();
    pulseActive.dispose();
    diagnostics.dispose();
  }

  Future<void> _switchToFallback({bool startImmediately = false}) async {
    if (!_fallback.prepared) {
      await _fallback.prepare();
    }
    _usingNative = false;
    _updateDiagnostics(mode: PracticeMetronomeEngineMode.fallback);
    if (startImmediately && _running) {
      await _fallback.start(bpm: _bpm, clickEnabled: _clickEnabled);
    }
  }

  void _handleFallbackBeat(int beatIndex) {
    if (!_pulseEnabled) return;
    _triggerPulseFlash();
  }

  Duration _flashWindowFor(int bpm) {
    final int beatMs = (60000 / bpm).round();
    return Duration(milliseconds: (beatMs * 0.18).round().clamp(75, 110));
  }

  void _startNativePulsePollingIfNeeded() {
    _stopNativePulsePolling();
    if (!_pulseEnabled || !_running) {
      _setPulseActive(false);
      return;
    }
    _nativePulsePoller = Timer.periodic(
      const Duration(milliseconds: 8),
      (_) => unawaited(_pollNativePulseState()),
    );
    unawaited(_pollNativePulseState());
  }

  void _stopNativePulsePolling() {
    _nativePulsePoller?.cancel();
    _nativePulsePoller = null;
    _lastNativeBeatIndex = -1;
  }

  void _stopPulseTracking() {
    _stopNativePulsePolling();
    _pulseOffTimer?.cancel();
    _pulseOffTimer = null;
    _setPulseActive(false);
  }

  Future<void> _pollNativePulseState() async {
    if (!_usingNative || !_running || !_pulseEnabled) {
      _setPulseActive(false);
      return;
    }
    try {
      final Object? raw = await _methodChannel.invokeMethod<Object?>(
        'pulseState',
      );
      if (raw is! Map<Object?, Object?>) return;
      final Object? activeValue = raw['active'];
      final Object? beatValue = raw['beatIndex'];
      final int beatIndex = beatValue is int
          ? beatValue
          : (beatValue is num ? beatValue.toInt() : _lastNativeBeatIndex);
      final bool active = activeValue == true;
      if (beatIndex != _lastNativeBeatIndex && beatIndex >= 0) {
        final bool hasEstablishedBeatPhase = _lastNativeBeatIndex >= 0;
        _lastNativeBeatIndex = beatIndex;
        if (hasEstablishedBeatPhase) {
          _triggerPulseFlash();
        }
        return;
      }
      if (!active && pulseActive.value) {
        // Keep the visual pulse latched locally for a short readable window.
        return;
      }
      if (!active) {
        _setPulseActive(false);
      }
    } catch (error, stackTrace) {
      _recordIssue(
        'Native pulse-state polling failed.',
        error: error,
        stackTrace: stackTrace,
      );
      _stopNativePulsePolling();
    }
  }

  void _setPulseActive(bool value) {
    if (pulseActive.value == value) return;
    pulseActive.value = value;
  }

  void _triggerPulseFlash() {
    _setPulseActive(true);
    _pulseOffTimer?.cancel();
    _pulseOffTimer = Timer(_flashWindowFor(_bpm), () {
      _setPulseActive(false);
    });
  }

  void _updateDiagnostics({
    required PracticeMetronomeEngineMode mode,
    String? lastIssue,
    bool clearIssue = false,
  }) {
    diagnostics.value = diagnostics.value.copyWith(
      mode: mode,
      lastIssue: lastIssue,
      clearIssue: clearIssue,
    );
  }

  void _recordIssue(String message, {Object? error, StackTrace? stackTrace}) {
    _updateDiagnostics(lastIssue: message, mode: diagnostics.value.mode);
    if (kDebugMode) {
      debugPrint(message);
      if (error != null) {
        debugPrint('Metronome error: $error');
      }
      if (stackTrace != null) {
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}

class _FallbackMetronomeEngine {
  static const int _clickPlayerPoolSize = 4;

  final String assetPath;
  final void Function(int beatIndex) onBeat;
  final List<AudioPlayer> _clickPlayers = List<AudioPlayer>.generate(
    _clickPlayerPoolSize,
    (_) => AudioPlayer(),
    growable: false,
  );
  final AudioPlayer _completionPlayer = AudioPlayer();

  bool prepared = false;
  bool _clickEnabled = true;
  int _nextClickPlayerIndex = 0;
  int _beatIndex = 0;
  Timer? _beatTimer;

  _FallbackMetronomeEngine({required this.assetPath, required this.onBeat});

  Future<void> prepare() async {
    if (prepared) return;
    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    for (final AudioPlayer player in _clickPlayers) {
      await player.setAsset(assetPath);
      await player.setVolume(1.0);
      await player.seek(Duration.zero);
      await player.pause();
    }
    await _completionPlayer.setAsset(assetPath);
    await _completionPlayer.setVolume(1.0);
    await _completionPlayer.seek(Duration.zero);
    await _completionPlayer.pause();
    prepared = true;
  }

  Future<void> start({required int bpm, required bool clickEnabled}) async {
    await prepare();
    _clickEnabled = clickEnabled;
    _beatTimer?.cancel();
    _beatIndex = -1;
    final int intervalMs = (60000 / bpm).round().clamp(120, 2000);
    _beatTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _beatIndex += 1;
      _emitBeat();
    });
  }

  Future<void> stop() async {
    _beatTimer?.cancel();
    for (final AudioPlayer player in _clickPlayers) {
      await player.pause();
      await player.seek(Duration.zero);
    }
  }

  Future<void> updateBpm({required int bpm}) async {
    await start(bpm: bpm, clickEnabled: _clickEnabled);
  }

  Future<void> setClickEnabled(bool value) async {
    _clickEnabled = value;
    if (!value) {
      for (final AudioPlayer player in _clickPlayers) {
        await player.pause();
        await player.seek(Duration.zero);
      }
    }
  }

  Future<void> playCompletionChime() async {
    try {
      await _completionPlayer.seek(Duration.zero);
      await _completionPlayer.play();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _completionPlayer.seek(Duration.zero);
      await _completionPlayer.play();
    } catch (_) {
      // Ignore transient playback errors during completion chime.
    }
  }

  Future<void> dispose() async {
    _beatTimer?.cancel();
    for (final AudioPlayer player in _clickPlayers) {
      await player.dispose();
    }
    await _completionPlayer.dispose();
  }

  void _emitBeat() {
    onBeat(_beatIndex);
    if (_clickEnabled) {
      unawaited(_triggerClick());
    }
  }

  Future<void> _triggerClick() async {
    try {
      final AudioPlayer player = _clickPlayers[_nextClickPlayerIndex];
      _nextClickPlayerIndex =
          (_nextClickPlayerIndex + 1) % _clickPlayers.length;
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Ignore transient playback errors in fallback mode.
    }
  }
}
