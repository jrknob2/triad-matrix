import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class PracticeMetronomeService {
  static const MethodChannel _channel = MethodChannel('drumcabulary/metronome');

  final String assetPath;
  late final _FallbackMetronomeEngine _fallback;

  bool _prepared = false;
  bool _usingNative = false;
  bool _running = false;
  int _bpm = 120;

  PracticeMetronomeService({required this.assetPath}) {
    _fallback = _FallbackMetronomeEngine(assetPath: assetPath);
  }

  Future<void> prepare() async {
    if (_prepared) return;
    try {
      await _channel.invokeMethod<void>('prepare', <String, Object?>{
        'assetPath': assetPath,
      });
      _usingNative = true;
    } on MissingPluginException {
      await _fallback.prepare();
      _usingNative = false;
    } catch (_) {
      await _fallback.prepare();
      _usingNative = false;
    }
    _prepared = true;
  }

  Future<void> start({required int bpm}) async {
    _bpm = bpm;
    _running = true;
    await prepare();
    if (_usingNative) {
      try {
        await _channel.invokeMethod<void>('start', <String, Object?>{
          'bpm': bpm,
        });
        return;
      } catch (_) {
        await _switchToFallback(startImmediately: true);
        return;
      }
    }
    await _fallback.start(bpm: bpm);
  }

  Future<void> stop() async {
    _running = false;
    if (_usingNative) {
      try {
        await _channel.invokeMethod<void>('stop');
        return;
      } catch (_) {
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
        await _channel.invokeMethod<void>('setBpm', <String, Object?>{
          'bpm': bpm,
        });
        return;
      } catch (_) {
        await _switchToFallback(startImmediately: true);
        return;
      }
    }
    await _fallback.updateBpm(bpm: bpm);
  }

  Future<void> playCompletionChime() async {
    await prepare();
    if (_usingNative) {
      try {
        await _channel.invokeMethod<void>('playCompletionChime');
        return;
      } catch (_) {
        await _switchToFallback();
      }
    }
    await _fallback.playCompletionChime();
  }

  Future<void> dispose() async {
    if (_usingNative) {
      try {
        await _channel.invokeMethod<void>('stop');
      } catch (_) {
        // Ignore native teardown errors during dispose.
      }
    }
    await _fallback.dispose();
  }

  Future<void> _switchToFallback({bool startImmediately = false}) async {
    if (!_fallback.prepared) {
      await _fallback.prepare();
    }
    _usingNative = false;
    if (startImmediately && _running) {
      await _fallback.start(bpm: _bpm);
    }
  }
}

class _FallbackMetronomeEngine {
  static const int _clickPlayerPoolSize = 4;

  final String assetPath;
  final List<AudioPlayer> _clickPlayers = List<AudioPlayer>.generate(
    _clickPlayerPoolSize,
    (_) => AudioPlayer(),
    growable: false,
  );
  final AudioPlayer _completionPlayer = AudioPlayer();

  bool prepared = false;
  int _nextClickPlayerIndex = 0;
  Timer? _beatTimer;

  _FallbackMetronomeEngine({required this.assetPath});

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

  Future<void> start({required int bpm}) async {
    await prepare();
    _beatTimer?.cancel();
    final int intervalMs = (60000 / bpm).round().clamp(120, 2000);
    await _triggerClick();
    _beatTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      unawaited(_triggerClick());
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
    await start(bpm: bpm);
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
