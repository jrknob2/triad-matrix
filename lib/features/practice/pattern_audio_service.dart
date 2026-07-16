import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/practice/practice_domain_v1.dart';
import 'pattern_playback_scheduler.dart';

enum PatternAudioSampleV1 {
  snare,
  kick,
  snareNormal,
  snareAccent,
  snareGhost,
  hihat,
  rackTom,
  tom2,
  floorTom,
  flam,
  unison,
  accentSnare,
  accentCrash,
  accentRide,
}

class PatternAudioCueV1 {
  final int tokenIndex;
  final Duration offset;
  final PatternAudioSampleV1 sample;
  final DrumVoiceV1 voice;
  final double volume;

  const PatternAudioCueV1({
    required this.tokenIndex,
    required this.offset,
    required this.sample,
    required this.voice,
    required this.volume,
  });
}

class PatternAudioPlanV1 {
  final List<PatternAudioCueV1> cues;
  final Duration cycleDuration;

  const PatternAudioPlanV1({required this.cues, required this.cycleDuration});
}

class PatternAudioMixerConfigV1 {
  final double kickVolume;
  final double normalNonCymbalVolume;
  final double normalCymbalVolume;
  final double crashVolume;
  final double ghostVolume;
  final double accentVolume;

  const PatternAudioMixerConfigV1({
    this.kickVolume = 1.0,
    this.normalNonCymbalVolume = 0.8,
    this.normalCymbalVolume = 0.8,
    this.crashVolume = 0.6,
    this.ghostVolume = 0.1,
    this.accentVolume = 1.0,
  }) : assert(kickVolume >= 0 && kickVolume <= 1),
       assert(normalNonCymbalVolume >= 0 && normalNonCymbalVolume <= 1),
       assert(normalCymbalVolume >= 0 && normalCymbalVolume <= 1),
       assert(crashVolume >= 0 && crashVolume <= 1),
       assert(ghostVolume >= 0 && ghostVolume <= 1),
       assert(accentVolume >= 0 && accentVolume <= 1);
}

abstract class PatternPlaybackCueOutputV1 {
  void triggerCue(PatternAudioCueV1 cue);
}

class PatternAudioService {
  static const int _playerPoolSize = 4;
  static const Duration _staleCueTolerance = Duration(milliseconds: 90);
  static const Map<PatternAudioSampleV1, String> assetPaths =
      <PatternAudioSampleV1, String>{
        PatternAudioSampleV1.snare: 'assets/audio/snare.wav',
        PatternAudioSampleV1.kick: 'assets/audio/kick.wav',
        PatternAudioSampleV1.snareNormal: 'assets/audio/snare_normal.wav',
        PatternAudioSampleV1.snareAccent: 'assets/audio/snare_accent.wav',
        PatternAudioSampleV1.snareGhost: 'assets/audio/snare_ghost.wav',
        PatternAudioSampleV1.hihat: 'assets/audio/hihat.wav',
        PatternAudioSampleV1.rackTom: 'assets/audio/rack_tom.wav',
        PatternAudioSampleV1.tom2: 'assets/audio/tom2.wav',
        PatternAudioSampleV1.floorTom: 'assets/audio/floor_tom.wav',
        PatternAudioSampleV1.flam: 'assets/audio/flam.wav',
        PatternAudioSampleV1.unison: 'assets/audio/unison.wav',
        PatternAudioSampleV1.accentSnare: 'assets/audio/accent_snare.wav',
        PatternAudioSampleV1.accentCrash: 'assets/audio/accent_crash.wav',
        PatternAudioSampleV1.accentRide: 'assets/audio/accent_ride.wav',
      };

  final List<PatternPlaybackCueOutputV1> _playbackOutputs;
  final Map<PatternAudioSampleV1, List<AudioPlayer>> _playersBySample =
      <PatternAudioSampleV1, List<AudioPlayer>>{
        for (final PatternAudioSampleV1 sample in PatternAudioSampleV1.values)
          sample: List<AudioPlayer>.generate(
            _playerPoolSize,
            (_) => AudioPlayer(),
            growable: false,
          ),
      };
  final Map<PatternAudioSampleV1, int> _nextPlayerIndexBySample =
      <PatternAudioSampleV1, int>{
        for (final PatternAudioSampleV1 sample in PatternAudioSampleV1.values)
          sample: 0,
      };

  final Set<PatternAudioSampleV1> _preparedSamples = <PatternAudioSampleV1>{};
  Future<void>? _prepareFuture;
  bool _running = false;
  Timer? _cycleTimer;
  final List<Timer> _cueTimers = <Timer>[];

  PatternAudioService({
    Iterable<PatternPlaybackCueOutputV1> playbackOutputs =
        const <PatternPlaybackCueOutputV1>[],
  }) : _playbackOutputs = List<PatternPlaybackCueOutputV1>.unmodifiable(
         playbackOutputs,
       );

  Future<void> prepare({Iterable<PatternAudioSampleV1>? samples}) async {
    final Set<PatternAudioSampleV1> requiredSamples = samples == null
        ? Set<PatternAudioSampleV1>.of(PatternAudioSampleV1.values)
        : samples.toSet();
    if (requiredSamples.isEmpty) return;

    while (true) {
      final Set<PatternAudioSampleV1> missingSamples = requiredSamples.where((
        PatternAudioSampleV1 sample,
      ) {
        return !_preparedSamples.contains(sample);
      }).toSet();
      if (missingSamples.isEmpty) return;

      final Future<void>? activePrepare = _prepareFuture;
      if (activePrepare != null) {
        await activePrepare;
        continue;
      }

      final Future<void> nextPrepare = _prepareSamples(missingSamples);
      _prepareFuture = nextPrepare;
      try {
        await nextPrepare;
      } finally {
        if (identical(_prepareFuture, nextPrepare)) {
          _prepareFuture = null;
        }
      }
    }
  }

  Future<void> reloadAssets() async {
    final Future<void>? activePrepare = _prepareFuture;
    if (activePrepare != null) {
      await activePrepare;
    }
    await stop();
    _preparedSamples.clear();
    await AudioPlayer.clearAssetCache();
  }

  Future<void> _prepareSamples(Set<PatternAudioSampleV1> samples) async {
    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    for (final PatternAudioSampleV1 sample in samples) {
      final String assetPath = assetPaths[sample]!;
      for (final AudioPlayer player in _playersBySample[sample]!) {
        await player.setAsset(assetPath);
        await player.setVolume(1.0);
        await player.seek(Duration.zero);
        await player.pause();
      }
      _preparedSamples.add(sample);
    }
  }

  Future<void> start({
    required List<PatternTokenV1> tokens,
    required List<PatternNoteMarkingV1> markings,
    required List<DrumVoiceV1> voices,
    required PatternGroupingV1 grouping,
    required PatternTimingV1 timing,
    required int bpm,
    AccentVoiceV1 accentVoice = AccentVoiceV1.snare,
    PatternAudioMixerConfigV1 mixerConfig = const PatternAudioMixerConfigV1(),
    Map<int, List<DrumVoiceV1>> additionalVoicesByIndex =
        const <int, List<DrumVoiceV1>>{},
    Duration startElapsed = Duration.zero,
  }) async {
    final PatternAudioPlanV1 plan = buildPlan(
      tokens: tokens,
      markings: markings,
      voices: voices,
      grouping: grouping,
      timing: timing,
      bpm: bpm,
      accentVoice: accentVoice,
      mixerConfig: mixerConfig,
      additionalVoicesByIndex: additionalVoicesByIndex,
    );
    if (plan.cues.isEmpty || plan.cycleDuration <= Duration.zero) return;

    await stop();
    await prepare(
      samples: plan.cues.map((PatternAudioCueV1 cue) => cue.sample),
    );

    _running = true;
    final Duration phase = _normalizedPhase(
      elapsed: startElapsed,
      cycleDuration: plan.cycleDuration,
    );
    _scheduleCycle(plan: plan, phase: phase);
  }

  Future<void> stop() async {
    _running = false;
    _cycleTimer?.cancel();
    _cycleTimer = null;
    for (final Timer timer in _cueTimers) {
      timer.cancel();
    }
    _cueTimers.clear();
    for (final List<AudioPlayer> players in _playersBySample.values) {
      for (final AudioPlayer player in players) {
        try {
          await player.pause();
          await player.seek(Duration.zero);
        } catch (_) {
          // Some players may not have an asset loaded yet.
        }
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    for (final List<AudioPlayer> players in _playersBySample.values) {
      for (final AudioPlayer player in players) {
        await player.dispose();
      }
    }
  }

  static PatternAudioPlanV1 buildPlan({
    required List<PatternTokenV1> tokens,
    required List<PatternNoteMarkingV1> markings,
    required List<DrumVoiceV1> voices,
    required PatternGroupingV1 grouping,
    required PatternTimingV1 timing,
    required int bpm,
    AccentVoiceV1 accentVoice = AccentVoiceV1.snare,
    PatternAudioMixerConfigV1 mixerConfig = const PatternAudioMixerConfigV1(),
    Map<int, List<DrumVoiceV1>> additionalVoicesByIndex =
        const <int, List<DrumVoiceV1>>{},
  }) {
    if (tokens.isEmpty || bpm <= 0) {
      return const PatternAudioPlanV1(
        cues: <PatternAudioCueV1>[],
        cycleDuration: Duration.zero,
      );
    }

    final PatternPlaybackPlanV1 playbackPlan =
        PatternPlaybackSchedulerV1.buildPlan(
          tokens: tokens,
          grouping: grouping,
          timing: timing,
        );
    if (playbackPlan.events.isEmpty || playbackPlan.totalBeatCount <= 0) {
      return const PatternAudioPlanV1(
        cues: <PatternAudioCueV1>[],
        cycleDuration: Duration.zero,
      );
    }

    final double microsPerBeat = Duration.microsecondsPerMinute / bpm;
    final List<PatternAudioCueV1> cues = <PatternAudioCueV1>[];
    for (final PatternPlaybackEventV1 event in playbackPlan.events) {
      final PatternTokenV1 token = tokens[event.tokenIndex];
      if (token.isRest) continue;
      final PatternNoteMarkingV1 marking = _markingForIndex(
        markings,
        event.tokenIndex,
      );
      final DrumVoiceV1 voice = _voiceForIndex(
        voices,
        tokens,
        event.tokenIndex,
      );
      final PatternAudioSampleV1 sample = _sampleFor(
        token: token,
        voice: voice,
        marking: marking,
        accentVoice: accentVoice,
      );
      cues.add(
        PatternAudioCueV1(
          tokenIndex: event.tokenIndex,
          offset: Duration(
            microseconds: (event.startBeat * microsPerBeat).round(),
          ),
          sample: sample,
          voice: voice,
          volume: _volumeFor(
            token: token,
            voice: voice,
            sample: sample,
            marking: marking,
            mixerConfig: mixerConfig,
          ),
        ),
      );
      for (final DrumVoiceV1 additionalVoice
          in additionalVoicesByIndex[event.tokenIndex] ??
              const <DrumVoiceV1>[]) {
        final PatternTokenV1 additionalToken = _tokenForAdditionalVoice(
          additionalVoice,
        );
        final PatternAudioSampleV1 additionalSample = _sampleFor(
          token: additionalToken,
          voice: additionalVoice,
          marking: PatternNoteMarkingV1.normal,
          accentVoice: accentVoice,
        );
        cues.add(
          PatternAudioCueV1(
            tokenIndex: event.tokenIndex,
            offset: Duration(
              microseconds: (event.startBeat * microsPerBeat).round(),
            ),
            sample: additionalSample,
            voice: additionalVoice,
            volume: _volumeFor(
              token: additionalToken,
              voice: additionalVoice,
              sample: additionalSample,
              marking: PatternNoteMarkingV1.normal,
              mixerConfig: mixerConfig,
            ),
          ),
        );
      }
    }

    return PatternAudioPlanV1(
      cues: List<PatternAudioCueV1>.unmodifiable(cues),
      cycleDuration: Duration(
        microseconds: (playbackPlan.totalBeatCount * microsPerBeat).round(),
      ),
    );
  }

  static PatternTokenV1 _tokenForAdditionalVoice(DrumVoiceV1 voice) {
    return switch (voice) {
      DrumVoiceV1.kick => PatternTokenV1.kick,
      DrumVoiceV1.crash ||
      DrumVoiceV1.ride ||
      DrumVoiceV1.hihat => PatternTokenV1.accent,
      DrumVoiceV1.floorTom ||
      DrumVoiceV1.tom2 ||
      DrumVoiceV1.rackTom ||
      DrumVoiceV1.snare => PatternTokenV1.right,
    };
  }

  void _scheduleCycle({
    required PatternAudioPlanV1 plan,
    required Duration phase,
  }) {
    if (!_running) return;
    _cueTimers.removeWhere((Timer timer) => !timer.isActive);
    final Stopwatch cycleStopwatch = Stopwatch()..start();
    for (final PatternAudioCueV1 cue in plan.cues) {
      if (phase > Duration.zero && cue.offset < phase) {
        continue;
      }
      final Duration delay = cue.offset - phase;
      _cueTimers.add(
        Timer(delay, () {
          if (!_running) return;
          if (cycleStopwatch.elapsed - delay > _staleCueTolerance) return;
          unawaited(_triggerCue(cue));
        }),
      );
    }

    final Duration nextCycleDelay = phase == Duration.zero
        ? plan.cycleDuration
        : plan.cycleDuration - phase;
    _cycleTimer = Timer(nextCycleDelay, () {
      if (!_running) return;
      _scheduleCycle(plan: plan, phase: Duration.zero);
    });
  }

  Future<void> _triggerCue(PatternAudioCueV1 cue) async {
    _triggerPlaybackOutputs(cue);
    final List<AudioPlayer> players = _playersBySample[cue.sample]!;
    final int nextIndex = _nextPlayerIndexBySample[cue.sample]!;
    final AudioPlayer player = players[nextIndex];
    _nextPlayerIndexBySample[cue.sample] = (nextIndex + 1) % players.length;
    try {
      await player.setVolume(cue.volume);
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {
      // Ignore transient one-shot errors.
    }
  }

  void _triggerPlaybackOutputs(PatternAudioCueV1 cue) {
    for (final PatternPlaybackCueOutputV1 output in _playbackOutputs) {
      try {
        output.triggerCue(cue);
      } catch (error, stackTrace) {
        debugPrint('Pattern playback output failed: $error\n$stackTrace');
      }
    }
  }

  static Duration _normalizedPhase({
    required Duration elapsed,
    required Duration cycleDuration,
  }) {
    if (elapsed <= Duration.zero || cycleDuration <= Duration.zero) {
      return Duration.zero;
    }
    final int cycleMicros = cycleDuration.inMicroseconds;
    if (cycleMicros <= 0) return Duration.zero;
    final int normalized = elapsed.inMicroseconds % cycleMicros;
    return Duration(microseconds: normalized);
  }

  static PatternNoteMarkingV1 _markingForIndex(
    List<PatternNoteMarkingV1> markings,
    int index,
  ) {
    if (index < 0 || index >= markings.length) {
      return PatternNoteMarkingV1.normal;
    }
    return markings[index];
  }

  static DrumVoiceV1 _voiceForIndex(
    List<DrumVoiceV1> voices,
    List<PatternTokenV1> tokens,
    int index,
  ) {
    if (index < 0 || index >= tokens.length) return DrumVoiceV1.snare;
    if (tokens[index].isKick) return DrumVoiceV1.kick;
    if (tokens[index].kind == PatternTokenKindV1.accent &&
        index < voices.length &&
        _isCymbalVoice(voices[index])) {
      return voices[index];
    }
    if (!tokens[index].allowsAuthoredVoice) return DrumVoiceV1.snare;
    if (index < voices.length) {
      final DrumVoiceV1 voice = voices[index];
      return voice == DrumVoiceV1.kick ? DrumVoiceV1.snare : voice;
    }
    return DrumVoiceV1.snare;
  }

  static PatternAudioSampleV1 _sampleFor({
    required PatternTokenV1 token,
    required DrumVoiceV1 voice,
    required PatternNoteMarkingV1 marking,
    required AccentVoiceV1 accentVoice,
  }) {
    if (token.kind == PatternTokenKindV1.flam) {
      return PatternAudioSampleV1.flam;
    }
    if (token.kind == PatternTokenKindV1.accent) {
      if (voice == DrumVoiceV1.crash) {
        return PatternAudioSampleV1.accentCrash;
      }
      if (voice == DrumVoiceV1.ride) {
        return PatternAudioSampleV1.accentRide;
      }
      if (voice == DrumVoiceV1.hihat) {
        return PatternAudioSampleV1.hihat;
      }
      return switch (accentVoice) {
        AccentVoiceV1.snare => PatternAudioSampleV1.accentSnare,
        AccentVoiceV1.crash => PatternAudioSampleV1.accentCrash,
        AccentVoiceV1.ride => PatternAudioSampleV1.accentRide,
      };
    }
    if (token.isKick || voice == DrumVoiceV1.kick) {
      return PatternAudioSampleV1.kick;
    }
    return switch (voice) {
      DrumVoiceV1.hihat => PatternAudioSampleV1.hihat,
      DrumVoiceV1.rackTom => PatternAudioSampleV1.rackTom,
      DrumVoiceV1.tom2 => PatternAudioSampleV1.tom2,
      DrumVoiceV1.floorTom => PatternAudioSampleV1.floorTom,
      DrumVoiceV1.crash => PatternAudioSampleV1.accentCrash,
      DrumVoiceV1.ride => PatternAudioSampleV1.accentRide,
      DrumVoiceV1.kick => PatternAudioSampleV1.kick,
      DrumVoiceV1.snare => switch (marking) {
        PatternNoteMarkingV1.accent => PatternAudioSampleV1.snareAccent,
        PatternNoteMarkingV1.ghost => PatternAudioSampleV1.snareGhost,
        PatternNoteMarkingV1.normal => PatternAudioSampleV1.snare,
      },
    };
  }

  static double _volumeFor({
    required PatternTokenV1 token,
    required DrumVoiceV1 voice,
    required PatternAudioSampleV1 sample,
    required PatternNoteMarkingV1 marking,
    required PatternAudioMixerConfigV1 mixerConfig,
  }) {
    if (token.isKick || voice == DrumVoiceV1.kick) {
      return mixerConfig.kickVolume;
    }
    if (sample == PatternAudioSampleV1.accentCrash) {
      return mixerConfig.crashVolume;
    }
    if (token.kind == PatternTokenKindV1.accent) {
      return mixerConfig.accentVolume;
    }
    return switch (marking) {
      PatternNoteMarkingV1.accent => mixerConfig.accentVolume,
      PatternNoteMarkingV1.ghost => mixerConfig.ghostVolume,
      PatternNoteMarkingV1.normal =>
        _isCymbalVoice(voice)
            ? mixerConfig.normalCymbalVolume
            : mixerConfig.normalNonCymbalVolume,
    };
  }

  static bool _isCymbalVoice(DrumVoiceV1 voice) {
    return voice == DrumVoiceV1.hihat ||
        voice == DrumVoiceV1.crash ||
        voice == DrumVoiceV1.ride;
  }
}
