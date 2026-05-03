import 'dart:async';

import 'package:audio_session/audio_session.dart';
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
  final double volume;

  const PatternAudioCueV1({
    required this.tokenIndex,
    required this.offset,
    required this.sample,
    required this.volume,
  });
}

class PatternAudioPlanV1 {
  final List<PatternAudioCueV1> cues;
  final Duration cycleDuration;

  const PatternAudioPlanV1({required this.cues, required this.cycleDuration});
}

class PatternAudioService {
  static const int _playerPoolSize = 4;
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

  bool _prepared = false;
  bool _running = false;
  Timer? _cycleTimer;
  final List<Timer> _cueTimers = <Timer>[];

  Future<void> prepare() async {
    if (_prepared) return;
    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    for (final PatternAudioSampleV1 sample in PatternAudioSampleV1.values) {
      final String assetPath = assetPaths[sample]!;
      for (final AudioPlayer player in _playersBySample[sample]!) {
        await player.setAsset(assetPath);
        await player.setVolume(1.0);
        await player.seek(Duration.zero);
        await player.pause();
      }
    }
    _prepared = true;
  }

  Future<void> start({
    required List<PatternTokenV1> tokens,
    required List<PatternNoteMarkingV1> markings,
    required List<DrumVoiceV1> voices,
    required PatternGroupingV1 grouping,
    required PatternTimingV1 timing,
    required int bpm,
    AccentVoiceV1 accentVoice = AccentVoiceV1.snare,
    Duration startElapsed = Duration.zero,
  }) async {
    await prepare();
    await stop();

    final PatternAudioPlanV1 plan = buildPlan(
      tokens: tokens,
      markings: markings,
      voices: voices,
      grouping: grouping,
      timing: timing,
      bpm: bpm,
      accentVoice: accentVoice,
    );
    if (plan.cues.isEmpty || plan.cycleDuration <= Duration.zero) return;

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
        await player.pause();
        await player.seek(Duration.zero);
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
      cues.add(
        PatternAudioCueV1(
          tokenIndex: event.tokenIndex,
          offset: Duration(
            microseconds: (event.startBeat * microsPerBeat).round(),
          ),
          sample: _sampleFor(
            token: token,
            voice: voice,
            marking: marking,
            accentVoice: accentVoice,
          ),
          volume: _volumeFor(token: token, voice: voice, marking: marking),
        ),
      );
    }

    return PatternAudioPlanV1(
      cues: List<PatternAudioCueV1>.unmodifiable(cues),
      cycleDuration: Duration(
        microseconds: (playbackPlan.totalBeatCount * microsPerBeat).round(),
      ),
    );
  }

  void _scheduleCycle({
    required PatternAudioPlanV1 plan,
    required Duration phase,
  }) {
    if (!_running) return;
    _cueTimers.removeWhere((Timer timer) => !timer.isActive);
    for (final PatternAudioCueV1 cue in plan.cues) {
      if (phase > Duration.zero && cue.offset < phase) {
        continue;
      }
      final Duration delay = cue.offset - phase;
      _cueTimers.add(
        Timer(delay, () {
          if (!_running) return;
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
    if (token.kind == PatternTokenKindV1.both) {
      return PatternAudioSampleV1.unison;
    }
    if (token.kind == PatternTokenKindV1.accent) {
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
    required PatternNoteMarkingV1 marking,
  }) {
    if (token.isKick || voice == DrumVoiceV1.kick) {
      return switch (marking) {
        PatternNoteMarkingV1.accent => 1.0,
        PatternNoteMarkingV1.ghost => 0.45,
        PatternNoteMarkingV1.normal => 0.92,
      };
    }
    return switch (marking) {
      PatternNoteMarkingV1.accent => 1.0,
      PatternNoteMarkingV1.ghost => 0.42,
      PatternNoteMarkingV1.normal => 0.88,
    };
  }
}
