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

enum MaterialFamilyV1 { triad, fiveNote, custom, combo }

enum PracticeItemSourceV1 { builtIn, userDefined, generated }

enum ComboIntentTagV1 { coreSkills, flow, both }

enum CompetencyLevelV1 { notStarted, learning, comfortable, reliable, musical }

enum ReflectionRatingV1 { easy, okay, hard }

enum TimerPresetV1 { none, minutes5, minutes10, minutes20, minutes30 }

enum TriadMatrixViewModeV1 { competency, lead, handsOnly, weakHand }

enum TriadMatrixFilterPaletteV1 { coaching, technique, combos }

enum TriadMatrixFilterV1 {
  competency,
  inRoutine,
  needsAttention,
  underPracticed,
  closeToToolkit,
  recent,
  unseen,
  lead,
  weakHand,
  handsOnly,
  hasKick,
  startsWithKick,
  endsWithKick,
  doubles,
}

enum PatternNoteMarkingV1 { normal, accent, ghost }

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
    required this.source,
    required this.tags,
    required this.saved,
  });

  bool get isTriad => family == MaterialFamilyV1.triad;
  bool get isFiveNote => family == MaterialFamilyV1.fiveNote;
  bool get isCustom => family == MaterialFamilyV1.custom;
  bool get isCombo => family == MaterialFamilyV1.combo;
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
      source: source ?? this.source,
      tags: tags ?? this.tags,
      saved: saved ?? this.saved,
    );
  }
}

@immutable
class CoachCueV1 {
  final String title;
  final String detail;
  final List<String> suggestedItemIds;

  const CoachCueV1({
    required this.title,
    required this.detail,
    required this.suggestedItemIds,
  });
}

@immutable
class TodayBriefingV1 {
  final String headline;
  final String summary;
  final List<CoachCueV1> cues;

  const TodayBriefingV1({
    required this.headline,
    required this.summary,
    required this.cues,
  });
}

@immutable
class PracticeCombinationV1 {
  final String id;
  final String name;
  final List<String> itemIds;
  final ComboIntentTagV1 intentTag;

  const PracticeCombinationV1({
    required this.id,
    required this.name,
    required this.itemIds,
    required this.intentTag,
  });

  PracticeCombinationV1 copyWith({
    String? id,
    String? name,
    List<String>? itemIds,
    ComboIntentTagV1? intentTag,
  }) {
    return PracticeCombinationV1(
      id: id ?? this.id,
      name: name ?? this.name,
      itemIds: itemIds ?? this.itemIds,
      intentTag: intentTag ?? this.intentTag,
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
  final int bpm;
  final TimerPresetV1 timerPreset;
  final bool clickEnabled;
  final String? routineId;

  const PracticeSessionSetupV1({
    required this.practiceItemIds,
    required this.family,
    required this.bpm,
    required this.timerPreset,
    required this.clickEnabled,
    required this.routineId,
  });

  PracticeSessionSetupV1 copyWith({
    List<String>? practiceItemIds,
    MaterialFamilyV1? family,
    int? bpm,
    TimerPresetV1? timerPreset,
    bool? clickEnabled,
    String? routineId,
    bool clearRoutineId = false,
  }) {
    return PracticeSessionSetupV1(
      practiceItemIds: practiceItemIds ?? this.practiceItemIds,
      family: family ?? this.family,
      bpm: bpm ?? this.bpm,
      timerPreset: timerPreset ?? this.timerPreset,
      clickEnabled: clickEnabled ?? this.clickEnabled,
      routineId: clearRoutineId ? null : (routineId ?? this.routineId),
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
  final MaterialFamilyV1 family;
  final int bpm;
  final bool clickEnabled;
  final String? routineId;
  final ReflectionRatingV1? reflection;

  const PracticeSessionLogV1({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.duration,
    required this.practiceItemIds,
    required this.family,
    required this.bpm,
    required this.clickEnabled,
    required this.routineId,
    required this.reflection,
  });

  PracticeSessionLogV1 copyWith({
    String? id,
    DateTime? startedAt,
    DateTime? endedAt,
    Duration? duration,
    List<String>? practiceItemIds,
    MaterialFamilyV1? family,
    int? bpm,
    bool? clickEnabled,
    String? routineId,
    bool clearRoutineId = false,
    ReflectionRatingV1? reflection,
    bool clearReflection = false,
  }) {
    return PracticeSessionLogV1(
      id: id ?? this.id,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      practiceItemIds: practiceItemIds ?? this.practiceItemIds,
      family: family ?? this.family,
      bpm: bpm ?? this.bpm,
      clickEnabled: clickEnabled ?? this.clickEnabled,
      routineId: clearRoutineId ? null : (routineId ?? this.routineId),
      reflection: clearReflection ? null : (reflection ?? this.reflection),
    );
  }
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
