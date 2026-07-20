import '../../core/practice/practice_domain_v1.dart';
import '../practice/widgets/sheet_notation_display.dart';

String normalizeExerciseNotation(String pattern) =>
    pattern.trim().toUpperCase();

List<DrumSheetNotationNote> parseExerciseNotation(String pattern) {
  return DrumSheetPatternParser.parse(normalizeExerciseNotation(pattern));
}

List<int> accentIndicesForSheetNotes(List<DrumSheetNotationNote> notes) {
  return <int>[
    for (int index = 0; index < notes.length; index += 1)
      if (notes[index].accent) index,
  ];
}

List<int> ghostIndicesForSheetNotes(List<DrumSheetNotationNote> notes) {
  return <int>[
    for (int index = 0; index < notes.length; index += 1)
      if (notes[index].ghost) index,
  ];
}

PatternTokenV1 legacyTokenForSheetNote(DrumSheetNotationNote note) {
  if (note.rest) return PatternTokenV1.rest;
  if (note.flam) return PatternTokenV1.flam;
  return switch (note.sticking.toUpperCase()) {
    'R' => PatternTokenV1.right,
    'L' => PatternTokenV1.left,
    'K' => PatternTokenV1.kick,
    'F' => PatternTokenV1.flam,
    'X' => PatternTokenV1.accent,
    _ =>
      note.voices.contains(DrumSheetVoice.kick)
          ? PatternTokenV1.kick
          : PatternTokenV1.right,
  };
}

DrumVoiceV1 legacyVoiceForSheetNote(DrumSheetNotationNote note) {
  if (note.rest || note.voices.isEmpty) return DrumVoiceV1.snare;
  return switch (note.voices.first) {
    DrumSheetVoice.snare => DrumVoiceV1.snare,
    DrumSheetVoice.tom1 => DrumVoiceV1.rackTom,
    DrumSheetVoice.tom2 => DrumVoiceV1.tom2,
    DrumSheetVoice.floorTom => DrumVoiceV1.floorTom,
    DrumSheetVoice.hihat => DrumVoiceV1.hihat,
    DrumSheetVoice.openHiHat => DrumVoiceV1.openHiHat,
    DrumSheetVoice.crash => DrumVoiceV1.crash,
    DrumSheetVoice.ride => DrumVoiceV1.ride,
    DrumSheetVoice.kick => DrumVoiceV1.kick,
  };
}

PatternNoteValueV1? storedValueForSheetNoteValue(DrumSheetNoteValue? value) {
  return switch (value) {
    null => null,
    DrumSheetNoteValue.whole => PatternNoteValueV1.whole,
    DrumSheetNoteValue.half => PatternNoteValueV1.half,
    DrumSheetNoteValue.quarter => PatternNoteValueV1.quarter,
    DrumSheetNoteValue.eighth => PatternNoteValueV1.eighth,
    DrumSheetNoteValue.sixteenth => PatternNoteValueV1.sixteenth,
    DrumSheetNoteValue.thirtySecond => PatternNoteValueV1.thirtySecond,
  };
}

DrumSheetNoteValue? sheetValueForStoredNoteValue(PatternNoteValueV1? value) {
  return switch (value) {
    null => null,
    PatternNoteValueV1.whole => DrumSheetNoteValue.whole,
    PatternNoteValueV1.half => DrumSheetNoteValue.half,
    PatternNoteValueV1.quarter => DrumSheetNoteValue.quarter,
    PatternNoteValueV1.eighth => DrumSheetNoteValue.eighth,
    PatternNoteValueV1.sixteenth => DrumSheetNoteValue.sixteenth,
    PatternNoteValueV1.thirtySecond => DrumSheetNoteValue.thirtySecond,
  };
}
