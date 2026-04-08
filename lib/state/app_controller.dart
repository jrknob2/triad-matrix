import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/pattern/triad_matrix.dart';
import '../core/practice/practice_domain_v1.dart';
import '../features/app/app_formatters.dart';
import 'persistence/app_state_store.dart';

class AppController extends ChangeNotifier {
  AppController._(this._store) {
    _initializeFirstLightState();
  }

  final AppStateStore _store;

  static Future<AppController> create() async {
    final AppStateStore store = await AppStateStore.open();
    final AppController controller = AppController._(store);
    await controller._restorePersistedState();
    return controller;
  }

  late UserProfileV1 _profile;
  late List<PracticeItemV1> _items;
  late List<PracticeCombinationV1> _combinations;
  late PracticeRoutineV1 _routine;
  late List<PracticeSessionLogV1> _sessions;
  late List<SessionAssessmentResultV1> _assessmentResults;
  late Map<String, PracticeAssessmentAggregateV1> _assessmentAggregateByItemId;
  late Map<String, CompetencyRecordV1> _competencyByItemId;
  bool _onboardingComplete = false;
  int _resetVersion = 0;

  UserProfileV1 get profile => _profile;
  List<PracticeItemV1> get items => List<PracticeItemV1>.unmodifiable(_items);
  List<PracticeCombinationV1> get combinations =>
      List<PracticeCombinationV1>.unmodifiable(_combinations);
  PracticeRoutineV1 get routine => _routine;
  List<SessionAssessmentResultV1> get assessmentResults =>
      List<SessionAssessmentResultV1>.unmodifiable(_assessmentResults);
  bool get onboardingComplete => _onboardingComplete;
  int get resetVersion => _resetVersion;
  bool get hasLoggedPractice => _sessions.isNotEmpty;
  bool get hasSavedPhraseWork => _combinations.isNotEmpty;
  bool get hasCustomPatterns =>
      _items.any((PracticeItemV1 item) => item.isCustom);
  bool get hasActiveWork => _routine.entries.isNotEmpty;
  bool get isFirstLight =>
      !hasLoggedPractice &&
      !hasSavedPhraseWork &&
      !hasCustomPatterns &&
      !hasActiveWork &&
      _competencyByItemId.isEmpty;

  Future<void> _restorePersistedState() async {
    final AppStateSnapshotData? snapshot = await _store.load();
    if (snapshot == null) return;

    _profile = snapshot.profile;
    _items = snapshot.items;
    _combinations = snapshot.combinations;
    _routine = snapshot.routine;
    _sessions = snapshot.sessions;
    _assessmentResults = snapshot.assessmentResults;
    _assessmentAggregateByItemId = <String, PracticeAssessmentAggregateV1>{
      for (final PracticeAssessmentAggregateV1 aggregate
          in snapshot.assessmentAggregates)
        aggregate.practiceItemId: aggregate,
    };
    _competencyByItemId = <String, CompetencyRecordV1>{
      for (final CompetencyRecordV1 record in snapshot.competencyRecords)
        record.practiceItemId: record,
    };
    _onboardingComplete = snapshot.onboardingComplete;
  }

  void _notifyChanged({bool bumpResetVersion = false}) {
    if (bumpResetVersion) {
      _resetVersion += 1;
    }
    unawaited(_persistState());
    notifyListeners();
  }

  Future<void> _persistState() async {
    await _store.save(
      AppStateSnapshotData(
        schemaVersion: AppStateStore.currentSchemaVersion,
        onboardingComplete: _onboardingComplete,
        profile: _profile,
        items: _items,
        combinations: _combinations,
        routine: _routine,
        sessions: _sessions,
        competencyRecords: _competencyByItemId.values.toList(growable: false),
        assessmentResults: _assessmentResults,
        assessmentAggregates: _assessmentAggregateByItemId.values.toList(
          growable: false,
        ),
      ),
    );
  }

  String get weakHandLabel =>
      _profile.handedness == HandednessV1.right ? 'Left' : 'Right';

  String get strongHandLabel =>
      _profile.handedness == HandednessV1.right ? 'Right' : 'Left';

  List<PracticeSessionLogV1> get recentSessions {
    final List<PracticeSessionLogV1> copy = List<PracticeSessionLogV1>.from(
      _sessions,
    );
    copy.sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return List<PracticeSessionLogV1>.unmodifiable(copy);
  }

  PracticeAssessmentAggregateV1? assessmentAggregateFor(String itemId) {
    return _assessmentAggregateByItemId[itemId];
  }

  List<PracticeItemV1> get triadMatrixItems {
    return triadMatrixAll()
        .map((cell) => itemById(_triadItemId(cell.id)))
        .toList(growable: false);
  }

  List<String> get recommendedStartingTriadItemIds => <String>[
    _triadItemId('RRR'),
    _triadItemId('LLL'),
    _triadItemId('RLL'),
    _triadItemId('LRR'),
  ];

  List<PracticeItemV1> get trackedItems {
    return _items.where((item) => !item.isCustom).toList(growable: false);
  }

  LearningLaneV1 laneForPracticeItem(
    String itemId, {
    PracticeModeV1 practiceMode = PracticeModeV1.singleSurface,
  }) {
    final PracticeItemV1 item = itemById(itemId);
    if (practiceMode == PracticeModeV1.flow) return LearningLaneV1.flow;
    if (item.isCombo) return LearningLaneV1.phrasing;
    if (hasKick(itemId)) return LearningLaneV1.integration;
    if (item.hasAccents || item.hasGhostNotes) return LearningLaneV1.dynamics;
    if (_isWeakHandLead(item)) return LearningLaneV1.balance;
    return LearningLaneV1.control;
  }

  String practiceGuidanceFor(
    String itemId, {
    PracticeModeV1 practiceMode = PracticeModeV1.singleSurface,
  }) {
    final LearningLaneV1 lane = laneForPracticeItem(
      itemId,
      practiceMode: practiceMode,
    );

    return switch (lane) {
      LearningLaneV1.control =>
        'Keep the sound even and the motion relaxed before you add anything else.',
      LearningLaneV1.balance =>
        '$weakHandLabel-hand lead is the point of this phrase. Match it to the strong side without forcing it.',
      LearningLaneV1.dynamics =>
        'Hold the sticking steady and shape the touch. Let the accents and ghosts do the work.',
      LearningLaneV1.integration =>
        'Add the kick without letting the hands smear. Keep the phrase clean first.',
      LearningLaneV1.phrasing =>
        'Listen to the transition points. The phrase should feel connected, not stitched together.',
      LearningLaneV1.flow =>
        'Assign voices deliberately and make the phrase read clearly around the kit.',
    };
  }

  TodayBriefingV1 buildTodayBriefing() {
    if (!hasLoggedPractice) {
      return TodayBriefingV1(
        primaryLane: LearningLaneV1.control,
        headline: 'Start with control.',
        summary:
            'Use one clear cell on one surface first. Build even sound and relaxed motion before you widen the phrase.',
        laneRecommendations: <TodayLaneRecommendationV1>[
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.control,
            title: 'Control',
            reason:
                'Hands-only triads are the cleanest place to establish pulse, rebound, and sound.',
            actionLabel: 'Practice',
            itemIds: <String>[triadMatrixItems.first.id],
            evidence: 'No practice logged yet',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.balance,
            title: 'Balance',
            reason:
                'Very early on, learn the phrase on both leads so the vocabulary does not become one-sided.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence: '$weakHandLabel lead has not been worked yet',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.dynamics,
            title: 'Dynamics',
            reason:
                'Add accents and ghosts after the base sticking feels steady. Do not force dynamic shape too early.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence: 'Start with plain strokes first',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.integration,
            title: 'Integration',
            reason:
                'Kick material comes after the hands are clear. Keep it in view, but do not start there.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence: '$totalKickTriadCount kick-based triads available later',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.phrasing,
            title: 'Phrasing',
            reason:
                'Phrase work matters, but it should rest on a few stable cells first.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence: 'Build phrases after core cells settle in',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.flow,
            title: 'Flow',
            reason:
                'Flow is where phrases move across voices on the kit. It comes after the phrase feels stable on one surface.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence: 'Voice work starts once the phrase is under your hands',
          ),
        ],
        momentumRecommendations: <TodayLaneRecommendationV1>[
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.control,
            title: 'First Step',
            reason:
                'Pick one hands-only triad, stay with it for a few minutes, then match it on the opposite lead.',
            actionLabel: 'Practice',
            itemIds: <String>[triadMatrixItems.first.id],
            evidence: 'Built-in vocabulary is ready to use',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.phrasing,
            title: 'What Stays Built In',
            reason:
                'The app always keeps the core vocabulary. Resetting clears your work, not the built-in material.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence:
                '${triadMatrixItems.length} built-in triads are ready whenever you are',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.flow,
            title: 'What Comes Later',
            reason:
                'Once a phrase is stable, take it into Flow and assign voices deliberately.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence: 'Single-surface first, flow second',
          ),
        ],
      );
    }

    final List<TodayLaneRecommendationV1> lanes = <TodayLaneRecommendationV1>[
      _buildControlLane(),
      _buildBalanceLane(),
      _buildDynamicsLane(),
      _buildIntegrationLane(),
      _buildPhrasingLane(),
      _buildFlowLane(),
    ];
    final List<TodayLaneRecommendationV1> rankedLanes =
        _rankedLaneRecommendations(lanes);

    final LearningLaneV1 primaryLane = rankedLanes.first.lane;

    final List<TodayLaneRecommendationV1> momentum =
        <TodayLaneRecommendationV1>[
          _buildWorkingOnMomentum(),
          _buildToolboxMomentum(),
          _buildNeglectedMomentum(),
          _buildReviewMomentum(),
        ].where(_isActionableRecommendation).take(2).toList(growable: false);

    return TodayBriefingV1(
      primaryLane: primaryLane,
      headline: 'Today centers on ${primaryLane.label.toLowerCase()}.',
      summary: _summaryForPrimaryLane(primaryLane),
      laneRecommendations: rankedLanes.take(3).toList(growable: false),
      momentumRecommendations: momentum,
    );
  }

  List<TodayLaneRecommendationV1> _rankedLaneRecommendations(
    List<TodayLaneRecommendationV1> lanes,
  ) {
    final List<TodayLaneRecommendationV1> ranked = lanes.toList(growable: false)
      ..sort((a, b) {
        final int priorityCompare = _lanePriority(
          b.lane,
        ).compareTo(_lanePriority(a.lane));
        if (priorityCompare != 0) return priorityCompare;
        final bool aInFocus = a.itemIds.any(isInRoutine);
        final bool bInFocus = b.itemIds.any(isInRoutine);
        if (aInFocus != bInFocus) return bInFocus ? 1 : -1;
        return a.title.compareTo(b.title);
      });
    return ranked;
  }

  bool _isActionableRecommendation(TodayLaneRecommendationV1 recommendation) {
    if (recommendation.itemIds.isEmpty) return true;
    return recommendation.itemIds.any(
      (String itemId) => itemByIdOrNull(itemId) != null,
    );
  }

  TodayLaneRecommendationV1 _buildWorkingOnMomentum() {
    if (activeWorkItems.isEmpty) {
      return TodayLaneRecommendationV1(
        lane: LearningLaneV1.control,
        title: 'Working On',
        reason:
            'Add a few cells to Working On so practice has a clear center of gravity.',
        actionLabel: 'Open Matrix',
        itemIds: const <String>[],
        evidence: 'No active work selected yet',
      );
    }

    final PracticeItemV1 target = activeWorkItems.first;
    return TodayLaneRecommendationV1(
      lane: laneForPracticeItem(target.id),
      title: 'Working On',
      reason:
          'Keep your active material moving. Repetition across days is what turns a pattern into vocabulary.',
      actionLabel: 'Practice',
      itemIds: <String>[target.id],
      evidence:
          '${formatDuration(totalTime(itemId: target.id))} logged • ${competencyFor(target.id).label}',
    );
  }

  List<PracticeItemV1> itemsByFamily(MaterialFamilyV1 family) {
    final List<PracticeItemV1> filtered = _items
        .where((item) => item.family == family)
        .toList(growable: false);
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

  PracticeItemV1? triadItemForCell(String cellId) {
    return itemByIdOrNull(_triadItemId(cellId));
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

  bool isDirectRoutineEntry(String itemId) {
    return _routine.entries.any((entry) => entry.practiceItemId == itemId);
  }

  bool isInRoutine(String itemId) {
    return _routine.entries.any((entry) {
      if (entry.practiceItemId == itemId) return true;
      return _entryContainsItem(entry.practiceItemId, itemId);
    });
  }

  List<PracticeItemV1> get routineItems {
    return _routine.entries
        .map((entry) => itemById(entry.practiceItemId))
        .toList(growable: false);
  }

  List<PracticeItemV1> get activeWorkItems {
    final List<PracticeItemV1> items = routineItems
        .where((item) => !item.isCustom)
        .toList(growable: false);
    items.sort((a, b) => _compareByNeed(a, b));
    return items;
  }

  List<PracticeItemV1> get phraseWorkItems {
    final List<PracticeItemV1> items = itemsByFamily(MaterialFamilyV1.combo);
    items.sort(_compareByNeed);
    return items;
  }

  List<PracticeItemV1> get customBucketItems {
    final List<PracticeItemV1> items = itemsByFamily(MaterialFamilyV1.custom);
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  List<PracticeItemV1> get toolboxReadyItems {
    final List<PracticeItemV1> items = _items
        .where((item) => !item.isCustom && isCloseToToolbox(item.id))
        .toList(growable: false);
    items.sort(
      (a, b) => totalTime(itemId: b.id).compareTo(totalTime(itemId: a.id)),
    );
    return items;
  }

  List<PracticeItemV1> get neglectedTrackedItems {
    final List<PracticeItemV1> items = trackedItems.toList(
      growable: false,
    )..sort((a, b) => _lastPracticedAt(a.id).compareTo(_lastPracticedAt(b.id)));
    return items;
  }

  List<PracticeItemV1> get reliableItemsNeedingReview {
    final List<PracticeItemV1> items =
        trackedItems
            .where(
              (item) =>
                  competencyFor(item.id).index >=
                      CompetencyLevelV1.reliable.index &&
                  !isRecent(item.id),
            )
            .toList(growable: false)
          ..sort(
            (a, b) => _lastPracticedAt(a.id).compareTo(_lastPracticedAt(b.id)),
          );
    return items;
  }

  Duration leadTime(HandednessV1 handedness) {
    return _timeForLead(handedness == HandednessV1.right ? 'R' : 'L');
  }

  int get practicedTriadCount {
    return triadMatrixItems.where((item) => !isUnseen(item.id)).length;
  }

  int get practicedHandsOnlyTriadCount {
    return triadMatrixItems
        .where((item) => handsOnly(item.id) && !isUnseen(item.id))
        .length;
  }

  int get practicedKickTriadCount {
    return triadMatrixItems
        .where((item) => hasKick(item.id) && !isUnseen(item.id))
        .length;
  }

  int get totalHandsOnlyTriadCount {
    return triadMatrixItems.where((item) => handsOnly(item.id)).length;
  }

  int get totalKickTriadCount {
    return triadMatrixItems.where((item) => hasKick(item.id)).length;
  }

  PracticeSessionLogV1? lastSessionForItem(String itemId) {
    for (final PracticeSessionLogV1 session in recentSessions) {
      if (_sessionContainsItem(session, itemId)) return session;
    }
    return null;
  }

  Duration totalTime({String? itemId, MaterialFamilyV1? family}) {
    Duration total = Duration.zero;

    for (final PracticeSessionLogV1 session in _sessions) {
      if (itemId != null && !_sessionContainsItem(session, itemId)) continue;
      if (family != null && session.family != family) continue;
      total += session.duration;
    }

    return total;
  }

  int sessionCount({String? itemId, MaterialFamilyV1? family}) {
    int total = 0;

    for (final PracticeSessionLogV1 session in _sessions) {
      if (itemId != null && !_sessionContainsItem(session, itemId)) continue;
      if (family != null && session.family != family) continue;
      total += 1;
    }

    return total;
  }

  bool usesKick(String itemId) =>
      _normalizedSticking(itemById(itemId)).contains('K');

  List<String> noteTokensFor(String itemId) {
    return _normalizedSticking(itemById(itemId)).split('');
  }

  List<PatternNoteMarkingV1> noteMarkingsFor(String itemId) {
    final PracticeItemV1 item = _sanitizedItem(itemById(itemId));
    final Set<int> accents = item.accentedNoteIndices.toSet();
    final Set<int> ghosts = item.ghostNoteIndices.toSet();

    return List<PatternNoteMarkingV1>.generate(item.noteCount, (index) {
      if (ghosts.contains(index)) return PatternNoteMarkingV1.ghost;
      if (accents.contains(index)) return PatternNoteMarkingV1.accent;
      return PatternNoteMarkingV1.normal;
    });
  }

  String markedPatternTextFor(String itemId) {
    final List<String> tokens = noteTokensFor(itemId);
    final List<PatternNoteMarkingV1> markings = noteMarkingsFor(itemId);
    return List<String>.generate(tokens.length, (index) {
      final String token = tokens[index];
      return switch (markings[index]) {
        PatternNoteMarkingV1.normal => token,
        PatternNoteMarkingV1.accent => '^$token',
        PatternNoteMarkingV1.ghost => '($token)',
      };
    }).join(' ');
  }

  List<DrumVoiceV1> noteVoicesFor(String itemId) {
    final PracticeItemV1 item = _sanitizedItem(itemById(itemId));
    return List<DrumVoiceV1>.unmodifiable(item.voiceAssignments);
  }

  bool hasNonSnareVoice(String itemId) {
    return noteVoicesFor(itemId).any((voice) => voice != DrumVoiceV1.snare);
  }

  bool hasKick(String itemId) => usesKick(itemId);

  bool handsOnly(String itemId) => !usesKick(itemId);

  bool startsWithRight(String itemId) => _firstNormalizedChar(itemId) == 'R';

  bool startsWithLeft(String itemId) => _firstNormalizedChar(itemId) == 'L';

  bool startsWithKick(String itemId) => _firstNormalizedChar(itemId) == 'K';

  bool endsWithKick(String itemId) => _lastNormalizedChar(itemId) == 'K';

  bool leadsWithWeakHand(String itemId) => _isWeakHandLead(itemById(itemId));

  bool hasDoubles(String itemId) {
    final String normalized = _normalizedSticking(itemById(itemId));
    if (normalized.length >= 3 && normalized.split('').toSet().length == 1) {
      return false;
    }
    for (int index = 0; index < normalized.length - 1; index++) {
      if (normalized[index] == normalized[index + 1]) return true;
    }
    return false;
  }

  String? mirrorItemId(String itemId) {
    final PracticeItemV1 item = itemById(itemId);
    if (!item.isTriad) return null;

    final String mirrored = _normalizedSticking(item).split('').map((ch) {
      return switch (ch) {
        'R' => 'L',
        'L' => 'R',
        _ => ch,
      };
    }).join();

    final PracticeItemV1? mirror = triadItemForCell(mirrored);
    return mirror?.id;
  }

  bool isUnseen(String itemId) => lastSessionForItem(itemId) == null;

  bool isRecent(String itemId) {
    final PracticeSessionLogV1? session = lastSessionForItem(itemId);
    if (session == null) return false;
    return DateTime.now().difference(session.endedAt) <=
        const Duration(days: 7);
  }

  bool isUnderPracticed(String itemId) {
    return totalTime(itemId: itemId) < const Duration(minutes: 12);
  }

  bool isCloseToToolbox(String itemId) {
    final CompetencyLevelV1 level = competencyFor(itemId);
    final bool strongCompetency =
        level == CompetencyLevelV1.comfortable ||
        level == CompetencyLevelV1.reliable;
    return strongCompetency &&
        totalTime(itemId: itemId) >= const Duration(minutes: 10);
  }

  bool needsAttention(String itemId) {
    final CompetencyLevelV1 level = competencyFor(itemId);
    final bool weakCompetency =
        level == CompetencyLevelV1.notStarted ||
        level == CompetencyLevelV1.learning;
    final bool stale = !isRecent(itemId);
    final bool lightTime =
        totalTime(itemId: itemId) < const Duration(minutes: 8);
    return weakCompetency && (stale || lightTime);
  }

  List<PracticeCombinationV1> get triadCombinations {
    final List<PracticeCombinationV1> combos = _combinations
        .where((combo) {
          return combo.itemIds.isNotEmpty &&
              combo.itemIds.every((itemId) => itemById(itemId).isTriad);
        })
        .toList(growable: false);
    combos.sort((a, b) => a.name.compareTo(b.name));
    return combos;
  }

  PracticeCombinationV1 combinationById(String id) {
    return _combinations.firstWhere((combo) => combo.id == id);
  }

  PracticeCombinationV1? combinationForItemIdsOrNull(List<String> itemIds) {
    for (final PracticeCombinationV1 combo in _combinations) {
      if (_sameOrderedItemIds(combo.itemIds, itemIds)) return combo;
    }
    return null;
  }

  String matrixLabelForCombination(String comboId) {
    final PracticeCombinationV1 combo = combinationById(comboId);
    return comboDisplayName(combo.itemIds);
  }

  String comboDisplayName(List<String> itemIds) {
    return itemIds.map((itemId) => itemById(itemId).name).join('-');
  }

  bool combinationContainsItem({
    required String comboId,
    required String itemId,
  }) {
    return combinationById(comboId).itemIds.contains(itemId);
  }

  bool _sessionContainsItem(PracticeSessionLogV1 session, String itemId) {
    for (final String sessionItemId in session.practiceItemIds) {
      if (sessionItemId == itemId) return true;
      if (_entryContainsItem(sessionItemId, itemId)) return true;
    }
    return false;
  }

  bool _entryContainsItem(String entryItemId, String itemId) {
    final PracticeItemV1? entryItem = itemByIdOrNull(entryItemId);
    if (entryItem == null || !entryItem.isCombo) return false;

    final PracticeCombinationV1? combo = _combinationByIdOrNull(entryItemId);
    if (combo == null) return false;
    return combo.itemIds.contains(itemId);
  }

  PracticeCombinationV1? _combinationByIdOrNull(String id) {
    for (final PracticeCombinationV1 combo in _combinations) {
      if (combo.id == id) return combo;
    }
    return null;
  }

  bool _sameOrderedItemIds(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  int weakHandNoteCount(String itemId) {
    final String weak = _profile.handedness == HandednessV1.right ? 'L' : 'R';
    return _normalizedSticking(
      itemById(itemId),
    ).split('').where((ch) => ch == weak).length;
  }

  String accentPatternLabelFor(String itemId) {
    final List<PatternNoteMarkingV1> markings = noteMarkingsFor(itemId);
    final Set<int> accented = <int>{
      for (int index = 0; index < markings.length; index++)
        if (markings[index] == PatternNoteMarkingV1.accent) index,
    };
    final PracticeItemV1 item = itemById(itemId);
    return List<String>.generate(
      item.noteCount,
      (index) => accented.contains(index) ? '^' : '·',
    ).join();
  }

  List<PracticeItemV1> itemsNeedingPractice(MaterialFamilyV1 family) {
    final List<PracticeItemV1> candidates = itemsByFamily(family);
    candidates.sort(_compareByNeed);
    return candidates;
  }

  int compareItemsByNeed(PracticeItemV1 a, PracticeItemV1 b) {
    return _compareByNeed(a, b);
  }

  TodayLaneRecommendationV1 _buildControlLane() {
    final List<PracticeItemV1> candidates =
        triadMatrixItems
            .where((item) => handsOnly(item.id))
            .toList(growable: false)
          ..sort(_compareByNeed);
    final PracticeItemV1 target = candidates.first;

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.control,
      title: 'Control',
      reason:
          'Start on one surface and clean up the pulse before adding more variables.',
      actionLabel: 'Practice',
      itemIds: <String>[target.id],
      evidence:
          '${formatDuration(totalTime(itemId: target.id))} logged • ${competencyFor(target.id).label}',
    );
  }

  TodayLaneRecommendationV1 _buildBalanceLane() {
    final List<PracticeItemV1> candidates =
        triadMatrixItems.where(_isWeakHandLead).toList(growable: false)
          ..sort(_compareByNeed);
    final PracticeItemV1 target = candidates.isNotEmpty
        ? candidates.first
        : triadMatrixItems.first;
    final Duration weakLeadTime = _timeForLead(weakHandLabel[0]);
    final Duration strongLeadTime = _timeForLead(strongHandLabel[0]);

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.balance,
      title: 'Balance',
      reason:
          '$weakHandLabel-hand lead is lagging. Put it first while your hands are fresh.',
      actionLabel: 'Practice',
      itemIds: <String>[target.id],
      evidence:
          '$weakHandLabel lead ${formatDuration(weakLeadTime)} vs ${strongHandLabel.toLowerCase()} lead ${formatDuration(strongLeadTime)}',
    );
  }

  TodayLaneRecommendationV1 _buildDynamicsLane() {
    final List<PracticeItemV1> candidates =
        triadMatrixItems
            .where((item) => handsOnly(item.id))
            .toList(growable: false)
          ..sort((a, b) {
            final int dynamicGap = _dynamicGapScore(
              b.id,
            ).compareTo(_dynamicGapScore(a.id));
            if (dynamicGap != 0) return dynamicGap;
            return _compareByNeed(a, b);
          });
    final PracticeItemV1 target = candidates.first;

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.dynamics,
      title: 'Dynamics',
      reason:
          'Use one stable cell to work accent height and ghost-note touch without changing the sticking.',
      actionLabel: 'Practice',
      itemIds: <String>[target.id],
      evidence: _dynamicEvidenceFor(target.id),
    );
  }

  TodayLaneRecommendationV1 _buildIntegrationLane() {
    final List<PracticeItemV1> candidates =
        triadMatrixItems
            .where((item) => hasKick(item.id))
            .toList(growable: false)
          ..sort(_compareByNeed);
    final PracticeItemV1 target = candidates.first;

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.integration,
      title: 'Integration',
      reason:
          'Bring the kick in only after the phrase is clear. This keeps coordination honest.',
      actionLabel: 'Practice',
      itemIds: <String>[target.id],
      evidence:
          '${formatDuration(totalTime(itemId: target.id))} logged on kick-based material',
    );
  }

  TodayLaneRecommendationV1 _buildPhrasingLane() {
    final List<PracticeItemV1> comboItems = itemsByFamily(
      MaterialFamilyV1.combo,
    );
    final PracticeItemV1 target;
    final String evidence;
    if (comboItems.isNotEmpty) {
      comboItems.sort(_compareByNeed);
      target = comboItems.first;
      evidence =
          '${formatDuration(totalTime(itemId: target.id))} logged • ${sessionCount(itemId: target.id)} sessions';
    } else {
      final List<PracticeItemV1> source = triadMatrixItems.toList()
        ..sort(_compareByNeed);
      target = source.first;
      evidence = 'No saved phrase work yet. Start by chaining stable cells.';
    }

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.phrasing,
      title: 'Phrasing',
      reason:
          'Move beyond single cells. Phrase length and transitions are where the vocabulary starts to sound musical.',
      actionLabel: comboItems.isNotEmpty ? 'Practice' : 'Open in Matrix',
      itemIds: <String>[target.id],
      evidence: evidence,
    );
  }

  TodayLaneRecommendationV1 _buildFlowLane() {
    final List<PracticeItemV1> candidates = _flowReadyItems();
    final PracticeItemV1 target = candidates.isNotEmpty
        ? candidates.first
        : triadMatrixItems.first;

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.flow,
      title: 'Flow',
      reason:
          'Take a phrase that already feels stable and assign voices so it starts behaving like kit vocabulary.',
      actionLabel: 'Practice in Flow',
      itemIds: <String>[target.id],
      evidence: _flowEvidenceFor(target.id),
    );
  }

  TodayLaneRecommendationV1 _buildToolboxMomentum() {
    final List<PracticeItemV1> items =
        triadMatrixItems
            .where((item) => isCloseToToolbox(item.id))
            .toList(growable: false)
          ..sort(
            (a, b) =>
                totalTime(itemId: b.id).compareTo(totalTime(itemId: a.id)),
          );
    final PracticeItemV1? target = items.isNotEmpty ? items.first : null;

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.control,
      title: 'Close To Toolbox',
      reason: target == null
          ? 'Nothing is near-ready yet. Stay with consistency and revisit the same few cells.'
          : 'This phrase is close to reliable. One focused pass could move it into your toolbox.',
      actionLabel: target == null ? 'Open Matrix' : 'Practice',
      itemIds: target == null ? const <String>[] : <String>[target.id],
      evidence: target == null
          ? '${recentSessions.length} total sessions logged'
          : '${competencyFor(target.id).label} • ${formatDuration(totalTime(itemId: target.id))}',
    );
  }

  TodayLaneRecommendationV1 _buildNeglectedMomentum() {
    final List<PracticeItemV1> items = triadMatrixItems.toList(
      growable: false,
    )..sort((a, b) => _lastPracticedAt(a.id).compareTo(_lastPracticedAt(b.id)));
    final PracticeItemV1 target = items.first;

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.balance,
      title: 'Neglected',
      reason:
          'Bring back material that has drifted out of rotation before it disappears.',
      actionLabel: 'Practice',
      itemIds: <String>[target.id],
      evidence: lastSessionForItem(target.id) == null
          ? 'No sessions yet'
          : 'Last touched ${formatShortDate(lastSessionForItem(target.id)!.endedAt)}',
    );
  }

  TodayLaneRecommendationV1 _buildReviewMomentum() {
    final List<PracticeItemV1> items =
        triadMatrixItems
            .where(
              (item) => competencyFor(item.id) == CompetencyLevelV1.reliable,
            )
            .toList(growable: false)
          ..sort(
            (a, b) => _lastPracticedAt(a.id).compareTo(_lastPracticedAt(b.id)),
          );
    final PracticeItemV1? target = items.isNotEmpty ? items.first : null;

    return TodayLaneRecommendationV1(
      lane: LearningLaneV1.phrasing,
      title: 'Needs Review',
      reason: target == null
          ? 'Nothing is established enough for review yet.'
          : 'Reliable material still needs revisits so it stays available on demand.',
      actionLabel: target == null ? 'Open Matrix' : 'Practice',
      itemIds: target == null ? const <String>[] : <String>[target.id],
      evidence: target == null
          ? '${triadMatrixItems.length} triads available'
          : '${formatDuration(totalTime(itemId: target.id))} total • ${competencyFor(target.id).label}',
    );
  }

  int _lanePriority(LearningLaneV1 lane) {
    return switch (lane) {
      LearningLaneV1.control => _controlPriority(),
      LearningLaneV1.balance => _balancePriority(),
      LearningLaneV1.dynamics => _dynamicsPriority(),
      LearningLaneV1.integration => _integrationPriority(),
      LearningLaneV1.phrasing => _phrasingPriority(),
      LearningLaneV1.flow => _flowPriority(),
    };
  }

  int _controlPriority() =>
      _notStartedCount(triadMatrixItems.where((item) => handsOnly(item.id)));

  int _balancePriority() {
    final Duration weakLeadTime = _timeForLead(weakHandLabel[0]);
    final Duration strongLeadTime = _timeForLead(strongHandLabel[0]);
    return (strongLeadTime - weakLeadTime).inMinutes.abs() +
        _notStartedCount(triadMatrixItems.where(_isWeakHandLead));
  }

  int _dynamicsPriority() => triadMatrixItems.fold<int>(
    0,
    (sum, item) => sum + _dynamicGapScore(item.id),
  );

  int _integrationPriority() =>
      _notStartedCount(triadMatrixItems.where((item) => hasKick(item.id)));

  int _phrasingPriority() {
    final int comboSessions = sessionCount(family: MaterialFamilyV1.combo);
    return comboSessions == 0 ? 10 : (4 - comboSessions).clamp(0, 4);
  }

  int _flowPriority() => _flowReadyItems().length;

  int _notStartedCount(Iterable<PracticeItemV1> items) {
    return items
        .where((item) => competencyFor(item.id) == CompetencyLevelV1.notStarted)
        .length;
  }

  Duration _timeForLead(String leadChar) {
    Duration total = Duration.zero;
    for (final PracticeItemV1 item in triadMatrixItems) {
      if (_firstNormalizedChar(item.id) == leadChar) {
        total += totalTime(itemId: item.id);
      }
    }
    return total;
  }

  int _dynamicGapScore(String itemId) {
    final PracticeItemV1 item = itemById(itemId);
    int score = 0;
    if (!item.hasAccents) score += 2;
    if (!item.hasGhostNotes) score += 2;
    if (totalTime(itemId: itemId) >= const Duration(minutes: 6)) score += 2;
    return score;
  }

  String _dynamicEvidenceFor(String itemId) {
    final PracticeItemV1 item = itemById(itemId);
    final List<String> parts = <String>[];
    parts.add(item.hasAccents ? 'accent-ready' : 'plain only');
    parts.add(item.hasGhostNotes ? 'ghosts present' : 'no ghost work');
    parts.add(formatDuration(totalTime(itemId: itemId)));
    return parts.join(' • ');
  }

  List<PracticeItemV1> _flowReadyItems() {
    final List<PracticeItemV1> items = <PracticeItemV1>[
      ...itemsByFamily(MaterialFamilyV1.combo),
      ...triadMatrixItems.where(
        (item) =>
            competencyFor(item.id).index >= CompetencyLevelV1.comfortable.index,
      ),
    ];
    final Map<String, PracticeItemV1> unique = <String, PracticeItemV1>{};
    for (final PracticeItemV1 item in items) {
      unique[item.id] = item;
    }
    final List<PracticeItemV1> deduped = unique.values.toList(growable: false)
      ..sort((a, b) {
        final int flowCompare = _flowSessionCount(
          a.id,
        ).compareTo(_flowSessionCount(b.id));
        if (flowCompare != 0) return flowCompare;
        return _compareByNeed(a, b);
      });
    return deduped;
  }

  int _flowSessionCount(String itemId) {
    int total = 0;
    for (final PracticeSessionLogV1 session in _sessions) {
      if (session.practiceMode == PracticeModeV1.flow &&
          _sessionContainsItem(session, itemId)) {
        total += 1;
      }
    }
    return total;
  }

  String _flowEvidenceFor(String itemId) {
    final int flowSessions = _flowSessionCount(itemId);
    if (flowSessions == 0) {
      return 'Stable on the surface, not yet applied in flow';
    }
    return '$flowSessions flow session${flowSessions == 1 ? '' : 's'} logged';
  }

  DateTime _lastPracticedAt(String itemId) {
    return lastSessionForItem(itemId)?.endedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _summaryForPrimaryLane(LearningLaneV1 lane) {
    return switch (lane) {
      LearningLaneV1.control =>
        'Keep the surface simple and tighten the pulse before adding more variables.',
      LearningLaneV1.balance =>
        '$weakHandLabel-hand lead is lagging. Today should rebalance the phrase work.',
      LearningLaneV1.dynamics =>
        'The next gain is in touch. Use stable material and shape it deliberately.',
      LearningLaneV1.integration =>
        'Kick-based material needs attention. Add it without letting the hands smear.',
      LearningLaneV1.phrasing =>
        'Single cells are not enough today. Extend them into phrases that have shape.',
      LearningLaneV1.flow =>
        'Some material is ready to leave the pad and behave like kit vocabulary.',
    };
  }

  void updateProfile(UserProfileV1 next) {
    _profile = next;
    _notifyChanged();
  }

  void completeOnboarding(UserProfileV1 profile) {
    _profile = profile;
    _onboardingComplete = true;
    _notifyChanged();
  }

  void clearAppData() {
    _initializeFirstLightState();
    _onboardingComplete = false;
    _notifyChanged(bumpResetVersion: true);
  }

  void updateCompetency(String itemId, CompetencyLevelV1 level) {
    _competencyByItemId[itemId] = CompetencyRecordV1(
      practiceItemId: itemId,
      level: level,
      updatedAt: DateTime.now(),
    );
    _notifyChanged();
  }

  void setNoteMarking({
    required String itemId,
    required int noteIndex,
    required PatternNoteMarkingV1 marking,
  }) {
    final PracticeItemV1 item = itemById(itemId);
    if (noteIndex < 0 || noteIndex >= item.noteCount) return;

    final Set<int> accents = item.accentedNoteIndices.toSet();
    final Set<int> ghosts = item.ghostNoteIndices.toSet();

    accents.remove(noteIndex);
    ghosts.remove(noteIndex);

    switch (marking) {
      case PatternNoteMarkingV1.normal:
        break;
      case PatternNoteMarkingV1.accent:
        if (_tokenAt(item, noteIndex) != 'K') {
          accents.add(noteIndex);
        }
        break;
      case PatternNoteMarkingV1.ghost:
        ghosts.add(noteIndex);
        break;
    }

    _items = _items
        .map((entry) {
          if (entry.id != itemId) return entry;
          return _sanitizedItem(
            entry.copyWith(
              accentedNoteIndices: accents.toList()..sort(),
              ghostNoteIndices: ghosts.toList()..sort(),
            ),
          );
        })
        .toList(growable: false);
    _notifyChanged();
  }

  void setNoteVoice({
    required String itemId,
    required int noteIndex,
    required DrumVoiceV1 voice,
  }) {
    final PracticeItemV1 item = itemById(itemId);
    if (noteIndex < 0 || noteIndex >= item.noteCount) return;

    final List<DrumVoiceV1> voices = List<DrumVoiceV1>.from(
      _sanitizedItem(item).voiceAssignments,
    );
    if (_tokenAt(item, noteIndex) == 'K') {
      voices[noteIndex] = DrumVoiceV1.kick;
    } else {
      voices[noteIndex] = voice == DrumVoiceV1.kick ? DrumVoiceV1.snare : voice;
    }

    _items = _items
        .map((entry) {
          if (entry.id != itemId) return entry;
          return _sanitizedItem(entry.copyWith(voiceAssignments: voices));
        })
        .toList(growable: false);
    _notifyChanged();
  }

  PracticeItemV1 createCustomPattern({
    required String sticking,
    List<String> tags = const <String>[],
  }) {
    final String trimmedSticking = sticking.trim();
    final String canonicalName = _canonicalPatternName(trimmedSticking);
    final String signature = _patternSignature(trimmedSticking);

    for (final PracticeItemV1 item in _items) {
      if (item.isCustom && _patternSignature(item.sticking) == signature) {
        return item;
      }
    }

    final PracticeItemV1 item = PracticeItemV1(
      id: 'custom_${signature.toLowerCase()}',
      family: MaterialFamilyV1.custom,
      name: canonicalName,
      sticking: canonicalName,
      noteCount: _estimateNoteCount(trimmedSticking),
      accentedNoteIndices: _defaultAccentIndicesForSticking(trimmedSticking),
      ghostNoteIndices: const <int>[],
      voiceAssignments: _defaultVoiceAssignmentsForSticking(trimmedSticking),
      source: PracticeItemSourceV1.userDefined,
      tags: tags.where((tag) => tag.trim().isNotEmpty).toList(growable: false),
      saved: true,
    );

    _items = <PracticeItemV1>[..._items, _sanitizedItem(item)];
    _notifyChanged();
    return item;
  }

  PracticeCombinationV1 createCombination({required List<String> itemIds}) {
    final String id = 'combo_${itemIds.join('_')}';
    final String comboName = comboDisplayName(itemIds);

    final PracticeCombinationV1? existing = combinationForItemIdsOrNull(
      itemIds,
    );
    if (existing != null) return existing;

    final PracticeCombinationV1 combo = PracticeCombinationV1(
      id: id,
      name: comboName,
      itemIds: List<String>.from(itemIds),
    );

    final int noteCount = itemIds.fold<int>(
      0,
      (sum, itemId) => sum + itemById(itemId).noteCount,
    );

    final List<int> accented = <int>[];
    final List<int> ghosted = <int>[];
    final List<DrumVoiceV1> voices = <DrumVoiceV1>[];
    int offset = 0;
    for (final String itemId in itemIds) {
      final PracticeItemV1 item = itemById(itemId);
      accented.addAll(item.accentedNoteIndices.map((index) => index + offset));
      ghosted.addAll(item.ghostNoteIndices.map((index) => index + offset));
      voices.addAll(_sanitizedItem(item).voiceAssignments);
      offset += item.noteCount;
    }

    final PracticeItemV1 comboItem = _sanitizedItem(
      PracticeItemV1(
        id: id,
        family: MaterialFamilyV1.combo,
        name: comboName,
        sticking: comboName,
        noteCount: noteCount,
        accentedNoteIndices: accented,
        ghostNoteIndices: ghosted,
        voiceAssignments: voices,
        source: PracticeItemSourceV1.userDefined,
        tags: <String>['combo'],
        saved: true,
      ),
    );

    _combinations = <PracticeCombinationV1>[combo, ..._combinations];
    _items = <PracticeItemV1>[..._items, comboItem];
    _notifyChanged();
    return combo;
  }

  void toggleRoutineItem(String itemId) {
    final bool alreadyInRoutine = isDirectRoutineEntry(itemId);
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
          RoutineEntryV1(practiceItemId: itemId, addedAt: DateTime.now()),
        ],
      );
    }
    _notifyChanged();
  }

  void addRoutineItems(Iterable<String> itemIds) {
    final Set<String> existingIds = _routine.entries
        .map((entry) => entry.practiceItemId)
        .toSet();
    final List<RoutineEntryV1> additions = itemIds
        .where((itemId) => itemByIdOrNull(itemId) != null)
        .where((itemId) => !existingIds.contains(itemId))
        .map(
          (itemId) =>
              RoutineEntryV1(practiceItemId: itemId, addedAt: DateTime.now()),
        )
        .toList(growable: false);
    if (additions.isEmpty) return;

    _routine = _routine.copyWith(
      entries: <RoutineEntryV1>[..._routine.entries, ...additions],
    );
    _notifyChanged();
  }

  void addRecommendedStartingTriadsToRoutine() {
    final Set<String> starterIds = recommendedStartingTriadItemIds.toSet();
    _items = _items
        .map(
          (PracticeItemV1 item) => starterIds.contains(item.id)
              ? item.copyWith(
                  accentedNoteIndices: const <int>[],
                  ghostNoteIndices: const <int>[],
                )
              : item,
        )
        .toList(growable: false);
    addRoutineItems(starterIds);
  }

  String competencyGuidanceFor(String itemId, CompetencyLevelV1 level) {
    final PracticeItemV1 item = itemById(itemId);
    return switch (level) {
      CompetencyLevelV1.notStarted =>
        'Start plain and slow. Keep the sound even before adding tempo, accents, or movement.',
      CompetencyLevelV1.learning =>
        'Stay with the pattern until the motion stops fighting you. Clean repetition matters more than speed here.',
      CompetencyLevelV1.comfortable =>
        'Now test the edges: raise the tempo a little, shape the dynamics, and check whether the phrase still feels relaxed.',
      CompetencyLevelV1.reliable =>
        item.isCombo
            ? 'This phrase is close to usable vocabulary. Review it, then try it in flow so the connections hold together around the kit.'
            : 'This pattern is close to dependable. Review it, then connect it to another idea so it becomes vocabulary, not just a cell.',
      CompetencyLevelV1.musical =>
        'Keep this in rotation. The goal now is musical use: fills, transitions, flow, and decisions made without overthinking.',
    };
  }

  PracticeSessionSetupV1 buildSessionForItem(
    String itemId, {
    PracticeModeV1 practiceMode = PracticeModeV1.singleSurface,
    String? routineId,
  }) {
    final PracticeItemV1 item = itemById(itemId);
    return PracticeSessionSetupV1(
      practiceItemIds: <String>[itemId],
      family: item.family,
      practiceMode: practiceMode,
      bpm: _profile.defaultBpm,
      timerPreset: _profile.defaultTimerPreset,
      clickEnabled: _profile.clickEnabledByDefault,
      routineId: routineId,
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
      practiceMode: setup.practiceMode,
      bpm: setup.bpm,
      clickEnabled: setup.clickEnabled,
      routineId: setup.routineId,
      reflection: reflection,
    );

    _sessions = <PracticeSessionLogV1>[session, ..._sessions];
    _notifyChanged();
    return session;
  }

  void updateSessionReflection(String sessionId, ReflectionRatingV1? rating) {
    _sessions = _sessions
        .map((session) {
          if (session.id != sessionId) return session;
          return session.copyWith(
            reflection: rating,
            clearReflection: rating == null,
          );
        })
        .toList(growable: false);
    _notifyChanged();
  }

  String recentSummaryForItem(String itemId) {
    final PracticeSessionLogV1? session = lastSessionForItem(itemId);
    if (session == null) return 'No sessions yet';
    return '${formatShortDate(session.endedAt)} · ${formatDuration(session.duration)}';
  }

  int _compareByNeed(PracticeItemV1 a, PracticeItemV1 b) {
    final int competencyCompare = _competencyScore(
      competencyFor(a.id),
    ).compareTo(_competencyScore(competencyFor(b.id)));
    if (competencyCompare != 0) return competencyCompare;

    final int timeCompare = totalTime(
      itemId: a.id,
    ).compareTo(totalTime(itemId: b.id));
    if (timeCompare != 0) return timeCompare;

    final DateTime aDate =
        lastSessionForItem(a.id)?.endedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final DateTime bDate =
        lastSessionForItem(b.id)?.endedAt ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return aDate.compareTo(bDate);
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

  bool _isWeakHandLead(PracticeItemV1 item) {
    final String weak = _profile.handedness == HandednessV1.right ? 'L' : 'R';
    return _firstHandChar(item.id) == weak;
  }

  String? _firstHandChar(String itemId) {
    final String normalized = _normalizedSticking(itemById(itemId));
    for (final String ch in normalized.split('')) {
      if (ch == 'R' || ch == 'L') return ch;
    }
    return null;
  }

  String? _firstNormalizedChar(String itemId) {
    final String normalized = _normalizedSticking(itemById(itemId));
    return normalized.isEmpty ? null : normalized[0];
  }

  String? _lastNormalizedChar(String itemId) {
    final String normalized = _normalizedSticking(itemById(itemId));
    return normalized.isEmpty ? null : normalized[normalized.length - 1];
  }

  String _normalizedSticking(PracticeItemV1 item) {
    return item.sticking.replaceAll(RegExp(r'[^RLK]'), '');
  }

  List<String> _normalizedTokensForItem(PracticeItemV1 item) {
    return _normalizedSticking(item).split('');
  }

  List<String> _normalizedTokensFromSticking(String sticking) {
    final String normalized = sticking.toUpperCase().replaceAll(
      RegExp(r'[^RLK]'),
      '',
    );
    return normalized.split('');
  }

  String? _tokenAt(PracticeItemV1 item, int index) {
    final List<String> tokens = _normalizedTokensForItem(item);
    if (index < 0 || index >= tokens.length) return null;
    return tokens[index];
  }

  PracticeItemV1 _sanitizedItem(PracticeItemV1 item) {
    final List<String> tokens = _normalizedTokensForItem(item);
    final List<int> accented =
        item.accentedNoteIndices
            .where(
              (index) =>
                  index >= 0 && index < tokens.length && tokens[index] != 'K',
            )
            .toSet()
            .toList()
          ..sort();
    final List<int> ghosted =
        item.ghostNoteIndices
            .where((index) => index >= 0 && index < tokens.length)
            .toSet()
            .toList()
          ..sort();
    final List<DrumVoiceV1> voices = List<DrumVoiceV1>.generate(tokens.length, (
      index,
    ) {
      final DrumVoiceV1 fallback = _defaultVoiceForToken(tokens[index]);
      if (index >= item.voiceAssignments.length) return fallback;
      final DrumVoiceV1 voice = item.voiceAssignments[index];
      if (tokens[index] == 'K') return DrumVoiceV1.kick;
      return voice == DrumVoiceV1.kick ? fallback : voice;
    });

    if (listEquals(accented, item.accentedNoteIndices) &&
        listEquals(ghosted, item.ghostNoteIndices) &&
        listEquals(voices, item.voiceAssignments)) {
      return item;
    }

    return item.copyWith(
      accentedNoteIndices: accented,
      ghostNoteIndices: ghosted,
      voiceAssignments: voices,
    );
  }

  String _patternSignature(String sticking) {
    return sticking.toUpperCase().replaceAll(RegExp(r'[^RLK]'), '');
  }

  String _canonicalPatternName(String sticking) {
    final String signature = _patternSignature(sticking);
    if (signature.isEmpty) return sticking.trim().toUpperCase();
    return signature.split('').join(' ');
  }

  int _estimateNoteCount(String sticking) {
    final List<String> tokens = sticking
        .split(RegExp(r'\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList(growable: false);
    return tokens.isEmpty ? sticking.length : tokens.length;
  }

  List<int> _defaultAccentIndicesForSticking(String sticking) {
    final List<String> tokens = _normalizedTokensFromSticking(sticking);
    if (tokens.isEmpty) return const <int>[];

    final List<int> handIndices = <int>[
      for (int index = 0; index < tokens.length; index++)
        if (tokens[index] != 'K') index,
    ];
    if (handIndices.isEmpty) return const <int>[];
    if (handIndices.length >= 3) {
      return <int>[handIndices.first, handIndices[2]];
    }
    return <int>[handIndices.first];
  }

  List<DrumVoiceV1> _defaultVoiceAssignmentsForSticking(String sticking) {
    return _normalizedTokensFromSticking(
      sticking,
    ).map(_defaultVoiceForToken).toList(growable: false);
  }

  DrumVoiceV1 _defaultVoiceForToken(String token) {
    return token == 'K' ? DrumVoiceV1.kick : DrumVoiceV1.snare;
  }

  String _triadItemId(String cellId) => 'triad_${cellId.toLowerCase()}';

  List<String> _tagsForTriadCell(TriadMatrixCell cell) {
    final List<String> tags = <String>['matrix'];
    if (cell.handsOnly) {
      tags.add('hands');
    } else {
      tags.add('kit');
    }
    if (cell.hasHandDouble) tags.add('double');
    if (cell.hasKickDouble) tags.add('kick-double');
    if (cell.id.startsWith('R')) tags.add('lead-right');
    if (cell.id.startsWith('L')) tags.add('lead-left');
    if (cell.id.startsWith('K')) tags.add('lead-kick');
    return tags;
  }

  List<int> _accentIndicesForTriadCell(TriadMatrixCell cell) {
    return _defaultAccentIndicesForSticking(cell.id);
  }

  void _initializeFirstLightState() {
    _profile = UserProfileV1.initial;
    _items = _basePracticeItems();
    _combinations = const <PracticeCombinationV1>[];
    _routine = const PracticeRoutineV1(
      id: 'main_routine',
      name: 'Working On',
      entries: <RoutineEntryV1>[],
    );
    _sessions = const <PracticeSessionLogV1>[];
    _assessmentResults = const <SessionAssessmentResultV1>[];
    _assessmentAggregateByItemId = <String, PracticeAssessmentAggregateV1>{};
    _competencyByItemId = <String, CompetencyRecordV1>{};
  }

  List<PracticeItemV1> _basePracticeItems() {
    final List<PracticeItemV1> triadItems = triadMatrixAll()
        .map(
          (cell) => PracticeItemV1(
            id: _triadItemId(cell.id),
            family: MaterialFamilyV1.triad,
            name: cell.id,
            sticking: cell.id,
            noteCount: 3,
            accentedNoteIndices: _accentIndicesForTriadCell(cell),
            ghostNoteIndices: const <int>[],
            voiceAssignments: _defaultVoiceAssignmentsForSticking(cell.id),
            source: PracticeItemSourceV1.builtIn,
            tags: _tagsForTriadCell(cell),
            saved: true,
          ),
        )
        .toList(growable: false);

    return <PracticeItemV1>[
      ...triadItems,
      const PracticeItemV1(
        id: 'five_rlrlk',
        family: MaterialFamilyV1.fiveNote,
        name: 'RLRLK',
        sticking: 'RLRLK',
        noteCount: 5,
        accentedNoteIndices: <int>[0],
        ghostNoteIndices: <int>[],
        voiceAssignments: <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.kick,
        ],
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['5s'],
        saved: true,
      ),
      const PracticeItemV1(
        id: 'five_rllrl',
        family: MaterialFamilyV1.fiveNote,
        name: 'RLLRL',
        sticking: 'RLLRL',
        noteCount: 5,
        accentedNoteIndices: <int>[0, 3],
        ghostNoteIndices: <int>[1],
        voiceAssignments: <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
        ],
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['5s'],
        saved: true,
      ),
    ];
  }
}
