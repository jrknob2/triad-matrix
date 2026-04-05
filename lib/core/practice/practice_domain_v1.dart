import 'package:flutter/foundation.dart';

/// Authoritative rebuild models for the app spec in docs/06 and docs/07.
///
/// These models intentionally define the product domain in one place so the
/// next implementation pass does not repeat the current enum/model drift across
/// multiple files.

/* -------------------------------------------------------------------------- */
/* Enums                                                                      */
/* -------------------------------------------------------------------------- */

enum HandednessV1 {
  right,
  left,
}

enum PlayerSelfRankV1 {
  beginner,
  developing,
  intermediate,
  advanced,
}

enum MaterialFamilyV1 {
  triad,
  fiveNote,
  custom,
  combo,
}

enum PracticeIntentV1 {
  coreSkills,
  flow,
}

enum PracticeContextV1 {
  singleSurface,
  kit,
}

enum PracticeItemSourceV1 {
  builtIn,
  userDefined,
  generated,
}

enum ComboIntentTagV1 {
  coreSkills,
  flow,
  both,
}

enum CompetencyLevelV1 {
  notStarted,
  learning,
  comfortable,
  reliable,
  musical,
}

enum ReflectionRatingV1 {
  easy,
  okay,
  hard,
}

enum TimerPresetV1 {
  none,
  minutes5,
  minutes10,
  minutes20,
  minutes30,
}

enum FlowFillLengthV1 {
  oneBeat,
  twoBeats,
  oneBar,
  twoBars,
}

enum FlowLandingRuleV1 {
  beat1,
}

enum GrooveFrameV1 {
  fourFourSixteenthGrid,
}

/* -------------------------------------------------------------------------- */
/* Value Objects                                                              */
/* -------------------------------------------------------------------------- */

@immutable
class UserProfileV1 {
  final HandednessV1 handedness;
  final PlayerSelfRankV1 selfRank;
  final int defaultBpm;
  final TimerPresetV1 defaultTimerPreset;
  final bool clickEnabledByDefault;
  final FlowFillLengthV1 defaultFlowFillLength;

  const UserProfileV1({
    required this.handedness,
    required this.selfRank,
    required this.defaultBpm,
    required this.defaultTimerPreset,
    required this.clickEnabledByDefault,
    required this.defaultFlowFillLength,
  });

  UserProfileV1 copyWith({
    HandednessV1? handedness,
    PlayerSelfRankV1? selfRank,
    int? defaultBpm,
    TimerPresetV1? defaultTimerPreset,
    bool? clickEnabledByDefault,
    FlowFillLengthV1? defaultFlowFillLength,
  }) {
    return UserProfileV1(
      handedness: handedness ?? this.handedness,
      selfRank: selfRank ?? this.selfRank,
      defaultBpm: defaultBpm ?? this.defaultBpm,
      defaultTimerPreset: defaultTimerPreset ?? this.defaultTimerPreset,
      clickEnabledByDefault:
          clickEnabledByDefault ?? this.clickEnabledByDefault,
      defaultFlowFillLength:
          defaultFlowFillLength ?? this.defaultFlowFillLength,
    );
  }

  static const UserProfileV1 initial = UserProfileV1(
    handedness: HandednessV1.right,
    selfRank: PlayerSelfRankV1.beginner,
    defaultBpm: 92,
    defaultTimerPreset: TimerPresetV1.minutes10,
    clickEnabledByDefault: true,
    defaultFlowFillLength: FlowFillLengthV1.oneBar,
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

  final PracticeItemSourceV1 source;
  final List<String> tags;
  final bool saved;

  const PracticeItemV1({
    required this.id,
    required this.family,
    required this.name,
    required this.sticking,
    required this.noteCount,
    required this.source,
    required this.tags,
    required this.saved,
  });

  bool get isTriad => family == MaterialFamilyV1.triad;
  bool get isFiveNote => family == MaterialFamilyV1.fiveNote;
  bool get isCustom => family == MaterialFamilyV1.custom;
  bool get isCombo => family == MaterialFamilyV1.combo;

  PracticeItemV1 copyWith({
    String? id,
    MaterialFamilyV1? family,
    String? name,
    String? sticking,
    int? noteCount,
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
      source: source ?? this.source,
      tags: tags ?? this.tags,
      saved: saved ?? this.saved,
    );
  }
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

  const RoutineEntryV1({
    required this.practiceItemId,
    required this.addedAt,
  });

  RoutineEntryV1 copyWith({
    String? practiceItemId,
    DateTime? addedAt,
  }) {
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
class FlowSpecV1 {
  final FlowFillLengthV1 fillLength;
  final FlowLandingRuleV1 landingRule;
  final GrooveFrameV1 grooveFrame;

  const FlowSpecV1({
    required this.fillLength,
    required this.landingRule,
    required this.grooveFrame,
  });

  FlowSpecV1 copyWith({
    FlowFillLengthV1? fillLength,
    FlowLandingRuleV1? landingRule,
    GrooveFrameV1? grooveFrame,
  }) {
    return FlowSpecV1(
      fillLength: fillLength ?? this.fillLength,
      landingRule: landingRule ?? this.landingRule,
      grooveFrame: grooveFrame ?? this.grooveFrame,
    );
  }

  static const FlowSpecV1 v1Default = FlowSpecV1(
    fillLength: FlowFillLengthV1.oneBar,
    landingRule: FlowLandingRuleV1.beat1,
    grooveFrame: GrooveFrameV1.fourFourSixteenthGrid,
  );
}

@immutable
class GeneratorOptionsV1 {
  final bool focusWeakItems;
  final bool focusUnderPracticedItems;
  final bool preferRoutineItems;
  final int itemCount;

  const GeneratorOptionsV1({
    required this.focusWeakItems,
    required this.focusUnderPracticedItems,
    required this.preferRoutineItems,
    required this.itemCount,
  });

  GeneratorOptionsV1 copyWith({
    bool? focusWeakItems,
    bool? focusUnderPracticedItems,
    bool? preferRoutineItems,
    int? itemCount,
  }) {
    return GeneratorOptionsV1(
      focusWeakItems: focusWeakItems ?? this.focusWeakItems,
      focusUnderPracticedItems:
          focusUnderPracticedItems ?? this.focusUnderPracticedItems,
      preferRoutineItems: preferRoutineItems ?? this.preferRoutineItems,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  static const GeneratorOptionsV1 defaults = GeneratorOptionsV1(
    focusWeakItems: false,
    focusUnderPracticedItems: false,
    preferRoutineItems: false,
    itemCount: 1,
  );
}

@immutable
class PracticeSessionSetupV1 {
  final List<String> practiceItemIds;
  final MaterialFamilyV1 family;
  final PracticeIntentV1 intent;
  final PracticeContextV1 context;
  final int bpm;
  final TimerPresetV1 timerPreset;
  final bool clickEnabled;
  final bool generated;
  final FlowSpecV1? flowSpec;
  final GeneratorOptionsV1? generatorOptions;
  final String? routineId;

  const PracticeSessionSetupV1({
    required this.practiceItemIds,
    required this.family,
    required this.intent,
    required this.context,
    required this.bpm,
    required this.timerPreset,
    required this.clickEnabled,
    required this.generated,
    required this.flowSpec,
    required this.generatorOptions,
    required this.routineId,
  });

  bool get isFlow => intent == PracticeIntentV1.flow;

  PracticeSessionSetupV1 copyWith({
    List<String>? practiceItemIds,
    MaterialFamilyV1? family,
    PracticeIntentV1? intent,
    PracticeContextV1? context,
    int? bpm,
    TimerPresetV1? timerPreset,
    bool? clickEnabled,
    bool? generated,
    FlowSpecV1? flowSpec,
    bool clearFlowSpec = false,
    GeneratorOptionsV1? generatorOptions,
    bool clearGeneratorOptions = false,
    String? routineId,
    bool clearRoutineId = false,
  }) {
    return PracticeSessionSetupV1(
      practiceItemIds: practiceItemIds ?? this.practiceItemIds,
      family: family ?? this.family,
      intent: intent ?? this.intent,
      context: context ?? this.context,
      bpm: bpm ?? this.bpm,
      timerPreset: timerPreset ?? this.timerPreset,
      clickEnabled: clickEnabled ?? this.clickEnabled,
      generated: generated ?? this.generated,
      flowSpec: clearFlowSpec ? null : (flowSpec ?? this.flowSpec),
      generatorOptions: clearGeneratorOptions
          ? null
          : (generatorOptions ?? this.generatorOptions),
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
  final PracticeIntentV1 intent;
  final PracticeContextV1 context;
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
    required this.intent,
    required this.context,
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
    PracticeIntentV1? intent,
    PracticeContextV1? context,
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
      intent: intent ?? this.intent,
      context: context ?? this.context,
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
  final PracticeIntentV1? intent;
  final PracticeContextV1? context;

  const PracticeTimeAggregateKeyV1({
    required this.practiceItemId,
    required this.family,
    required this.intent,
    required this.context,
  });

  @override
  bool operator ==(Object other) {
    return other is PracticeTimeAggregateKeyV1 &&
        other.practiceItemId == practiceItemId &&
        other.family == family &&
        other.intent == intent &&
        other.context == context;
  }

  @override
  int get hashCode => Object.hash(practiceItemId, family, intent, context);
}
