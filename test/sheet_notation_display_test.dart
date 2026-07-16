import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_webview_platform.dart';

void main() {
  setUp(installFakeWebViewPlatform);

  test('parses duration and voice overrides separately from sticking', () {
    final DrumSheetNotationDocument document =
        DrumSheetNotationDocument.fromPattern('^R[T1:L][16:R][16:L]R^L');

    expect(document.subdivision, DrumSheetNoteValue.eighth);
    expect(
      document.flattenedNotes
          .map(
            (DrumSheetNotationNote note) => <Object?>[
              note.sticking,
              note.voices,
              note.value,
              note.accent,
            ],
          )
          .toList(),
      <Object>[
        <Object?>[
          'R',
          <DrumSheetVoice>[DrumSheetVoice.snare],
          null,
          true,
        ],
        <Object?>[
          'L',
          <DrumSheetVoice>[DrumSheetVoice.tom1],
          null,
          false,
        ],
        <Object?>[
          'R',
          <DrumSheetVoice>[DrumSheetVoice.snare],
          DrumSheetNoteValue.sixteenth,
          false,
        ],
        <Object?>[
          'L',
          <DrumSheetVoice>[DrumSheetVoice.snare],
          DrumSheetNoteValue.sixteenth,
          false,
        ],
        <Object?>[
          'R',
          <DrumSheetVoice>[DrumSheetVoice.snare],
          null,
          false,
        ],
        <Object?>[
          'L',
          <DrumSheetVoice>[DrumSheetVoice.snare],
          null,
          true,
        ],
      ],
    );
  });

  test('parses phrase groups and multi-voice beats as one slot', () {
    final List<DrumSheetNotationNote> notes =
        DrumSheetNotationDocument.fromPattern(
          '^R^L^R(L)(L) K ^R^L^R(L)(L) ^R^L^R(L)(L) [XK]',
        ).flattenedNotes;

    expect(notes, hasLength(17));
    expect(notes.last.sticking, 'XK');
    expect(notes.last.voices, <DrumSheetVoice>[
      DrumSheetVoice.crash,
      DrumSheetVoice.kick,
    ]);
  });

  test('builds measures from time signature subdivision and triplet feel', () {
    final DrumSheetNotationDocument straight =
        DrumSheetNotationDocument.fromPattern(
          '[HH K:R] [HH:R] [HH S:R] [HH:R] [HH K:R] [HH:R] [HH S:R] [HH:R] '
          '[HH K:R] [HH:R] [HH S:R] [HH:R] [HH K:R] [HH:R] [HH S:R] [HH:R]',
          subdivision: DrumSheetNoteValue.eighth,
          timeSignature: '4/4',
        );

    expect(straight.measures, hasLength(2));
    expect(straight.measures.first.notes, hasLength(8));

    final DrumSheetNotationDocument triplet =
        DrumSheetNotationDocument.fromPattern(
          'R L R L R L R L R L R L',
          subdivision: DrumSheetNoteValue.eighth,
          feel: DrumSheetFeel.triplet,
          timeSignature: '4/4',
        );

    expect(triplet.measures, hasLength(1));
    expect(triplet.measures.single.notes, hasLength(12));
    expect(triplet.feel, DrumSheetFeel.triplet);
  });

  test('parses multi-voice hand and limb beats', () {
    expect(
      DrumSheetNotationDocument.fromPattern(
        '[RL]',
      ).flattenedNotes.single.sticking,
      'RL',
    );
    final DrumSheetNotationNote note = DrumSheetNotationDocument.fromPattern(
      '[RKL]',
    ).flattenedNotes.single;
    expect(note.sticking, 'RKL');
    expect(note.voices, contains(DrumSheetVoice.kick));
  });

  test('parses accent and ghost decorations inside or outside brackets', () {
    final List<DrumSheetNotationNote> notes =
        DrumSheetNotationDocument.fromPattern(
          '^[T1:R][T2:^L][T1:(L)]([T2:R])',
        ).flattenedNotes;

    expect(notes[0].accent, true);
    expect(notes[0].voices, <DrumSheetVoice>[DrumSheetVoice.tom1]);
    expect(notes[1].accent, true);
    expect(notes[1].voices, <DrumSheetVoice>[DrumSheetVoice.tom2]);
    expect(notes[2].ghost, true);
    expect(notes[2].voices, <DrumSheetVoice>[DrumSheetVoice.tom1]);
    expect(notes[3].ghost, true);
    expect(notes[3].voices, <DrumSheetVoice>[DrumSheetVoice.tom2]);
  });

  test('rejects accented ghost notes', () {
    expect(
      () => DrumSheetNotationDocument.fromPattern('^(L)'),
      throwsFormatException,
    );
    expect(
      () => DrumSheetNotationDocument.fromPattern('[T1:^(L)]'),
      throwsFormatException,
    );
    expect(
      () => DrumSheetNotationDocument.fromPattern('^[T1:(L)]'),
      throwsFormatException,
    );
  });

  test('rejects invalid tokens and malformed multi-voice beats', () {
    expect(
      () => DrumSheetNotationDocument.fromPattern('B'),
      throwsFormatException,
    );
    expect(
      () => DrumSheetNotationDocument.fromPattern('[B]'),
      throwsFormatException,
    );
    expect(
      () => DrumSheetNotationDocument.fromPattern('[]'),
      throwsFormatException,
    );
    expect(
      () => DrumSheetNotationDocument.fromPattern('[X_]'),
      throwsFormatException,
    );
  });

  test('serializes selected-note edits back to bracket syntax', () {
    final List<DrumSheetNotationNote> notes =
        DrumSheetNotationDocument.fromPattern('R L').flattenedNotes;
    final List<DrumSheetNotationNote> edited =
        DrumSheetPatternParser.toggleGhost(
          DrumSheetPatternParser.toggleAccent(
            DrumSheetPatternParser.applyVoiceOverride(
              DrumSheetPatternParser.applyValueOverride(notes, <int>{
                1,
              }, DrumSheetNoteValue.sixteenth),
              <int>{1},
              DrumSheetVoice.tom2,
            ),
            <int>{0},
          ),
          <int>{1},
        );

    expect(
      DrumSheetPatternParser.serialize(
        edited,
        subdivision: DrumSheetNoteValue.eighth,
      ),
      '^R[T2 16:(L)]',
    );
  });

  test(
    'serializes multiple override voices and uppercases sticking labels',
    () {
      final List<DrumSheetNotationNote> notes =
          DrumSheetNotationDocument.fromPattern('[S T1:l]').flattenedNotes;

      expect(notes.single.sticking, 'L');
      expect(notes.single.voices, <DrumSheetVoice>[
        DrumSheetVoice.snare,
        DrumSheetVoice.tom1,
      ]);
      expect(DrumSheetPatternParser.serialize(notes), '[S T1:L]');
    },
  );

  test('lenient parsing tolerates incomplete editing states', () {
    expect(
      DrumSheetNotationDocument.fromPattern('^', lenient: true).flattenedNotes,
      isEmpty,
    );
    expect(
      DrumSheetNotationDocument.fromPattern(
        'R[32:',
        lenient: true,
      ).flattenedNotes.single.sticking,
      'R',
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
                '^R[T1:L][16:R][16:L]R^L',
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
                  'R L L R R L R L L R R L',
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
