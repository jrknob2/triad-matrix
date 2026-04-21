import 'package:flutter_test/flutter_test.dart';
import 'package:traid_trainer/core/practice/practice_domain_v1.dart';

void main() {
  group('Phase 1 canonical pattern model', () {
    test('parses canonical tokens and preserves rest positions', () {
      final PatternSequenceV1 sequence = PatternSequenceV1.parse('RLL - _K');

      expect(sequence.symbols, <String>['R', 'L', 'L', '_', 'K']);
      expect(sequence.positionCount, 5);
      expect(sequence.canonicalText, 'RLL_K');
    });

    test(
      'legacy practice item inputs resolve to canonical sequence storage',
      () {
        final PracticeItemV1 item = PracticeItemV1(
          id: 'combo_demo',
          family: MaterialFamilyV1.combo,
          name: 'RLL-LRR',
          sticking: 'RLL-LRR',
          noteCount: 6,
          accentedNoteIndices: const <int>[],
          ghostNoteIndices: const <int>[],
          voiceAssignments: const <DrumVoiceV1>[],
          source: PracticeItemSourceV1.generated,
          tags: const <String>['combo'],
          saved: true,
        );

        expect(item.sequence.symbols, <String>['R', 'L', 'L', 'L', 'R', 'R']);
        expect(item.noteCount, 6);
        expect(item.sticking, 'RLLLRR');
        expect(item.groupingHint, PatternGroupingV1.none);
      },
    );

    test(
      'grouping hint is not inferred from family in the canonical item model',
      () {
        final PracticeItemV1 item = PracticeItemV1(
          id: 'family_meta_only',
          family: MaterialFamilyV1.fiveNote,
          name: 'RLRLK',
          sequence: PatternSequenceV1.parse('RLRLK'),
          accentedNoteIndices: const <int>[],
          ghostNoteIndices: const <int>[],
          voiceAssignments: const <DrumVoiceV1>[],
          source: PracticeItemSourceV1.userDefined,
          tags: const <String>[],
          saved: true,
        );

        expect(item.groupingHint, PatternGroupingV1.none);
      },
    );
  });
}
