import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/features/practice/widgets/pattern_voice_display.dart';

void main() {
  test('uses stable measured slots for dynamic notation marks', () {
    const TextStyle style = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
    );
    const double cellWidth = 32;

    final double normalWidth = PatternVoiceDisplay.tokenWidthForMarking(
      PatternNoteMarkingV1.normal,
      style,
      cellWidth,
    );
    final double accentWidth = PatternVoiceDisplay.tokenWidthForMarking(
      PatternNoteMarkingV1.accent,
      style,
      cellWidth,
    );
    final double ghostWidth = PatternVoiceDisplay.tokenWidthForMarking(
      PatternNoteMarkingV1.ghost,
      style,
      cellWidth,
    );
    final double separatorWidth = PatternVoiceDisplay.separatorWidthForStyle(
      style,
      cellWidth,
    );

    final double tokenGapWidth = PatternVoiceDisplay.tokenGapWidthForStyle(
      style,
      cellWidth,
    );

    expect(normalWidth, separatorWidth);
    expect(accentWidth, separatorWidth * 2);
    expect(ghostWidth, lessThan(separatorWidth * 3));
    expect(ghostWidth, greaterThan(separatorWidth * 2));
    expect(tokenGapWidth, greaterThanOrEqualTo(0));
    expect(tokenGapWidth, lessThan(separatorWidth));
  });

  testWidgets(
    'wraps long ungrouped notation in constrained summary-style widths',
    (WidgetTester tester) async {
      final List<PatternTokenV1> tokens = <PatternTokenV1>[
        PatternTokenV1.right,
        PatternTokenV1.left,
        PatternTokenV1.right,
        PatternTokenV1.left,
        PatternTokenV1.left,
        PatternTokenV1.kick,
        PatternTokenV1.right,
        PatternTokenV1.left,
        PatternTokenV1.right,
        PatternTokenV1.left,
        PatternTokenV1.left,
        PatternTokenV1.right,
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 220,
                child: PatternVoiceDisplay(
                  tokens: tokens,
                  markings: const <PatternNoteMarkingV1>[
                    PatternNoteMarkingV1.accent,
                    PatternNoteMarkingV1.normal,
                    PatternNoteMarkingV1.accent,
                    PatternNoteMarkingV1.ghost,
                    PatternNoteMarkingV1.ghost,
                    PatternNoteMarkingV1.accent,
                    PatternNoteMarkingV1.normal,
                    PatternNoteMarkingV1.normal,
                    PatternNoteMarkingV1.accent,
                    PatternNoteMarkingV1.ghost,
                    PatternNoteMarkingV1.ghost,
                    PatternNoteMarkingV1.accent,
                  ],
                  voices: const <DrumVoiceV1>[
                    DrumVoiceV1.snare,
                    DrumVoiceV1.snare,
                    DrumVoiceV1.snare,
                    DrumVoiceV1.snare,
                    DrumVoiceV1.snare,
                    DrumVoiceV1.kick,
                    DrumVoiceV1.tom2,
                    DrumVoiceV1.snare,
                    DrumVoiceV1.snare,
                    DrumVoiceV1.snare,
                    DrumVoiceV1.snare,
                    DrumVoiceV1.floorTom,
                  ],
                  grouping: PatternGroupingV1.none,
                  scrollable: false,
                  wrap: true,
                  cellWidth: 32,
                  patternStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                  voiceStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
    },
  );
}
