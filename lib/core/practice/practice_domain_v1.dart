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

enum PracticeSessionEndBehaviorV1 { openSummary, returnToPrevious }

enum PatternTokenKindV1 { right, left, kick, rest }

enum DrumVoiceV1 { snare, rackTom, tom2, floorTom, hihat, kick }

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

  const UserProfileV1({
    required this.handedness,
    required this.defaultBpm,
    required this.defaultTimerPreset,
    required this.clickEnabledByDefault,
  });

  UserProfileV1 copyWith({
    HandednessV1? handedness,
    int? defaultBpm,
    TimerPresetV1? defaultTimerPreset,
    bool? clickEnabledByDefault,
  }) {
    return UserProfileV1(
      handedness: handedness ?? this.handedness,
      defaultBpm: defaultBpm ?? this.defaultBpm,
      defaultTimerPreset: defaultTimerPreset ?? this.defaultTimerPreset,
      clickEnabledByDefault:
          clickEnabledByDefault ?? this.clickEnabledByDefault,
    );
  }

  static const UserProfileV1 initial = UserProfileV1(
    handedness: HandednessV1.right,
    defaultBpm: 92,
    defaultTimerPreset: TimerPresetV1.minutes10,
    clickEnabledByDefault: true,
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
  static const PatternTokenV1 rest = PatternTokenV1(PatternTokenKindV1.rest);

  factory PatternTokenV1.fromSymbol(String symbol) {
    return switch (symbol.toUpperCase()) {
      'R' => right,
      'L' => left,
      'K' => kick,
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
    PatternTokenKindV1.rest => '_',
  };

  String get notationSymbol => switch (kind) {
    PatternTokenKindV1.right => 'R',
    PatternTokenKindV1.left => 'L',
    PatternTokenKindV1.kick => 'K',
    PatternTokenKindV1.rest => '•',
  };

  bool get isRest => kind == PatternTokenKindV1.rest;
  bool get isKick => kind == PatternTokenKindV1.kick;
  bool get isHand =>
      kind == PatternTokenKindV1.right || kind == PatternTokenKindV1.left;

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
    for (final String char in text.toUpperCase().split('')) {
      switch (char) {
        case 'R':
        case 'L':
        case 'K':
        case '_':
          parsed.add(PatternTokenV1.fromSymbol(char));
          break;
        case ' ':
        case '-':
          break;
        default:
          break;
      }
    }
    return PatternSequenceV1(tokens: parsed);
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
  final PatternSequenceV1 sequence;

  /// Metadata only.
  ///
  /// Grouping is display/readability scaffolding rather than canonical pattern
  /// structure. `PatternGroupingV1.none` means no explicit grouping hint is
  /// stored on the item.
  final PatternGroupingV1 groupingHint;

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

  final PracticeItemSourceV1 source;
  final List<String> tags;
  final bool saved;

  PracticeItemV1({
    required this.id,
    required this.family,
    required this.name,
    PatternSequenceV1? sequence,
    String? sticking,
    int? noteCount,
    PatternGroupingV1? groupingHint,
    required this.accentedNoteIndices,
    required this.ghostNoteIndices,
    required this.voiceAssignments,
    required this.source,
    required this.tags,
    required this.saved,
  }) : assert(sequence != null || sticking != null),
       sequence = sequence ?? PatternSequenceV1.parse(sticking ?? ''),
       groupingHint = groupingHint ?? PatternGroupingV1.none,
       assert(
         noteCount == null ||
             (sequence ?? PatternSequenceV1.parse(sticking ?? ''))
                     .positionCount ==
                 noteCount,
         'noteCount must match the canonical token sequence length.',
       );

  /// Temporary compatibility getter while the app migrates away from
  /// `sticking` as a structural field.
  String get sticking => sequence.toDisplayText(groupingHint);

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
    PatternSequenceV1? sequence,
    String? sticking,
    int? noteCount,
    PatternGroupingV1? groupingHint,
    List<int>? accentedNoteIndices,
    List<int>? ghostNoteIndices,
    List<DrumVoiceV1>? voiceAssignments,
    PracticeItemSourceV1? source,
    List<String>? tags,
    bool? saved,
  }) {
    final MaterialFamilyV1 nextFamily = family ?? this.family;
    final PatternSequenceV1 nextSequence =
        sequence ??
        (sticking != null ? PatternSequenceV1.parse(sticking) : this.sequence);
    assert(
      noteCount == null || nextSequence.positionCount == noteCount,
      'noteCount must match the canonical token sequence length.',
    );
    return PracticeItemV1(
      id: id ?? this.id,
      family: nextFamily,
      name: name ?? this.name,
      sequence: nextSequence,
      groupingHint: groupingHint ?? this.groupingHint,
      accentedNoteIndices: accentedNoteIndices ?? this.accentedNoteIndices,
      ghostNoteIndices: ghostNoteIndices ?? this.ghostNoteIndices,
      voiceAssignments: voiceAssignments ?? this.voiceAssignments,
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
