import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('renders sheet notation widget and supports note selection', (
    WidgetTester tester,
  ) async {
    Set<int> selected = <int>{};
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Scaffold(
              body: SizedBox(
                width: 360,
                child: DrumSheetNotationDisplay(
                  document: DrumSheetNotationDocument.fromPattern(
                    '^R[T1:L][16:R][16:L]R^L',
                  ),
                  grouping: '3535',
                  selectedIndexes: selected,
                  onSelectionChanged: (Set<int> next) {
                    setState(() => selected = next);
                  },
                  debugUseNativeFallback: true,
                ),
              ),
            );
          },
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(DrumSheetNotationDisplay), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(80, 40));
    await tester.pump();

    expect(selected, isNotEmpty);
  });
}
