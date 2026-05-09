import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/features/app/app_formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pattern text formatting', () {
    PracticeItemV1 itemWithGrouping(String beatGrouping) {
      return PracticeItemV1(
        id: 'grouped',
        family: MaterialFamilyV1.custom,
        name: 'Grouped',
        pattern: '',
        sequence: PatternSequenceV1.parse('RLL_RLLKXF'),
        accentedNoteIndices: const <int>[0, 4, 9],
        ghostNoteIndices: const <int>[1, 2, 5, 6],
        voiceAssignments: const <DrumVoiceV1>[],
        beatGrouping: beatGrouping,
        source: PracticeItemSourceV1.userDefined,
        tags: const <String>[],
        saved: true,
      );
    }

    test('parses compact and spaced grouping text the same way', () {
      expect(groupingSizesForText('3313'), <int>[3, 3, 1, 3]);
      expect(groupingSizesForText('3 3 1 3'), <int>[3, 3, 1, 3]);
    });

    test(
      'applies saved beat grouping as visual spaces in compact readouts',
      () {
        expect(
          markedPatternTextForPracticeItem(itemWithGrouping('3 3 1 3')),
          '^R(L)(L) _^R(L) (L) KX^F',
        );
        expect(
          markedPatternTextForPracticeItem(itemWithGrouping('3313')),
          '^R(L)(L) _^R(L) (L) KX^F',
        );
      },
    );

    test('does not add literal spacing when no grouping is stored', () {
      expect(
        markedPatternTextForPracticeItem(itemWithGrouping('')),
        '^R(L)(L)_^R(L)(L)KX^F',
      );
    });

    test('uses authored pattern text as compact readout source of truth', () {
      final PracticeItemV1 item = PracticeItemV1(
        id: 'authored',
        family: MaterialFamilyV1.custom,
        name: 'Authored',
        pattern: '[S HH:R]LRLLKRLRLL[KX]',
        sequence: PatternSequenceV1.parse('RLRLLKRLRLLK'),
        accentedNoteIndices: const <int>[],
        ghostNoteIndices: const <int>[],
        voiceAssignments: const <DrumVoiceV1>[],
        beatGrouping: '3 5 4',
        source: PracticeItemSourceV1.userDefined,
        tags: const <String>[],
        saved: true,
      );

      expect(markedPatternTextForPracticeItem(item), '[S HH:R]LRLLKRLRLL[KX]');
    });
  });
}
