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
  AppMockScenarioV1? _activeMockScenario;
  _ControllerRuntimeSnapshot? _liveStateBeforeMock;

  UserProfileV1 get profile => _profile;
  List<PracticeItemV1> get items => List<PracticeItemV1>.unmodifiable(_items);
  List<PracticeCombinationV1> get combinations =>
      List<PracticeCombinationV1>.unmodifiable(_combinations);
  PracticeRoutineV1 get routine => _routine;
  List<SessionAssessmentResultV1> get assessmentResults =>
      List<SessionAssessmentResultV1>.unmodifiable(_assessmentResults);
  bool get onboardingComplete => _onboardingComplete;
  int get resetVersion => _resetVersion;
  AppMockScenarioV1? get activeMockScenario => _activeMockScenario;
  bool get isMockScenarioActive => _activeMockScenario != null;
  bool get hasLoggedPractice => _sessions.any(
    (PracticeSessionLogV1 session) => !_isWarmupSession(session),
  );
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
    _items = _itemsWithMissingBuiltIns(snapshot.items);
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

  List<PracticeItemV1> _itemsWithMissingBuiltIns(List<PracticeItemV1> items) {
    final List<PracticeItemV1> canonicalWarmups = _baseWarmupItems();
    final Set<String> canonicalWarmupIds = canonicalWarmups
        .map((PracticeItemV1 item) => item.id)
        .toSet();
    final List<PracticeItemV1> filteredItems = items
        .where(
          (PracticeItemV1 item) =>
              !(item.source == PracticeItemSourceV1.builtIn &&
                  item.isWarmup &&
                  !canonicalWarmupIds.contains(item.id)),
        )
        .where(
          (PracticeItemV1 item) =>
              !(item.source == PracticeItemSourceV1.builtIn && item.isWarmup),
        )
        .map(_migrateLegacyBuiltInAuthoring)
        .toList(growable: false);

    final Set<String> existingIds = filteredItems
        .map((PracticeItemV1 item) => item.id)
        .toSet();
    final List<PracticeItemV1> missingBuiltIns = _basePracticeItems()
        .where((PracticeItemV1 item) => !existingIds.contains(item.id))
        .toList(growable: false);
    if (missingBuiltIns.isEmpty) return filteredItems;
    return <PracticeItemV1>[...filteredItems, ...missingBuiltIns];
  }

  PracticeItemV1 _migrateLegacyBuiltInAuthoring(PracticeItemV1 item) {
    if (item.source != PracticeItemSourceV1.builtIn) {
      return _sanitizedItem(item);
    }

    final bool accentsMatchLegacy = listEquals(
      item.accentedNoteIndices,
      _legacyAccentIndicesFor(item),
    );
    final bool ghostsMatchLegacy = item.ghostNoteIndices.isEmpty;
    final bool voicesMatchLegacy = listEquals(
      item.voiceAssignments,
      _legacyVoiceAssignmentsFor(item),
    );

    final PracticeItemV1 migrated = item.copyWith(
      accentedNoteIndices: accentsMatchLegacy
          ? const <int>[]
          : item.accentedNoteIndices,
      ghostNoteIndices: ghostsMatchLegacy
          ? const <int>[]
          : item.ghostNoteIndices,
      voiceAssignments: voicesMatchLegacy
          ? const <DrumVoiceV1>[]
          : item.voiceAssignments,
    );

    return _sanitizedItem(migrated);
  }

  List<int> _legacyAccentIndicesFor(PracticeItemV1 item) {
    if (item.isTriad) {
      for (final TriadMatrixCell cell in triadMatrixAll()) {
        if (cell.id == item.name) return _accentIndicesForTriadCell(cell);
      }
    }

    return switch (item.id) {
      'five_rlrlk' => const <int>[0],
      'five_rllrl' => const <int>[0, 3],
      _ => const <int>[],
    };
  }

  List<DrumVoiceV1> _legacyVoiceAssignmentsFor(PracticeItemV1 item) {
    return switch (item.id) {
      'five_rlrlk' => const <DrumVoiceV1>[
        DrumVoiceV1.snare,
        DrumVoiceV1.snare,
        DrumVoiceV1.snare,
        DrumVoiceV1.snare,
        DrumVoiceV1.kick,
      ],
      'five_rllrl' => const <DrumVoiceV1>[
        DrumVoiceV1.snare,
        DrumVoiceV1.snare,
        DrumVoiceV1.snare,
        DrumVoiceV1.snare,
        DrumVoiceV1.snare,
      ],
      _ => _defaultVoiceAssignmentsForSticking(
        _patternSignature(item.sticking),
      ),
    };
  }

  Future<void> _persistState() async {
    if (isMockScenarioActive) return;
    final List<PracticeItemV1> persistedItems = _items
        .where((PracticeItemV1 item) => !item.isWarmup)
        .toList(growable: false);
    await _store.save(
      AppStateSnapshotData(
        schemaVersion: AppStateStore.currentSchemaVersion,
        onboardingComplete: _onboardingComplete,
        profile: _profile,
        items: persistedItems,
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

  PracticeSessionLogV1? get lastTrackedSession {
    for (final PracticeSessionLogV1 session in recentSessions) {
      if (!_isWarmupSession(session)) return session;
    }
    return null;
  }

  PracticeAssessmentAggregateV1? assessmentAggregateFor(String itemId) {
    return _assessmentAggregateByItemId[itemId];
  }

  List<SessionAssessmentResultV1> assessmentHistoryForItem(String itemId) {
    final List<SessionAssessmentResultV1> copy = _assessmentResults
        .where(
          (SessionAssessmentResultV1 result) => result.practiceItemId == itemId,
        )
        .toList(growable: false);
    copy.sort((a, b) => a.assessedAt.compareTo(b.assessedAt));
    return List<SessionAssessmentResultV1>.unmodifiable(copy);
  }

  List<PracticeSessionLogV1> sessionHistoryForItem(String itemId) {
    final List<PracticeSessionLogV1> copy = _sessions
        .where(
          (PracticeSessionLogV1 session) =>
              _sessionContainsItem(session, itemId),
        )
        .toList(growable: false);
    copy.sort((a, b) => a.endedAt.compareTo(b.endedAt));
    return List<PracticeSessionLogV1>.unmodifiable(copy);
  }

  MatrixProgressStateV1 statusForAssessmentResult(
    SessionAssessmentResultV1 result,
  ) {
    return _classifyAssessmentAggregate(
      assessmentCount: 1,
      stabilityScore: result.stabilityScore,
      driftScore: result.driftScore,
      jitterScore: result.jitterScore,
      continuityScore: result.continuityScore,
      confidence: result.confidence,
    );
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
    return _items
        .where((item) => !item.isCustom && !item.isWarmup)
        .toList(growable: false);
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

  CoachBriefingV1 buildCoachBriefing() {
    if (!hasLoggedPractice) {
      return CoachBriefingV1(
        blocks: activeWorkItems.isEmpty
            ? const <CoachBlockV1>[]
            : <CoachBlockV1>[selectCoachFocus()!],
      );
    }

    final CoachBlockV1? focus = selectCoachFocus();
    final CoachBlockV1? needsWork = selectCoachNeedsWork();
    final CoachBlockV1? momentum = selectCoachMomentum();
    final CoachBlockV1? nextUnlock = selectCoachNextUnlock();

    if (nextUnlock?.ctaAction == CoachActionV1.moveToFlow && momentum != null) {
      return CoachBriefingV1(blocks: <CoachBlockV1>[momentum, nextUnlock!]);
    }

    if (nextUnlock?.ctaAction == CoachActionV1.buildCombo && momentum != null) {
      return CoachBriefingV1(
        blocks: <CoachBlockV1>[if (focus != null) focus, momentum, nextUnlock!],
      );
    }

    final bool anyStrong = trackedItems.any(
      (PracticeItemV1 item) =>
          matrixProgressStateFor(item.id) == MatrixProgressStateV1.strong,
    );
    if (!anyStrong && needsWork != null) {
      return CoachBriefingV1(
        blocks: <CoachBlockV1>[if (focus != null) focus, needsWork],
      );
    }

    return CoachBriefingV1(
      blocks: <CoachBlockV1>[
        if (focus != null) focus,
        if (needsWork != null) needsWork,
        if (momentum != null) momentum,
      ].take(3).toList(growable: false),
    );
  }

  CoachBlockV1? selectCoachFocus() {
    if (!hasLoggedPractice && activeWorkItems.isNotEmpty) {
      final PracticeItemV1 target = activeWorkItems.first;
      return CoachBlockV1(
        id: 'focus_first_session',
        type: CoachBlockTypeV1.focus,
        title: 'Start here',
        subtitle: 'Focus',
        body:
            'You already picked the first material. Start with one clean, relaxed pass and let the sound settle in.',
        itemIds: <String>[target.id],
        ctaLabel: 'Start Practice',
        ctaAction: CoachActionV1.startPractice,
        matrixPalette: null,
        matrixFilters: const <TriadMatrixFilterV1>{},
        practiceMode: PracticeModeV1.singleSurface,
      );
    }

    if (activeWorkItems.isNotEmpty) {
      final List<PracticeItemV1> candidates = activeWorkItems.toList(
        growable: false,
      )..sort(_compareByAssessmentNeed);
      final PracticeItemV1 target = candidates.first;
      final PracticeAssessmentAggregateV1? aggregate = assessmentAggregateFor(
        target.id,
      );
      return CoachBlockV1(
        id: 'focus_working_on',
        type: CoachBlockTypeV1.focus,
        title: 'Stay with ${target.name}',
        subtitle: 'Focus',
        body: aggregate == null
            ? 'Stay with the same phrase long enough for it to feel familiar instead of forced.'
            : _focusBodyForAggregate(aggregate),
        itemIds: <String>[target.id],
        ctaLabel: 'Start Practice',
        ctaAction: CoachActionV1.startPractice,
        matrixPalette: null,
        matrixFilters: const <TriadMatrixFilterV1>{},
        practiceMode: PracticeModeV1.singleSurface,
      );
    }

    if (!hasLoggedPractice) return null;

    final PracticeItemV1 target = itemsNeedingPractice(
      MaterialFamilyV1.triad,
    ).first;
    return CoachBlockV1(
      id: 'focus_balanced_triads',
      type: CoachBlockTypeV1.focus,
      title: 'Bring ${target.name} into the day',
      subtitle: 'Focus',
      body: 'This is the clearest next triad to put under your hands today.',
      itemIds: <String>[target.id],
      ctaLabel: 'Start Practice',
      ctaAction: CoachActionV1.startPractice,
      matrixPalette: TriadMatrixFilterPaletteV1.coaching,
      matrixFilters: const <TriadMatrixFilterV1>{
        TriadMatrixFilterV1.underPracticed,
      },
      practiceMode: PracticeModeV1.singleSurface,
    );
  }

  CoachBlockV1? selectCoachNeedsWork() {
    final List<PracticeItemV1> candidates =
        trackedItems
            .where((PracticeItemV1 item) {
              final PracticeAssessmentAggregateV1? aggregate =
                  assessmentAggregateFor(item.id);
              return aggregate != null &&
                  aggregate.status == MatrixProgressStateV1.needsWork;
            })
            .toList(growable: false)
          ..sort(_compareByAssessmentNeed);

    if (candidates.isEmpty) return null;

    final PracticeItemV1 target = candidates.first;
    return CoachBlockV1(
      id: 'needs_work_${target.id}',
      type: CoachBlockTypeV1.needsWork,
      title: 'Clean up ${target.name}',
      subtitle: 'Needs Work',
      body: _needsWorkBodyForAggregate(assessmentAggregateFor(target.id)),
      itemIds: <String>[target.id],
      ctaLabel: 'Fix This',
      ctaAction: CoachActionV1.startPractice,
      matrixPalette: TriadMatrixFilterPaletteV1.coaching,
      matrixFilters: const <TriadMatrixFilterV1>{
        TriadMatrixFilterV1.needsAttention,
      },
      practiceMode: PracticeModeV1.singleSurface,
    );
  }

  CoachBlockV1? selectCoachMomentum() {
    final List<PracticeItemV1> candidates =
        trackedItems
            .where((PracticeItemV1 item) {
              final PracticeAssessmentAggregateV1? aggregate =
                  assessmentAggregateFor(item.id);
              return aggregate != null &&
                  aggregate.status == MatrixProgressStateV1.strong &&
                  isRecent(item.id);
            })
            .toList(growable: false)
          ..sort(
            (PracticeItemV1 a, PracticeItemV1 b) =>
                assessmentAggregateFor(b.id)!.stabilityScore.compareTo(
                  assessmentAggregateFor(a.id)!.stabilityScore,
                ),
          );

    if (candidates.isEmpty) return null;

    final PracticeItemV1 target = candidates.first;
    return CoachBlockV1(
      id: 'momentum_${target.id}',
      type: CoachBlockTypeV1.momentum,
      title: '${target.name} is starting to settle in',
      subtitle: 'Momentum',
      body: _momentumBodyForAggregate(assessmentAggregateFor(target.id)),
      itemIds: <String>[target.id],
      ctaLabel: target.isCombo ? 'Move to Flow' : 'Build Combo',
      ctaAction: target.isCombo
          ? CoachActionV1.moveToFlow
          : CoachActionV1.buildCombo,
      matrixPalette: TriadMatrixFilterPaletteV1.coaching,
      matrixFilters: const <TriadMatrixFilterV1>{TriadMatrixFilterV1.recent},
      practiceMode: target.isCombo
          ? PracticeModeV1.flow
          : PracticeModeV1.singleSurface,
    );
  }

  CoachBlockV1? selectCoachResume() {
    // A real Resume block needs persisted active/incomplete sessions. The app
    // only logs completed sessions right now, so returning null is intentional.
    return null;
  }

  CoachBlockV1? selectCoachNextUnlock() {
    final List<PracticeItemV1> flowCandidates = _flowReadyItems()
        .where((PracticeItemV1 item) => _flowSessionCount(item.id) == 0)
        .toList(growable: false);
    if (flowCandidates.isNotEmpty) {
      final PracticeItemV1 target = flowCandidates.first;
      return CoachBlockV1(
        id: 'unlock_flow_${target.id}',
        type: CoachBlockTypeV1.nextUnlock,
        title: 'Take ${target.name} around the kit',
        subtitle: 'Next Unlock',
        body:
            'This phrase is ready to leave one surface. Assign voices and make it speak clearly around the kit.',
        itemIds: <String>[target.id],
        ctaLabel: 'Move to Flow',
        ctaAction: CoachActionV1.moveToFlow,
        matrixPalette: TriadMatrixFilterPaletteV1.combos,
        matrixFilters: const <TriadMatrixFilterV1>{},
        practiceMode: PracticeModeV1.flow,
      );
    }

    final List<PracticeItemV1> stableTriads = triadMatrixItems
        .where(
          (PracticeItemV1 item) =>
              assessmentAggregateFor(item.id)?.status ==
              MatrixProgressStateV1.strong,
        )
        .toList(growable: false);
    if (stableTriads.length < 2) return null;

    stableTriads.sort(
      (PracticeItemV1 a, PracticeItemV1 b) =>
          totalTime(itemId: b.id).compareTo(totalTime(itemId: a.id)),
    );
    final List<String> itemIds = stableTriads
        .take(2)
        .map((PracticeItemV1 item) => item.id)
        .toList(growable: false);

    return CoachBlockV1(
      id: 'unlock_combo_${itemIds.join('_')}',
      type: CoachBlockTypeV1.nextUnlock,
      title: 'Build a phrase',
      subtitle: 'Next Unlock',
      body:
          'These cells are ready to be joined. Work the handoff until the whole phrase feels like one thought.',
      itemIds: itemIds,
      ctaLabel: 'Build Combo',
      ctaAction: CoachActionV1.buildCombo,
      matrixPalette: TriadMatrixFilterPaletteV1.combos,
      matrixFilters: const <TriadMatrixFilterV1>{},
      practiceMode: PracticeModeV1.singleSurface,
    );
  }

  String _focusBodyForAggregate(PracticeAssessmentAggregateV1 aggregate) {
    return switch (aggregate.status) {
      MatrixProgressStateV1.notTrained =>
        'You have not spent enough real time with this yet. Give it a clean first pass.',
      MatrixProgressStateV1.active =>
        'This is still taking shape. Stay with it until the motion and sound start to feel dependable.',
      MatrixProgressStateV1.needsWork =>
        'This is getting away from you a little. Slow it down and straighten it out before pushing.',
      MatrixProgressStateV1.strong =>
        'This is holding together. Give it a short review or use it to build something longer.',
    };
  }

  String _needsWorkBodyForAggregate(PracticeAssessmentAggregateV1? aggregate) {
    if (aggregate == null) {
      return 'There is some history here, but it is not settled yet. Keep the tempo controlled and clean it up before pushing.';
    }

    final List<String> reasons = <String>[];
    if (aggregate.stabilityScore < 0.50) reasons.add('stability');
    if (aggregate.jitterScore >= 0.40) reasons.add('evenness');
    if (aggregate.driftScore >= 0.45) reasons.add('tempo');
    if (aggregate.continuityScore < 0.55) reasons.add('continuity');

    final String reasonText = reasons.isEmpty
        ? 'the way it is feeling'
        : reasons.join(', ');
    return 'The weak spot right now is $reasonText. Slow it down enough to get it even again.';
  }

  String _momentumBodyForAggregate(PracticeAssessmentAggregateV1? aggregate) {
    if (aggregate == null) {
      return 'This is recent and starting to hold. Review it briefly, then use it to grow a longer phrase.';
    }

    final String stableBpm = aggregate.bestStableBpm == null
        ? 'the current tempo'
        : '${aggregate.bestStableBpm!.round()} BPM';
    return 'This is holding at $stableBpm. Review it briefly, then build from it while it still feels fresh.';
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
            evidence:
                'No sessions yet. Start on one surface and let the sound settle in first.',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.balance,
            title: 'Balance',
            reason:
                'Very early on, learn the phrase on both leads so the vocabulary does not become one-sided.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence:
                '$weakHandLabel lead still has no time on it. Start balancing that from day one.',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.dynamics,
            title: 'Dynamics',
            reason:
                'Add accents and ghosts after the base sticking feels steady. Do not force dynamic shape too early.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence: 'Keep the base version plain first, then add shape.',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.integration,
            title: 'Integration',
            reason:
                'Kick material comes after the hands are clear. Keep it in view, but do not start there.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence:
                '$totalKickTriadCount kick-based cells are waiting once the hands are clean.',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.phrasing,
            title: 'Phrasing',
            reason:
                'Phrase work matters, but it should rest on a few stable cells first.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence:
                'Build phrases after a few core cells start to feel natural.',
          ),
          TodayLaneRecommendationV1(
            lane: LearningLaneV1.flow,
            title: 'Flow',
            reason:
                'Flow is where phrases move across voices on the kit. It comes after the phrase feels stable on one surface.',
            actionLabel: 'Open Matrix',
            itemIds: const <String>[],
            evidence:
                'Voice work starts once the phrase is under your hands on one surface.',
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
            evidence: 'Single-surface first. Kit movement comes after that.',
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
      evidence: _statusAndTimeEvidence(target.id),
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
        .where(
          (item) =>
              item.family != MaterialFamilyV1.combo &&
              item.family != MaterialFamilyV1.warmup,
        )
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
        .where((item) => !item.isCustom && !item.isWarmup)
        .toList(growable: false);
    items.sort((a, b) => _compareByNeed(a, b));
    return items;
  }

  List<PracticeItemV1> get warmupItems {
    final List<String> orderedIds = _warmupItemIdsInOrder();
    return orderedIds
        .map(itemByIdOrNull)
        .whereType<PracticeItemV1>()
        .toList(growable: false);
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
        .where(
          (item) =>
              !item.isCustom && !item.isWarmup && isCloseToToolbox(item.id),
        )
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

  PatternGroupingV1 displayGroupingFor(String itemId) {
    final PracticeItemV1 item = itemById(itemId);
    if (!item.isWarmup) return PatternGroupingV1.spaced;
    if (item.tags.contains('paradiddle-diddle')) {
      return const PatternGroupingV1(groupSize: 6, separator: '-');
    }
    return PatternGroupingV1.fourNote;
  }

  String? warmupRudimentLabelFor(String itemId) {
    final PracticeItemV1 item = itemById(itemId);
    if (!item.isWarmup) return null;
    if (item.tags.contains('paradiddle-diddle')) {
      return 'Paradiddle-Diddle';
    }
    if (item.tags.contains('paradiddle')) {
      return 'Paradiddle';
    }
    if (item.tags.contains('doubles')) {
      return 'Doubles';
    }
    if (item.tags.contains('singles')) {
      return 'Singles';
    }
    return 'Rudiment';
  }

  String markedPatternTextFor(
    String itemId, {
    PatternGroupingV1 grouping = PatternGroupingV1.spaced,
  }) {
    final List<String> tokens = noteTokensFor(itemId);
    final List<PatternNoteMarkingV1> markings = noteMarkingsFor(itemId);
    return List<String>.generate(tokens.length, (index) {
      final String token = tokens[index];
      final String marked = switch (markings[index]) {
        PatternNoteMarkingV1.normal => token,
        PatternNoteMarkingV1.accent => '^$token',
        PatternNoteMarkingV1.ghost => '($token)',
      };
      return '$marked${grouping.separatorAfter(index, tokens.length)}';
    }).join();
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
    for (int index = 0; index < normalized.length - 1; index++) {
      if (normalized[index] == normalized[index + 1]) return true;
    }
    return false;
  }

  MatrixCellVisualStateV1 matrixCellVisualStateFor({
    required String itemId,
    required MatrixFiltersV1 filters,
    required MatrixSelectionStateV1 selection,
  }) {
    final bool inScope = _matrixCellIsInScope(itemId, filters);
    final int selectedCount = selection.countOf(itemId);
    return MatrixCellVisualStateV1(
      itemId: itemId,
      inScope: inScope,
      muted: !inScope,
      progress: matrixProgressStateFor(itemId),
      selected: selectedCount > 0,
      selectedCount: selectedCount,
    );
  }

  MatrixProgressStateV1 matrixProgressStateFor(String itemId) {
    final PracticeAssessmentAggregateV1? aggregate =
        _assessmentAggregateByItemId[itemId];
    if (aggregate != null && aggregate.assessmentCount > 0) {
      return aggregate.status;
    }

    if (isUnseen(itemId)) return MatrixProgressStateV1.notTrained;
    if (competencyFor(itemId).index >= CompetencyLevelV1.reliable.index ||
        isCloseToToolbox(itemId)) {
      return MatrixProgressStateV1.strong;
    }
    if (needsAttention(itemId)) return MatrixProgressStateV1.needsWork;
    return MatrixProgressStateV1.active;
  }

  bool _matrixCellIsInScope(String itemId, MatrixFiltersV1 filters) {
    if (filters.selectedRows.isNotEmpty) {
      final String rowLabel = itemById(itemId).name.substring(1);
      if (!filters.selectedRows.contains(rowLabel)) return false;
    }

    if (filters.selectedColumns.isNotEmpty) {
      final String columnLabel = itemById(itemId).name.substring(0, 1);
      if (!filters.selectedColumns.contains(columnLabel)) return false;
    }

    final Set<TriadMatrixFilterV1> activeFilters = filters.filters;

    if (activeFilters.contains(TriadMatrixFilterV1.handsOnly) &&
        !handsOnly(itemId)) {
      return false;
    }

    final bool leadSideFilterActive =
        activeFilters.contains(TriadMatrixFilterV1.rightLead) ||
        activeFilters.contains(TriadMatrixFilterV1.leftLead);
    if (leadSideFilterActive) {
      final bool matchesLeadSide =
          (activeFilters.contains(TriadMatrixFilterV1.rightLead) &&
              startsWithRight(itemId)) ||
          (activeFilters.contains(TriadMatrixFilterV1.leftLead) &&
              startsWithLeft(itemId));
      if (!matchesLeadSide) return false;
    }

    if (activeFilters.contains(TriadMatrixFilterV1.hasKick) &&
        !hasKick(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.startsWithKick) &&
        !startsWithKick(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.endsWithKick) &&
        !endsWithKick(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.inRoutine) &&
        !isInRoutine(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.inPhrases) &&
        !isInAnyPhrase(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.needsAttention) &&
        !needsAttention(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.underPracticed) &&
        !isUnderPracticed(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.closeToToolkit) &&
        !isCloseToToolbox(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.recent) &&
        !isRecent(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.unseen) &&
        !isUnseen(itemId)) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.notTrained) &&
        matrixProgressStateFor(itemId) != MatrixProgressStateV1.notTrained) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.activeStatus) &&
        matrixProgressStateFor(itemId) != MatrixProgressStateV1.active) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.needsWorkStatus) &&
        matrixProgressStateFor(itemId) != MatrixProgressStateV1.needsWork) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.strongStatus) &&
        matrixProgressStateFor(itemId) != MatrixProgressStateV1.strong) {
      return false;
    }
    if (activeFilters.contains(TriadMatrixFilterV1.doubles) &&
        !hasDoubles(itemId)) {
      return false;
    }

    return true;
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
    final PracticeAssessmentAggregateV1? aggregate = assessmentAggregateFor(
      itemId,
    );
    if (aggregate != null && aggregate.assessmentCount > 0) {
      return aggregate.status == MatrixProgressStateV1.strong;
    }

    final CompetencyLevelV1 level = competencyFor(itemId);
    final bool strongCompetency =
        level == CompetencyLevelV1.comfortable ||
        level == CompetencyLevelV1.reliable;
    return strongCompetency &&
        totalTime(itemId: itemId) >= const Duration(minutes: 10);
  }

  bool needsAttention(String itemId) {
    final PracticeAssessmentAggregateV1? aggregate = assessmentAggregateFor(
      itemId,
    );
    if (aggregate != null && aggregate.assessmentCount > 0) {
      return aggregate.status == MatrixProgressStateV1.needsWork;
    }
    if (isUnseen(itemId)) return false;

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

  bool isInAnyPhrase(String itemId) {
    return triadCombinations.any((combo) => combo.itemIds.contains(itemId));
  }

  bool isPhraseEligible(String itemId) {
    if (!itemById(itemId).isTriad) return false;
    return competencyFor(itemId).index >= CompetencyLevelV1.comfortable.index;
  }

  bool canAppendToPhrase({
    required List<String> currentItemIds,
    required String nextItemId,
  }) {
    if (currentItemIds.isEmpty) return true;
    if (!isPhraseEligible(nextItemId)) return false;
    return currentItemIds.every(isPhraseEligible);
  }

  bool _sessionContainsItem(PracticeSessionLogV1 session, String itemId) {
    for (final String sessionItemId in session.practiceItemIds) {
      if (sessionItemId == itemId) return true;
      if (_entryContainsItem(sessionItemId, itemId)) return true;
    }
    return false;
  }

  bool _isWarmupSession(PracticeSessionLogV1 session) {
    return session.family == MaterialFamilyV1.warmup ||
        session.practiceItemIds.every(
          (String itemId) => itemByIdOrNull(itemId)?.isWarmup ?? false,
        );
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
      evidence: _statusAndTimeEvidence(target.id),
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
          '${formatDuration(totalTime(itemId: target.id))} on kick-based work • ${matrixProgressStateFor(target.id).label}',
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
      actionLabel: 'Practice',
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
          : 'This phrase is getting close. One focused pass could move it into your toolbox.',
      actionLabel: target == null ? 'Open Matrix' : 'Practice',
      itemIds: target == null ? const <String>[] : <String>[target.id],
      evidence: target == null
          ? '${recentSessions.length} sessions logged so far'
          : _statusAndTimeEvidence(target.id),
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
          : 'Strong material still needs revisits so it stays available on demand.',
      actionLabel: target == null ? 'Open Matrix' : 'Practice',
      itemIds: target == null ? const <String>[] : <String>[target.id],
      evidence: target == null
          ? '${triadMatrixItems.length} triads available'
          : '${recentSummaryForItem(target.id)} • ${formatDuration(totalTime(itemId: target.id))} logged',
    );
  }

  String _statusAndTimeEvidence(String itemId) {
    return '${matrixProgressStateFor(itemId).label} • ${formatDuration(totalTime(itemId: itemId))} logged';
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
    if (isMockScenarioActive) {
      _liveStateBeforeMock = _buildFirstLightRuntimeSnapshot(
        onboardingComplete: false,
      );
      _applyRuntimeSnapshot(_buildMockScenarioSnapshot(_activeMockScenario!));
      _notifyChanged(bumpResetVersion: true);
      return;
    }
    _initializeFirstLightState();
    _onboardingComplete = false;
    _notifyChanged(bumpResetVersion: true);
  }

  void setMockScenario(AppMockScenarioV1? scenario) {
    if (!kDebugMode) return;
    if (scenario == null) {
      if (_liveStateBeforeMock != null) {
        _applyRuntimeSnapshot(_liveStateBeforeMock!);
      }
      _liveStateBeforeMock = null;
      _activeMockScenario = null;
      _notifyChanged(bumpResetVersion: true);
      return;
    }

    _liveStateBeforeMock ??= _captureRuntimeSnapshot();
    _applyRuntimeSnapshot(_buildMockScenarioSnapshot(scenario));
    _activeMockScenario = scenario;
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
      accentedNoteIndices: const <int>[],
      ghostNoteIndices: const <int>[],
      voiceAssignments: const <DrumVoiceV1>[],
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
      sourceName: '',
    );
  }

  PracticeSessionSetupV1 buildSessionForWorkingOn({
    PracticeModeV1 practiceMode = PracticeModeV1.singleSurface,
  }) {
    final List<String> itemIds = activeWorkItems
        .where(
          (PracticeItemV1 item) =>
              practiceMode == PracticeModeV1.singleSurface ||
              hasNonSnareVoice(item.id),
        )
        .map((PracticeItemV1 item) => item.id)
        .toList(growable: false);
    return PracticeSessionSetupV1(
      practiceItemIds: itemIds,
      family: itemIds.length == 1
          ? itemById(itemIds.first).family
          : MaterialFamilyV1.combo,
      practiceMode: practiceMode,
      bpm: _profile.defaultBpm,
      timerPreset: _profile.defaultTimerPreset,
      clickEnabled: _profile.clickEnabledByDefault,
      routineId: _routine.id,
      sourceName: 'Working On',
    );
  }

  PracticeSessionSetupV1 buildWarmupSession() {
    return PracticeSessionSetupV1(
      practiceItemIds: warmupItems
          .map((PracticeItemV1 item) => item.id)
          .toList(growable: false),
      family: MaterialFamilyV1.warmup,
      practiceMode: PracticeModeV1.singleSurface,
      bpm: _profile.defaultBpm,
      timerPreset: TimerPresetV1.none,
      clickEnabled: false,
      routineId: null,
      sourceName: 'Warmup',
    );
  }

  PracticeSessionSetupV1? buildSessionFromLastSessionOrNull() {
    final PracticeSessionLogV1? session = lastTrackedSession;
    if (session == null) return null;
    final List<String> itemIds = session.practiceItemIds
        .where((String itemId) => itemByIdOrNull(itemId) != null)
        .toList(growable: false);
    if (itemIds.isEmpty) return null;
    return PracticeSessionSetupV1(
      practiceItemIds: itemIds,
      family: itemIds.length == 1
          ? itemById(itemIds.first).family
          : MaterialFamilyV1.combo,
      practiceMode: session.practiceMode,
      bpm: session.bpm,
      timerPreset: _profile.defaultTimerPreset,
      clickEnabled: session.clickEnabled,
      routineId: session.routineId,
      sourceName: 'Repeat Last Session',
    );
  }

  PracticeSessionLogV1 completeSession(
    PracticeSessionSetupV1 setup,
    Duration duration, {
    String? assessmentItemId,
    ReflectionRatingV1? reflection,
    SelfReportControlV1? selfReportControl,
    SelfReportTensionV1? selfReportTension,
    SelfReportTempoReadinessV1? selfReportTempoReadiness,
  }) {
    final DateTime endedAt = DateTime.now();
    final PracticeSessionLogV1 session = PracticeSessionLogV1(
      id: 'session_${endedAt.microsecondsSinceEpoch}',
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      duration: duration,
      practiceItemIds: setup.practiceItemIds,
      assessmentItemId:
          assessmentItemId ??
          (setup.practiceItemIds.isEmpty ? null : setup.practiceItemIds.first),
      family: setup.family,
      practiceMode: setup.practiceMode,
      bpm: setup.bpm,
      clickEnabled: setup.clickEnabled,
      routineId: setup.routineId,
      reflection: reflection,
      sourceName: setup.sourceName,
    );

    _sessions = <PracticeSessionLogV1>[session, ..._sessions];
    if (!_isWarmupSession(session)) {
      _recordManualAssessment(
        session: session,
        selfReportControl: selfReportControl,
        selfReportTension: selfReportTension,
        selfReportTempoReadiness: selfReportTempoReadiness,
      );
    }
    _notifyChanged();
    return session;
  }

  void updateSessionAssessment({
    required String sessionId,
    required SelfReportControlV1? selfReportControl,
    required SelfReportTensionV1? selfReportTension,
    required SelfReportTempoReadinessV1? selfReportTempoReadiness,
  }) {
    final PracticeSessionLogV1? session = sessionById(sessionId);
    if (session == null) return;
    _assessmentResults = _assessmentResults
        .where(
          (SessionAssessmentResultV1 result) => result.sessionId != sessionId,
        )
        .toList(growable: false);
    if (_isWarmupSession(session)) {
      _notifyChanged();
      return;
    }
    _recordManualAssessment(
      session: session,
      selfReportControl: selfReportControl,
      selfReportTension: selfReportTension,
      selfReportTempoReadiness: selfReportTempoReadiness,
    );
    _notifyChanged();
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

  SessionAssessmentResultV1? assessmentForSession(String sessionId) {
    for (final SessionAssessmentResultV1 result in _assessmentResults) {
      if (result.sessionId == sessionId) return result;
    }
    return null;
  }

  void _recordManualAssessment({
    required PracticeSessionLogV1 session,
    required SelfReportControlV1? selfReportControl,
    required SelfReportTensionV1? selfReportTension,
    required SelfReportTempoReadinessV1? selfReportTempoReadiness,
  }) {
    final String? itemId =
        session.assessmentItemId ??
        (session.practiceItemIds.isEmpty
            ? null
            : session.practiceItemIds.first);
    if (itemId == null) return;
    final PracticeItemV1? item = itemByIdOrNull(itemId);
    if (item == null || item.isCustom || item.isWarmup) return;
    final SessionAssessmentResultV1 result = _manualAssessmentForItem(
      session: session,
      itemId: itemId,
      selfReportControl: selfReportControl,
      selfReportTension: selfReportTension,
      selfReportTempoReadiness: selfReportTempoReadiness,
    );
    _assessmentResults = <SessionAssessmentResultV1>[
      result,
      ..._assessmentResults.where(
        (SessionAssessmentResultV1 existing) =>
            existing.sessionId != result.sessionId ||
            existing.practiceItemId != result.practiceItemId,
      ),
    ];
    _assessmentAggregateByItemId[itemId] = _aggregateAssessmentForItem(itemId);
  }

  SessionAssessmentResultV1 _manualAssessmentForItem({
    required PracticeSessionLogV1 session,
    required String itemId,
    required SelfReportControlV1? selfReportControl,
    required SelfReportTensionV1? selfReportTension,
    required SelfReportTempoReadinessV1? selfReportTempoReadiness,
  }) {
    final double controlScore = switch (selfReportControl) {
      SelfReportControlV1.high => 0.88,
      SelfReportControlV1.medium => 0.64,
      SelfReportControlV1.low => 0.34,
      null => _controlScoreFromReflection(session.reflection),
    };
    final double tensionPenalty = switch (selfReportTension) {
      SelfReportTensionV1.none => 0.0,
      SelfReportTensionV1.some => 0.12,
      SelfReportTensionV1.high => 0.28,
      null => 0.08,
    };
    final double readinessAdjustment = switch (selfReportTempoReadiness) {
      SelfReportTempoReadinessV1.increase => 0.08,
      SelfReportTempoReadinessV1.same => 0.0,
      SelfReportTempoReadinessV1.decrease => -0.16,
      null => 0.0,
    };
    final double durationScore = (session.duration.inSeconds / 300)
        .clamp(0.0, 1.0)
        .toDouble();
    final double stability = (controlScore + readinessAdjustment)
        .clamp(0.0, 1.0)
        .toDouble();
    final double jitter = (1.0 - controlScore + tensionPenalty)
        .clamp(0.0, 1.0)
        .toDouble();
    final double drift = switch (selfReportTempoReadiness) {
      SelfReportTempoReadinessV1.decrease => 0.52,
      SelfReportTempoReadinessV1.same => 0.28,
      SelfReportTempoReadinessV1.increase => 0.18,
      null => 0.35,
    };
    final double continuity = ((controlScore * 0.75) + (durationScore * 0.25))
        .clamp(0.0, 1.0)
        .toDouble();
    final AssessmentConfidenceV1 confidence = _manualAssessmentConfidence(
      session: session,
      selfReportControl: selfReportControl,
      selfReportTension: selfReportTension,
      selfReportTempoReadiness: selfReportTempoReadiness,
    );

    return SessionAssessmentResultV1(
      sessionId: session.id,
      practiceItemId: itemId,
      practiceMode: session.practiceMode,
      inputType: AssessmentInputTypeV1.manual,
      confidence: confidence,
      attemptedBpm: session.bpm,
      estimatedBpm: session.bpm.toDouble(),
      stabilityScore: stability,
      driftScore: drift,
      jitterScore: jitter,
      continuityScore: continuity,
      breakdownCount: stability < 0.50 ? 1 : 0,
      successfulRunCount: stability >= 0.72 ? 1 : 0,
      completedTargetDuration: session.duration.inSeconds >= 60,
      selfReportControl: selfReportControl,
      selfReportTension: selfReportTension,
      selfReportTempoReadiness: selfReportTempoReadiness,
      assessedAt: session.endedAt,
    );
  }

  double _controlScoreFromReflection(ReflectionRatingV1? reflection) {
    return switch (reflection) {
      ReflectionRatingV1.easy => 0.78,
      ReflectionRatingV1.okay => 0.58,
      ReflectionRatingV1.hard => 0.34,
      null => 0.50,
    };
  }

  AssessmentConfidenceV1 _manualAssessmentConfidence({
    required PracticeSessionLogV1 session,
    required SelfReportControlV1? selfReportControl,
    required SelfReportTensionV1? selfReportTension,
    required SelfReportTempoReadinessV1? selfReportTempoReadiness,
  }) {
    final int answered = <Object?>[
      selfReportControl,
      selfReportTension,
      selfReportTempoReadiness,
    ].whereType<Object>().length;
    if (session.duration.inSeconds >= 180 && answered == 3) {
      return AssessmentConfidenceV1.high;
    }
    if (session.duration.inSeconds >= 60 && answered >= 1) {
      return AssessmentConfidenceV1.medium;
    }
    return AssessmentConfidenceV1.low;
  }

  PracticeAssessmentAggregateV1 _aggregateAssessmentForItem(String itemId) {
    final List<SessionAssessmentResultV1> results =
        _assessmentResults
            .where(
              (SessionAssessmentResultV1 result) =>
                  result.practiceItemId == itemId,
            )
            .toList(growable: false)
          ..sort(
            (SessionAssessmentResultV1 a, SessionAssessmentResultV1 b) =>
                b.assessedAt.compareTo(a.assessedAt),
          );
    if (results.isEmpty) {
      return PracticeAssessmentAggregateV1(
        practiceItemId: itemId,
        lastAssessmentAt: null,
        recentAttemptedBpm: null,
        recentStableBpm: null,
        bestStableBpm: null,
        stabilityScore: 0,
        driftScore: 1,
        jitterScore: 1,
        continuityScore: 0,
        confidence: AssessmentConfidenceV1.low,
        status: MatrixProgressStateV1.notTrained,
        assessmentCount: 0,
      );
    }

    final List<SessionAssessmentResultV1> recent = results
        .take(5)
        .toList(growable: false);
    final double stability = _mean(
      recent.map((SessionAssessmentResultV1 result) => result.stabilityScore),
    );
    final double drift = _mean(
      recent.map((SessionAssessmentResultV1 result) => result.driftScore),
    );
    final double jitter = _mean(
      recent.map((SessionAssessmentResultV1 result) => result.jitterScore),
    );
    final double continuity = _mean(
      recent.map((SessionAssessmentResultV1 result) => result.continuityScore),
    );
    final SessionAssessmentResultV1 latest = results.first;
    final List<double> stableBpms = results
        .where(
          (SessionAssessmentResultV1 result) => _isStrongAssessment(result),
        )
        .map(
          (SessionAssessmentResultV1 result) => result.attemptedBpm.toDouble(),
        )
        .toList(growable: false);

    return PracticeAssessmentAggregateV1(
      practiceItemId: itemId,
      lastAssessmentAt: latest.assessedAt,
      recentAttemptedBpm: latest.attemptedBpm,
      recentStableBpm: _isStrongAssessment(latest)
          ? latest.attemptedBpm.toDouble()
          : null,
      bestStableBpm: stableBpms.isEmpty
          ? null
          : stableBpms.reduce((double a, double b) => a > b ? a : b),
      stabilityScore: stability,
      driftScore: drift,
      jitterScore: jitter,
      continuityScore: continuity,
      confidence: _highestConfidence(recent),
      status: _classifyAssessmentAggregate(
        assessmentCount: results.length,
        stabilityScore: stability,
        driftScore: drift,
        jitterScore: jitter,
        continuityScore: continuity,
        confidence: _highestConfidence(recent),
      ),
      assessmentCount: results.length,
    );
  }

  MatrixProgressStateV1 _classifyAssessmentAggregate({
    required int assessmentCount,
    required double stabilityScore,
    required double driftScore,
    required double jitterScore,
    required double continuityScore,
    required AssessmentConfidenceV1 confidence,
  }) {
    if (assessmentCount == 0) return MatrixProgressStateV1.notTrained;
    if (stabilityScore >= 0.80 &&
        driftScore <= 0.40 &&
        jitterScore <= 0.25 &&
        continuityScore >= 0.80 &&
        confidence != AssessmentConfidenceV1.low) {
      return MatrixProgressStateV1.strong;
    }
    if (stabilityScore < 0.50 ||
        driftScore >= 0.45 ||
        jitterScore >= 0.40 ||
        continuityScore < 0.55) {
      return MatrixProgressStateV1.needsWork;
    }
    return MatrixProgressStateV1.active;
  }

  bool _isStrongAssessment(SessionAssessmentResultV1 result) {
    return result.stabilityScore >= 0.80 &&
        result.driftScore <= 0.40 &&
        result.jitterScore <= 0.25 &&
        result.continuityScore >= 0.80 &&
        result.confidence != AssessmentConfidenceV1.low;
  }

  AssessmentConfidenceV1 _highestConfidence(
    Iterable<SessionAssessmentResultV1> results,
  ) {
    AssessmentConfidenceV1 highest = AssessmentConfidenceV1.low;
    for (final SessionAssessmentResultV1 result in results) {
      if (result.confidence.index > highest.index) highest = result.confidence;
    }
    return highest;
  }

  double _mean(Iterable<double> values) {
    final List<double> list = values.toList(growable: false);
    if (list.isEmpty) return 0;
    return list.reduce((double a, double b) => a + b) / list.length;
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

  int _compareByAssessmentNeed(PracticeItemV1 a, PracticeItemV1 b) {
    final PracticeAssessmentAggregateV1? aAggregate = assessmentAggregateFor(
      a.id,
    );
    final PracticeAssessmentAggregateV1? bAggregate = assessmentAggregateFor(
      b.id,
    );
    final int statusCompare = _assessmentNeedRank(
      bAggregate?.status,
    ).compareTo(_assessmentNeedRank(aAggregate?.status));
    if (statusCompare != 0) return statusCompare;

    final double aStability = aAggregate?.stabilityScore ?? -1;
    final double bStability = bAggregate?.stabilityScore ?? -1;
    final int stabilityCompare = aStability.compareTo(bStability);
    if (stabilityCompare != 0) return stabilityCompare;

    return _compareByNeed(a, b);
  }

  int _assessmentNeedRank(MatrixProgressStateV1? status) {
    return switch (status) {
      MatrixProgressStateV1.needsWork => 4,
      MatrixProgressStateV1.active => 3,
      MatrixProgressStateV1.notTrained => 2,
      MatrixProgressStateV1.strong => 1,
      null => 0,
    };
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

  _ControllerRuntimeSnapshot _captureRuntimeSnapshot() {
    return _ControllerRuntimeSnapshot(
      profile: _profile,
      items: List<PracticeItemV1>.from(_items),
      combinations: List<PracticeCombinationV1>.from(_combinations),
      routine: _routine,
      sessions: List<PracticeSessionLogV1>.from(_sessions),
      assessmentResults: List<SessionAssessmentResultV1>.from(
        _assessmentResults,
      ),
      assessmentAggregateByItemId:
          Map<String, PracticeAssessmentAggregateV1>.from(
            _assessmentAggregateByItemId,
          ),
      competencyByItemId: Map<String, CompetencyRecordV1>.from(
        _competencyByItemId,
      ),
      onboardingComplete: _onboardingComplete,
    );
  }

  _ControllerRuntimeSnapshot _buildFirstLightRuntimeSnapshot({
    bool onboardingComplete = false,
  }) {
    return _ControllerRuntimeSnapshot(
      profile: UserProfileV1.initial,
      items: _basePracticeItems(),
      combinations: const <PracticeCombinationV1>[],
      routine: const PracticeRoutineV1(
        id: 'main_routine',
        name: 'Working On',
        entries: <RoutineEntryV1>[],
      ),
      sessions: const <PracticeSessionLogV1>[],
      assessmentResults: const <SessionAssessmentResultV1>[],
      assessmentAggregateByItemId:
          const <String, PracticeAssessmentAggregateV1>{},
      competencyByItemId: const <String, CompetencyRecordV1>{},
      onboardingComplete: onboardingComplete,
    );
  }

  void _applyRuntimeSnapshot(_ControllerRuntimeSnapshot snapshot) {
    _profile = snapshot.profile;
    _items = List<PracticeItemV1>.from(snapshot.items);
    _combinations = List<PracticeCombinationV1>.from(snapshot.combinations);
    _routine = snapshot.routine;
    _sessions = List<PracticeSessionLogV1>.from(snapshot.sessions);
    _assessmentResults = List<SessionAssessmentResultV1>.from(
      snapshot.assessmentResults,
    );
    _assessmentAggregateByItemId =
        Map<String, PracticeAssessmentAggregateV1>.from(
          snapshot.assessmentAggregateByItemId,
        );
    _competencyByItemId = Map<String, CompetencyRecordV1>.from(
      snapshot.competencyByItemId,
    );
    _onboardingComplete = snapshot.onboardingComplete;
  }

  _ControllerRuntimeSnapshot _buildMockScenarioSnapshot(
    AppMockScenarioV1 scenario,
  ) {
    return switch (scenario) {
      AppMockScenarioV1.firstLight => _buildFirstLightRuntimeSnapshot(
        onboardingComplete: true,
      ),
      AppMockScenarioV1.starterItemsSelected => _mockStarterItemsSelected(),
      AppMockScenarioV1.earlyStruggle => _mockEarlyStruggle(),
      AppMockScenarioV1.steadyProgress => _mockSteadyProgress(),
      AppMockScenarioV1.phraseReady => _mockPhraseReady(),
      AppMockScenarioV1.flowReady => _mockFlowReady(),
    };
  }

  _ControllerRuntimeSnapshot _mockStarterItemsSelected() {
    final _MockScenarioBuilder builder = _MockScenarioBuilder(
      this,
      onboardingComplete: true,
    )..addRoutineItems(recommendedStartingTriadItemIds);
    return builder.build();
  }

  _ControllerRuntimeSnapshot _mockEarlyStruggle() {
    final DateTime now = DateTime.now();
    final _MockScenarioBuilder builder =
        _MockScenarioBuilder(this, onboardingComplete: true)
          ..addRoutineItems(recommendedStartingTriadItemIds)
          ..setCompetency(_triadItemId('RRR'), CompetencyLevelV1.learning)
          ..setCompetency(_triadItemId('LLL'), CompetencyLevelV1.learning)
          ..setCompetency(_triadItemId('RLL'), CompetencyLevelV1.learning)
          ..addManualSession(
            itemId: _triadItemId('RRR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 72,
            duration: const Duration(minutes: 3),
            endedAt: now.subtract(const Duration(days: 14)),
            selfReportControl: SelfReportControlV1.low,
            selfReportTension: SelfReportTensionV1.high,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.decrease,
          )
          ..addManualSession(
            itemId: _triadItemId('RRR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 74,
            duration: const Duration(minutes: 4),
            endedAt: now.subtract(const Duration(days: 9)),
            selfReportControl: SelfReportControlV1.low,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.decrease,
          )
          ..addManualSession(
            itemId: _triadItemId('LLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 76,
            duration: const Duration(minutes: 4),
            endedAt: now.subtract(const Duration(days: 7)),
            selfReportControl: SelfReportControlV1.low,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('LLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 76,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 3, hours: 6)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 78,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 5)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 80,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(hours: 20)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          );
    return builder.build();
  }

  _ControllerRuntimeSnapshot _mockSteadyProgress() {
    final DateTime now = DateTime.now();
    final _MockScenarioBuilder builder =
        _MockScenarioBuilder(this, onboardingComplete: true)
          ..addRoutineItems(<String>[
            _triadItemId('RLL'),
            _triadItemId('LRR'),
            _triadItemId('RLR'),
            _triadItemId('KRL'),
          ])
          ..setCompetency(_triadItemId('RLL'), CompetencyLevelV1.comfortable)
          ..setCompetency(_triadItemId('LRR'), CompetencyLevelV1.learning)
          ..setCompetency(_triadItemId('RLR'), CompetencyLevelV1.comfortable)
          ..setCompetency(_triadItemId('KRL'), CompetencyLevelV1.learning)
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 78,
            duration: const Duration(minutes: 4),
            endedAt: now.subtract(const Duration(days: 27)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 84,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 20)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 88,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(days: 13)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 92,
            duration: const Duration(minutes: 7),
            endedAt: now.subtract(const Duration(days: 6)),
            selfReportControl: SelfReportControlV1.high,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 96,
            duration: const Duration(minutes: 8),
            endedAt: now.subtract(const Duration(days: 1)),
            selfReportControl: SelfReportControlV1.high,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
          )
          ..addManualSession(
            itemId: _triadItemId('LRR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 74,
            duration: const Duration(minutes: 4),
            endedAt: now.subtract(const Duration(days: 18)),
            selfReportControl: SelfReportControlV1.low,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.decrease,
          )
          ..addManualSession(
            itemId: _triadItemId('LRR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 82,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 8)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('LRR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 86,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(days: 2)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 82,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 15)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 86,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 9)),
            selfReportControl: SelfReportControlV1.low,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.decrease,
          )
          ..addManualSession(
            itemId: _triadItemId('RLR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 84,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(days: 4)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('KRL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 68,
            duration: const Duration(minutes: 4),
            endedAt: now.subtract(const Duration(days: 16)),
            selfReportControl: SelfReportControlV1.low,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.decrease,
          )
          ..addManualSession(
            itemId: _triadItemId('KRL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 72,
            duration: const Duration(minutes: 4),
            endedAt: now.subtract(const Duration(days: 10)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('KRL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 76,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 3)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          );
    return builder.build();
  }

  _ControllerRuntimeSnapshot _mockPhraseReady() {
    final DateTime now = DateTime.now();
    final _MockScenarioBuilder builder =
        _MockScenarioBuilder(this, onboardingComplete: true)
          ..addRoutineItems(<String>[
            _triadItemId('RLL'),
            _triadItemId('LRR'),
            _triadItemId('RLR'),
          ])
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 88,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 28)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 92,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(days: 21)),
            selfReportControl: SelfReportControlV1.high,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 96,
            duration: const Duration(minutes: 7),
            endedAt: now.subtract(const Duration(days: 14)),
            selfReportControl: SelfReportControlV1.high,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 102,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(days: 7)),
            selfReportControl: SelfReportControlV1.high,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
          )
          ..addManualSession(
            itemId: _triadItemId('RLL'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 106,
            duration: const Duration(minutes: 7),
            endedAt: now.subtract(const Duration(days: 1)),
            selfReportControl: SelfReportControlV1.high,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
          )
          ..addManualSession(
            itemId: _triadItemId('LRR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 86,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 24)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('LRR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 94,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(days: 12)),
            selfReportControl: SelfReportControlV1.high,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
          )
          ..addManualSession(
            itemId: _triadItemId('LRR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 98,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(days: 3)),
            selfReportControl: SelfReportControlV1.high,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
          )
          ..addManualSession(
            itemId: _triadItemId('RLR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 84,
            duration: const Duration(minutes: 5),
            endedAt: now.subtract(const Duration(days: 20)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.some,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..addManualSession(
            itemId: _triadItemId('RLR'),
            practiceMode: PracticeModeV1.singleSurface,
            bpm: 90,
            duration: const Duration(minutes: 6),
            endedAt: now.subtract(const Duration(days: 9)),
            selfReportControl: SelfReportControlV1.medium,
            selfReportTension: SelfReportTensionV1.none,
            selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
          )
          ..setCompetency(_triadItemId('RLL'), CompetencyLevelV1.comfortable)
          ..setCompetency(_triadItemId('LRR'), CompetencyLevelV1.comfortable)
          ..setCompetency(_triadItemId('RLR'), CompetencyLevelV1.comfortable);
    return builder.build();
  }

  _ControllerRuntimeSnapshot _mockFlowReady() {
    final DateTime now = DateTime.now();
    final _MockScenarioBuilder builder = _MockScenarioBuilder(
      this,
      onboardingComplete: true,
    );
    final PracticeCombinationV1 combo = builder.addSavedPhrase(
      id: 'combo_rll_lrr_rlr',
      name: 'RLL - LRR - RLR',
      itemIds: <String>[
        _triadItemId('RLL'),
        _triadItemId('LRR'),
        _triadItemId('RLR'),
      ],
    );
    builder
      ..addRoutineItems(<String>[combo.id, _triadItemId('KRL')])
      ..addManualSession(
        itemId: combo.id,
        practiceMode: PracticeModeV1.singleSurface,
        bpm: 82,
        duration: const Duration(minutes: 6),
        endedAt: now.subtract(const Duration(days: 28)),
        selfReportControl: SelfReportControlV1.medium,
        selfReportTension: SelfReportTensionV1.some,
        selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
      )
      ..addManualSession(
        itemId: combo.id,
        practiceMode: PracticeModeV1.singleSurface,
        bpm: 90,
        duration: const Duration(minutes: 8),
        endedAt: now.subtract(const Duration(days: 18)),
        selfReportControl: SelfReportControlV1.high,
        selfReportTension: SelfReportTensionV1.none,
        selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
      )
      ..addManualSession(
        itemId: combo.id,
        practiceMode: PracticeModeV1.singleSurface,
        bpm: 96,
        duration: const Duration(minutes: 7),
        endedAt: now.subtract(const Duration(days: 10)),
        selfReportControl: SelfReportControlV1.high,
        selfReportTension: SelfReportTensionV1.none,
        selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
      )
      ..addManualSession(
        itemId: combo.id,
        practiceMode: PracticeModeV1.flow,
        bpm: 92,
        duration: const Duration(minutes: 6),
        endedAt: now.subtract(const Duration(days: 4)),
        selfReportControl: SelfReportControlV1.medium,
        selfReportTension: SelfReportTensionV1.some,
        selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
      )
      ..addManualSession(
        itemId: combo.id,
        practiceMode: PracticeModeV1.flow,
        bpm: 98,
        duration: const Duration(minutes: 7),
        endedAt: now.subtract(const Duration(days: 1)),
        selfReportControl: SelfReportControlV1.high,
        selfReportTension: SelfReportTensionV1.none,
        selfReportTempoReadiness: SelfReportTempoReadinessV1.increase,
      )
      ..addManualSession(
        itemId: _triadItemId('KRL'),
        practiceMode: PracticeModeV1.singleSurface,
        bpm: 74,
        duration: const Duration(minutes: 4),
        endedAt: now.subtract(const Duration(days: 16)),
        selfReportControl: SelfReportControlV1.medium,
        selfReportTension: SelfReportTensionV1.some,
        selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
      )
      ..addManualSession(
        itemId: _triadItemId('KRL'),
        practiceMode: PracticeModeV1.singleSurface,
        bpm: 80,
        duration: const Duration(minutes: 5),
        endedAt: now.subtract(const Duration(days: 7)),
        selfReportControl: SelfReportControlV1.medium,
        selfReportTension: SelfReportTensionV1.none,
        selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
      )
      ..setCompetency(combo.id, CompetencyLevelV1.reliable)
      ..setCompetency(_triadItemId('KRL'), CompetencyLevelV1.comfortable);
    return builder.build();
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
            accentedNoteIndices: const <int>[],
            ghostNoteIndices: const <int>[],
            voiceAssignments: const <DrumVoiceV1>[],
            source: PracticeItemSourceV1.builtIn,
            tags: _tagsForTriadCell(cell),
            saved: true,
          ),
        )
        .toList(growable: false);

    return <PracticeItemV1>[
      ...triadItems,
      ..._baseWarmupItems(),
      const PracticeItemV1(
        id: 'five_rlrlk',
        family: MaterialFamilyV1.fiveNote,
        name: 'RLRLK',
        sticking: 'RLRLK',
        noteCount: 5,
        accentedNoteIndices: <int>[],
        ghostNoteIndices: <int>[],
        voiceAssignments: <DrumVoiceV1>[],
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
        accentedNoteIndices: <int>[],
        ghostNoteIndices: <int>[],
        voiceAssignments: <DrumVoiceV1>[],
        source: PracticeItemSourceV1.builtIn,
        tags: <String>['5s'],
        saved: true,
      ),
    ];
  }

  List<PracticeItemV1> _baseWarmupItems() {
    return <PracticeItemV1>[
      _warmupItem(
        id: 'warmup_right_hand_singles',
        name: 'Right-Hand Singles',
        sticking: 'RRRRRRRRRRRRRRRR',
        tags: const <String>['warmup', 'rudiment', 'singles', 'right-hand'],
      ),
      _warmupItem(
        id: 'warmup_left_hand_singles',
        name: 'Left-Hand Singles',
        sticking: 'LLLLLLLLLLLLLLLL',
        tags: const <String>['warmup', 'rudiment', 'singles', 'left-hand'],
      ),
      _warmupItem(
        id: 'warmup_singles',
        name: 'Singles',
        sticking: 'RLRLRLRLRLRLRLRL',
        tags: const <String>['warmup', 'rudiment', 'singles'],
      ),
      _warmupItem(
        id: 'warmup_doubles',
        name: 'Doubles',
        sticking: 'RRLLRRLLRRLLRRLL',
        tags: const <String>['warmup', 'rudiment', 'doubles'],
      ),
      _warmupItem(
        id: 'warmup_paradiddles',
        name: 'Paradiddles',
        sticking: 'RLRRLRLLRLRRLRLL',
        tags: const <String>['warmup', 'rudiment', 'paradiddle'],
      ),
      _warmupItem(
        id: 'warmup_paradiddle_diddles',
        name: 'Right Paradiddle-Diddle',
        sticking: 'RLRRLLRLRRLLRLRRLLRLRRLL',
        tags: const <String>[
          'warmup',
          'rudiment',
          'paradiddle-diddle',
          'right',
        ],
      ),
      _warmupItem(
        id: 'warmup_left_paradiddle_diddles',
        name: 'Left Paradiddle-Diddle',
        sticking: 'LRLLRRLRLLRRLRLLRRLRLLRR',
        tags: const <String>['warmup', 'rudiment', 'paradiddle-diddle', 'left'],
      ),
    ];
  }

  List<String> _warmupItemIdsInOrder() {
    return const <String>[
      'warmup_right_hand_singles',
      'warmup_left_hand_singles',
      'warmup_singles',
      'warmup_doubles',
      'warmup_paradiddles',
      'warmup_paradiddle_diddles',
      'warmup_left_paradiddle_diddles',
    ];
  }

  PracticeItemV1 _warmupItem({
    required String id,
    required String name,
    required String sticking,
    required List<String> tags,
  }) {
    return PracticeItemV1(
      id: id,
      family: MaterialFamilyV1.warmup,
      name: name,
      sticking: sticking,
      noteCount: _normalizedTokensFromSticking(sticking).length,
      accentedNoteIndices: const <int>[],
      ghostNoteIndices: const <int>[],
      voiceAssignments: const <DrumVoiceV1>[],
      source: PracticeItemSourceV1.builtIn,
      tags: tags,
      saved: true,
    );
  }
}

class _ControllerRuntimeSnapshot {
  final UserProfileV1 profile;
  final List<PracticeItemV1> items;
  final List<PracticeCombinationV1> combinations;
  final PracticeRoutineV1 routine;
  final List<PracticeSessionLogV1> sessions;
  final List<SessionAssessmentResultV1> assessmentResults;
  final Map<String, PracticeAssessmentAggregateV1> assessmentAggregateByItemId;
  final Map<String, CompetencyRecordV1> competencyByItemId;
  final bool onboardingComplete;

  const _ControllerRuntimeSnapshot({
    required this.profile,
    required this.items,
    required this.combinations,
    required this.routine,
    required this.sessions,
    required this.assessmentResults,
    required this.assessmentAggregateByItemId,
    required this.competencyByItemId,
    required this.onboardingComplete,
  });
}

class _MockScenarioBuilder {
  _MockScenarioBuilder(this.controller, {required this.onboardingComplete})
    : profile = UserProfileV1.initial,
      items = List<PracticeItemV1>.from(controller._basePracticeItems()),
      combinations = <PracticeCombinationV1>[],
      routine = const PracticeRoutineV1(
        id: 'main_routine',
        name: 'Working On',
        entries: <RoutineEntryV1>[],
      ),
      sessions = <PracticeSessionLogV1>[],
      assessmentResults = <SessionAssessmentResultV1>[],
      assessmentAggregateByItemId = <String, PracticeAssessmentAggregateV1>{},
      competencyByItemId = <String, CompetencyRecordV1>{};

  final AppController controller;
  final UserProfileV1 profile;
  List<PracticeItemV1> items;
  List<PracticeCombinationV1> combinations;
  PracticeRoutineV1 routine;
  final List<PracticeSessionLogV1> sessions;
  final List<SessionAssessmentResultV1> assessmentResults;
  final Map<String, PracticeAssessmentAggregateV1> assessmentAggregateByItemId;
  final Map<String, CompetencyRecordV1> competencyByItemId;
  final bool onboardingComplete;

  void addRoutineItems(List<String> itemIds) {
    final Set<String> existing = routine.entries
        .map((RoutineEntryV1 entry) => entry.practiceItemId)
        .toSet();
    final DateTime now = DateTime.now();
    final List<RoutineEntryV1> nextEntries = <RoutineEntryV1>[
      ...routine.entries,
      ...itemIds
          .where(existing.add)
          .map(
            (String itemId) =>
                RoutineEntryV1(practiceItemId: itemId, addedAt: now),
          ),
    ];
    routine = routine.copyWith(entries: nextEntries);
  }

  void setCompetency(String itemId, CompetencyLevelV1 level) {
    competencyByItemId[itemId] = CompetencyRecordV1(
      practiceItemId: itemId,
      level: level,
      updatedAt: DateTime.now(),
    );
  }

  PracticeCombinationV1 addSavedPhrase({
    required String id,
    required String name,
    required List<String> itemIds,
  }) {
    final PracticeCombinationV1 combo = PracticeCombinationV1(
      id: id,
      name: name,
      itemIds: itemIds,
    );
    combinations = <PracticeCombinationV1>[...combinations, combo];
    items = <PracticeItemV1>[
      ...items,
      _comboItem(id: id, name: name, itemIds: itemIds),
    ];
    return combo;
  }

  void addManualSession({
    required String itemId,
    required PracticeModeV1 practiceMode,
    required int bpm,
    required Duration duration,
    required DateTime endedAt,
    required SelfReportControlV1 selfReportControl,
    required SelfReportTensionV1 selfReportTension,
    required SelfReportTempoReadinessV1 selfReportTempoReadiness,
  }) {
    final PracticeItemV1 item = items.firstWhere(
      (PracticeItemV1 entry) => entry.id == itemId,
    );
    final PracticeSessionLogV1 session = PracticeSessionLogV1(
      id: 'mock_session_${sessions.length + 1}_${itemId.replaceAll('-', '_')}',
      startedAt: endedAt.subtract(duration),
      endedAt: endedAt,
      duration: duration,
      practiceItemIds: <String>[itemId],
      assessmentItemId: itemId,
      family: item.family,
      practiceMode: practiceMode,
      bpm: bpm,
      clickEnabled: true,
      routineId:
          routine.entries.any(
            (RoutineEntryV1 entry) => entry.practiceItemId == itemId,
          )
          ? routine.id
          : null,
      reflection: null,
      sourceName:
          routine.entries.any(
            (RoutineEntryV1 entry) => entry.practiceItemId == itemId,
          )
          ? 'Working On'
          : 'Mock',
    );
    sessions.add(session);

    final SessionAssessmentResultV1 result = controller
        ._manualAssessmentForItem(
          session: session,
          itemId: itemId,
          selfReportControl: selfReportControl,
          selfReportTension: selfReportTension,
          selfReportTempoReadiness: selfReportTempoReadiness,
        );
    assessmentResults.add(result);
    assessmentAggregateByItemId[itemId] = _aggregateForItem(itemId);
  }

  PracticeItemV1 _comboItem({
    required String id,
    required String name,
    required List<String> itemIds,
  }) {
    final List<PracticeItemV1> comboItems = itemIds
        .map(
          (String itemId) =>
              items.firstWhere((PracticeItemV1 item) => item.id == itemId),
        )
        .toList(growable: false);
    int offset = 0;
    final List<int> accents = <int>[];
    final List<int> ghosts = <int>[];
    final List<DrumVoiceV1> voices = <DrumVoiceV1>[];
    for (final PracticeItemV1 item in comboItems) {
      accents.addAll(
        item.accentedNoteIndices.map((int index) => index + offset),
      );
      ghosts.addAll(item.ghostNoteIndices.map((int index) => index + offset));
      voices.addAll(item.voiceAssignments);
      offset += item.noteCount;
    }
    return controller._sanitizedItem(
      PracticeItemV1(
        id: id,
        family: MaterialFamilyV1.combo,
        name: name,
        sticking: name,
        noteCount: comboItems.fold<int>(
          0,
          (int sum, PracticeItemV1 item) => sum + item.noteCount,
        ),
        accentedNoteIndices: accents,
        ghostNoteIndices: ghosts,
        voiceAssignments: voices,
        source: PracticeItemSourceV1.userDefined,
        tags: const <String>['combo'],
        saved: true,
      ),
    );
  }

  PracticeAssessmentAggregateV1 _aggregateForItem(String itemId) {
    final List<SessionAssessmentResultV1> results =
        assessmentResults
            .where(
              (SessionAssessmentResultV1 result) =>
                  result.practiceItemId == itemId,
            )
            .toList(growable: false)
          ..sort(
            (SessionAssessmentResultV1 a, SessionAssessmentResultV1 b) =>
                b.assessedAt.compareTo(a.assessedAt),
          );
    if (results.isEmpty) {
      return PracticeAssessmentAggregateV1(
        practiceItemId: itemId,
        lastAssessmentAt: null,
        recentAttemptedBpm: null,
        recentStableBpm: null,
        bestStableBpm: null,
        stabilityScore: 0,
        driftScore: 1,
        jitterScore: 1,
        continuityScore: 0,
        confidence: AssessmentConfidenceV1.low,
        status: MatrixProgressStateV1.notTrained,
        assessmentCount: 0,
      );
    }
    final List<SessionAssessmentResultV1> recent = results
        .take(5)
        .toList(growable: false);
    final List<double> stableBpms = results
        .where(controller._isStrongAssessment)
        .map(
          (SessionAssessmentResultV1 result) => result.attemptedBpm.toDouble(),
        )
        .toList(growable: false);
    final SessionAssessmentResultV1 latest = results.first;
    final double stability = controller._mean(
      recent.map((SessionAssessmentResultV1 result) => result.stabilityScore),
    );
    final double drift = controller._mean(
      recent.map((SessionAssessmentResultV1 result) => result.driftScore),
    );
    final double jitter = controller._mean(
      recent.map((SessionAssessmentResultV1 result) => result.jitterScore),
    );
    final double continuity = controller._mean(
      recent.map((SessionAssessmentResultV1 result) => result.continuityScore),
    );
    final AssessmentConfidenceV1 confidence = controller._highestConfidence(
      recent,
    );
    return PracticeAssessmentAggregateV1(
      practiceItemId: itemId,
      lastAssessmentAt: latest.assessedAt,
      recentAttemptedBpm: latest.attemptedBpm,
      recentStableBpm: controller._isStrongAssessment(latest)
          ? latest.attemptedBpm.toDouble()
          : null,
      bestStableBpm: stableBpms.isEmpty
          ? null
          : stableBpms.reduce((double a, double b) => a > b ? a : b),
      stabilityScore: stability,
      driftScore: drift,
      jitterScore: jitter,
      continuityScore: continuity,
      confidence: confidence,
      status: controller._classifyAssessmentAggregate(
        assessmentCount: results.length,
        stabilityScore: stability,
        driftScore: drift,
        jitterScore: jitter,
        continuityScore: continuity,
        confidence: confidence,
      ),
      assessmentCount: results.length,
    );
  }

  _ControllerRuntimeSnapshot build() {
    return _ControllerRuntimeSnapshot(
      profile: profile,
      items: items,
      combinations: combinations,
      routine: routine,
      sessions: List<PracticeSessionLogV1>.from(sessions)
        ..sort(
          (PracticeSessionLogV1 a, PracticeSessionLogV1 b) =>
              b.endedAt.compareTo(a.endedAt),
        ),
      assessmentResults: List<SessionAssessmentResultV1>.from(assessmentResults)
        ..sort(
          (SessionAssessmentResultV1 a, SessionAssessmentResultV1 b) =>
              b.assessedAt.compareTo(a.assessedAt),
        ),
      assessmentAggregateByItemId:
          Map<String, PracticeAssessmentAggregateV1>.from(
            assessmentAggregateByItemId,
          ),
      competencyByItemId: Map<String, CompetencyRecordV1>.from(
        competencyByItemId,
      ),
      onboardingComplete: onboardingComplete,
    );
  }
}
