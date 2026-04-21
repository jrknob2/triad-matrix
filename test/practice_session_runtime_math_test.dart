import 'package:flutter_test/flutter_test.dart';
import 'package:traid_trainer/core/practice/practice_domain_v1.dart';
import 'package:traid_trainer/features/practice/practice_session_screen.dart';

void main() {
  group('PracticeSessionRuntimeMath.activeTokenIndex', () {
    test('advances by canonical token positions and wraps by token count', () {
      final List<PatternTokenV1> tokens = <PatternTokenV1>[
        PatternTokenV1.right,
        PatternTokenV1.left,
        PatternTokenV1.kick,
      ];

      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          elapsed: Duration.zero,
          bpm: 60,
        ),
        0,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          elapsed: const Duration(seconds: 1),
          bpm: 60,
        ),
        1,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          elapsed: const Duration(seconds: 2),
          bpm: 60,
        ),
        2,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          elapsed: const Duration(seconds: 3),
          bpm: 60,
        ),
        0,
      );
    });

    test('counts rests as full timed positions', () {
      final List<PatternTokenV1> tokens = <PatternTokenV1>[
        PatternTokenV1.right,
        PatternTokenV1.rest,
        PatternTokenV1.left,
      ];

      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          elapsed: Duration.zero,
          bpm: 60,
        ),
        0,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          elapsed: const Duration(seconds: 1),
          bpm: 60,
        ),
        1,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          elapsed: const Duration(seconds: 2),
          bpm: 60,
        ),
        2,
      );
      expect(
        PracticeSessionRuntimeMath.activeTokenIndex(
          tokens: tokens,
          elapsed: const Duration(seconds: 3),
          bpm: 60,
        ),
        0,
      );
    });
  });
}
