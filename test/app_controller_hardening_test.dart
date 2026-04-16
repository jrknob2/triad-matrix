import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:traid_trainer/core/practice/practice_domain_v1.dart';
import 'package:traid_trainer/state/app_controller.dart';
import 'package:traid_trainer/state/persistence/app_state_store.dart';

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

    test(
      'matrix preview draft combinations can be discarded cleanly',
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
      },
    );

    test(
      'saving an authored built-in triad creates or reuses a distinct saved variant',
      () async {
        final FakeAppStateStore store = FakeAppStateStore();
        final AppController controller = await AppController.createForTesting(
          store,
        );
        final String baseItemId =
            controller.recommendedStartingTriadItemIds.first;
        final int initialSavedCount = controller.items
            .where((PracticeItemV1 item) => item.saved)
            .length;

        final String firstVariantId = controller.savePracticeItemEdits(
          itemId: baseItemId,
          accentedNoteIndices: const <int>[0],
          ghostNoteIndices: const <int>[],
          voiceAssignments: const <DrumVoiceV1>[],
          competency: CompetencyLevelV1.learning,
          saveToWorkingOn: true,
        );

        expect(firstVariantId, isNot(baseItemId));
        expect(
          controller.itemById(firstVariantId).source,
          PracticeItemSourceV1.userDefined,
        );
        expect(
          controller.itemById(firstVariantId).accentedNoteIndices,
          const <int>[0],
        );
        expect(controller.isDirectRoutineEntry(firstVariantId), isTrue);
        expect(controller.itemById(baseItemId).accentedNoteIndices, isEmpty);

        final String reusedVariantId = controller.savePracticeItemEdits(
          itemId: baseItemId,
          accentedNoteIndices: const <int>[0],
          ghostNoteIndices: const <int>[],
          voiceAssignments: const <DrumVoiceV1>[],
          competency: CompetencyLevelV1.learning,
          saveToWorkingOn: true,
        );

        expect(reusedVariantId, firstVariantId);
        expect(
          controller.items.where((PracticeItemV1 item) => item.saved).length,
          initialSavedCount + 1,
        );
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
