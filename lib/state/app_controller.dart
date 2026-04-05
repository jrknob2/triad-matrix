import 'package:flutter/foundation.dart';

import '../core/practice/practice_domain_v1.dart';
import '../features/app/app_formatters.dart';

class AppController extends ChangeNotifier {
  AppController() {
    _seed();
  }

  late UserProfileV1 _profile;
  late List<PracticeItemV1> _items;
  late List<PracticeCombinationV1> _combinations;
  late PracticeRoutineV1 _routine;
  late List<PracticeSessionLogV1> _sessions;
  late Map<String, CompetencyRecordV1> _competencyByItemId;

  UserProfileV1 get profile => _profile;
  List<PracticeItemV1> get items => List<PracticeItemV1>.unmodifiable(_items);
  List<PracticeCombinationV1> get combinations =>
      List<PracticeCombinationV1>.unmodifiable(_combinations);
  PracticeRoutineV1 get routine => _routine;

  List<PracticeSessionLogV1> get recentSessions {
    final List<PracticeSessionLogV1> copy =
        List<PracticeSessionLogV1>.from(_sessions);
    copy.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return List<PracticeSessionLogV1>.unmodifiable(copy);
  }

  List<PracticeItemV1> itemsByFamily(MaterialFamilyV1 family) {
    final List<PracticeItemV1> filtered =
        _items.where((item) => item.family == family).toList(growable: false);
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  List<PracticeItemV1> sourceItemsForBuilder() {
    final List<PracticeItemV1> filtered = _items
        .where((item) => item.family != MaterialFamilyV1.combo)
        .toList(growable: false);
    filtered.sort((a, b) => a.name.compareTo(b.name));
    return filtered;
  }

  PracticeItemV1 itemById(String id) {
    return _items.firstWhere((item) => item.id == id);
  }

  PracticeItemV1? itemByIdOrNull(String id) {
    for (final PracticeItemV1 item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  PracticeSessionLogV1? sessionById(String id) {
    for (final PracticeSessionLogV1 session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  CompetencyLevelV1 competencyFor(String itemId) {
    return _competencyByItemId[itemId]?.level ?? CompetencyLevelV1.notStarted;
  }

  bool isInRoutine(String itemId) {
    return _routine.entries.any((entry) => entry.practiceItemId == itemId);
  }

  List<PracticeItemV1> get routineItems {
    return _routine.entries
        .map((entry) => itemById(entry.practiceItemId))
        .toList(growable: false);
  }

  PracticeSessionLogV1? lastSessionForItem(String itemId) {
    for (final PracticeSessionLogV1 session in recentSessions) {
      if (session.practiceItemIds.contains(itemId)) return session;
    }
    return null;
  }

  Duration totalTime({
    String? itemId,
    MaterialFamilyV1? family,
    PracticeContextV1? context,
    PracticeIntentV1? intent,
  }) {
    Duration total = Duration.zero;

    for (final PracticeSessionLogV1 session in _sessions) {
      if (itemId != null && !session.practiceItemIds.contains(itemId)) continue;
      if (family != null && session.family != family) continue;
      if (context != null && session.context != context) continue;
      if (intent != null && session.intent != intent) continue;
      total += session.duration;
    }

    return total;
  }

  List<PracticeItemV1> itemsNeedingPractice(MaterialFamilyV1 family) {
    final List<PracticeItemV1> candidates = itemsByFamily(family);
    candidates.sort((a, b) {
      final int competencyCompare =
          _competencyScore(competencyFor(a.id)).compareTo(
        _competencyScore(competencyFor(b.id)),
      );
      if (competencyCompare != 0) return competencyCompare;

      final int timeCompare =
          totalTime(itemId: a.id).compareTo(totalTime(itemId: b.id));
      if (timeCompare != 0) return timeCompare;

      final DateTime aDate =
          lastSessionForItem(a.id)?.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final DateTime bDate =
          lastSessionForItem(b.id)?.endedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
    return candidates;
  }

  void updateProfile(UserProfileV1 next) {
    _profile = next;
    notifyListeners();
  }

  void updateCompetency(String itemId, CompetencyLevelV1 level) {
    _competencyByItemId[itemId] = CompetencyRecordV1(
      practiceItemId: itemId,
      level: level,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  PracticeItemV1 createCustomPattern({
    required String name,
    required String sticking,
    List<String> tags = const <String>[],
  }) {
    final String trimmedName = name.trim();
    final String trimmedSticking = sticking.trim();

    final PracticeItemV1 item = PracticeItemV1(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      family: MaterialFamilyV1.custom,
      name: trimmedName,
      sticking: trimmedSticking,
      noteCount: _estimateNoteCount(trimmedSticking),
      source: PracticeItemSourceV1.userDefined,
      tags: tags.where((tag) => tag.trim().isNotEmpty).toList(growable: false),
      saved: true,
    );

    _items = <PracticeItemV1>[..._items, item];
    notifyListeners();
    return item;
  }

  PracticeCombinationV1 createCombination({
    required String name,
    required List<String> itemIds,
    required ComboIntentTagV1 intentTag,
  }) {
    final String id = 'combo_${DateTime.now().microsecondsSinceEpoch}';
    final String sticking = itemIds
        .map((itemId) => itemById(itemId).name)
        .join(' → ');

    final PracticeCombinationV1 combo = PracticeCombinationV1(
      id: id,
      name: name.trim(),
      itemIds: List<String>.from(itemIds),
      intentTag: intentTag,
    );

    final int noteCount = itemIds.fold<int>(
      0,
      (sum, itemId) => sum + itemById(itemId).noteCount,
    );

    final PracticeItemV1 comboItem = PracticeItemV1(
      id: id,
      family: MaterialFamilyV1.combo,
      name: name.trim(),
      sticking: sticking,
      noteCount: noteCount,
      source: PracticeItemSourceV1.userDefined,
      tags: <String>['combo', intentTag.name],
      saved: true,
    );

    _combinations = <PracticeCombinationV1>[combo, ..._combinations];
    _items = <PracticeItemV1>[..._items, comboItem];
    notifyListeners();
    return combo;
  }

  void toggleRoutineItem(String itemId) {
    final bool alreadyInRoutine = isInRoutine(itemId);
    if (alreadyInRoutine) {
      _routine = _routine.copyWith(
        entries: _routine.entries
            .where((entry) => entry.practiceItemId != itemId)
            .toList(growable: false),
      );
    } else {
      _routine = _routine.copyWith(
        entries: <RoutineEntryV1>[
          ..._routine.entries,
          RoutineEntryV1(
            practiceItemId: itemId,
            addedAt: DateTime.now(),
          ),
        ],
      );
    }
    notifyListeners();
  }

  PracticeSessionSetupV1 buildGeneratedSetup({
    required MaterialFamilyV1 family,
    required PracticeIntentV1 intent,
    required PracticeContextV1 context,
    required int bpm,
    required TimerPresetV1 timerPreset,
    required bool clickEnabled,
    FlowSpecV1? flowSpec,
    GeneratorOptionsV1? generatorOptions,
  }) {
    final GeneratorOptionsV1 options =
        generatorOptions ?? GeneratorOptionsV1.defaults;

    final List<PracticeItemV1> candidates = _generatedCandidates(
      family: family,
      options: options,
    );

    final List<String> itemIds = candidates
        .take(options.itemCount.clamp(1, candidates.length))
        .map((item) => item.id)
        .toList(growable: false);

    return PracticeSessionSetupV1(
      practiceItemIds: itemIds,
      family: family,
      intent: intent,
      context: context,
      bpm: bpm,
      timerPreset: timerPreset,
      clickEnabled: clickEnabled,
      generated: true,
      flowSpec: intent == PracticeIntentV1.flow
          ? (flowSpec ?? FlowSpecV1.v1Default)
          : null,
      generatorOptions: options,
      routineId: null,
    );
  }

  PracticeSessionLogV1 completeSession(
    PracticeSessionSetupV1 setup,
    Duration duration, {
    ReflectionRatingV1? reflection,
  }) {
    final DateTime endedAt = DateTime.now();
    final PracticeSessionLogV1 session = PracticeSessionLogV1(
      id: 'session_${endedAt.microsecondsSinceEpoch}',
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      duration: duration,
      practiceItemIds: setup.practiceItemIds,
      family: setup.family,
      intent: setup.intent,
      context: setup.context,
      bpm: setup.bpm,
      clickEnabled: setup.clickEnabled,
      routineId: setup.routineId,
      reflection: reflection,
    );

    _sessions = <PracticeSessionLogV1>[session, ..._sessions];
    notifyListeners();
    return session;
  }

  void updateSessionReflection(String sessionId, ReflectionRatingV1? rating) {
    _sessions = _sessions.map((session) {
      if (session.id != sessionId) return session;
      return session.copyWith(
        reflection: rating,
        clearReflection: rating == null,
      );
    }).toList(growable: false);
    notifyListeners();
  }

  String recentSummaryForItem(String itemId) {
    final PracticeSessionLogV1? session = lastSessionForItem(itemId);
    if (session == null) return 'No sessions yet';
    return '${formatShortDate(session.endedAt)} · ${formatDuration(session.duration)}';
  }

  List<PracticeItemV1> _generatedCandidates({
    required MaterialFamilyV1 family,
    required GeneratorOptionsV1 options,
  }) {
    List<PracticeItemV1> base = itemsByFamily(family);

    if (options.preferRoutineItems) {
      final List<PracticeItemV1> routineFiltered = routineItems
          .where((item) => item.family == family)
          .toList(growable: false);
      if (routineFiltered.isNotEmpty) base = routineFiltered;
    }

    if (base.isEmpty) return items.take(1).toList(growable: false);

    base.sort((a, b) {
      if (options.focusWeakItems) {
        final int weakCompare =
            _competencyScore(competencyFor(a.id)).compareTo(
          _competencyScore(competencyFor(b.id)),
        );
        if (weakCompare != 0) return weakCompare;
      }

      if (options.focusUnderPracticedItems || !options.focusWeakItems) {
        final int timeCompare =
            totalTime(itemId: a.id).compareTo(totalTime(itemId: b.id));
        if (timeCompare != 0) return timeCompare;
      }

      return a.name.compareTo(b.name);
    });

    return base;
  }

  int _competencyScore(CompetencyLevelV1 level) {
    return switch (level) {
      CompetencyLevelV1.notStarted => 0,
      CompetencyLevelV1.learning => 1,
      CompetencyLevelV1.comfortable => 2,
      CompetencyLevelV1.reliable => 3,
      CompetencyLevelV1.musical => 4,
    };
  }

  int _estimateNoteCount(String sticking) {
    final List<String> tokens = sticking
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
    return tokens.isEmpty ? sticking.length : tokens.length;
  }

  void _seed() {
    _profile = UserProfileV1.initial;

    _items = const <PracticeItemV1>[
      PracticeItemV1(
        id: 'triad_rll',
        family: MaterialFamilyV1.triad,
        name: 'RLL',
        sticking: 'RLL',
        noteCount: 3,
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['double', 'core'],
        saved: true,
      ),
      PracticeItemV1(
        id: 'triad_rrl',
        family: MaterialFamilyV1.triad,
        name: 'RRL',
        sticking: 'RRL',
        noteCount: 3,
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['double', 'core'],
        saved: true,
      ),
      PracticeItemV1(
        id: 'triad_lrr',
        family: MaterialFamilyV1.triad,
        name: 'LRR',
        sticking: 'LRR',
        noteCount: 3,
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['lead-shift'],
        saved: true,
      ),
      PracticeItemV1(
        id: 'triad_rlr',
        family: MaterialFamilyV1.triad,
        name: 'RLR',
        sticking: 'RLR',
        noteCount: 3,
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['alternating'],
        saved: true,
      ),
      PracticeItemV1(
        id: 'five_rlrlk',
        family: MaterialFamilyV1.fiveNote,
        name: 'RLRLK',
        sticking: 'RLRLK',
        noteCount: 5,
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['5s', 'flow'],
        saved: true,
      ),
      PracticeItemV1(
        id: 'five_rllrl',
        family: MaterialFamilyV1.fiveNote,
        name: 'RLLRL',
        sticking: 'RLLRL',
        noteCount: 5,
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['5s', 'core'],
        saved: true,
      ),
      PracticeItemV1(
        id: 'custom_linear_break',
        family: MaterialFamilyV1.custom,
        name: 'Linear Break',
        sticking: 'R K L R L',
        noteCount: 5,
        source: PracticeItemSourceV1.userDefined,
        tags: <String>['custom', 'linear'],
        saved: true,
      ),
      PracticeItemV1(
        id: 'combo_double_builder',
        family: MaterialFamilyV1.combo,
        name: 'Double Builder',
        sticking: 'RLL → RRL',
        noteCount: 6,
        source: PracticeItemSourceV1.userDefined,
        tags: <String>['combo', 'core'],
        saved: true,
      ),
    ];

    _combinations = const <PracticeCombinationV1>[
      PracticeCombinationV1(
        id: 'combo_double_builder',
        name: 'Double Builder',
        itemIds: <String>['triad_rll', 'triad_rrl'],
        intentTag: ComboIntentTagV1.coreSkills,
      ),
    ];

    _routine = PracticeRoutineV1(
      id: 'main_routine',
      name: 'Current Focus',
      entries: <RoutineEntryV1>[
        RoutineEntryV1(
          practiceItemId: 'triad_rll',
          addedAt: DateTime.now().subtract(const Duration(days: 10)),
        ),
        RoutineEntryV1(
          practiceItemId: 'combo_double_builder',
          addedAt: DateTime.now().subtract(const Duration(days: 7)),
        ),
        RoutineEntryV1(
          practiceItemId: 'five_rlrlk',
          addedAt: DateTime.now().subtract(const Duration(days: 4)),
        ),
      ],
    );

    _sessions = <PracticeSessionLogV1>[
      PracticeSessionLogV1(
        id: 'session_seed_1',
        startedAt: DateTime.now().subtract(const Duration(days: 1, minutes: 18)),
        endedAt: DateTime.now().subtract(const Duration(days: 1)),
        duration: const Duration(minutes: 18),
        practiceItemIds: const <String>['triad_rll'],
        family: MaterialFamilyV1.triad,
        intent: PracticeIntentV1.coreSkills,
        context: PracticeContextV1.singleSurface,
        bpm: 84,
        clickEnabled: true,
        routineId: 'main_routine',
        reflection: ReflectionRatingV1.okay,
      ),
      PracticeSessionLogV1(
        id: 'session_seed_2',
        startedAt: DateTime.now().subtract(const Duration(days: 3, minutes: 12)),
        endedAt: DateTime.now().subtract(const Duration(days: 3)),
        duration: const Duration(minutes: 12),
        practiceItemIds: const <String>['combo_double_builder'],
        family: MaterialFamilyV1.combo,
        intent: PracticeIntentV1.coreSkills,
        context: PracticeContextV1.singleSurface,
        bpm: 92,
        clickEnabled: true,
        routineId: 'main_routine',
        reflection: ReflectionRatingV1.okay,
      ),
      PracticeSessionLogV1(
        id: 'session_seed_3',
        startedAt: DateTime.now().subtract(const Duration(days: 5, minutes: 9)),
        endedAt: DateTime.now().subtract(const Duration(days: 5)),
        duration: const Duration(minutes: 9),
        practiceItemIds: const <String>['five_rlrlk'],
        family: MaterialFamilyV1.fiveNote,
        intent: PracticeIntentV1.flow,
        context: PracticeContextV1.kit,
        bpm: 100,
        clickEnabled: true,
        routineId: 'main_routine',
        reflection: ReflectionRatingV1.hard,
      ),
      PracticeSessionLogV1(
        id: 'session_seed_4',
        startedAt: DateTime.now().subtract(const Duration(days: 8, minutes: 14)),
        endedAt: DateTime.now().subtract(const Duration(days: 8)),
        duration: const Duration(minutes: 14),
        practiceItemIds: const <String>['custom_linear_break'],
        family: MaterialFamilyV1.custom,
        intent: PracticeIntentV1.flow,
        context: PracticeContextV1.kit,
        bpm: 88,
        clickEnabled: false,
        routineId: null,
        reflection: ReflectionRatingV1.okay,
      ),
    ];

    _competencyByItemId = <String, CompetencyRecordV1>{
      'triad_rll': CompetencyRecordV1(
        practiceItemId: 'triad_rll',
        level: CompetencyLevelV1.comfortable,
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      'triad_rrl': CompetencyRecordV1(
        practiceItemId: 'triad_rrl',
        level: CompetencyLevelV1.learning,
        updatedAt: DateTime.now().subtract(const Duration(days: 6)),
      ),
      'five_rlrlk': CompetencyRecordV1(
        practiceItemId: 'five_rlrlk',
        level: CompetencyLevelV1.learning,
        updatedAt: DateTime.now().subtract(const Duration(days: 4)),
      ),
      'combo_double_builder': CompetencyRecordV1(
        practiceItemId: 'combo_double_builder',
        level: CompetencyLevelV1.learning,
        updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    };
  }
}
