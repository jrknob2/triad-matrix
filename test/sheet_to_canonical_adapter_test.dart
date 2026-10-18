import 'package:flutter_test/flutter_test.dart';
import 'package:drumcabulary/core/music/canonical_musical_document.dart';
import 'package:drumcabulary/core/practice/practice_domain_v1.dart';
import 'package:drumcabulary/features/practice/sheet_to_canonical_adapter.dart';
import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';

DrumSheetNotationDocument sheet(
  List<DrumSheetNotationNote> notes, {
  DrumSheetNoteValue subdivision = DrumSheetNoteValue.eighth,
  DrumSheetFeel feel = DrumSheetFeel.straight,
  String meter = '4/4',
}) => DrumSheetNotationDocument(
  subdivision: subdivision,
  feel: feel,
  timeSignature: meter,
  measures: [DrumSheetNotationMeasure(notes: notes)],
);
DrumSheetNotationNote note(DrumSheetNoteValue value) =>
    DrumSheetNotationNote(value: value, voices: const [DrumSheetVoice.snare]);

void main() {
  for (final (count, value) in [
    (4, DrumSheetNoteValue.quarter),
    (8, DrumSheetNoteValue.eighth),
    (16, DrumSheetNoteValue.sixteenth),
  ]) {
    test('converts $count notes with subdivision defaults', () {
      final result = SheetToCanonicalAdapter.convert(
        sheet(
          List.generate(
            count,
            (_) => DrumSheetNotationNote(voices: [DrumSheetVoice.snare]),
          ),
          subdivision: value,
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(result.diagnostics, isEmpty);
      expect(result.document!.events.last.end, MusicalTime(4));
      expect(
        result.document!.events.every(
          (e) => e.duration == MusicalTime(4, count),
        ),
        isTrue,
      );
    });
  }
  test('mixed explicit values override default and preserve exact meter', () {
    final result = SheetToCanonicalAdapter.convert(
      sheet([
        note(DrumSheetNoteValue.half),
        note(DrumSheetNoteValue.quarter),
        note(DrumSheetNoteValue.eighth),
        note(DrumSheetNoteValue.eighth),
      ]),
    );
    expect(result.isSuccess, isTrue);
    expect(result.document!.events.map((e) => e.duration), [
      MusicalTime(2),
      MusicalTime(1),
      MusicalTime(1, 2),
      MusicalTime(1, 2),
    ]);
    final sixEight = SheetToCanonicalAdapter.convert(
      sheet(
        List.generate(6, (_) => note(DrumSheetNoteValue.eighth)),
        meter: '6/8',
      ),
    );
    expect(sixEight.document!.measures.single.duration, MusicalTime(3));
    expect(sixEight.document!.timeSignature.numerator, 6);
    expect(sixEight.document!.timeSignature.denominator, 8);
  });
  test(
    'one event holds simultaneous kick, snare and hi-hat without invented hands',
    () {
      final result = SheetToCanonicalAdapter.convert(
        DrumSheetNotationDocument.fromPattern('[K S HH]'),
      );
      final e = result.document!.events.single;
      expect(e.strikes.map((s) => s.voice), [
        DrumVoiceV1.kick,
        DrumVoiceV1.snare,
        DrumVoiceV1.hihat,
      ]);
      expect(e.strikes.every((s) => s.hand == null), isTrue);
    },
  );
  test(
    'structured sticking and voice-specific articulation survive expansion',
    () {
      final result = SheetToCanonicalAdapter.convert(
        DrumSheetNotationDocument.fromPattern('[HH:^R(R) S:(L)^L]'),
      );
      expect(result.isSuccess, isTrue);
      final events = result.document!.events;
      expect(events, hasLength(2));
      expect(events[0].strikes.map((s) => s.hand), [
        MusicalHand.right,
        MusicalHand.left,
      ]);
      expect(events[0].strikes.map((s) => s.articulation), [
        StrikeArticulation.accent,
        StrikeArticulation.ghost,
      ]);
      expect(events[1].strikes.map((s) => s.articulation), [
        StrikeArticulation.ghost,
        StrikeArticulation.accent,
      ]);
    },
  );
  test(
    'summary flags never spread articulation or sticking to an unassigned voice',
    () {
      final result = SheetToCanonicalAdapter.convert(
        DrumSheetNotationDocument.fromPattern('[S:^R K] [S:(L) HH]'),
      );
      expect(result.isSuccess, isTrue);
      for (final event in result.document!.events) {
        expect(event.strikes.last.hand, isNull);
        expect(event.strikes.last.articulation, StrikeArticulation.normal);
      }
    },
  );
  test('all existing instrument voices map without loss', () {
    final result = SheetToCanonicalAdapter.convert(
      DrumSheetNotationDocument.fromPattern('[S T1 T2 FT HH OHH CR RD K]'),
    );
    expect(
      result.document!.events.single.strikes.map((s) => s.voice).toSet(),
      DrumVoiceV1.values.toSet(),
    );
  });
  test(
    'legacy single-voice hand and aggregate dynamics convert unambiguously',
    () {
      final result = SheetToCanonicalAdapter.convert(
        sheet([
          DrumSheetNotationNote(
            voices: [DrumSheetVoice.snare],
            sticking: 'L',
            accent: true,
          ),
          DrumSheetNotationNote(
            voices: [DrumSheetVoice.snare],
            sticking: 'R',
            ghost: true,
          ),
        ]),
      );
      expect(result.isSuccess, isTrue);
      expect(
        result.document!.events.first.strikes.single.hand,
        MusicalHand.left,
      );
      expect(
        result.document!.events.first.strikes.single.articulation,
        StrikeArticulation.accent,
      );
      expect(
        result.document!.events.last.strikes.single.articulation,
        StrikeArticulation.ghost,
      );
    },
  );
  test('rests consume exact time and carry no strikes', () {
    final result = SheetToCanonicalAdapter.convert(
      sheet([
        note(DrumSheetNoteValue.quarter),
        DrumSheetNotationNote(rest: true, value: DrumSheetNoteValue.quarter),
      ]),
    );
    expect(result.document!.events.last.isRest, isTrue);
    expect(result.document!.events.last.strikes, isEmpty);
    expect(result.document!.events.last.end, MusicalTime(2));
  });
  for (final (value, duration) in [
    (DrumSheetNoteValue.eighth, MusicalTime(1, 3)),
    (DrumSheetNoteValue.sixteenth, MusicalTime(1, 6)),
    (DrumSheetNoteValue.thirtySecond, MusicalTime(1, 12)),
  ]) {
    test('triplet feel $value uses an exact 3:2 ratio', () {
      final result = SheetToCanonicalAdapter.convert(
        sheet(
          List.generate(3, (_) => note(value)),
          feel: DrumSheetFeel.triplet,
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(
        result.document!.events.every((e) => e.duration == duration),
        isTrue,
      );
      expect(result.document!.events.last.end, duration * MusicalTime(3));
      expect(result.document!.tupletGroups.single.actual, 3);
      expect(result.document!.tupletGroups.single.normal, 2);
      expect(result.document!.tupletGroups.single.isIncomplete, isFalse);
    });
  }
  test(
    'triplet feel leaves quarter notes ordinary and preserves partial tuplets explicitly',
    () {
      final result = SheetToCanonicalAdapter.convert(
        sheet([
          note(DrumSheetNoteValue.quarter),
          note(DrumSheetNoteValue.eighth),
        ], feel: DrumSheetFeel.triplet),
      );
      expect(result.document!.events.first.duration, MusicalTime(1));
      expect(result.document!.events.last.end, MusicalTime(4, 3));
      expect(result.document!.tupletGroups.single.isIncomplete, isTrue);
    },
  );
  test('incomplete measures are preserved without preview padding', () {
    final result = SheetToCanonicalAdapter.convert(
      sheet([note(DrumSheetNoteValue.eighth)]),
    );
    expect(result.document!.events.single.duration, MusicalTime(1, 2));
    expect(result.document!.measures.single.isIncomplete, isTrue);
    expect(result.diagnostics.single.code, 'incomplete_measure');
    expect(
      result.diagnostics.single.severity,
      MusicalDiagnosticSeverity.warning,
    );
  });
  test(
    'source identity and unchanged measure/note positions yield stable event IDs',
    () {
      final source = DrumSheetNotationDocument.fromPattern('[S:LRLR]');
      final first = SheetToCanonicalAdapter.convert(
        source,
        sourceId: 'lesson:exercise',
      ).document!;
      final again = SheetToCanonicalAdapter.convert(
        source,
        sourceId: 'lesson:exercise',
      ).document!;
      expect(first.events.map((e) => e.id), again.events.map((e) => e.id));
      expect(first.events.first.id, 'lesson:exercise:m0:e0');
      expect(first.events.map((e) => e.onset), [
        MusicalTime.zero,
        MusicalTime(1, 2),
        MusicalTime(1),
        MusicalTime(3, 2),
      ]);
      expect(first.phraseGroups, isEmpty);
    },
  );
  test('multi-measure conversion preserves boundaries', () {
    final source = DrumSheetNotationDocument.fromPattern(
      List.filled(8, '[S]').join(' '),
      subdivision: DrumSheetNoteValue.quarter,
    );
    final result = SheetToCanonicalAdapter.convert(source);
    expect(result.document!.measures, hasLength(2));
    expect(result.document!.measures.last.onset, MusicalTime(4));
    expect(result.document!.events.last.end, MusicalTime(8));
  });
  final invalid = <String, DrumSheetNotationDocument>{
    'measure_overflow': sheet(
      List.generate(5, (_) => note(DrumSheetNoteValue.quarter)),
    ),
    'empty_measure': sheet([]),
    'unsupported_ornament': sheet([
      DrumSheetNotationNote(voices: [DrumSheetVoice.snare], tie: true),
    ]),
    'ambiguous_sticking': sheet([
      DrumSheetNotationNote(
        voices: [DrumSheetVoice.snare, DrumSheetVoice.hihat],
        sticking: 'RL',
      ),
    ]),
    'ambiguous_articulation': sheet([
      DrumSheetNotationNote(
        voices: [DrumSheetVoice.snare, DrumSheetVoice.hihat],
        accent: true,
      ),
    ]),
    'conflicting_rest': sheet([
      DrumSheetNotationNote(rest: true, voices: [DrumSheetVoice.snare]),
    ]),
    'invalid_voices': sheet([
      DrumSheetNotationNote(
        voices: [DrumSheetVoice.snare, DrumSheetVoice.snare],
      ),
    ]),
    'invalid_voice_strokes': sheet([
      DrumSheetNotationNote(
        voices: [DrumSheetVoice.snare],
        voiceStrokes: [DrumSheetVoiceStroke(voice: DrumSheetVoice.kick)],
      ),
    ]),
    'conflicting_sticking': sheet([
      DrumSheetNotationNote(
        voices: [DrumSheetVoice.snare],
        voiceStrokes: [
          DrumSheetVoiceStroke(
            voice: DrumSheetVoice.snare,
            stroke: DrumSheetStrokeDescriptor(hand: DrumSheetStrokeHand.left),
          ),
        ],
        accent: true,
      ),
    ]),
  };
  for (final entry in invalid.entries) {
    test('diagnoses ${entry.key} without a partial document', () {
      final result = SheetToCanonicalAdapter.convert(entry.value);
      expect(result.document, isNull);
      expect(result.isSuccess, isFalse);
      expect(result.diagnostics.map((d) => d.code), contains(entry.key));
      expect(result.diagnostics.first.measureIndex, 0);
    });
  }
  test(
    'invalid meter, empty source and unsupported repeats are explicit errors',
    () {
      for (final source in [
        sheet([note(DrumSheetNoteValue.quarter)], meter: 'bad'),
        sheet([note(DrumSheetNoteValue.quarter)], meter: '4/0'),
        const DrumSheetNotationDocument(measures: []),
        const DrumSheetNotationDocument(repeatCount: 2, measures: []),
      ]) {
        final result = SheetToCanonicalAdapter.convert(source);
        expect(result.document, isNull);
        expect(
          result.diagnostics.any(
            (d) => d.severity == MusicalDiagnosticSeverity.error,
          ),
          isTrue,
        );
      }
    },
  );
}
