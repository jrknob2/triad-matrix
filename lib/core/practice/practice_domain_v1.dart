import 'package:flutter/foundation.dart';

/// Authoritative rebuild models for the app spec in docs/06 and docs/07.
///
/// These models intentionally define the product domain in one place so the
/// next implementation pass does not repeat the current enum/model drift across
/// multiple files.

/* -------------------------------------------------------------------------- */
/* Enums                                                                      */
/* -------------------------------------------------------------------------- */

enum HandednessV1 { right, left }

enum MaterialFamilyV1 { triad, fourNote, fiveNote, custom, combo, warmup }

enum PracticeItemSourceV1 { builtIn, userDefined, generated }

enum PracticeModeV1 { singleSurface, flow }

enum PatternRoleV1 { groove, fill, chop, rudiment, warmup, transition, unknown }

enum PatternFeelV1 { straight, triplet, shuffle, swing, unknown }

enum PatternLengthHintV1 { fragment, beat, bar, twoBars, unknown }

enum PatternIntensityV1 { low, medium, high, unknown }

enum PracticeSessionEndBehaviorV1 { openSummary, returnToPrevious }

enum PatternTokenKindV1 { right, left, kick, flam, accent, rest }

enum PatternTimingModeV1 { autoByGrouping, explicitSpans }

enum PatternPulseRoleV1 { normal, tag }

enum DrumVoiceV1 { snare, rackTom, tom2, floorTom, hihat, crash, ride, kick }

enum PatternNoteValueV1 {
  whole,
  half,
  quarter,
  eighth,
  sixteenth,
  thirtySecond,
}

enum DrumSubdivision { eight, triplet, sixteen }

enum AccentVoiceV1 { snare, crash, ride }

enum LearningLaneV1 { control, balance, dynamics, integration, phrasing, flow }

enum CompetencyLevelV1 { notStarted, learning, comfortable, reliable, musical }

enum ReflectionRatingV1 { easy, okay, hard }

enum TimerPresetV1 { none, minutes2, minutes5, minutes10, minutes20, minutes30 }

enum TriadMatrixFilterV1 {
  inRoutine,
  inPhrases,
  underPracticed,
  recent,
  notTrained,
  activeStatus,
  needsWorkStatus,
  strongStatus,
  rightLead,
  leftLead,
  handsOnly,
  hasKick,
  startsWithKick,
  endsWithKick,
  doubles,
}

enum WorkingOnSessionFilterV1 {
  handsOnly,
  hasKick,
  flow,
  flowReady,
  needsWork,
  active,
  strongReview,
  rightLead,
  leftLead,
  doubles,
}

enum PatternNoteMarkingV1 { normal, accent, ghost }

enum MatrixProgressStateV1 { notTrained, active, needsWork, strong }

enum CoachBlockTypeV1 {
  summary,
  focus,
  needsWork,
  momentum,
  resume,
  nextUnlock,
}

enum CoachActionV1 {
  startPractice,
  resumePractice,
  openMatrix,
  buildCombo,
  moveToFlow,
}

enum AssessmentInputTypeV1 { manual, singleSurfaceAudio, eDrumAudio, eDrumMidi }

enum AssessmentConfidenceV1 { low, medium, high }

enum SelfReportControlV1 { low, medium, high }

enum SelfReportTensionV1 { none, some, high }

enum SelfReportTempoReadinessV1 { decrease, same, increase }

enum AppMockScenarioV1 {
  firstLight,
  starterItemsSelected,
  earlyStruggle,
  steadyProgress,
  phraseReady,
  flowReady,
}

/* -------------------------------------------------------------------------- */
/* Value Objects                                                              */
/* -------------------------------------------------------------------------- */

@immutable
class UserProfileV1 {
  final HandednessV1 handedness;
  final int defaultBpm;
  final TimerPresetV1 defaultTimerPreset;
  final bool clickEnabledByDefault;
  final AccentVoiceV1 accentVoice;
  final bool darkPracticeSheetNotation;

  const UserProfileV1({
    required this.handedness,
    required this.defaultBpm,
    required this.defaultTimerPreset,
    required this.clickEnabledByDefault,
    required this.accentVoice,
    required this.darkPracticeSheetNotation,
  });

  UserProfileV1 copyWith({
    HandednessV1? handedness,
    int? defaultBpm,
    TimerPresetV1? defaultTimerPreset,
    bool? clickEnabledByDefault,
    AccentVoiceV1? accentVoice,
    bool? darkPracticeSheetNotation,
  }) {
    return UserProfileV1(
      handedness: handedness ?? this.handedness,
      defaultBpm: defaultBpm ?? this.defaultBpm,
      defaultTimerPreset: defaultTimerPreset ?? this.defaultTimerPreset,
      clickEnabledByDefault:
          clickEnabledByDefault ?? this.clickEnabledByDefault,
      accentVoice: accentVoice ?? this.accentVoice,
      darkPracticeSheetNotation:
          darkPracticeSheetNotation ?? this.darkPracticeSheetNotation,
    );
  }

  static const UserProfileV1 initial = UserProfileV1(
    handedness: HandednessV1.right,
    defaultBpm: 92,
    defaultTimerPreset: TimerPresetV1.minutes10,
    clickEnabledByDefault: true,
    accentVoice: AccentVoiceV1.snare,
    darkPracticeSheetNotation: false,
  );
}

@immutable
class PatternGroupingV1 {
  final int? groupSize;
  final String separator;

  const PatternGroupingV1({this.groupSize, this.separator = '-'})
    : assert(groupSize == null || groupSize > 0);

  static const PatternGroupingV1 none = PatternGroupingV1(
    groupSize: null,
    separator: '',
  );

  static const PatternGroupingV1 spaced = PatternGroupingV1(
    groupSize: null,
    separator: ' ',
  );

  static const PatternGroupingV1 triads = PatternGroupingV1(
    groupSize: 3,
    separator: '-',
  );

  static const PatternGroupingV1 fourNote = PatternGroupingV1(
    groupSize: 4,
    separator: '-',
  );

  static const PatternGroupingV1 fiveNote = PatternGroupingV1(
    groupSize: 5,
    separator: '-',
  );

  String separatorAfter(int index, int tokenCount) {
    if (index >= tokenCount - 1) return '';
    final int? size = groupSize;
    if (size == null) return separator;
    return (index + 1) % size == 0 ? separator : '';
  }

  @override
  bool operator ==(Object other) {
    return other is PatternGroupingV1 &&
        other.groupSize == groupSize &&
        other.separator == separator;
  }

  @override
  int get hashCode => Object.hash(groupSize, separator);
}

@immutable
class PatternTokenV1 {
  final PatternTokenKindV1 kind;

  const PatternTokenV1(this.kind);

  static const PatternTokenV1 right = PatternTokenV1(PatternTokenKindV1.right);
  static const PatternTokenV1 left = PatternTokenV1(PatternTokenKindV1.left);
  static const PatternTokenV1 kick = PatternTokenV1(PatternTokenKindV1.kick);
  static const PatternTokenV1 flam = PatternTokenV1(PatternTokenKindV1.flam);
  static const PatternTokenV1 accent = PatternTokenV1(
    PatternTokenKindV1.accent,
  );
  static const PatternTokenV1 rest = PatternTokenV1(PatternTokenKindV1.rest);

  factory PatternTokenV1.fromSymbol(String symbol) {
    return switch (symbol.toUpperCase()) {
      'R' => right,
      'L' => left,
      'K' => kick,
      'F' => flam,
      'X' => accent,
      '_' => rest,
      _ => throw ArgumentError.value(
        symbol,
        'symbol',
        'Unsupported pattern token symbol.',
      ),
    };
  }

  String get symbol => switch (kind) {
    PatternTokenKindV1.right => 'R',
    PatternTokenKindV1.left => 'L',
    PatternTokenKindV1.kick => 'K',
    PatternTokenKindV1.flam => 'F',
    PatternTokenKindV1.accent => 'X',
    PatternTokenKindV1.rest => '_',
  };

  String get notationSymbol => switch (kind) {
    PatternTokenKindV1.right => 'R',
    PatternTokenKindV1.left => 'L',
    PatternTokenKindV1.kick => 'K',
    PatternTokenKindV1.flam => 'F',
    PatternTokenKindV1.accent => 'X',
    PatternTokenKindV1.rest => '_',
  };

  bool get isRest => kind == PatternTokenKindV1.rest;
  bool get isKick => kind == PatternTokenKindV1.kick;
  bool get isHand =>
      kind == PatternTokenKindV1.right || kind == PatternTokenKindV1.left;
  bool get allowsAuthoredVoice => isHand;

  @override
  bool operator ==(Object other) {
    return other is PatternTokenV1 && other.kind == kind;
  }

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => symbol;
}

@immutable
class PatternSequenceV1 {
  final List<PatternTokenV1> tokens;

  PatternSequenceV1({required List<PatternTokenV1> tokens})
    : tokens = List<PatternTokenV1>.unmodifiable(tokens);

  factory PatternSequenceV1.fromSymbols(List<String> symbols) {
    return PatternSequenceV1(
      tokens: symbols.map(PatternTokenV1.fromSymbol).toList(growable: false),
    );
  }

  factory PatternSequenceV1.parse(String text) {
    final List<PatternTokenV1> parsed = <PatternTokenV1>[];
    final String upper = text.toUpperCase();
    for (int index = 0; index < upper.length; index += 1) {
      final String char = upper[index];
      if (char == '^') continue;
      if (char == '(') continue;
      if (char == ')') continue;
      if (char == '[') {
        final int close = upper.indexOf(']', index + 1);
        if (close < 0) {
          throw const FormatException('Unclosed bracket group.');
        }
        final String body = upper.substring(index + 1, close).trim();
        if (body.isEmpty) {
          throw const FormatException('Empty bracket group.');
        }
        final int separator = body.indexOf(':');
        final String playable = separator < 0
            ? body
            : body.substring(separator + 1).trim();
        if (playable.contains('B')) {
          throw const FormatException(
            'Invalid token: B is no longer supported. Use [RL] for both hands/unison or assign explicit voices.',
          );
        }
        final PatternTokenV1? token = _firstPlayableToken(playable);
        if (token != null) parsed.add(token);
        index = close;
        continue;
      }
      switch (char) {
        case 'R':
        case 'L':
        case 'K':
        case 'F':
        case 'X':
        case '_':
          parsed.add(PatternTokenV1.fromSymbol(char));
          break;
        case ' ':
        case '-':
          break;
        case 'B':
          throw const FormatException(
            'Invalid token: B is no longer supported. Use [RL] for both hands/unison or assign explicit voices.',
          );
        default:
          throw FormatException('Unsupported pattern token: $char');
      }
    }
    return PatternSequenceV1(tokens: parsed);
  }

  static PatternTokenV1? _firstPlayableToken(String text) {
    for (int index = 0; index < text.length; index += 1) {
      final String char = text[index];
      switch (char) {
        case 'R':
        case 'L':
        case 'K':
        case 'F':
        case 'X':
        case '_':
          return PatternTokenV1.fromSymbol(char);
      }
    }
    return null;
  }

  String get canonicalText =>
      tokens.map((PatternTokenV1 token) => token.symbol).join();

  int get positionCount => tokens.length;

  List<String> get symbols => tokens
      .map((PatternTokenV1 token) => token.symbol)
      .toList(growable: false);

  String toDisplayText(PatternGroupingV1 groupingHint) {
    if (tokens.isEmpty) return '';
    final StringBuffer buffer = StringBuffer();
    for (int index = 0; index < tokens.length; index++) {
      buffer.write(tokens[index].notationSymbol);
      buffer.write(groupingHint.separatorAfter(index, tokens.length));
    }
    return buffer.toString();
  }
}

@immutable
class PatternTimingSpanV1 {
  final int startIndex;
  final int tokenCount;
  final double beatCount;

  const PatternTimingSpanV1({
    required this.startIndex,
    required this.tokenCount,
    required this.beatCount,
  }) : assert(startIndex >= 0),
       assert(tokenCount > 0),
       assert(beatCount > 0);

  PatternTimingSpanV1 copyWith({
    int? startIndex,
    int? tokenCount,
    double? beatCount,
  }) {
    return PatternTimingSpanV1(
      startIndex: startIndex ?? this.startIndex,
      tokenCount: tokenCount ?? this.tokenCount,
      beatCount: beatCount ?? this.beatCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PatternTimingSpanV1 &&
        other.startIndex == startIndex &&
        other.tokenCount == tokenCount &&
        other.beatCount == beatCount;
  }

  @override
  int get hashCode => Object.hash(startIndex, tokenCount, beatCount);
}

@immutable
class PatternPulseMetadataV1 {
  final bool pulseStart;
  final PatternPulseRoleV1 role;

  const PatternPulseMetadataV1({
    this.pulseStart = false,
    this.role = PatternPulseRoleV1.normal,
  });

  PatternPulseMetadataV1 copyWith({
    bool? pulseStart,
    PatternPulseRoleV1? role,
  }) {
    return PatternPulseMetadataV1(
      pulseStart: pulseStart ?? this.pulseStart,
      role: role ?? this.role,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PatternPulseMetadataV1 &&
        other.pulseStart == pulseStart &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(pulseStart, role);
}

@immutable
class PatternTimingV1 {
  final PatternTimingModeV1 mode;
  final List<PatternTimingSpanV1> spans;
  final List<PatternPulseMetadataV1> pulses;

  PatternTimingV1({
    this.mode = PatternTimingModeV1.autoByGrouping,
    List<PatternTimingSpanV1>? spans,
    List<PatternPulseMetadataV1>? pulses,
  }) : spans = List<PatternTimingSpanV1>.unmodifiable(spans ?? const []),
       pulses = List<PatternPulseMetadataV1>.unmodifiable(pulses ?? const []);

  const PatternTimingV1.auto()
    : mode = PatternTimingModeV1.autoByGrouping,
      spans = const <PatternTimingSpanV1>[],
      pulses = const <PatternPulseMetadataV1>[];

  const PatternTimingV1.explicit({
    required this.spans,
    this.pulses = const <PatternPulseMetadataV1>[],
  }) : mode = PatternTimingModeV1.explicitSpans;

  PatternTimingV1 copyWith({
    PatternTimingModeV1? mode,
    List<PatternTimingSpanV1>? spans,
    List<PatternPulseMetadataV1>? pulses,
  }) {
    return PatternTimingV1(
      mode: mode ?? this.mode,
      spans: spans ?? this.spans,
      pulses: pulses ?? this.pulses,
    );
  }

  bool get usesExplicitSpans => mode == PatternTimingModeV1.explicitSpans;
  bool get hasPulseMetadata => pulses.isNotEmpty;

  @override
  bool operator ==(Object other) {
    return other is PatternTimingV1 &&
        other.mode == mode &&
        listEquals(other.spans, spans) &&
        listEquals(other.pulses, pulses);
  }

  @override
  int get hashCode =>
      Object.hash(mode, Object.hashAll(spans), Object.hashAll(pulses));
}

@immutable
class PatternItem {
  final String id;
  final String title;
  final String pattern;
  final List<String> tags;
  final String? notes;
  final PatternMetadata? metadata;

  PatternItem({
    required this.id,
    required this.title,
    required this.pattern,
    List<String> tags = const <String>[],
    this.notes,
    this.metadata,
  }) : tags = List<String>.unmodifiable(tags);
}

@immutable
class PatternMetadata {
  final PatternRoleV1 role;
  final PatternFeelV1 feel;
  final DrumSubdivision? subdivisionHint;
  final String? timeSignatureHint;
  final PatternLengthHintV1 lengthHint;
  final PatternIntensityV1 intensity;

  const PatternMetadata({
    this.role = PatternRoleV1.unknown,
    this.feel = PatternFeelV1.unknown,
    this.subdivisionHint,
    this.timeSignatureHint,
    this.lengthHint = PatternLengthHintV1.unknown,
    this.intensity = PatternIntensityV1.unknown,
  });
}

@immutable
class TempoPlan {
  final int start;
  final int? step;
  final int? max;

  const TempoPlan({required this.start, this.step, this.max});

  List<String> validate() {
    final List<String> errors = <String>[];
    if (start <= 0) errors.add('Tempo start must be greater than zero.');
    final int? resolvedStep = step;
    if (resolvedStep != null && resolvedStep <= 0) {
      errors.add('Tempo step must be greater than zero.');
    }
    final int? resolvedMax = max;
    if (resolvedMax != null && resolvedMax < start) {
      errors.add('Tempo max must be greater than or equal to start.');
    }
    return errors;
  }
}

@immutable
class BeatAlignment {
  final bool enabled;
  final String? anchoredPattern;

  const BeatAlignment({required this.enabled, this.anchoredPattern});

  List<String> validate() {
    final String? text = anchoredPattern;
    if (!enabled || text == null || text.trim().isEmpty) {
      return const <String>[];
    }
    final Iterable<RegExpMatch> matches = RegExp(
      r'\|([^|]+)\|',
    ).allMatches(text);
    for (final RegExpMatch match in matches) {
      final String value = match.group(1) ?? '';
      final int? beat = int.tryParse(value);
      if (beat == null || beat <= 0) {
        return <String>['Beat anchors must look like |1|, |2|, |3|, or |4|.'];
      }
    }
    if (text.contains('|') && matches.isEmpty) {
      return <String>['Beat anchors must look like |1|, |2|, |3|, or |4|.'];
    }
    return const <String>[];
  }
}

@immutable
class PracticeCycleStep {
  final String? label;
  final DrumSubdivision subdivision;
  final String pattern;

  const PracticeCycleStep({
    this.label,
    required this.subdivision,
    required this.pattern,
  });
}

@immutable
class PracticeCycle {
  final List<PracticeCycleStep> steps;

  PracticeCycle({required List<PracticeCycleStep> steps})
    : steps = List<PracticeCycleStep>.unmodifiable(steps);
}

@immutable
class LoopSettings {
  final bool enabled;
  final int? count;

  const LoopSettings({required this.enabled, this.count});

  List<String> validate() {
    final int? resolvedCount = count;
    if (resolvedCount != null && resolvedCount <= 0) {
      return <String>['Loop count must be greater than zero.'];
    }
    return const <String>[];
  }
}

@immutable
class PracticeContext {
  final String id;
  final String? patternId;
  final List<String> selectedPatternIds;
  final DrumSubdivision? subdivision;
  final TempoPlan? tempo;
  final BeatAlignment? beatAlignment;
  final PracticeCycle? cycle;
  final LoopSettings? loop;
  final GrooveContext? grooveContext;
  final PracticeFlow? flow;

  const PracticeContext({
    required this.id,
    this.patternId,
    this.selectedPatternIds = const <String>[],
    this.subdivision,
    this.tempo,
    this.beatAlignment,
    this.cycle,
    this.loop,
    this.grooveContext,
    this.flow,
  });

  List<String> validate({
    required List<String> Function(String pattern) validatePattern,
  }) {
    final List<String> errors = <String>[];
    errors.addAll(tempo?.validate() ?? const <String>[]);
    errors.addAll(beatAlignment?.validate() ?? const <String>[]);
    errors.addAll(loop?.validate() ?? const <String>[]);
    final PracticeCycle? resolvedCycle = cycle;
    if (resolvedCycle != null) {
      if (resolvedCycle.steps.isEmpty) {
        errors.add('Cycle must contain at least one step.');
      }
      for (final PracticeCycleStep step in resolvedCycle.steps) {
        for (final String error in validatePattern(step.pattern)) {
          errors.add(
            'Cycle step ${step.label ?? step.subdivision.name}: $error',
          );
        }
      }
    }
    final PracticeFlow? resolvedFlow = flow;
    if (resolvedFlow != null) {
      errors.addAll(resolvedFlow.validate());
    }
    return errors;
  }
}

@immutable
class GrooveContext {
  final String? groovePatternId;
  final List<String> applyAgainstPatternIds;
  final String? notes;

  GrooveContext({
    this.groovePatternId,
    List<String> applyAgainstPatternIds = const <String>[],
    this.notes,
  }) : applyAgainstPatternIds = List<String>.unmodifiable(
         applyAgainstPatternIds,
       );
}

@immutable
class PracticeFlow {
  final List<PracticeFlowStep> steps;
  final bool loopEnabled;

  PracticeFlow({
    required List<PracticeFlowStep> steps,
    this.loopEnabled = false,
  }) : steps = List<PracticeFlowStep>.unmodifiable(steps);

  List<String> validate() {
    final List<String> errors = <String>[];
    for (int index = 0; index < steps.length; index += 1) {
      final PracticeFlowStep step = steps[index];
      if (step.patternId.trim().isEmpty) {
        errors.add('Flow step ${index + 1} must reference a pattern.');
      }
      if (step.repeatCount <= 0) {
        errors.add(
          'Flow step ${index + 1} repeat count must be greater than zero.',
        );
      }
    }
    return errors;
  }
}

@immutable
class PracticeFlowStep {
  final String patternId;
  final PatternRoleV1 role;
  final int repeatCount;
  final DrumSubdivision? subdivisionOverride;
  final String? notes;

  const PracticeFlowStep({
    required this.patternId,
    this.role = PatternRoleV1.unknown,
    this.repeatCount = 1,
    this.subdivisionOverride,
    this.notes,
  });
}

@immutable
class PracticeSelfAssessment {
  final bool clean;
  final int difficulty;
  final String? notes;

  const PracticeSelfAssessment({
    required this.clean,
    required this.difficulty,
    this.notes,
  }) : assert(difficulty >= 1 && difficulty <= 5);
}

@immutable
class PracticeSession {
  final String id;
  final String patternId;
  final String? practiceContextId;
  final DateTime dateStarted;
  final int durationSeconds;
  final int? tempoUsed;
  final DrumSubdivision? subdivisionUsed;
  final PracticeSelfAssessment? selfAssessment;

  const PracticeSession({
    required this.id,
    required this.patternId,
    this.practiceContextId,
    required this.dateStarted,
    required this.durationSeconds,
    this.tempoUsed,
    this.subdivisionUsed,
    this.selfAssessment,
  });
}

@immutable
class ProgressSummary {
  final String patternId;
  final int? highestCleanTempo;
  final int totalSessions;
  final int totalPracticeSeconds;
  final List<String> weakAreas;
  final bool owned;

  ProgressSummary({
    required this.patternId,
    this.highestCleanTempo,
    required this.totalSessions,
    required this.totalPracticeSeconds,
    List<String> weakAreas = const <String>[],
    required this.owned,
  }) : weakAreas = List<String>.unmodifiable(weakAreas);
}

@immutable
class PracticeLaunchPreferenceV1 {
  final String practiceItemId;
  final int bpm;
  final TimerPresetV1 timerPreset;

  const PracticeLaunchPreferenceV1({
    required this.practiceItemId,
    required this.bpm,
    required this.timerPreset,
  });

  PracticeLaunchPreferenceV1 copyWith({
    String? practiceItemId,
    int? bpm,
    TimerPresetV1? timerPreset,
  }) {
    return PracticeLaunchPreferenceV1(
      practiceItemId: practiceItemId ?? this.practiceItemId,
      bpm: bpm ?? this.bpm,
      timerPreset: timerPreset ?? this.timerPreset,
    );
  }
}

@immutable
class PracticeItemV1 {
  final String id;

  /// Metadata only.
  ///
  /// Family is preserved for pedagogy, filtering, and legacy compatibility.
  /// It must not define canonical pattern structure.
  final MaterialFamilyV1 family;
  final String name;
  final String pattern;
  final PatternSequenceV1 sequence;

  /// Metadata only.
  ///
  /// Grouping is display/readability scaffolding rather than canonical pattern
  /// structure. `PatternGroupingV1.none` means no explicit grouping hint is
  /// stored on the item.
  final PatternGroupingV1 groupingHint;

  /// Playback timing metadata.
  ///
  /// Grouping stays a display/pedagogy hint. Timing is the playback contract.
  /// The default auto mode is legacy-safe for existing drills. Explicit spans
  /// allow advanced fills or phrases to diverge from visible grouping later.
  final PatternTimingV1 timing;

  /// Zero-based note indices the user has explicitly marked as accents.
  final List<int> accentedNoteIndices;

  /// Zero-based note indices the user has explicitly marked as ghosts.
  final List<int> ghostNoteIndices;

  /// User-authored voice assignment overrides.
  ///
  /// Empty means default single-surface voices:
  /// snare for hand notes and kick for K notes.
  /// Flow is derived from authored off-snare movement on non-kick notes.
  final List<DrumVoiceV1> voiceAssignments;

  /// Sheet-notation grouping text, such as `4`, `3535`, or `3 5 3 5`.
  ///
  /// This preserves the editable sheet-music grouping exactly. Legacy
  /// `groupingHint` remains available for older display surfaces and simple
  /// equal-size group metadata.
  final String beatGrouping;

  /// Default rendered sheet-note value.
  final PatternNoteValueV1 notationSubdivision;

  /// Per-position sheet-note value overrides.
  ///
  /// `null` means use [notationSubdivision]. The list is position-aligned with
  /// [sequence] and may be empty for legacy/default items.
  final List<PatternNoteValueV1?> noteValueOverrides;

  final PracticeItemSourceV1 source;
  final List<String> tags;
  final bool saved;

  PracticeItemV1({
    required this.id,
    required this.family,
    required this.name,
    String? pattern,
    PatternSequenceV1? sequence,
    String? sticking,
    int? noteCount,
    PatternGroupingV1? groupingHint,
    PatternTimingV1? timing,
    required this.accentedNoteIndices,
    required this.ghostNoteIndices,
    required this.voiceAssignments,
    this.beatGrouping = '',
    this.notationSubdivision = PatternNoteValueV1.eighth,
    List<PatternNoteValueV1?>? noteValueOverrides,
    required this.source,
    required this.tags,
    required this.saved,
  }) : assert(sequence != null || sticking != null || pattern != null),
       pattern =
           pattern ??
           sticking ??
           (sequence ?? PatternSequenceV1.parse(sticking ?? '')).canonicalText,
       sequence =
           sequence ?? PatternSequenceV1.parse(pattern ?? sticking ?? ''),
       groupingHint = groupingHint ?? PatternGroupingV1.none,
       timing = timing ?? const PatternTimingV1.auto(),
       noteValueOverrides = List<PatternNoteValueV1?>.unmodifiable(
         noteValueOverrides ?? const <PatternNoteValueV1?>[],
       ),
       assert(
         noteCount == null ||
             (sequence ?? PatternSequenceV1.parse(pattern ?? sticking ?? ''))
                     .positionCount ==
                 noteCount,
         'noteCount must match the canonical token sequence length.',
       );

  /// Temporary compatibility getter while the app migrates away from
  /// `sticking` as a structural field.
  String get sticking => pattern;

  /// Temporary compatibility getter while the app migrates away from
  /// `noteCount` as a stored field.
  int get noteCount => sequence.positionCount;

  List<PatternTokenV1> get tokens => sequence.tokens;

  bool get isTriad => family == MaterialFamilyV1.triad;
  bool get isFourNote => family == MaterialFamilyV1.fourNote;
  bool get isFiveNote => family == MaterialFamilyV1.fiveNote;
  bool get isCustom => family == MaterialFamilyV1.custom;
  bool get isCombo => family == MaterialFamilyV1.combo;
  bool get isWarmup => family == MaterialFamilyV1.warmup;
  bool get hasAccents => accentedNoteIndices.isNotEmpty;
  bool get hasGhostNotes => ghostNoteIndices.isNotEmpty;

  PracticeItemV1 copyWith({
    String? id,
    MaterialFamilyV1? family,
    String? name,
    String? pattern,
    PatternSequenceV1? sequence,
    String? sticking,
    int? noteCount,
    PatternGroupingV1? groupingHint,
    PatternTimingV1? timing,
    List<int>? accentedNoteIndices,
    List<int>? ghostNoteIndices,
    List<DrumVoiceV1>? voiceAssignments,
    String? beatGrouping,
    PatternNoteValueV1? notationSubdivision,
    List<PatternNoteValueV1?>? noteValueOverrides,
    PracticeItemSourceV1? source,
    List<String>? tags,
    bool? saved,
  }) {
    final MaterialFamilyV1 nextFamily = family ?? this.family;
    final String? nextPattern = pattern ?? sticking;
    final PatternSequenceV1 nextSequence =
        sequence ??
        (nextPattern != null
            ? PatternSequenceV1.parse(nextPattern)
            : this.sequence);
    assert(
      noteCount == null || nextSequence.positionCount == noteCount,
      'noteCount must match the canonical token sequence length.',
    );
    return PracticeItemV1(
      id: id ?? this.id,
      family: nextFamily,
      name: name ?? this.name,
      pattern: nextPattern ?? this.pattern,
      sequence: nextSequence,
      groupingHint: groupingHint ?? this.groupingHint,
      timing: timing ?? this.timing,
      accentedNoteIndices: accentedNoteIndices ?? this.accentedNoteIndices,
      ghostNoteIndices: ghostNoteIndices ?? this.ghostNoteIndices,
      voiceAssignments: voiceAssignments ?? this.voiceAssignments,
      beatGrouping: beatGrouping ?? this.beatGrouping,
      notationSubdivision: notationSubdivision ?? this.notationSubdivision,
      noteValueOverrides: noteValueOverrides ?? this.noteValueOverrides,
      source: source ?? this.source,
      tags: tags ?? this.tags,
      saved: saved ?? this.saved,
    );
  }
}

@immutable
class CoachBlockV1 {
  final String id;
  final CoachBlockTypeV1 type;
  final String title;
  final String? subtitle;
  final String? body;
  final List<String> itemIds;
  final String ctaLabel;
  final CoachActionV1 ctaAction;
  final Set<TriadMatrixFilterV1> matrixFilters;
  final PracticeModeV1 practiceMode;

  const CoachBlockV1({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.itemIds,
    required this.ctaLabel,
    required this.ctaAction,
    required this.matrixFilters,
    required this.practiceMode,
  });
}

@immutable
class CoachBriefingV1 {
  final List<CoachBlockV1> blocks;

  const CoachBriefingV1({required this.blocks});

  CoachBlockV1? firstBlockOfType(CoachBlockTypeV1 type) {
    for (final CoachBlockV1 block in blocks) {
      if (block.type == type) return block;
    }
    return null;
  }
}

@immutable
class MatrixFiltersV1 {
  final LearningLaneV1? lane;
  final Set<TriadMatrixFilterV1> filters;
  final Set<String> selectedRows;
  final Set<String> selectedColumns;

  const MatrixFiltersV1({
    required this.lane,
    required this.filters,
    required this.selectedRows,
    required this.selectedColumns,
  });
}

@immutable
class MatrixSelectionStateV1 {
  final List<String> orderedItemIds;

  const MatrixSelectionStateV1({required this.orderedItemIds});

  bool contains(String itemId) => orderedItemIds.contains(itemId);

  int countOf(String itemId) {
    return orderedItemIds.where((String id) => id == itemId).length;
  }
}

@immutable
class MatrixCellVisualStateV1 {
  final String itemId;
  final bool inScope;
  final bool muted;
  final MatrixProgressStateV1 progress;
  final bool selected;
  final int selectedCount;

  const MatrixCellVisualStateV1({
    required this.itemId,
    required this.inScope,
    required this.muted,
    required this.progress,
    required this.selected,
    required this.selectedCount,
  });
}

@immutable
class PracticeCombinationV1 {
  final String id;
  final String name;
  final List<String> itemIds;

  const PracticeCombinationV1({
    required this.id,
    required this.name,
    required this.itemIds,
  });

  PracticeCombinationV1 copyWith({
    String? id,
    String? name,
    List<String>? itemIds,
  }) {
    return PracticeCombinationV1(
      id: id ?? this.id,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
    );
  }
}

@immutable
class RoutineEntryV1 {
  final String practiceItemId;
  final DateTime addedAt;

  const RoutineEntryV1({required this.practiceItemId, required this.addedAt});

  RoutineEntryV1 copyWith({String? practiceItemId, DateTime? addedAt}) {
    return RoutineEntryV1(
      practiceItemId: practiceItemId ?? this.practiceItemId,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

@immutable
class PracticeRoutineV1 {
  final String id;
  final String name;
  final List<RoutineEntryV1> entries;

  const PracticeRoutineV1({
    required this.id,
    required this.name,
    required this.entries,
  });

  PracticeRoutineV1 copyWith({
    String? id,
    String? name,
    List<RoutineEntryV1>? entries,
  }) {
    return PracticeRoutineV1(
      id: id ?? this.id,
      name: name ?? this.name,
      entries: entries ?? this.entries,
    );
  }
}

@immutable
class PracticeSessionItemRuntimeV1 {
  final String practiceItemId;
  final int startingBpm;
  final int endingBpm;
  final Duration activeDuration;
  final int earnedReps;
  final int claimedReps;

  const PracticeSessionItemRuntimeV1({
    required this.practiceItemId,
    required this.startingBpm,
    required this.endingBpm,
    this.activeDuration = Duration.zero,
    this.earnedReps = 0,
    this.claimedReps = 0,
  });

  PracticeSessionItemRuntimeV1 copyWith({
    String? practiceItemId,
    int? startingBpm,
    int? endingBpm,
    Duration? activeDuration,
    int? earnedReps,
    int? claimedReps,
  }) {
    return PracticeSessionItemRuntimeV1(
      practiceItemId: practiceItemId ?? this.practiceItemId,
      startingBpm: startingBpm ?? this.startingBpm,
      endingBpm: endingBpm ?? this.endingBpm,
      activeDuration: activeDuration ?? this.activeDuration,
      earnedReps: earnedReps ?? this.earnedReps,
      claimedReps: claimedReps ?? this.claimedReps,
    );
  }
}

@immutable
class PracticeSessionSetupV1 {
  final List<String> practiceItemIds;

  /// Metadata only.
  final MaterialFamilyV1 family;

  /// Metadata only.
  final PracticeModeV1 practiceMode;
  final PracticeSessionEndBehaviorV1 endBehavior;
  final int bpm;
  final Map<String, int> itemBpmById;
  final TimerPresetV1 timerPreset;
  final bool clickEnabled;
  final String? routineId;
  final String sourceName;
  final List<String> ephemeralItemIds;

  PracticeSessionSetupV1({
    required this.practiceItemIds,
    required this.family,
    required this.practiceMode,
    this.endBehavior = PracticeSessionEndBehaviorV1.openSummary,
    required this.bpm,
    Map<String, int>? itemBpmById,
    required this.timerPreset,
    required this.clickEnabled,
    required this.routineId,
    this.sourceName = '',
    List<String>? ephemeralItemIds,
  }) : itemBpmById = Map<String, int>.unmodifiable(
         itemBpmById ??
             <String, int>{
               for (final String itemId in practiceItemIds) itemId: bpm,
             },
       ),
       ephemeralItemIds = List<String>.unmodifiable(
         ephemeralItemIds ?? const <String>[],
       );

  PracticeSessionSetupV1 copyWith({
    List<String>? practiceItemIds,
    MaterialFamilyV1? family,
    PracticeModeV1? practiceMode,
    PracticeSessionEndBehaviorV1? endBehavior,
    int? bpm,
    Map<String, int>? itemBpmById,
    TimerPresetV1? timerPreset,
    bool? clickEnabled,
    String? routineId,
    String? sourceName,
    List<String>? ephemeralItemIds,
    bool clearRoutineId = false,
  }) {
    final List<String> nextPracticeItemIds =
        practiceItemIds ?? this.practiceItemIds;
    final int nextBpm = bpm ?? this.bpm;
    return PracticeSessionSetupV1(
      practiceItemIds: nextPracticeItemIds,
      family: family ?? this.family,
      practiceMode: practiceMode ?? this.practiceMode,
      endBehavior: endBehavior ?? this.endBehavior,
      bpm: nextBpm,
      itemBpmById:
          itemBpmById ??
          this.itemBpmById.map(
            (String key, int value) => MapEntry<String, int>(key, value),
          ),
      timerPreset: timerPreset ?? this.timerPreset,
      clickEnabled: clickEnabled ?? this.clickEnabled,
      routineId: clearRoutineId ? null : (routineId ?? this.routineId),
      sourceName: sourceName ?? this.sourceName,
      ephemeralItemIds: ephemeralItemIds ?? this.ephemeralItemIds,
    );
  }
}

@immutable
class PracticeSessionLogV1 {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final Duration duration;
  final List<String> practiceItemIds;
  final String? assessmentItemId;

  /// Metadata only.
  final MaterialFamilyV1 family;

  /// Metadata only.
  final PracticeModeV1 practiceMode;
  final int startingBpm;
  final int bpm;
  final List<PracticeSessionItemRuntimeV1> itemRuntimes;
  final int earnedReps;
  final int claimedReps;
  final bool clickEnabled;
  final String? routineId;
  final ReflectionRatingV1? reflection;
  final String sourceName;

  PracticeSessionLogV1({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.practiceItemIds,
    required this.assessmentItemId,
    required this.family,
    required this.practiceMode,
    int? startingBpm,
    required this.bpm,
    List<PracticeSessionItemRuntimeV1>? itemRuntimes,
    int? earnedReps,
    int? claimedReps,
    required this.clickEnabled,
    required this.routineId,
    required this.reflection,
    this.sourceName = '',
  }) : startingBpm = startingBpm ?? bpm,
       itemRuntimes = List<PracticeSessionItemRuntimeV1>.unmodifiable(
         itemRuntimes ??
             practiceItemIds
                 .map(
                   (String itemId) => PracticeSessionItemRuntimeV1(
                     practiceItemId: itemId,
                     startingBpm: startingBpm ?? bpm,
                     endingBpm: bpm,
                   ),
                 )
                 .toList(growable: false),
       ),
       earnedReps =
           earnedReps ??
           (itemRuntimes ??
                   practiceItemIds
                       .map(
                         (String itemId) => PracticeSessionItemRuntimeV1(
                           practiceItemId: itemId,
                           startingBpm: startingBpm ?? bpm,
                           endingBpm: bpm,
                         ),
                       )
                       .toList(growable: false))
               .fold<int>(
                 0,
                 (int sum, PracticeSessionItemRuntimeV1 runtime) =>
                     sum + runtime.earnedReps,
               ),
       claimedReps =
           claimedReps ??
           (itemRuntimes ??
                   practiceItemIds
                       .map(
                         (String itemId) => PracticeSessionItemRuntimeV1(
                           practiceItemId: itemId,
                           startingBpm: startingBpm ?? bpm,
                           endingBpm: bpm,
                         ),
                       )
                       .toList(growable: false))
               .fold<int>(
                 0,
                 (int sum, PracticeSessionItemRuntimeV1 runtime) =>
                     sum + runtime.claimedReps,
               );

  PracticeSessionLogV1 copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? duration,
    List<String>? practiceItemIds,
    String? assessmentItemId,
    bool clearAssessmentItemId = false,
    MaterialFamilyV1? family,
    PracticeModeV1? practiceMode,
    int? startingBpm,
    int? bpm,
    List<PracticeSessionItemRuntimeV1>? itemRuntimes,
    int? earnedReps,
    int? claimedReps,
    bool? clickEnabled,
    String? routineId,
    bool clearRoutineId = false,
    ReflectionRatingV1? reflection,
    bool clearReflection = false,
    String? sourceName,
  }) {
    return PracticeSessionLogV1(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      practiceItemIds: practiceItemIds ?? this.practiceItemIds,
      assessmentItemId: clearAssessmentItemId
          ? null
          : (assessmentItemId ?? this.assessmentItemId),
      family: family ?? this.family,
      practiceMode: practiceMode ?? this.practiceMode,
      startingBpm: startingBpm ?? this.startingBpm,
      bpm: bpm ?? this.bpm,
      itemRuntimes: itemRuntimes ?? this.itemRuntimes,
      earnedReps: earnedReps ?? this.earnedReps,
      claimedReps: claimedReps ?? this.claimedReps,
      clickEnabled: clickEnabled ?? this.clickEnabled,
      routineId: clearRoutineId ? null : (routineId ?? this.routineId),
      reflection: clearReflection ? null : (reflection ?? this.reflection),
      sourceName: sourceName ?? this.sourceName,
    );
  }
}

@immutable
class SessionAssessmentResultV1 {
  final String sessionId;
  final String practiceItemId;
  final PracticeModeV1 practiceMode;
  final AssessmentInputTypeV1 inputType;
  final AssessmentConfidenceV1 confidence;
  final int attemptedBpm;
  final double? estimatedBpm;
  final double stabilityScore;
  final double driftScore;
  final double jitterScore;
  final double continuityScore;
  final int breakdownCount;
  final int successfulRunCount;
  final bool completedTargetDuration;
  final SelfReportControlV1? selfReportControl;
  final SelfReportTensionV1? selfReportTension;
  final SelfReportTempoReadinessV1? selfReportTempoReadiness;
  final DateTime assessedAt;

  const SessionAssessmentResultV1({
    required this.sessionId,
    required this.practiceItemId,
    required this.practiceMode,
    required this.inputType,
    required this.confidence,
    required this.attemptedBpm,
    required this.estimatedBpm,
    required this.stabilityScore,
    required this.driftScore,
    required this.jitterScore,
    required this.continuityScore,
    required this.breakdownCount,
    required this.successfulRunCount,
    required this.completedTargetDuration,
    required this.selfReportControl,
    required this.selfReportTension,
    required this.selfReportTempoReadiness,
    required this.assessedAt,
  });
}

@immutable
class PracticeAssessmentAggregateV1 {
  final String practiceItemId;
  final DateTime? lastAssessmentAt;
  final int? recentAttemptedBpm;
  final double? recentStableBpm;
  final double? bestStableBpm;
  final double stabilityScore;
  final double driftScore;
  final double jitterScore;
  final double continuityScore;
  final AssessmentConfidenceV1 confidence;
  final MatrixProgressStateV1 status;
  final int assessmentCount;

  const PracticeAssessmentAggregateV1({
    required this.practiceItemId,
    required this.lastAssessmentAt,
    required this.recentAttemptedBpm,
    required this.recentStableBpm,
    required this.bestStableBpm,
    required this.stabilityScore,
    required this.driftScore,
    required this.jitterScore,
    required this.continuityScore,
    required this.confidence,
    required this.status,
    required this.assessmentCount,
  });
}

@immutable
class CompetencyRecordV1 {
  final String practiceItemId;
  final CompetencyLevelV1 level;
  final DateTime updatedAt;

  const CompetencyRecordV1({
    required this.practiceItemId,
    required this.level,
    required this.updatedAt,
  });

  CompetencyRecordV1 copyWith({
    String? practiceItemId,
    CompetencyLevelV1? level,
    DateTime? updatedAt,
  }) {
    return CompetencyRecordV1(
      practiceItemId: practiceItemId ?? this.practiceItemId,
      level: level ?? this.level,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

@immutable
class PracticeTimeAggregateKeyV1 {
  final String? practiceItemId;
  final MaterialFamilyV1? family;

  const PracticeTimeAggregateKeyV1({
    required this.practiceItemId,
    required this.family,
  });

  @override
  bool operator ==(Object other) {
    return other is PracticeTimeAggregateKeyV1 &&
        other.practiceItemId == practiceItemId &&
        other.family == family;
  }

  @override
  int get hashCode => Object.hash(practiceItemId, family);
}
