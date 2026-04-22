import 'package:flutter_test/flutter_test.dart';
import 'package:traid_trainer/core/practice/practice_domain_v1.dart';
import 'package:traid_trainer/features/practice/practice_session_screen.dart';

void main() {
  group('PracticeSessionRuntimeMath.activeTokenIndex', () {
    test(
      'uses grouping-derived subdivision timing for compatible simple drills',
      () {
        final List<PatternTokenV1> tokens = <PatternTokenV1>[
          PatternTokenV1.right,
          PatternTokenV1.left,
          PatternTokenV1.kick,
        ];

        expect(
          PracticeSessionRuntimeMath.activeTokenIndex(
            tokens: tokens,
            grouping: PatternGroupingV1.triads,
            timing: const PatternTimingV1.auto(),
            elapsed: Duration.zero,
            bpm: 60,
          ),
          0,
        );
        expect(
          PracticeSessionRuntimeMath.activeTokenIndex(
            tokens: tokens,
            grouping: PatternGroupingV1.triads,
            timing: const PatternTimingV1.auto(),
            elapsed: const Duration(milliseconds: 334),
            bpm: 60,
          ),
          1,
        );
        expect(
          PracticeSessionRuntimeMath.activeTokenIndex(
            tokens: tokens,
            grouping: PatternGroupingV1.triads,
            timing: const PatternTimingV1.auto(),
            elapsed: const Duration(milliseconds: 667),
            bpm: 60,
          ),
          2,
        );
        expect(
          PracticeSessionRuntimeMath.activeTokenIndex(
            tokens: tokens,
            grouping: PatternGroupingV1.triads,
            timing: const PatternTimingV1.auto(),
            elapsed: const Duration(seconds: 1),
            bpm: 60,
          ),
          0,
        );
      },
    );

    test('counts rests as full timed positions', () {
      final List<PatternTokenV1> tokens = <PatternTokenV1>[
        PatternTokenV1.right,
        PatternTokenV1.rest,
        PatternTokenV1.left,
      ];

      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          grouping: PatternGroupingV1.triads,
          timing: const PatternTimingV1.auto(),
          elapsed: Duration.zero,
          bpm: 60,
        ),
        0,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          grouping: PatternGroupingV1.triads,
          timing: const PatternTimingV1.auto(),
          elapsed: const Duration(milliseconds: 334),
          bpm: 60,
        ),
        1,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          grouping: PatternGroupingV1.triads,
          timing: const PatternTimingV1.auto(),
          elapsed: const Duration(milliseconds: 667),
          bpm: 60,
        ),
        2,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          grouping: PatternGroupingV1.triads,
          timing: const PatternTimingV1.auto(),
          elapsed: const Duration(seconds: 1),
          bpm: 60,
        ),
        0,
      );
    });

    test(
      'falls back to one token per beat when no compatible grouping exists',
      () {
        final List<PatternTokenV1> tokens = <PatternTokenV1>[
          PatternTokenV1.right,
          PatternTokenV1.left,
          PatternTokenV1.right,
          PatternTokenV1.kick,
        ];

        expect(
          PracticeSessionRuntimeMath.activeTokenIndex(
            tokens: tokens,
            grouping: PatternGroupingV1.none,
            timing: const PatternTimingV1.auto(),
            elapsed: const Duration(seconds: 2),
            bpm: 60,
          ),
          2,
        );
      },
    );

    test('explicit timing spans override grouping-derived timing', () {
      final List<PatternTokenV1> tokens = <PatternTokenV1>[
        PatternTokenV1.right,
        PatternTokenV1.left,
        PatternTokenV1.left,
        PatternTokenV1.rest,
        PatternTokenV1.right,
      ];

      const PatternTimingV1 explicitTiming = PatternTimingV1.explicit(
        spans: <PatternTimingSpanV1>[
          PatternTimingSpanV1(startIndex: 0, tokenCount: 3, beatCount: 1),
          PatternTimingSpanV1(startIndex: 3, tokenCount: 2, beatCount: 1),
        ],
      );

      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          grouping: PatternGroupingV1.fiveNote,
          timing: explicitTiming,
          elapsed: const Duration(milliseconds: 1100),
          bpm: 60,
        ),
        3,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          grouping: PatternGroupingV1.fiveNote,
          timing: explicitTiming,
          elapsed: const Duration(milliseconds: 1500),
          bpm: 60,
        ),
        4,
      );
    });
  });
}
