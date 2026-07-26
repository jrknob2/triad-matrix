import 'dart:async';

import 'package:flutter/foundation.dart';

import '../practice/widgets/sheet_notation_display.dart';
import 'midi_input_models.dart';

@immutable
class MidiPatternCaptureConfig {
  final Duration simultaneousWindow;
  final Duration liveUpdateInterval;
  final int tempoIntervalSampleCount;
  final double tempoEventsPerQuarterNote;
  final int minimumEstimatedBpm;
  final int maximumEstimatedBpm;
  final int ghostVelocityMaximum;
  final int accentVelocityMinimum;
  final DrumSheetStrokeHand ghostStrokeHand;
  final DrumSheetStrokeHand accentStrokeHand;

  const MidiPatternCaptureConfig({
    this.simultaneousWindow = const Duration(milliseconds: 30),
    this.liveUpdateInterval = const Duration(milliseconds: 100),
    this.tempoIntervalSampleCount = 8,
    this.tempoEventsPerQuarterNote = 2,
    this.minimumEstimatedBpm = 30,
    this.maximumEstimatedBpm = 260,
    this.ghostVelocityMaximum = 63,
    this.accentVelocityMinimum = 100,
    this.ghostStrokeHand = DrumSheetStrokeHand.left,
    this.accentStrokeHand = DrumSheetStrokeHand.right,
  }) : assert(tempoIntervalSampleCount > 0),
       assert(tempoEventsPerQuarterNote > 0),
       assert(minimumEstimatedBpm > 0),
       assert(maximumEstimatedBpm >= minimumEstimatedBpm),
       assert(ghostVelocityMaximum >= 0),
       assert(ghostVelocityMaximum < accentVelocityMinimum),
       assert(accentVelocityMinimum <= 127);
}

@immutable
class CapturedMidiHit {
  final DrumVoice voice;
  final int velocity;
  final Duration offset;
  final DrumSheetStrokeDescriptor? stroke;

  const CapturedMidiHit({
    required this.voice,
    required this.velocity,
    required this.offset,
    this.stroke,
  });
}

@immutable
class MidiTempoEstimate {
  final double bpm;
  final int intervalCount;
  final Duration averageOnsetInterval;

  const MidiTempoEstimate({
    required this.bpm,
    required this.intervalCount,
    required this.averageOnsetInterval,
  });

  int get roundedBpm => bpm.round();
}

class MidiPatternCaptureController extends ChangeNotifier {
  final MidiPatternBuilder builder;
  final DateTime Function() _clock;

  final List<CapturedMidiHit> _hits = <CapturedMidiHit>[];
  bool _isRecording = false;
  String _generatedPattern = '';
  MidiTempoEstimate? _tempoEstimate;
  DateTime? _startedAt;
  Timer? _liveUpdateTimer;

  MidiPatternCaptureController({
    this.builder = const MidiPatternBuilder(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  bool get isRecording => _isRecording;
  String get generatedPattern => _generatedPattern;
  MidiTempoEstimate? get tempoEstimate => _tempoEstimate;
  List<CapturedMidiHit> get capturedHits => List.unmodifiable(_hits);

  void record() {
    _liveUpdateTimer?.cancel();
    _liveUpdateTimer = null;
    _hits.clear();
    _generatedPattern = '';
    _tempoEstimate = null;
    _startedAt = _clock();
    _isRecording = true;
    notifyListeners();
  }

  String stop() {
    if (!_isRecording) {
      return _generatedPattern;
    }
    _liveUpdateTimer?.cancel();
    _liveUpdateTimer = null;
    _isRecording = false;
    _regeneratePattern(forceNotify: true);
    return _generatedPattern;
  }

  void clear() {
    _liveUpdateTimer?.cancel();
    _liveUpdateTimer = null;
    _hits.clear();
    _generatedPattern = '';
    _tempoEstimate = null;
    _startedAt = _isRecording ? _clock() : null;
    notifyListeners();
  }

  void captureMappedEvent({
    required RawMidiEvent raw,
    required DrumInputEvent drum,
    DrumSheetStrokeDescriptor? stroke,
  }) {
    if (!_isRecording) {
      return;
    }
    if (raw.messageType != MidiMessageType.noteOn) {
      return;
    }
    if (raw.velocity <= 0) {
      return;
    }

    final DateTime startedAt = _startedAt ?? raw.timestamp;
    final Duration offset = raw.timestamp.difference(startedAt);
    final DrumSheetStrokeDescriptor? resolvedStroke =
        stroke ?? _strokeForCapturedVelocity(raw.velocity, drum.voice);
    _hits.add(
      CapturedMidiHit(
        voice: drum.voice,
        velocity: raw.velocity,
        offset: offset.isNegative ? Duration.zero : offset,
        stroke: resolvedStroke,
      ),
    );
    _scheduleLiveUpdate();
  }

  void capture(MidiDiagnosticEvent event) {
    captureMappedEvent(raw: event.raw, drum: event.drum);
  }

  void _scheduleLiveUpdate() {
    if (_liveUpdateTimer != null) return;
    _liveUpdateTimer = Timer(builder.config.liveUpdateInterval, () {
      _liveUpdateTimer = null;
      _regeneratePattern();
    });
  }

  void _regeneratePattern({bool forceNotify = false}) {
    final String nextPattern = builder.buildPattern(_hits);
    final MidiTempoEstimate? nextTempoEstimate = builder.estimateTempo(_hits);
    if (nextPattern == _generatedPattern &&
        _tempoEstimateEquals(nextTempoEstimate, _tempoEstimate) &&
        !forceNotify) {
      return;
    }
    _generatedPattern = nextPattern;
    _tempoEstimate = nextTempoEstimate;
    notifyListeners();
  }

  @override
  void dispose() {
    _liveUpdateTimer?.cancel();
    super.dispose();
  }

  DrumSheetStrokeDescriptor? _strokeForCapturedVelocity(
    int velocity,
    DrumVoice voice,
  ) {
    if (!_supportsVelocityArticulation(voice)) return null;
    if (velocity <= builder.config.ghostVelocityMaximum) {
      return DrumSheetStrokeDescriptor(
        hand: builder.config.ghostStrokeHand,
        articulation: DrumSheetStrokeArticulation.ghost,
      );
    }
    if (velocity >= builder.config.accentVelocityMinimum) {
      return DrumSheetStrokeDescriptor(
        hand: builder.config.accentStrokeHand,
        articulation: DrumSheetStrokeArticulation.accent,
      );
    }
    return null;
  }
}

class MidiPatternBuilder {
  final MidiPatternCaptureConfig config;

  const MidiPatternBuilder({this.config = const MidiPatternCaptureConfig()});

  String buildPattern(List<CapturedMidiHit> hits) {
    final List<CapturedMidiHit> supportedHits =
        hits
            .where((CapturedMidiHit hit) => _voiceLabel(hit.voice) != null)
            .toList(growable: false)
          ..sort(
            (CapturedMidiHit a, CapturedMidiHit b) =>
                a.offset.compareTo(b.offset),
          );
    if (supportedHits.isEmpty) {
      return '';
    }

    final List<List<CapturedMidiHit>> groups = _simultaneousGroups(
      supportedHits,
    );
    final List<DrumSheetNotationNote> notes = <DrumSheetNotationNote>[
      for (final List<CapturedMidiHit> group in groups)
        if (_noteForGroup(group) case final DrumSheetNotationNote note) note,
    ];
    final String pattern = DrumSheetPatternParser.serialize(notes);

    // Keep the capture path honest: generated output must remain accepted by
    // the same parser used by the rest of the authoring UI during development.
    assert(() {
      DrumSheetPatternParser.parse(pattern);
      return true;
    }());
    return pattern;
  }

  MidiTempoEstimate? estimateTempo(List<CapturedMidiHit> hits) {
    final List<CapturedMidiHit> sortedHits = hits.toList(growable: false)
      ..sort(
        (CapturedMidiHit a, CapturedMidiHit b) => a.offset.compareTo(b.offset),
      );
    final List<List<CapturedMidiHit>> groups = _simultaneousGroups(sortedHits);
    if (groups.length < 2) return null;

    final List<Duration> onsets = groups
        .map(_onsetForGroup)
        .toList(growable: false);
    final List<Duration> intervals = <Duration>[];
    for (int index = 1; index < onsets.length; index += 1) {
      final Duration interval = onsets[index] - onsets[index - 1];
      if (interval > Duration.zero) intervals.add(interval);
    }
    if (intervals.isEmpty) return null;

    final int sampleCount = intervals.length < config.tempoIntervalSampleCount
        ? intervals.length
        : config.tempoIntervalSampleCount;
    final List<Duration> samples = intervals.sublist(
      intervals.length - sampleCount,
    );
    final int averageMicros =
        samples
            .map((Duration interval) => interval.inMicroseconds)
            .reduce((int total, int micros) => total + micros) ~/
        samples.length;
    if (averageMicros <= 0) return null;

    final double secondsPerQuarter =
        (averageMicros / Duration.microsecondsPerSecond) *
        config.tempoEventsPerQuarterNote;
    final double bpm = 60 / secondsPerQuarter;
    if (bpm < config.minimumEstimatedBpm || bpm > config.maximumEstimatedBpm) {
      return null;
    }

    return MidiTempoEstimate(
      bpm: bpm,
      intervalCount: samples.length,
      averageOnsetInterval: Duration(microseconds: averageMicros),
    );
  }

  List<List<CapturedMidiHit>> _simultaneousGroups(List<CapturedMidiHit> hits) {
    final List<List<CapturedMidiHit>> groups = <List<CapturedMidiHit>>[];
    List<CapturedMidiHit> current = <CapturedMidiHit>[];
    Duration? groupStart;

    for (final CapturedMidiHit hit in hits) {
      final Duration? start = groupStart;
      if (start == null || hit.offset - start <= config.simultaneousWindow) {
        current.add(hit);
        groupStart ??= hit.offset;
        continue;
      }

      groups.add(_deduplicateVoices(current));
      current = <CapturedMidiHit>[hit];
      groupStart = hit.offset;
    }

    if (current.isNotEmpty) {
      groups.add(_deduplicateVoices(current));
    }
    return groups;
  }

  List<CapturedMidiHit> _deduplicateVoices(List<CapturedMidiHit> hits) {
    final Map<DrumVoice, CapturedMidiHit> byVoice =
        <DrumVoice, CapturedMidiHit>{};
    for (final CapturedMidiHit hit in hits) {
      final CapturedMidiHit? existing = byVoice[hit.voice];
      if (existing == null || hit.velocity > existing.velocity) {
        byVoice[hit.voice] = hit;
      }
    }
    final List<CapturedMidiHit> deduped = byVoice.values.toList(growable: false)
      ..sort(_compareVoiceOrder);
    return deduped;
  }

  int _compareVoiceOrder(CapturedMidiHit a, CapturedMidiHit b) {
    return _voiceOrder(a.voice).compareTo(_voiceOrder(b.voice));
  }

  Duration _onsetForGroup(List<CapturedMidiHit> group) {
    return group.map((CapturedMidiHit hit) => hit.offset).reduce((
      Duration earliest,
      Duration offset,
    ) {
      return offset < earliest ? offset : earliest;
    });
  }

  DrumSheetNotationNote? _noteForGroup(List<CapturedMidiHit> group) {
    final List<DrumSheetVoiceStroke> voiceStrokes = <DrumSheetVoiceStroke>[];
    for (final CapturedMidiHit hit in group) {
      final DrumSheetVoice? voice = _sheetVoice(hit.voice);
      if (voice == null) continue;
      voiceStrokes.add(DrumSheetVoiceStroke(voice: voice, stroke: hit.stroke));
    }
    if (voiceStrokes.isEmpty) return null;

    final List<DrumSheetVoice> voices = <DrumSheetVoice>[
      for (final DrumSheetVoiceStroke voiceStroke in voiceStrokes)
        voiceStroke.voice,
    ];
    final List<DrumSheetStrokeDescriptor> authoredStrokes =
        <DrumSheetStrokeDescriptor>[
          for (final DrumSheetVoiceStroke voiceStroke in voiceStrokes)
            if (voiceStroke.stroke != null) voiceStroke.stroke!,
        ];
    return DrumSheetNotationNote(
      voices: voices,
      voiceStrokes: voiceStrokes,
      sticking: authoredStrokes
          .map((DrumSheetStrokeDescriptor stroke) => stroke.displayLabel)
          .join(),
      accent: authoredStrokes.any(
        (DrumSheetStrokeDescriptor stroke) =>
            stroke.articulation == DrumSheetStrokeArticulation.accent,
      ),
      ghost:
          authoredStrokes.isNotEmpty &&
          authoredStrokes.every(
            (DrumSheetStrokeDescriptor stroke) =>
                stroke.articulation == DrumSheetStrokeArticulation.ghost,
          ),
    );
  }
}

bool _tempoEstimateEquals(MidiTempoEstimate? left, MidiTempoEstimate? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return false;
  return left.roundedBpm == right.roundedBpm &&
      left.intervalCount == right.intervalCount &&
      left.averageOnsetInterval == right.averageOnsetInterval;
}

String? _voiceLabel(DrumVoice voice) {
  return switch (voice) {
    DrumVoice.snare => 'S',
    DrumVoice.kick => 'K',
    DrumVoice.hiHatClosed || DrumVoice.hiHatPedal => 'HH',
    DrumVoice.hiHatOpen => 'OHH',
    DrumVoice.tom1 => 'T1',
    DrumVoice.tom2 => 'T2',
    DrumVoice.floorTom => 'FT',
    DrumVoice.crash => 'CR',
    DrumVoice.ride => 'RD',
    DrumVoice.unknown => null,
  };
}

int _voiceOrder(DrumVoice voice) {
  return switch (voice) {
    DrumVoice.crash => 0,
    DrumVoice.ride => 1,
    DrumVoice.hiHatClosed => 2,
    DrumVoice.hiHatOpen => 3,
    DrumVoice.hiHatPedal => 4,
    DrumVoice.snare => 5,
    DrumVoice.tom1 => 6,
    DrumVoice.tom2 => 7,
    DrumVoice.floorTom => 8,
    DrumVoice.kick => 9,
    DrumVoice.unknown => 10,
  };
}

DrumSheetVoice? _sheetVoice(DrumVoice voice) {
  return switch (voice) {
    DrumVoice.snare => DrumSheetVoice.snare,
    DrumVoice.kick => DrumSheetVoice.kick,
    DrumVoice.hiHatClosed || DrumVoice.hiHatPedal => DrumSheetVoice.hihat,
    DrumVoice.hiHatOpen => DrumSheetVoice.openHiHat,
    DrumVoice.tom1 => DrumSheetVoice.tom1,
    DrumVoice.tom2 => DrumSheetVoice.tom2,
    DrumVoice.floorTom => DrumSheetVoice.floorTom,
    DrumVoice.crash => DrumSheetVoice.crash,
    DrumVoice.ride => DrumSheetVoice.ride,
    DrumVoice.unknown => null,
  };
}

bool _supportsVelocityArticulation(DrumVoice voice) {
  return switch (voice) {
    DrumVoice.kick || DrumVoice.hiHatPedal || DrumVoice.unknown => false,
    _ => true,
  };
}
