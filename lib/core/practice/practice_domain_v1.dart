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

enum MaterialFamilyV1 { triad, fiveNote, custom, combo, warmup }

enum PracticeItemSourceV1 { builtIn, userDefined, generated }

enum PracticeModeV1 { singleSurface, flow }

enum DrumVoiceV1 { snare, rackTom, tom2, floorTom, hihat, kick }

enum LearningLaneV1 { control, balance, dynamics, integration, phrasing, flow }

enum CompetencyLevelV1 { notStarted, learning, comfortable, reliable, musical }

enum ReflectionRatingV1 { easy, okay, hard }

enum TimerPresetV1 { none, minutes5, minutes10, minutes20, minutes30 }

enum TriadMatrixViewModeV1 { competency, rightLead, leftLead, handsOnly }

enum TriadMatrixFilterPaletteV1 { coaching, technique, combos }

enum TriadMatrixFilterV1 {
  competency,
  inRoutine,
  inPhrases,
  needsAttention,
  underPracticed,
  closeToToolkit,
  recent,
  unseen,
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

enum PatternNoteMarkingV1 { normal, accent, ghost }

enum MatrixProgressStateV1 { notTrained, active, needsWork, strong }

enum CoachBlockTypeV1 { focus, needsWork, momentum, resume, nextUnlock }

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

  String separatorAfter(int index, int tokenCount) {
    if (index >= tokenCount - 1) return '';
    final int? size = groupSize;
    if (size == null) return separator;
    return (index + 1) % size == 0 ? separator : '';
  }
}

@immutable
class PracticeItemV1 {
  final String id;
  final MaterialFamilyV1 family;
  final String name;

  /// Canonical sticking text shown to the user.
  final String sticking;

  /// Number of notes in the base grouping or phrase.
  final int noteCount;

  /// Zero-based note indices that should be accented in the default guided view.
  final List<int> accentedNoteIndices;

  /// Zero-based note indices that should be ghosted in the guided view.
  final List<int> ghostNoteIndices;

  /// Default voice assignment used when the phrase is practiced in flow mode.
  final List<DrumVoiceV1> voiceAssignments;

  final PracticeItemSourceV1 source;
  final List<String> tags;
  final bool saved;

  const PracticeItemV1({
    required this.id,
    required this.family,
    required this.name,
    required this.sticking,
    required this.noteCount,
    required this.accentedNoteIndices,
    required this.ghostNoteIndices,
    required this.voiceAssignments,
    required this.source,
    required this.tags,
    required this.saved,
  });

  bool get isTriad => family == MaterialFamilyV1.triad;
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
    String? sticking,
    int? noteCount,
    List<int>? accentedNoteIndices,
    List<int>? ghostNoteIndices,
    List<DrumVoiceV1>? voiceAssignments,
    PracticeItemSourceV1? source,
    List<String>? tags,
    bool? saved,
  }) {
    return PracticeItemV1(
      id: id ?? this.id,
      family: family ?? this.family,
      name: name ?? this.name,
      sticking: sticking ?? this.sticking,
      noteCount: noteCount ?? this.noteCount,
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
class TodayLaneRecommendationV1 {
  final LearningLaneV1 lane;
  final String title;
  final String reason;
  final String actionLabel;
  final List<String> itemIds;
  final String evidence;

  const TodayLaneRecommendationV1({
    required this.lane,
    required this.title,
    required this.reason,
    required this.actionLabel,
    required this.itemIds,
    required this.evidence,
  });
}

@immutable
class TodayBriefingV1 {
  final LearningLaneV1 primaryLane;
  final String headline;
  final String summary;
  final List<TodayLaneRecommendationV1> laneRecommendations;
  final List<TodayLaneRecommendationV1> momentumRecommendations;

  const TodayBriefingV1({
    required this.primaryLane,
    required this.headline,
    required this.summary,
    required this.laneRecommendations,
    required this.momentumRecommendations,
  });
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
  final TriadMatrixFilterPaletteV1? matrixPalette;
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
    required this.matrixPalette,
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
  final TriadMatrixFilterPaletteV1? palette;
  final Set<TriadMatrixFilterV1> filters;
  final Set<String> selectedRows;
  final Set<String> selectedColumns;

  const MatrixFiltersV1({
    required this.lane,
    required this.palette,
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
class PracticeSessionSetupV1 {
  final List<String> practiceItemIds;
  final MaterialFamilyV1 family;
  final PracticeModeV1 practiceMode;
  final int bpm;
  final TimerPresetV1 timerPreset;
  final bool clickEnabled;
  final String? routineId;
  final String sourceName;

  const PracticeSessionSetupV1({
    required this.practiceItemIds,
    required this.family,
    required this.practiceMode,
    required this.bpm,
    required this.timerPreset,
    required this.clickEnabled,
    required this.routineId,
    this.sourceName = '',
  });

  PracticeSessionSetupV1 copyWith({
    List<String>? practiceItemIds,
    MaterialFamilyV1? family,
    PracticeModeV1? practiceMode,
    int? bpm,
    TimerPresetV1? timerPreset,
    bool? clickEnabled,
    String? routineId,
    String? sourceName,
    bool clearRoutineId = false,
  }) {
    return PracticeSessionSetupV1(
      practiceItemIds: practiceItemIds ?? this.practiceItemIds,
      family: family ?? this.family,
      practiceMode: practiceMode ?? this.practiceMode,
      bpm: bpm ?? this.bpm,
      timerPreset: timerPreset ?? this.timerPreset,
      clickEnabled: clickEnabled ?? this.clickEnabled,
      routineId: clearRoutineId ? null : (routineId ?? this.routineId),
      sourceName: sourceName ?? this.sourceName,
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
  final MaterialFamilyV1 family;
  final PracticeModeV1 practiceMode;
  final int bpm;
  final bool clickEnabled;
  final String? routineId;
  final ReflectionRatingV1? reflection;
  final String sourceName;

  const PracticeSessionLogV1({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.practiceItemIds,
    required this.assessmentItemId,
    required this.family,
    required this.practiceMode,
    required this.bpm,
    required this.clickEnabled,
    required this.routineId,
    required this.reflection,
    this.sourceName = '',
  });

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
    int? bpm,
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
      bpm: bpm ?? this.bpm,
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
