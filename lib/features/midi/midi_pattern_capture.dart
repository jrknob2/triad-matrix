import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../practice/widgets/sheet_notation_display.dart';
import 'midi_input_models.dart';

enum MidiPatternCaptureTempoMode { auto, fixed }

enum MidiPatternCaptureStatus {
  idle,
  countingIn,
  recording,
  analyzing,
  finishingCycle,
  captured,
  review,
  error,
}

@immutable
class MidiPatternCaptureConfig {
  final String timeSignature;
  final int measureCount;
  final MidiPatternCaptureTempoMode tempoMode;
  final int fixedBpm;
  final int countInMeasures;
  final bool autoStopWhenRecognized;
  final Duration simultaneousWindow;
  final Duration liveUpdateInterval;
  final int tempoIntervalSampleCount;
  final double tempoEventsPerQuarterNote;
  final int minimumEstimatedBpm;
  final int maximumEstimatedBpm;
  final int minimumRecognizedRepetitions;
  final double recognitionConfidenceMinimum;
  final double eventAgreementMinimum;
  final Duration onsetClusterTolerance;
  final int ghostVelocityMaximum;
  final int accentVelocityMinimum;
  final DrumSheetStrokeHand ghostStrokeHand;
  final DrumSheetStrokeHand accentStrokeHand;

  const MidiPatternCaptureConfig({
    this.timeSignature = '4/4',
    this.measureCount = 1,
    this.tempoMode = MidiPatternCaptureTempoMode.auto,
    this.fixedBpm = 92,
    this.countInMeasures = 0,
    this.autoStopWhenRecognized = true,
    this.simultaneousWindow = const Duration(milliseconds: 30),
    this.liveUpdateInterval = const Duration(milliseconds: 100),
    this.tempoIntervalSampleCount = 8,
    this.tempoEventsPerQuarterNote = 2,
    this.minimumEstimatedBpm = 30,
    this.maximumEstimatedBpm = 300,
    this.minimumRecognizedRepetitions = 3,
    this.recognitionConfidenceMinimum = 0.85,
    this.eventAgreementMinimum = 0.75,
    this.onsetClusterTolerance = const Duration(milliseconds: 70),
    this.ghostVelocityMaximum = 63,
    this.accentVelocityMinimum = 100,
    this.ghostStrokeHand = DrumSheetStrokeHand.left,
    this.accentStrokeHand = DrumSheetStrokeHand.right,
  }) : assert(
         timeSignature == '4/4' ||
             timeSignature == '3/4' ||
             timeSignature == '6/8',
       ),
       assert(
         measureCount == 1 ||
             measureCount == 2 ||
             measureCount == 4 ||
             measureCount == 8,
       ),
       assert(fixedBpm >= 30 && fixedBpm <= 300),
       assert(
         countInMeasures == 0 || countInMeasures == 1 || countInMeasures == 2,
       ),
       assert(tempoIntervalSampleCount > 0),
       assert(tempoEventsPerQuarterNote > 0),
       assert(minimumEstimatedBpm > 0),
       assert(maximumEstimatedBpm >= minimumEstimatedBpm),
       assert(minimumRecognizedRepetitions > 0),
       assert(recognitionConfidenceMinimum > 0),
       assert(recognitionConfidenceMinimum <= 1),
       assert(eventAgreementMinimum > 0),
       assert(eventAgreementMinimum <= 1),
       assert(ghostVelocityMaximum >= 0),
       assert(ghostVelocityMaximum < accentVelocityMinimum),
       assert(accentVelocityMinimum <= 127);

  bool get isFixedTempo => tempoMode == MidiPatternCaptureTempoMode.fixed;

  MidiPatternCaptureConfig copyWith({
    String? timeSignature,
    int? measureCount,
    MidiPatternCaptureTempoMode? tempoMode,
    int? fixedBpm,
    int? countInMeasures,
    bool? autoStopWhenRecognized,
    Duration? simultaneousWindow,
    Duration? liveUpdateInterval,
    int? tempoIntervalSampleCount,
    double? tempoEventsPerQuarterNote,
    int? minimumEstimatedBpm,
    int? maximumEstimatedBpm,
    int? minimumRecognizedRepetitions,
    double? recognitionConfidenceMinimum,
    double? eventAgreementMinimum,
    Duration? onsetClusterTolerance,
    int? ghostVelocityMaximum,
    int? accentVelocityMinimum,
    DrumSheetStrokeHand? ghostStrokeHand,
    DrumSheetStrokeHand? accentStrokeHand,
  }) {
    return MidiPatternCaptureConfig(
      timeSignature: timeSignature ?? this.timeSignature,
      measureCount: measureCount ?? this.measureCount,
      tempoMode: tempoMode ?? this.tempoMode,
      fixedBpm: fixedBpm ?? this.fixedBpm,
      countInMeasures: countInMeasures ?? this.countInMeasures,
      autoStopWhenRecognized:
          autoStopWhenRecognized ?? this.autoStopWhenRecognized,
      simultaneousWindow: simultaneousWindow ?? this.simultaneousWindow,
      liveUpdateInterval: liveUpdateInterval ?? this.liveUpdateInterval,
      tempoIntervalSampleCount:
          tempoIntervalSampleCount ?? this.tempoIntervalSampleCount,
      tempoEventsPerQuarterNote:
          tempoEventsPerQuarterNote ?? this.tempoEventsPerQuarterNote,
      minimumEstimatedBpm: minimumEstimatedBpm ?? this.minimumEstimatedBpm,
      maximumEstimatedBpm: maximumEstimatedBpm ?? this.maximumEstimatedBpm,
      minimumRecognizedRepetitions:
          minimumRecognizedRepetitions ?? this.minimumRecognizedRepetitions,
      recognitionConfidenceMinimum:
          recognitionConfidenceMinimum ?? this.recognitionConfidenceMinimum,
      eventAgreementMinimum:
          eventAgreementMinimum ?? this.eventAgreementMinimum,
      onsetClusterTolerance:
          onsetClusterTolerance ?? this.onsetClusterTolerance,
      ghostVelocityMaximum: ghostVelocityMaximum ?? this.ghostVelocityMaximum,
      accentVelocityMinimum:
          accentVelocityMinimum ?? this.accentVelocityMinimum,
      ghostStrokeHand: ghostStrokeHand ?? this.ghostStrokeHand,
      accentStrokeHand: accentStrokeHand ?? this.accentStrokeHand,
    );
  }
}

@immutable
class CapturedMidiHit {
  final DrumVoice voice;
  final int velocity;
  final Duration offset;
  final DrumSheetStrokeDescriptor? stroke;
  final RawMidiEvent? raw;
  final DrumInputEvent? drum;

  const CapturedMidiHit({
    required this.voice,
    required this.velocity,
    required this.offset,
    this.stroke,
    this.raw,
    this.drum,
  });
}

@immutable
class CapturedMidiRawEvent {
  final RawMidiEvent raw;
  final DrumInputEvent? drum;
  final Duration offset;

  const CapturedMidiRawEvent({
    required this.raw,
    required this.offset,
    this.drum,
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

@immutable
class CapturedPatternResult {
  final String pattern;
  final MidiPatternCaptureConfig config;
  final MidiTempoEstimate? tempoEstimate;
  final bool recognized;
  final double confidence;
  final int repetitionCount;
  final Duration? cycleDuration;
  final DrumSheetNoteValue subdivision;
  final DrumSheetFeel feel;
  final List<DrumSheetNoteValue?> noteValueOverrides;
  final String? warning;

  const CapturedPatternResult({
    required this.pattern,
    required this.config,
    required this.tempoEstimate,
    required this.recognized,
    required this.confidence,
    required this.repetitionCount,
    required this.cycleDuration,
    required this.subdivision,
    required this.feel,
    required this.noteValueOverrides,
    this.warning,
  });

  bool get hasPattern => pattern.trim().isNotEmpty;
}

class MidiPatternCaptureController extends ChangeNotifier {
  final DateTime Function() _clock;
  final Future<void> Function() _recognitionSignal;

  MidiPatternBuilder _builder;
  final List<CapturedMidiHit> _hits = <CapturedMidiHit>[];
  final List<CapturedMidiRawEvent> _rawEvents = <CapturedMidiRawEvent>[];
  MidiPatternCaptureStatus _status = MidiPatternCaptureStatus.idle;
  String _generatedPattern = '';
  MidiTempoEstimate? _tempoEstimate;
  CapturedPatternResult? _result;
  String? _statusMessage;
  DateTime? _startedAt;
  Timer? _liveUpdateTimer;
  Timer? _countInTimer;
  Timer? _autoStopTimer;
  bool _recognitionSignalPlayed = false;

  MidiPatternCaptureController({
    MidiPatternBuilder builder = const MidiPatternBuilder(),
    DateTime Function()? clock,
    Future<void> Function()? recognitionSignal,
  }) : _builder = builder,
       _clock = clock ?? DateTime.now,
       _recognitionSignal = recognitionSignal ?? _defaultRecognitionSignal;

  MidiPatternBuilder get builder => _builder;
  MidiPatternCaptureConfig get config => _builder.config;
  MidiPatternCaptureStatus get status => _status;
  String? get statusMessage => _statusMessage;
  bool get isRecording {
    return switch (_status) {
      MidiPatternCaptureStatus.countingIn ||
      MidiPatternCaptureStatus.recording ||
      MidiPatternCaptureStatus.analyzing ||
      MidiPatternCaptureStatus.finishingCycle => true,
      _ => false,
    };
  }

  String get generatedPattern => _generatedPattern;
  MidiTempoEstimate? get tempoEstimate => _tempoEstimate;
  CapturedPatternResult? get result => _result;
  List<CapturedMidiHit> get capturedHits => List.unmodifiable(_hits);
  List<CapturedMidiRawEvent> get rawEvents => List.unmodifiable(_rawEvents);

  void updateConfig(MidiPatternCaptureConfig config) {
    if (isRecording) return;
    _builder = MidiPatternBuilder(config: config);
    _result = _result == null
        ? null
        : _builder.analyzePattern(_hits, forceBestEffort: true);
    _generatedPattern = _result?.pattern ?? _generatedPattern;
    _tempoEstimate = _result?.tempoEstimate ?? _tempoEstimate;
    notifyListeners();
  }

  void record([MidiPatternCaptureConfig? config]) {
    if (config != null) {
      updateConfig(config);
    }
    _liveUpdateTimer?.cancel();
    _liveUpdateTimer = null;
    _countInTimer?.cancel();
    _countInTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _hits.clear();
    _rawEvents.clear();
    _generatedPattern = '';
    _tempoEstimate = null;
    _result = null;
    _recognitionSignalPlayed = false;
    if (_builder.config.countInMeasures > 0 && _builder.config.isFixedTempo) {
      _startedAt = null;
      _status = MidiPatternCaptureStatus.countingIn;
      _statusMessage =
          'Count-in: ${_builder.config.countInMeasures} measure${_builder.config.countInMeasures == 1 ? '' : 's'}.';
      _countInTimer = Timer(_countInDuration(_builder.config), () {
        _countInTimer = null;
        _beginRecording();
      });
    } else {
      _beginRecording();
    }
    notifyListeners();
  }

  void _beginRecording() {
    _startedAt = _clock();
    _status = MidiPatternCaptureStatus.recording;
    _statusMessage = 'Listening for a repeated pattern.';
    notifyListeners();
  }

  String stop() {
    if (!isRecording) {
      return _generatedPattern;
    }
    _liveUpdateTimer?.cancel();
    _liveUpdateTimer = null;
    _countInTimer?.cancel();
    _countInTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _status = MidiPatternCaptureStatus.analyzing;
    _regeneratePattern(forceNotify: true);
    _status = _generatedPattern.trim().isEmpty
        ? MidiPatternCaptureStatus.idle
        : MidiPatternCaptureStatus.captured;
    _statusMessage = _generatedPattern.trim().isEmpty
        ? 'No supported MIDI hits captured.'
        : 'Captured pattern ready to review.';
    notifyListeners();
    return _generatedPattern;
  }

  void clear() {
    _liveUpdateTimer?.cancel();
    _liveUpdateTimer = null;
    _countInTimer?.cancel();
    _countInTimer = null;
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _hits.clear();
    _rawEvents.clear();
    _generatedPattern = '';
    _tempoEstimate = null;
    _result = null;
    _startedAt = isRecording ? _clock() : null;
    _status = MidiPatternCaptureStatus.idle;
    _statusMessage = null;
    _recognitionSignalPlayed = false;
    notifyListeners();
  }

  void captureMappedEvent({
    required RawMidiEvent raw,
    required DrumInputEvent drum,
    DrumSheetStrokeDescriptor? stroke,
  }) {
    if (!_acceptsInput) {
      return;
    }
    final DateTime startedAt = _startedAt ?? raw.timestamp;
    final Duration offset = raw.timestamp.difference(startedAt);
    final Duration clampedOffset = offset.isNegative ? Duration.zero : offset;
    _rawEvents.add(
      CapturedMidiRawEvent(
        raw: raw,
        drum: drum.voice == DrumVoice.unknown ? null : drum,
        offset: clampedOffset,
      ),
    );
    if (raw.messageType != MidiMessageType.noteOn) {
      return;
    }
    if (raw.velocity <= 0) {
      return;
    }
    if (drum.voice == DrumVoice.unknown) {
      return;
    }

    final DrumSheetStrokeDescriptor? resolvedStroke =
        stroke ?? _strokeForCapturedVelocity(raw.velocity, drum.voice);
    _hits.add(
      CapturedMidiHit(
        voice: drum.voice,
        velocity: raw.velocity,
        offset: clampedOffset,
        stroke: resolvedStroke,
        raw: raw,
        drum: drum,
      ),
    );
    _scheduleLiveUpdate();
  }

  void capture(MidiDiagnosticEvent event) {
    captureMappedEvent(raw: event.raw, drum: event.drum);
  }

  void _scheduleLiveUpdate() {
    if (_liveUpdateTimer != null) return;
    _liveUpdateTimer = Timer(_builder.config.liveUpdateInterval, () {
      _liveUpdateTimer = null;
      _regeneratePattern();
    });
  }

  void _regeneratePattern({bool forceNotify = false}) {
    final CapturedPatternResult nextResult = _builder.analyzePattern(
      _hits,
      forceBestEffort: true,
    );
    final String nextPattern = nextResult.pattern;
    final MidiTempoEstimate? nextTempoEstimate = nextResult.tempoEstimate;
    if (nextPattern == _generatedPattern &&
        _tempoEstimateEquals(nextTempoEstimate, _tempoEstimate) &&
        nextResult.recognized == _result?.recognized &&
        nextResult.repetitionCount == _result?.repetitionCount &&
        !forceNotify) {
      return;
    }
    _generatedPattern = nextPattern;
    _tempoEstimate = nextTempoEstimate;
    _result = nextResult;
    if (_status == MidiPatternCaptureStatus.recording ||
        _status == MidiPatternCaptureStatus.finishingCycle) {
      _statusMessage = _captureStatusMessage(nextResult);
    }
    if (_shouldArmAutoStop(nextResult)) {
      _armAutoStop(nextResult);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _liveUpdateTimer?.cancel();
    _countInTimer?.cancel();
    _autoStopTimer?.cancel();
    super.dispose();
  }

  bool get _acceptsInput {
    return _status == MidiPatternCaptureStatus.recording ||
        _status == MidiPatternCaptureStatus.finishingCycle;
  }

  DrumSheetStrokeDescriptor? _strokeForCapturedVelocity(
    int velocity,
    DrumVoice voice,
  ) {
    if (!_supportsVelocityArticulation(voice)) return null;
    if (velocity <= _builder.config.ghostVelocityMaximum) {
      return DrumSheetStrokeDescriptor(
        hand: _builder.config.ghostStrokeHand,
        articulation: DrumSheetStrokeArticulation.ghost,
      );
    }
    if (velocity >= _builder.config.accentVelocityMinimum) {
      return DrumSheetStrokeDescriptor(
        hand: _builder.config.accentStrokeHand,
        articulation: DrumSheetStrokeArticulation.accent,
      );
    }
    return null;
  }

  bool _shouldArmAutoStop(CapturedPatternResult result) {
    return _status == MidiPatternCaptureStatus.recording &&
        _builder.config.autoStopWhenRecognized &&
        result.recognized &&
        !_recognitionSignalPlayed;
  }

  void _armAutoStop(CapturedPatternResult result) {
    _recognitionSignalPlayed = true;
    _status = MidiPatternCaptureStatus.finishingCycle;
    _statusMessage = 'Pattern recognized. Finish this repetition.';
    unawaited(_recognitionSignal());
    final Duration? cycleDuration = result.cycleDuration;
    if (cycleDuration == null || cycleDuration <= Duration.zero) {
      stop();
      return;
    }
    final DateTime startedAt = _startedAt ?? _clock();
    final Duration elapsed = _clock().difference(startedAt);
    final int cycleMicros = cycleDuration.inMicroseconds;
    final int elapsedMicros = elapsed.inMicroseconds < 0
        ? 0
        : elapsed.inMicroseconds;
    final int remainder = elapsedMicros % cycleMicros;
    final Duration remaining = remainder == 0
        ? cycleDuration
        : Duration(microseconds: cycleMicros - remainder);
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(remaining, () {
      _autoStopTimer = null;
      stop();
    });
  }

  String _captureStatusMessage(CapturedPatternResult result) {
    if (_hits.isEmpty) return 'Listening for a repeated pattern.';
    if (result.recognized) return 'Pattern recognized.';
    if (result.repetitionCount <= 1) return 'Repetition 1 captured.';
    return 'Confirming pattern: repetition ${result.repetitionCount}.';
  }

  static Future<void> _defaultRecognitionSignal() {
    return SystemSound.play(SystemSoundType.alert);
  }
}

class MidiPatternBuilder {
  final MidiPatternCaptureConfig config;

  const MidiPatternBuilder({this.config = const MidiPatternCaptureConfig()});

  CapturedPatternResult analyzePattern(
    List<CapturedMidiHit> hits, {
    bool forceBestEffort = false,
  }) {
    final List<CapturedMidiHit> supportedHits = _supportedHits(hits);
    final String bestEffortPattern = _buildPatternFromSupported(supportedHits);
    final MidiTempoEstimate? estimate = estimateTempo(supportedHits);
    CapturedPatternResult bestEffort() {
      final Duration? quarterDuration = estimate == null
          ? null
          : Duration(
              microseconds: (_microsecondsPerMinute / estimate.bpm).round(),
            );
      final _CapturedRhythm rhythm = _inferRhythm(
        _eventPositions(_simultaneousGroups(supportedHits)),
        quarterDuration,
      );
      return CapturedPatternResult(
        pattern: bestEffortPattern,
        config: config,
        tempoEstimate: estimate,
        recognized: false,
        confidence: 0,
        repetitionCount: _bestEffortRepetitionCount(
          supportedHits,
          estimate?.bpm,
        ),
        cycleDuration: _cycleDurationFor(estimate?.bpm),
        subdivision: rhythm.subdivision,
        feel: rhythm.feel,
        noteValueOverrides: rhythm.noteValueOverrides,
      );
    }

    if (supportedHits.isEmpty) {
      return bestEffort();
    }

    final double? bpm = config.isFixedTempo
        ? config.fixedBpm.toDouble()
        : estimate?.bpm;
    final Duration? cycleDuration = _cycleDurationFor(bpm);
    if (bpm == null || cycleDuration == null) {
      return bestEffort();
    }

    final List<List<CapturedMidiHit>> groups = _simultaneousGroups(
      supportedHits,
    );
    final _RecognizedCycle? recognized = _recognizeRepeatedCycle(
      groups,
      cycleDuration,
    );
    if (recognized == null) {
      return bestEffort();
    }

    final List<DrumSheetNotationNote> notes = <DrumSheetNotationNote>[
      for (final _CycleCluster cluster in recognized.clusters)
        if (_noteForGroup(cluster.representativeGroup)
            case final DrumSheetNotationNote note)
          note,
    ];
    final String pattern = DrumSheetPatternParser.serialize(notes);
    final _CapturedRhythm rhythm = _inferRhythm(
      recognized.positions,
      Duration(
        microseconds:
            (cycleDuration.inMicroseconds /
                    (_quarterNoteBeatsForTimeSignature(config.timeSignature) *
                        config.measureCount))
                .round(),
      ),
    );

    return CapturedPatternResult(
      pattern: pattern,
      config: config,
      tempoEstimate: MidiTempoEstimate(
        bpm: bpm,
        intervalCount: estimate?.intervalCount ?? 0,
        averageOnsetInterval:
            estimate?.averageOnsetInterval ??
            Duration(microseconds: (_microsecondsPerMinute / bpm / 2).round()),
      ),
      recognized: true,
      confidence: recognized.confidence,
      repetitionCount: recognized.repetitionCount,
      cycleDuration: cycleDuration,
      subdivision: rhythm.subdivision,
      feel: rhythm.feel,
      noteValueOverrides: rhythm.noteValueOverrides,
    );
  }

  String buildPattern(List<CapturedMidiHit> hits) {
    return _buildPatternFromSupported(_supportedHits(hits));
  }

  List<CapturedMidiHit> _supportedHits(List<CapturedMidiHit> hits) {
    return hits
        .where((CapturedMidiHit hit) => _voiceLabel(hit.voice) != null)
        .toList(growable: false)
      ..sort(
        (CapturedMidiHit a, CapturedMidiHit b) => a.offset.compareTo(b.offset),
      );
  }

  String _buildPatternFromSupported(List<CapturedMidiHit> supportedHits) {
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

  _RecognizedCycle? _recognizeRepeatedCycle(
    List<List<CapturedMidiHit>> groups,
    Duration cycleDuration,
  ) {
    final int cycleMicros = cycleDuration.inMicroseconds;
    if (cycleMicros <= 0 || groups.isEmpty) return null;

    final List<_CycleOnset> onsets = <_CycleOnset>[];
    for (final List<CapturedMidiHit> group in groups) {
      final Duration onset = _onsetForGroup(group);
      final int cycleIndex = onset.inMicroseconds ~/ cycleMicros;
      final Duration cyclePosition = Duration(
        microseconds: onset.inMicroseconds - cycleIndex * cycleMicros,
      );
      onsets.add(
        _CycleOnset(
          cycleIndex: cycleIndex,
          position: cyclePosition,
          group: group,
          signature: _groupSignature(group),
        ),
      );
    }

    final int repetitionCount =
        onsets
            .map((_CycleOnset onset) => onset.cycleIndex)
            .reduce((int left, int right) => left > right ? left : right) +
        1;
    if (repetitionCount < config.minimumRecognizedRepetitions) {
      return null;
    }

    final List<_CycleCluster> clusters = <_CycleCluster>[];
    for (final _CycleOnset onset in onsets) {
      final _CycleCluster? match = _matchingCluster(clusters, onset);
      if (match == null) {
        clusters.add(_CycleCluster(onset));
      } else {
        match.add(onset);
      }
    }

    final List<_CycleCluster> accepted =
        clusters
            .where(
              (_CycleCluster cluster) =>
                  cluster.agreement(repetitionCount) >=
                  config.eventAgreementMinimum,
            )
            .toList(growable: false)
          ..sort(
            (_CycleCluster a, _CycleCluster b) =>
                a.averagePosition.compareTo(b.averagePosition),
          );
    if (accepted.isEmpty) return null;

    final double averageAgreement =
        accepted
            .map((_CycleCluster cluster) => cluster.agreement(repetitionCount))
            .reduce((double left, double right) => left + right) /
        accepted.length;
    final double confidence = averageAgreement >= config.eventAgreementMinimum
        ? 0.85 +
              (((averageAgreement - config.eventAgreementMinimum) /
                              (1 - config.eventAgreementMinimum))
                          .clamp(0, 1))
                      .toDouble() *
                  0.15
        : averageAgreement;
    if (confidence < config.recognitionConfidenceMinimum) {
      return null;
    }

    return _RecognizedCycle(
      clusters: accepted,
      confidence: confidence,
      repetitionCount: repetitionCount,
    );
  }

  _CycleCluster? _matchingCluster(
    List<_CycleCluster> clusters,
    _CycleOnset onset,
  ) {
    for (final _CycleCluster cluster in clusters) {
      if (cluster.signature != onset.signature) continue;
      final Duration delta = cluster.averagePosition - onset.position;
      final Duration absoluteDelta = delta.isNegative ? -delta : delta;
      if (absoluteDelta <= config.onsetClusterTolerance) return cluster;
    }
    return null;
  }

  String _groupSignature(List<CapturedMidiHit> group) {
    final List<DrumVoice> voices =
        <DrumVoice>[for (final CapturedMidiHit hit in group) hit.voice]..sort(
          (DrumVoice a, DrumVoice b) =>
              _voiceOrder(a).compareTo(_voiceOrder(b)),
        );
    return voices.map((DrumVoice voice) => voice.name).join('+');
  }

  List<Duration> _eventPositions(List<List<CapturedMidiHit>> groups) {
    return <Duration>[
      for (final List<CapturedMidiHit> group in groups) _onsetForGroup(group),
    ];
  }

  int _bestEffortRepetitionCount(List<CapturedMidiHit> hits, double? bpm) {
    final Duration? cycleDuration = _cycleDurationFor(bpm);
    if (hits.isEmpty || cycleDuration == null) return 0;
    final Duration lastOffset = hits.last.offset;
    return lastOffset.inMicroseconds ~/ cycleDuration.inMicroseconds + 1;
  }

  Duration? _cycleDurationFor(double? bpm) {
    if (bpm == null || bpm <= 0) return null;
    final double quarterBeats =
        _quarterNoteBeatsForTimeSignature(config.timeSignature) *
        config.measureCount;
    return Duration(
      microseconds: (quarterBeats * _microsecondsPerMinute / bpm).round(),
    );
  }

  _CapturedRhythm _inferRhythm(
    List<Duration> positions,
    Duration? quarterDuration,
  ) {
    if (positions.length < 2 || quarterDuration == null) {
      return const _CapturedRhythm(
        subdivision: DrumSheetNoteValue.eighth,
        feel: DrumSheetFeel.straight,
        noteValueOverrides: <DrumSheetNoteValue?>[],
      );
    }

    final List<Duration> sorted = positions.toList(growable: false)..sort();
    final List<double> intervalBeats = <double>[];
    for (int index = 1; index < sorted.length; index += 1) {
      final int intervalMicros =
          (sorted[index] - sorted[index - 1]).inMicroseconds;
      if (intervalMicros <= 0) continue;
      intervalBeats.add(intervalMicros / quarterDuration.inMicroseconds);
    }
    if (intervalBeats.isEmpty) {
      return const _CapturedRhythm(
        subdivision: DrumSheetNoteValue.eighth,
        feel: DrumSheetFeel.straight,
        noteValueOverrides: <DrumSheetNoteValue?>[],
      );
    }

    intervalBeats.sort();
    final double smallest = intervalBeats.first;
    final _SubdivisionCandidate candidate = _closestSubdivision(smallest);
    return _CapturedRhythm(
      subdivision: candidate.value,
      feel: candidate.feel,
      noteValueOverrides: List<DrumSheetNoteValue?>.filled(
        positions.length,
        null,
        growable: false,
      ),
    );
  }
}

const int _microsecondsPerMinute = 60 * Duration.microsecondsPerSecond;

@immutable
class _CycleOnset {
  final int cycleIndex;
  final Duration position;
  final List<CapturedMidiHit> group;
  final String signature;

  const _CycleOnset({
    required this.cycleIndex,
    required this.position,
    required this.group,
    required this.signature,
  });
}

class _CycleCluster {
  final List<_CycleOnset> onsets = <_CycleOnset>[];

  _CycleCluster(_CycleOnset onset) {
    add(onset);
  }

  String get signature => onsets.first.signature;

  Duration get averagePosition {
    final int averageMicros =
        onsets
            .map((_CycleOnset onset) => onset.position.inMicroseconds)
            .reduce((int total, int micros) => total + micros) ~/
        onsets.length;
    return Duration(microseconds: averageMicros);
  }

  List<CapturedMidiHit> get representativeGroup => onsets.first.group;

  Set<int> get cycleIndexes {
    return <int>{for (final _CycleOnset onset in onsets) onset.cycleIndex};
  }

  void add(_CycleOnset onset) {
    onsets.add(onset);
  }

  double agreement(int repetitionCount) {
    if (repetitionCount <= 0) return 0;
    return cycleIndexes.length / repetitionCount;
  }
}

@immutable
class _RecognizedCycle {
  final List<_CycleCluster> clusters;
  final double confidence;
  final int repetitionCount;

  const _RecognizedCycle({
    required this.clusters,
    required this.confidence,
    required this.repetitionCount,
  });

  List<Duration> get positions {
    return <Duration>[
      for (final _CycleCluster cluster in clusters) cluster.averagePosition,
    ];
  }
}

@immutable
class _CapturedRhythm {
  final DrumSheetNoteValue subdivision;
  final DrumSheetFeel feel;
  final List<DrumSheetNoteValue?> noteValueOverrides;

  const _CapturedRhythm({
    required this.subdivision,
    required this.feel,
    required this.noteValueOverrides,
  });
}

@immutable
class _SubdivisionCandidate {
  final DrumSheetNoteValue value;
  final DrumSheetFeel feel;
  final double beats;

  const _SubdivisionCandidate({
    required this.value,
    required this.feel,
    required this.beats,
  });
}

_SubdivisionCandidate _closestSubdivision(double beats) {
  const List<_SubdivisionCandidate> candidates = <_SubdivisionCandidate>[
    _SubdivisionCandidate(
      value: DrumSheetNoteValue.quarter,
      feel: DrumSheetFeel.straight,
      beats: 1,
    ),
    _SubdivisionCandidate(
      value: DrumSheetNoteValue.eighth,
      feel: DrumSheetFeel.straight,
      beats: 0.5,
    ),
    _SubdivisionCandidate(
      value: DrumSheetNoteValue.eighth,
      feel: DrumSheetFeel.triplet,
      beats: 1 / 3,
    ),
    _SubdivisionCandidate(
      value: DrumSheetNoteValue.sixteenth,
      feel: DrumSheetFeel.straight,
      beats: 0.25,
    ),
    _SubdivisionCandidate(
      value: DrumSheetNoteValue.sixteenth,
      feel: DrumSheetFeel.triplet,
      beats: 1 / 6,
    ),
  ];

  return candidates.reduce((
    _SubdivisionCandidate best,
    _SubdivisionCandidate candidate,
  ) {
    final double bestDistance = (best.beats - beats).abs();
    final double candidateDistance = (candidate.beats - beats).abs();
    return candidateDistance < bestDistance ? candidate : best;
  });
}

double _quarterNoteBeatsForTimeSignature(String timeSignature) {
  final List<String> parts = timeSignature.split('/');
  if (parts.length != 2) return 4;
  final int? numerator = int.tryParse(parts[0]);
  final int? denominator = int.tryParse(parts[1]);
  if (numerator == null || denominator == null || denominator == 0) return 4;
  return numerator * 4 / denominator;
}

Duration _countInDuration(MidiPatternCaptureConfig config) {
  if (!config.isFixedTempo || config.countInMeasures <= 0) {
    return Duration.zero;
  }
  final double quarterBeats =
      _quarterNoteBeatsForTimeSignature(config.timeSignature) *
      config.countInMeasures;
  return Duration(
    microseconds: (quarterBeats * _microsecondsPerMinute / config.fixedBpm)
        .round(),
  );
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
