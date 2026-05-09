import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/state/app_controller.dart';
import 'package:drumcabulary/state/persistence/app_state_store.dart';

import 'helpers/fake_app_state_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppController hardening', () {
    test('serializes persistence and saves the latest snapshot', () async {
      final Completer<void> firstSaveGate = Completer<void>();
      final FakeAppStateStore store = FakeAppStateStore(
        onSave: (AppStateSnapshotData snapshot) async {
          if (snapshot.routine.entries.isNotEmpty &&
              !firstSaveGate.isCompleted) {
            await firstSaveGate.future;
          }
        },
      );
      final AppController controller = await AppController.createForTesting(
        store,
      );
      final String itemId = controller.recommendedStartingTriadItemIds.first;

      controller.addRecommendedStartingTriadsToRoutine();
      await Future<void>.delayed(Duration.zero);
      controller.rememberLaunchPreferencesForItem(
        itemId: itemId,
        bpm: 144,
        timerPreset: TimerPresetV1.minutes20,
      );
      firstSaveGate.complete();
      await controller.flushPersistence();

      expect(store.saveCount, 2);
      expect(
        store.savedSnapshots.last.routine.entries.map(
          (entry) => entry.practiceItemId,
        ),
        containsAll(controller.recommendedStartingTriadItemIds),
      );
      expect(
        store.savedSnapshots.last.launchPreferences.any(
          (PracticeLaunchPreferenceV1 preference) =>
              preference.practiceItemId == itemId &&
              preference.bpm == 144 &&
              preference.timerPreset == TimerPresetV1.minutes20,
        ),
        isTrue,
      );
    });

    test('matrix preview ephemeral items can be discarded cleanly', () async {
      final FakeAppStateStore store = FakeAppStateStore();
      final AppController controller = await AppController.createForTesting(
        store,
      );
      final List<String> itemIds = controller.recommendedStartingTriadItemIds
          .take(2)
          .toList(growable: false);

      final PracticeSessionSetupV1 setup = controller.buildMatrixPreviewSession(
        itemIds,
        practiceMode: PracticeModeV1.flow,
      );

      expect(setup.ephemeralItemIds, hasLength(1));
      final String comboId = setup.ephemeralItemIds.single;
      expect(controller.itemById(comboId).saved, isFalse);

      controller.discardUnsavedPracticeItem(comboId);

      expect(controller.itemByIdOrNull(comboId), isNull);
      expect(
        controller.combinations.any(
          (PracticeCombinationV1 combo) => combo.id == comboId,
        ),
        isFalse,
      );
    });

    test('built-in seed catalog does not appear in authored library', () async {
      final FakeAppStateStore store = FakeAppStateStore();
      final AppController controller = await AppController.createForTesting(
        store,
      );

      expect(controller.items, isNotEmpty);
      expect(controller.libraryPatterns, isEmpty);

      final String itemId = controller.createBlankDraftPracticeItem();
      controller.savePracticeItemEdits(
        itemId: itemId,
        accentedNoteIndices: const <int>[],
        ghostNoteIndices: const <int>[],
        voiceAssignments: const <DrumVoiceV1>[
          DrumVoiceV1.snare,
          DrumVoiceV1.snare,
          DrumVoiceV1.kick,
        ],
        competency: CompetencyLevelV1.learning,
        sequence: PatternSequenceV1.parse('RLK'),
        pattern: 'RLK',
        saveAsPattern: true,
      );
      await controller.flushPersistence();

      expect(
        controller.libraryPatterns.map((PracticeItemV1 item) => item.id),
        <String>[itemId],
      );
      expect(
        store.savedSnapshots.last.items.every(
          (PracticeItemV1 item) => item.source != PracticeItemSourceV1.builtIn,
        ),
        isTrue,
      );
    });

    test(
      'removing a saved pattern hides it from library and working on',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );

        final String itemId = controller.createBlankDraftPracticeItem();
        controller.savePracticeItemEdits(
          itemId: itemId,
          accentedNoteIndices: const <int>[],
          ghostNoteIndices: const <int>[],
          voiceAssignments: const <DrumVoiceV1>[
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.kick,
          ],
          competency: CompetencyLevelV1.learning,
          sequence: PatternSequenceV1.parse('RLK'),
          pattern: 'RLK',
          saveAsPattern: true,
        );
        controller.toggleRoutineItem(itemId);

        expect(
          controller.libraryPatterns.map((item) => item.id),
          contains(itemId),
        );
        expect(controller.isDirectRoutineEntry(itemId), isTrue);

        controller.removeSavedPatternFromLibrary(itemId);

        expect(
          controller.libraryPatterns.map((PracticeItemV1 item) => item.id),
          isNot(contains(itemId)),
        );
        expect(controller.isDirectRoutineEntry(itemId), isFalse);
        expect(controller.itemById(itemId).saved, isFalse);
      },
    );

    test(
      'matrix preview emits a generic ephemeral phrase item instead of a combo runtime item',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final List<String> itemIds = controller.recommendedStartingTriadItemIds
            .take(2)
            .toList(growable: false);

        final PracticeSessionSetupV1 setup = controller
            .buildMatrixPreviewSession(
              itemIds,
              practiceMode: PracticeModeV1.flow,
            );

        expect(setup.ephemeralItemIds, hasLength(1));
        final String phraseItemId = setup.ephemeralItemIds.single;
        final PracticeItemV1 phraseItem = controller.itemById(phraseItemId);

        expect(phraseItem.isCombo, isFalse);
        expect(phraseItem.saved, isFalse);
        expect(phraseItem.groupingHint, PatternGroupingV1.triads);
        expect(
          controller.displayGroupingFor(phraseItemId),
          PatternGroupingV1.triads,
        );
        expect(
          controller
              .patternTokensFor(phraseItemId)
              .map((PatternTokenV1 token) => token.symbol),
          <String>['R', 'R', 'R', 'L', 'L', 'L'],
        );
        expect(
          controller.combinations.any(
            (PracticeCombinationV1 combo) => combo.id == phraseItemId,
          ),
          isFalse,
        );
      },
    );

    test('warmup items carry explicit grouping metadata', () async {
      final FakeAppStateStore store = FakeAppStateStore();
      final AppController controller = await AppController.createForTesting(
        store,
      );

      expect(
        controller.itemById('warmup_paradiddles').groupingHint,
        PatternGroupingV1.fourNote,
      );
      expect(
        controller.itemById('warmup_paradiddle_diddles').groupingHint,
        const PatternGroupingV1(groupSize: 6, separator: '-'),
      );
      expect(
        controller.displayGroupingFor('warmup_paradiddles'),
        PatternGroupingV1.fourNote,
      );
    });

    test(
      'base items include generic rest-bearing fixtures with explicit grouping',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );

        final PracticeItemV1 groupedRestItem = controller.itemById(
          'custom_rll_rest_lr',
        );
        final PracticeItemV1 simpleRestItem = controller.itemById(
          'custom_rl_rest_k',
        );

        expect(groupedRestItem.family, MaterialFamilyV1.custom);
        expect(groupedRestItem.source, PracticeItemSourceV1.builtIn);
        expect(groupedRestItem.groupingHint, PatternGroupingV1.triads);
        expect(
          controller
              .patternTokensFor(groupedRestItem.id)
              .map((PatternTokenV1 token) => token.symbol),
          <String>['R', 'L', 'L', '_', 'L', 'R'],
        );
        expect(groupedRestItem.tags, containsAll(<String>['custom', 'rest']));

        expect(simpleRestItem.family, MaterialFamilyV1.custom);
        expect(
          controller
              .patternTokensFor(simpleRestItem.id)
              .map((PatternTokenV1 token) => token.symbol),
          <String>['R', 'L', '_', 'K'],
        );
        expect(simpleRestItem.groupingHint, PatternGroupingV1.none);
      },
    );

    test(
      'saving an authored built-in triad mutates the same item and preserves its routine identity',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final String baseItemId =
            controller.recommendedStartingTriadItemIds.first;

        controller.toggleRoutineItem(baseItemId);

        final String savedItemId = controller.savePracticeItemEdits(
          itemId: baseItemId,
          accentedNoteIndices: const <int>[0, 2],
          ghostNoteIndices: const <int>[1],
          voiceAssignments: const <DrumVoiceV1>[],
          competency: CompetencyLevelV1.learning,
          saveToWorkingOn: true,
        );

        expect(savedItemId, baseItemId);
        expect(controller.itemById(baseItemId).accentedNoteIndices, const <int>[
          0,
          2,
        ]);
        expect(controller.itemById(baseItemId).ghostNoteIndices, const <int>[
          1,
        ]);
        expect(controller.isDirectRoutineEntry(baseItemId), isTrue);
        expect(
          controller.noteMarkingsFor(baseItemId),
          const <PatternNoteMarkingV1>[
            PatternNoteMarkingV1.accent,
            PatternNoteMarkingV1.ghost,
            PatternNoteMarkingV1.accent,
          ],
        );
      },
    );

    test(
      'saving sheet notation metadata persists grouping and note values',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final String itemId = controller.recommendedStartingTriadItemIds.first;

        controller.savePracticeItemEdits(
          itemId: itemId,
          accentedNoteIndices: const <int>[],
          ghostNoteIndices: const <int>[],
          voiceAssignments: const <DrumVoiceV1>[],
          competency: CompetencyLevelV1.learning,
          beatGrouping: '3 5 3 5',
          notationSubdivision: PatternNoteValueV1.eighth,
          noteValueOverrides: const <PatternNoteValueV1?>[
            null,
            PatternNoteValueV1.sixteenth,
            PatternNoteValueV1.thirtySecond,
          ],
        );

        final PracticeItemV1 item = controller.itemById(itemId);
        expect(item.beatGrouping, '3 5 3 5');
        expect(item.notationSubdivision, PatternNoteValueV1.eighth);
        expect(item.noteValueOverrides, const <PatternNoteValueV1?>[
          null,
          PatternNoteValueV1.sixteenth,
          PatternNoteValueV1.thirtySecond,
        ]);
      },
    );

    test(
      'explicit single-surface session mode is preserved for orchestrated items and history',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final String itemId = controller.recommendedStartingTriadItemIds.first;

        controller.savePracticeItemEdits(
          itemId: itemId,
          accentedNoteIndices: const <int>[],
          ghostNoteIndices: const <int>[],
          voiceAssignments: const <DrumVoiceV1>[
            DrumVoiceV1.hihat,
            DrumVoiceV1.snare,
            DrumVoiceV1.hihat,
          ],
          competency: CompetencyLevelV1.comfortable,
        );

        final PracticeSessionSetupV1 setup = controller.buildSessionForItem(
          itemId,
          practiceMode: PracticeModeV1.singleSurface,
          bpm: 92,
        );
        expect(setup.practiceMode, PracticeModeV1.singleSurface);

        final PracticeSessionLogV1 session = controller.completeSession(
          setup,
          const Duration(minutes: 2),
          practicedItemIds: <String>[itemId],
        );
        expect(session.practiceMode, PracticeModeV1.singleSurface);

        final PracticeSessionSetupV1? replaySetup = controller
            .buildSessionFromSessionOrNull(session);
        expect(replaySetup, isNotNull);
        expect(replaySetup!.practiceMode, PracticeModeV1.singleSurface);

        final CoachBlockV1? nextUnlock = controller.selectCoachNextUnlock();
        expect(nextUnlock, isNotNull);
        expect(nextUnlock!.ctaAction, CoachActionV1.moveToFlow);
        expect(nextUnlock.itemIds, <String>[itemId]);
      },
    );

    test(
      'matrix edit readout uses the authored phrase instead of child triad voices',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );

        controller.setMockScenario(AppMockScenarioV1.flowReady);

        const String comboId = 'combo_rll_lrr_rlr';
        final List<String> itemIds = controller.matrixSelectionItemIdsForItem(
          comboId,
        );

        final MatrixPhraseReadoutDataV1 genericReadout = controller
            .matrixPhraseReadoutForSelection(selectedItemIds: itemIds);
        final MatrixPhraseReadoutDataV1 editingReadout = controller
            .matrixPhraseReadoutForSelection(
              selectedItemIds: itemIds,
              editingItemId: comboId,
            );

        expect(genericReadout.showVoices, isTrue);
        expect(editingReadout.showVoices, isFalse);
        expect(
          editingReadout.voices,
          List<DrumVoiceV1>.filled(9, DrumVoiceV1.snare),
        );
        expect(editingReadout.tokens.join(), 'RLLLRRRLR');
      },
    );

    test(
      'flow ready mock includes mixed triad and generic rest-bearing work with authored state',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );

        controller.setMockScenario(AppMockScenarioV1.flowReady);

        const String restItemId = 'custom_rll_rest_lr';
        expect(controller.isDirectRoutineEntry(restItemId), isTrue);
        expect(
          controller.activeWorkItems.map((PracticeItemV1 item) => item.id),
          containsAll(<String>[
            'triad_rll',
            'four_rlrk',
            'five_rlrlk',
            restItemId,
          ]),
        );
        expect(
          controller.trackedItems.map((PracticeItemV1 item) => item.id),
          contains(restItemId),
        );
        expect(
          controller
              .patternTokensFor(restItemId)
              .map((PatternTokenV1 token) => token.symbol),
          <String>['R', 'L', 'L', '_', 'L', 'R'],
        );
        expect(
          controller.noteMarkingsFor(restItemId),
          const <PatternNoteMarkingV1>[
            PatternNoteMarkingV1.accent,
            PatternNoteMarkingV1.normal,
            PatternNoteMarkingV1.normal,
            PatternNoteMarkingV1.normal,
            PatternNoteMarkingV1.ghost,
            PatternNoteMarkingV1.normal,
          ],
        );
        expect(
          controller.displayGroupingFor(restItemId),
          PatternGroupingV1.triads,
        );
        expect(controller.hasNonSnareVoice(restItemId), isTrue);
        expect(controller.assessmentAggregateFor(restItemId), isNotNull);
      },
    );

    test('custom generic items can record manual assessments', () async {
      final FakeAppStateStore store = FakeAppStateStore();
      final AppController controller = await AppController.createForTesting(
        store,
      );
      const String itemId = 'custom_rll_rest_lr';

      final PracticeSessionSetupV1 setup = controller.buildSessionForItem(
        itemId,
      );
      final PracticeSessionLogV1 session = controller.completeSession(
        setup,
        const Duration(minutes: 2),
      );

      controller.updateSessionAssessment(
        sessionId: session.id,
        itemId: itemId,
        selfReportControl: SelfReportControlV1.medium,
        selfReportTension: SelfReportTensionV1.some,
        selfReportTempoReadiness: SelfReportTempoReadinessV1.same,
      );

      expect(
        controller.assessmentForSessionItem(session.id, itemId),
        isNotNull,
      );
      expect(controller.assessmentAggregateFor(itemId)?.assessmentCount, 1);
    });

    test(
      'saving a generic triad-sequence item preserves item identity and matrix handoff',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final String itemId = controller.recommendedStartingTriadItemIds.first;

        final String savedItemId = controller.savePracticeItemEdits(
          itemId: itemId,
          accentedNoteIndices: const <int>[0],
          ghostNoteIndices: const <int>[4],
          voiceAssignments: const <DrumVoiceV1>[
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
          ],
          competency: CompetencyLevelV1.learning,
          sequence: PatternSequenceV1.parse('RLL-LRR'),
        );

        expect(savedItemId, itemId);
        expect(controller.itemById(itemId).isCombo, isFalse);
        expect(controller.itemById(itemId).family, MaterialFamilyV1.custom);
        expect(
          controller
              .patternTokensFor(itemId)
              .map((PatternTokenV1 token) => token.symbol),
          <String>['R', 'L', 'L', 'L', 'R', 'R'],
        );
        expect(controller.matrixSelectionItemIdsForItem(itemId), <String>[
          'triad_rll',
          'triad_lrr',
        ]);
      },
    );

    test(
      'applying matrix selection updates the same authored item id without combo metadata',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final String itemId = controller.recommendedStartingTriadItemIds.first;

        controller.applyMatrixSelectionToItem(
          itemId: itemId,
          itemIds: const <String>['triad_rll', 'triad_lrr'],
        );

        expect(controller.itemById(itemId).isCombo, isFalse);
        expect(controller.itemById(itemId).family, MaterialFamilyV1.custom);
        expect(
          controller
              .patternTokensFor(itemId)
              .map((PatternTokenV1 token) => token.symbol),
          <String>['R', 'L', 'L', 'L', 'R', 'R'],
        );
        expect(controller.matrixSelectionItemIdsForItem(itemId), <String>[
          'triad_rll',
          'triad_lrr',
        ]);
        expect(
          controller.savedItemIdForTriadSelection(const <String>[
            'triad_rll',
            'triad_lrr',
          ]),
          itemId,
        );
        expect(
          controller.combinations.any(
            (PracticeCombinationV1 combo) => combo.id == itemId,
          ),
          isFalse,
        );
      },
    );

    test(
      'saving a structurally edited combo removes combo metadata and keeps the item',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final List<String> itemIds = controller.recommendedStartingTriadItemIds
            .take(2)
            .toList(growable: false);
        final PracticeCombinationV1 combo = controller
            .createDraftCombinationForEditing(itemIds: itemIds);

        controller.savePracticeItemEdits(
          itemId: combo.id,
          accentedNoteIndices: const <int>[0],
          ghostNoteIndices: const <int>[3],
          voiceAssignments: const <DrumVoiceV1>[
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
            DrumVoiceV1.snare,
          ],
          competency: CompetencyLevelV1.learning,
          sequence: PatternSequenceV1.parse('RLL-LRR_'),
        );

        expect(controller.itemById(combo.id).isCombo, isFalse);
        expect(controller.itemById(combo.id).family, MaterialFamilyV1.custom);
        expect(
          controller.combinations.any(
            (PracticeCombinationV1 entry) => entry.id == combo.id,
          ),
          isFalse,
        );
      },
    );

    test(
      'completeSession stores earned reps from active tracked time',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final List<String> itemIds = controller.recommendedStartingTriadItemIds
            .take(2)
            .toList(growable: false);
        final PracticeSessionSetupV1 setup = controller
            .buildSessionForItem(itemIds.first)
            .copyWith(practiceItemIds: itemIds);

        final PracticeSessionLogV1 session = controller.completeSession(
          setup,
          const Duration(minutes: 3),
          practicedItemIds: itemIds,
          activeDurationByItemId: <String, Duration>{
            itemIds.first: const Duration(minutes: 2, seconds: 30),
            itemIds.last: const Duration(seconds: 50),
          },
        );

        expect(session.earnedReps, 2);
        expect(session.claimedReps, 0);
        expect(
          controller.sessionItemRuntimeFor(session, itemIds.first)?.earnedReps,
          2,
        );
        expect(
          controller.sessionItemRuntimeFor(session, itemIds.last)?.earnedReps,
          0,
        );
      },
    );
  });
}
