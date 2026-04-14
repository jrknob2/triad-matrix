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
  });
}
