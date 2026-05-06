import 'package:flutter_test/flutter_test.dart';
import 'package:drumcabulary/core/practice/practice_domain_v1.dart';

void main() {
  group('Phase 1 canonical pattern model', () {
    test('parses canonical tokens and preserves rest positions', () {
      final PatternSequenceV1 sequence = PatternSequenceV1.parse('RLL - _K');

      expect(sequence.symbols, <String>['R', 'L', 'L', '_', 'K']);
      expect(sequence.positionCount, 5);
      expect(sequence.canonicalText, 'RLL_K');
    });

    test(
      'uses underscore for user-facing rest display and canonical storage',
      () {
        final PatternSequenceV1 sequence = PatternSequenceV1.parse('RL_K');

        expect(sequence.canonicalText, 'RL_K');
        expect(sequence.toDisplayText(PatternGroupingV1.none), 'RL_K');
        expect(PatternTokenV1.rest.symbol, '_');
        expect(PatternTokenV1.rest.notationSymbol, '_');
      },
    );

    test('accepts core playable tokens as single preserved positions', () {
      const List<String> examples = <String>['FKLRK', 'RLLF_K', 'XRLK'];

      for (final String example in examples) {
        final PatternSequenceV1 sequence = PatternSequenceV1.parse(example);

        expect(sequence.canonicalText, example);
        expect(sequence.positionCount, example.length);
      }

      expect(PatternTokenV1.flam.symbol, 'F');
      expect(PatternTokenV1.accent.symbol, 'X');
      expect(PatternTokenV1.rest.symbol, '_');
      expect(PatternTokenV1.rest.notationSymbol, '_');
    });

    test('rejects B because unison is represented as simultaneous hits', () {
      expect(() => PatternTokenV1.fromSymbol('B'), throwsArgumentError);
      expect(() => PatternSequenceV1.parse('RBL'), throwsFormatException);
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
        expect(item.pattern, 'RLL-LRR');
        expect(item.sticking, 'RLL-LRR');
        expect(item.groupingHint, PatternGroupingV1.none);
      },
    );

    test('practice item preserves authored pattern text separately', () {
      const String pattern = '^R^L^R(L)(L) K ^R^L^R(L)(L) ^R^L^R(L)(L) [XK]';
      final PracticeItemV1 item = PracticeItemV1(
        id: 'authored_pattern',
        family: MaterialFamilyV1.custom,
        name: 'Authored Pattern',
        pattern: pattern,
        accentedNoteIndices: const <int>[],
        ghostNoteIndices: const <int>[],
        voiceAssignments: const <DrumVoiceV1>[],
        source: PracticeItemSourceV1.userDefined,
        tags: const <String>['custom'],
        saved: true,
      );

      expect(item.pattern, pattern);
      expect(item.sticking, pattern);
      expect(item.sequence.positionCount, 17);
    });

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

    test(
      'timing metadata is separate from grouping and defaults to auto playback timing',
      () {
        final PracticeItemV1 item = PracticeItemV1(
          id: 'timing_meta_only',
          family: MaterialFamilyV1.custom,
          name: 'RLL_RRL',
          sequence: PatternSequenceV1.parse('RLL_RRL'),
          groupingHint: PatternGroupingV1.triads,
          accentedNoteIndices: const <int>[],
          ghostNoteIndices: const <int>[],
          voiceAssignments: const <DrumVoiceV1>[],
          source: PracticeItemSourceV1.userDefined,
          tags: const <String>[],
          saved: true,
        );

        expect(item.timing, const PatternTimingV1.auto());
        expect(item.groupingHint, PatternGroupingV1.triads);

        final PracticeItemV1 explicitTimingItem = item.copyWith(
          timing: const PatternTimingV1.explicit(
            spans: <PatternTimingSpanV1>[
              PatternTimingSpanV1(startIndex: 0, tokenCount: 3, beatCount: 1),
              PatternTimingSpanV1(startIndex: 3, tokenCount: 4, beatCount: 1),
            ],
          ),
        );

        expect(explicitTimingItem.timing.usesExplicitSpans, isTrue);
        expect(explicitTimingItem.groupingHint, PatternGroupingV1.triads);
        expect(explicitTimingItem.timing.spans.length, 2);
      },
    );
  });

  group('PracticeContext model', () {
    List<String> validatePattern(String pattern) {
      if (pattern.contains('B')) {
        return <String>[
          'Invalid token: B is no longer supported. Use [RL] for both hands/unison or assign explicit voices.',
        ];
      }
      return const <String>[];
    }

    test('accepts subdivision tempo cycle and beat alignment metadata', () {
      final PracticeContext context = PracticeContext(
        id: 'ctx_001',
        patternId: 'pattern_001',
        subdivision: DrumSubdivision.sixteen,
        tempo: const TempoPlan(start: 70, step: 10, max: 110),
        loop: const LoopSettings(enabled: true),
        beatAlignment: const BeatAlignment(
          enabled: true,
          anchoredPattern: '|1| R L |2| K R |3| L K |4| R L',
        ),
        cycle: PracticeCycle(
          steps: const <PracticeCycleStep>[
            PracticeCycleStep(
              label: '8ths',
              subdivision: DrumSubdivision.eight,
              pattern: 'R L R L',
            ),
            PracticeCycleStep(
              label: 'Triplets',
              subdivision: DrumSubdivision.triplet,
              pattern: 'R L R L R L',
            ),
            PracticeCycleStep(
              label: '16ths',
              subdivision: DrumSubdivision.sixteen,
              pattern: 'R L R L R L R L',
            ),
          ],
        ),
      );

      expect(context.validate(validatePattern: validatePattern), isEmpty);
    });

    test('rejects invalid practice context values', () {
      final PracticeContext context = PracticeContext(
        id: 'ctx_bad',
        patternId: 'pattern_001',
        tempo: const TempoPlan(start: 70, step: 0, max: 60),
        cycle: PracticeCycle(
          steps: const <PracticeCycleStep>[
            PracticeCycleStep(
              subdivision: DrumSubdivision.eight,
              pattern: 'RBL',
            ),
          ],
        ),
      );

      expect(
        context.validate(validatePattern: validatePattern),
        containsAll(<String>[
          'Tempo step must be greater than zero.',
          'Tempo max must be greater than or equal to start.',
          'Cycle step eight: Invalid token: B is no longer supported. Use [RL] for both hands/unison or assign explicit voices.',
        ]),
      );
    });
  });
}
