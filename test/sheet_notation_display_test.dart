import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';
import 'package:drumcabulary/features/practice/sticking_cue.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_webview_platform.dart';

void main() {
  setUp(installFakeWebViewPlatform);

  test('parses voice-first notes with optional sticking', () {
    final List<DrumSheetNotationNote> notes =
        DrumSheetNotationDocument.fromPattern(
          '[S] [HH] [OHH] [K] [OHH:R] [S:LRLR] [S:(L)(L)^R]',
        ).flattenedNotes;

    expect(notes[0].voices, <DrumSheetVoice>[DrumSheetVoice.snare]);
    expect(notes[0].sticking, isEmpty);
    expect(notes[1].voices, <DrumSheetVoice>[DrumSheetVoice.hihat]);
    expect(notes[1].sticking, isEmpty);
    expect(notes[2].voices, <DrumSheetVoice>[DrumSheetVoice.openHiHat]);
    expect(notes[2].sticking, isEmpty);
    expect(notes[3].voices, <DrumSheetVoice>[DrumSheetVoice.kick]);
    expect(notes[3].sticking, isEmpty);
    expect(notes[4].voices, <DrumSheetVoice>[DrumSheetVoice.openHiHat]);
    expect(notes[4].sticking, 'R');

    expect(
      notes.sublist(5, 9).map((DrumSheetNotationNote note) => note.sticking),
      <String>['L', 'R', 'L', 'R'],
    );
    expect(
      notes.sublist(9).map((DrumSheetNotationNote note) => note.sticking),
      <String>['L', 'L', 'R'],
    );
    expect(notes[9].ghost, isTrue);
    expect(notes[10].ghost, isTrue);
    expect(notes[11].accent, isTrue);
  });

  test('parses simultaneous voices and aligned stroke sequences', () {
    final List<DrumSheetNotationNote> notes =
        DrumSheetNotationDocument.fromPattern(
          '[HH K] [OHH K] [OHH:R K] [HH:RRRR S:LRLR]',
        ).flattenedNotes;

    expect(notes[0].voices, <DrumSheetVoice>[
      DrumSheetVoice.hihat,
      DrumSheetVoice.kick,
    ]);
    expect(notes[0].sticking, isEmpty);
    expect(notes[1].voices, <DrumSheetVoice>[
      DrumSheetVoice.openHiHat,
      DrumSheetVoice.kick,
    ]);
    expect(notes[1].sticking, isEmpty);
    expect(
      notes[2].strokeForVoice(DrumSheetVoice.openHiHat)!.hand,
      DrumSheetStrokeHand.right,
    );
    expect(notes[2].strokeForVoice(DrumSheetVoice.kick), isNull);

    expect(notes.sublist(3), hasLength(4));
    expect(
      notes.sublist(3).map((DrumSheetNotationNote note) => note.voices),
      everyElement(<DrumSheetVoice>[
        DrumSheetVoice.hihat,
        DrumSheetVoice.snare,
      ]),
    );
    expect(
      notes
          .sublist(3)
          .map(
            (DrumSheetNotationNote note) =>
                note.strokeForVoice(DrumSheetVoice.snare)!.hand,
          )
          .toList(),
      <DrumSheetStrokeHand>[
        DrumSheetStrokeHand.left,
        DrumSheetStrokeHand.right,
        DrumSheetStrokeHand.left,
        DrumSheetStrokeHand.right,
      ],
    );
  });

  test('builds measures from time signature subdivision and triplet feel', () {
    final DrumSheetNotationDocument straight =
        DrumSheetNotationDocument.fromPattern(
          '[HH K] [HH] [HH S] [HH] [HH K] [HH] [HH S] [HH] '
          '[HH K] [HH] [HH S] [HH] [HH K] [HH] [HH S] [HH]',
          subdivision: DrumSheetNoteValue.eighth,
          timeSignature: '4/4',
        );

    expect(straight.measures, hasLength(2));
    expect(straight.measures.first.notes, hasLength(8));

    final DrumSheetNotationDocument triplet =
        DrumSheetNotationDocument.fromPattern(
          '[S:RLRLRLRLRLRL]',
          subdivision: DrumSheetNoteValue.eighth,
          feel: DrumSheetFeel.triplet,
          timeSignature: '4/4',
        );

    expect(triplet.measures, hasLength(1));
    expect(triplet.measures.single.notes, hasLength(12));
    expect(triplet.feel, DrumSheetFeel.triplet);
  });

  test(
    'rejects invalid voice-first syntax and obsolete root-sticking syntax',
    () {
      for (final String source in <String>[
        '[]',
        '[:R]',
        '[S:]',
        '[S:^]',
        '[S:()]',
        '[S:(R]',
        '[S:R)]',
        '[UNKNOWN:R]',
        '[HH:RRRR K]',
        '[OHH:RRRR K]',
        'RLRL',
        'K',
        '^R',
        '(L)',
      ]) {
        expect(
          () => DrumSheetNotationDocument.fromPattern(source),
          throwsFormatException,
          reason: source,
        );
      }
    },
  );

  test('serializes canonical voice-first notation', () {
    String roundTrip(String source) => DrumSheetPatternParser.serialize(
      DrumSheetNotationDocument.fromPattern(source).flattenedNotes,
    );

    expect(roundTrip('[HH]'), '[HH]');
    expect(roundTrip('[OHH]'), '[OHH]');
    expect(roundTrip('[OHH:R]'), '[OHH:R]');
    expect(roundTrip('[S:LRLR]'), '[S:LRLR]');
    expect(roundTrip('[S:(L)(L)^R]'), '[S:(L)(L)^R]');
    expect(roundTrip('[HH K]'), '[HH K]');
    expect(roundTrip('[OHH:R K]'), '[OHH:R K]');
  });

  test('serializes selected-note edits without inventing sticking', () {
    final List<DrumSheetNotationNote> notes =
        DrumSheetNotationDocument.fromPattern(
          '[S:R] [S:L] [HH]',
        ).flattenedNotes;
    final List<DrumSheetNotationNote> edited =
        DrumSheetPatternParser.toggleGhost(
          DrumSheetPatternParser.toggleAccent(
            DrumSheetPatternParser.applyVoiceOverride(notes, <int>{
              1,
            }, DrumSheetVoice.tom2),
            <int>{0},
          ),
          <int>{1},
        );

    expect(DrumSheetPatternParser.serialize(edited), '[S:^R] [T2:(L)] [HH]');
  });

  test('ghost strokes become dim sticking cues in playback plans', () {
    final DrumSheetAudioPreviewPlan plan =
        buildSheetNotationAudioPreviewPlanDetails(
          DrumSheetNotationDocument.fromPattern('[S:(L)] [OHH:(R) K]'),
        );

    expect(plan.audioPlan.cues[0].sticking, StickingCue.ghostLeft);
    expect(
      plan.audioPlan.cues
          .where((cue) => cue.tokenIndex == 1)
          .map((cue) => cue.sticking)
          .toList(),
      contains(StickingCue.ghostRight),
    );
  });

  test('lenient parsing tolerates incomplete editing states', () {
    expect(
      DrumSheetNotationDocument.fromPattern('^', lenient: true).flattenedNotes,
      isEmpty,
    );
    expect(
      DrumSheetNotationDocument.fromPattern(
        '[S:',
        lenient: true,
      ).flattenedNotes,
      isEmpty,
    );
  });

  test(
    'semantic notation selection filters invalid indexes and carries purpose',
    () {
      final DrumSheetNotationSelection selection =
          DrumSheetNotationSelection.guidedPractice(<int>{2, -1, 1});

      expect(selection.sortedIndexes, <int>[1, 2]);
      expect(
        selection.purpose,
        DrumSheetNotationSelectionPurpose.guidedPractice,
      );
      expect(selection.isGuidedPractice, true);
    },
  );

  testWidgets('renders sheet notation widget with WebView renderer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: DrumSheetNotationDisplay(
              document: DrumSheetNotationDocument.fromPattern(
                '[S:^R][T1:L][S:R][S:L][S:R][S:^L]',
              ),
              grouping: '3535',
              selection: DrumSheetNotationSelection.editing(<int>{1}),
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(DrumSheetNotationDisplay), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses WebView renderer on macOS', (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: DrumSheetNotationDisplay(
                document: DrumSheetNotationDocument.fromPattern(
                  '[S:RLLRRL] [S:RLLRRL]',
                  subdivision: DrumSheetNoteValue.sixteenth,
                  feel: DrumSheetFeel.triplet,
                  timeSignature: '4/4',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.byType(DrumSheetNotationDisplay), findsOneWidget);
      expect(tester.takeException(), isNull);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
