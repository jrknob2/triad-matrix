import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_app_state_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const patterns = <String>[
    '[HH K]',
    '[S:LRLR]',
    '[S:^R]',
    '[S:(L)]',
    '[HH:RR S:LL]',
    '[HH K]  [S:LRLR] [S:^R] [S:(L)] [HH:RR S:LL]',
  ];

  for (final pattern in patterns) {
    test('metadata saves and snapshot reload preserve $pattern', () async {
      final store = FakeAppStateStore();
      var controller = await AppController.createForTesting(store);
      addTearDown(() => controller.dispose());
      final id = controller.createExerciseDraftFromNotation(pattern: pattern);
      final original = controller.itemById(id);
      final timing = PatternTimingV1.explicit(
        spans: [
          PatternTimingSpanV1(
            startIndex: 0,
            tokenCount: original.noteCount,
            beatCount: 2,
          ),
        ],
      );
      controller.savePracticeItemEdits(
        itemId: id,
        accentedNoteIndices: original.accentedNoteIndices,
        ghostNoteIndices: original.ghostNoteIndices,
        voiceAssignments: original.voiceAssignments,
        competency: CompetencyLevelV1.learning,
        pattern: pattern,
        sequence: original.sequence,
        timing: timing,
        saveAsPattern: true,
      );

      // Exercise independent metadata edits, both with an omitted sequence and
      // an explicitly supplied, equivalent compatibility projection.
      for (var edit = 0; edit < 3; edit++) {
        final current = controller.itemById(id);
        controller.savePracticeItemEdits(
          itemId: id,
          accentedNoteIndices: current.accentedNoteIndices,
          ghostNoteIndices: current.ghostNoteIndices,
          voiceAssignments: current.voiceAssignments,
          competency: CompetencyLevelV1.comfortable,
          name: edit == 0 ? 'Renamed exercise' : null,
          notes: edit == 1 ? 'Updated description' : null,
          tags: edit == 2 ? ['updated'] : null,
          sequence: edit == 2
              ? PatternSequenceV1(tokens: current.tokens)
              : null,
        );
        expect(controller.itemById(id).pattern, pattern);
        expect(controller.itemById(id).tokens, original.tokens);
        expect(controller.itemById(id).timing, timing);
      }
      controller.rememberLaunchPreferencesForItem(
        itemId: id,
        bpm: 123,
        timerPreset: TimerPresetV1.minutes20,
      );
      await controller.flushPersistence();
      expect(
        store.savedSnapshots.last.items.singleWhere((i) => i.id == id).pattern,
        pattern,
      );
      controller.dispose();
      controller = await AppController.createForTesting(
        FakeAppStateStore(initialSnapshot: store.savedSnapshots.last),
      );
      final restored = controller.itemById(id);
      expect(restored.pattern, pattern);
      expect(restored.name, 'Renamed exercise');
      expect(restored.notes, 'Updated description');
      expect(restored.tags, ['updated']);
      expect(restored.timing, timing);
      expect(restored.accentedNoteIndices, original.accentedNoteIndices);
      expect(restored.ghostNoteIndices, original.ghostNoteIndices);
      expect(restored.voiceAssignments, original.voiceAssignments);
      expect(controller.launchBpmForItem(id), 123);
      controller.savePracticeItemEdits(
        itemId: id,
        accentedNoteIndices: restored.accentedNoteIndices,
        ghostNoteIndices: restored.ghostNoteIndices,
        voiceAssignments: restored.voiceAssignments,
        competency: CompetencyLevelV1.reliable,
        notes: 'Saved after reload',
      );
      await controller.flushPersistence();
      expect(controller.itemById(id).pattern, pattern);
      expect(controller.itemById(id).timing, timing);
    });
  }

  test(
    'changed legacy sequence cannot implicitly replace rich notation',
    () async {
      final store = FakeAppStateStore();
      final controller = await AppController.createForTesting(store);
      addTearDown(controller.dispose);
      final id = controller.createExerciseDraftFromNotation(
        pattern: '[HH K] [S]',
      );
      final item = controller.itemById(id);
      expect(
        () => controller.savePracticeItemEdits(
          itemId: id,
          accentedNoteIndices: item.accentedNoteIndices,
          ghostNoteIndices: item.ghostNoteIndices,
          voiceAssignments: item.voiceAssignments,
          competency: CompetencyLevelV1.learning,
          sequence: PatternSequenceV1.parse('RLL'),
        ),
        throwsArgumentError,
      );
      expect(controller.itemById(id).pattern, item.pattern);
      expect(controller.itemById(id).tokens, item.tokens);
    },
  );

  test(
    'legacy sequence-only edits and subsequent metadata saves remain usable',
    () async {
      final store = FakeAppStateStore();
      final controller = await AppController.createForTesting(store);
      addTearDown(controller.dispose);
      final id = controller.createBlankDraftPracticeItem();
      for (final sequence in [PatternSequenceV1.parse('RLLLRR'), null]) {
        controller.savePracticeItemEdits(
          itemId: id,
          accentedNoteIndices: const [],
          ghostNoteIndices: const [],
          voiceAssignments: const [],
          competency: CompetencyLevelV1.learning,
          sequence: sequence,
          name: 'Legacy item',
          saveAsPattern: true,
        );
        expect(controller.itemById(id).pattern, 'RLLLRR');
        expect(controller.itemById(id).noteCount, 6);
      }
      await controller.flushPersistence();
      final restored = await AppController.createForTesting(
        FakeAppStateStore(initialSnapshot: store.savedSnapshots.last),
      );
      addTearDown(restored.dispose);
      expect(restored.itemById(id).pattern, 'RLLLRR');
      expect(
        restored.patternTokensFor(id),
        PatternSequenceV1.parse('RLLLRR').tokens,
      );
    },
  );
}
