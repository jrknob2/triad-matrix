import '../practice/widgets/sheet_notation_display.dart';
import 'lesson_plan.dart';

DrumSheetNotationDocument documentForNotationSection(
  ExerciseNotationSection section, {
  bool lenient = true,
}) {
  final DrumSheetNotationDocument document =
      DrumSheetNotationDocument.fromPattern(
        section.pattern,
        subdivision: subdivisionForNotationSection(section),
        feel: feelForNotationSection(section),
        timeSignature: section.timeSignature,
        repeatCount: section.repeatCount,
        lenient: lenient,
      );
  final String? sticking = section.sticking;
  if (sticking == null) return document;
  return _documentWithExplicitSticking(document, stickingLabels(sticking));
}

bool shouldShowStickingForNotationSection(ExerciseNotationSection section) {
  return section.sticking != null;
}

DrumSheetNoteValue subdivisionForNotationSection(
  ExerciseNotationSection section,
) {
  return _subdivisionValue(section.subdivision) ?? DrumSheetNoteValue.eighth;
}

DrumSheetFeel feelForNotationSection(ExerciseNotationSection section) {
  return _isTripletSubdivision(section.subdivision)
      ? DrumSheetFeel.triplet
      : DrumSheetFeel.straight;
}

List<String> stickingLabels(String sticking) {
  final String trimmed = sticking.trim();
  if (trimmed.isEmpty) return const <String>[];
  final List<String> spaced = trimmed
      .split(RegExp(r'\s+'))
      .where((String item) => item.isNotEmpty)
      .toList(growable: false);
  if (spaced.length > 1) return spaced;
  final Iterable<RegExpMatch> cueMatches = RegExp(
    r'\([RLrl]\)\^?[RLrl]|[RrLlKkFfXx_]',
  ).allMatches(trimmed);
  final List<String> cueLabels = <String>[
    for (final RegExpMatch match in cueMatches) match.group(0)!.toUpperCase(),
  ];
  if (cueLabels.isNotEmpty && cueLabels.join() == trimmed.toUpperCase()) {
    return cueLabels;
  }
  return trimmed
      .split('')
      .where((String item) => item.trim().isNotEmpty)
      .toList(growable: false);
}

String groupingTextFromPattern(String pattern) {
  final List<String> groups = topLevelPatternGroups(pattern);
  if (groups.length <= 1) return '';
  final List<String> counts = <String>[];
  for (final String group in groups) {
    final int count = DrumSheetPatternParser.parse(group, lenient: true).length;
    if (count > 0) counts.add('$count');
  }
  return counts.length > 1 ? counts.join(' ') : '';
}

List<String> topLevelPatternGroups(String pattern) {
  final List<String> groups = <String>[];
  final StringBuffer current = StringBuffer();
  int bracketDepth = 0;
  int parenDepth = 0;
  for (int index = 0; index < pattern.length; index += 1) {
    final String char = pattern[index];
    if (char == '[') bracketDepth += 1;
    if (char == ']' && bracketDepth > 0) bracketDepth -= 1;
    if (char == '(') parenDepth += 1;
    if (char == ')' && parenDepth > 0) parenDepth -= 1;
    if (char.trim().isEmpty && bracketDepth == 0 && parenDepth == 0) {
      if (current.isNotEmpty) {
        groups.add(current.toString());
        current.clear();
      }
      continue;
    }
    current.write(char);
  }
  if (current.isNotEmpty) groups.add(current.toString());
  return groups;
}

void validateNotationSection(
  ExerciseNotationSection section, {
  required String path,
}) {
  final DrumSheetNotationDocument document = documentForNotationSection(
    section,
    lenient: false,
  );
  final String? sticking = section.sticking;
  if (sticking == null) return;
  final int playableNoteCount = document.flattenedNotes
      .where((DrumSheetNotationNote note) => !note.rest)
      .length;
  final int labelCount = stickingLabels(sticking).length;
  if (playableNoteCount != labelCount) {
    throw LessonPlanLoadException(
      '$path.sticking has $labelCount labels but notation has $playableNoteCount playable notes.',
    );
  }
}

DrumSheetNotationDocument _documentWithExplicitSticking(
  DrumSheetNotationDocument document,
  List<String> labels,
) {
  int labelIndex = 0;
  return DrumSheetNotationDocument(
    subdivision: document.subdivision,
    feel: document.feel,
    timeSignature: document.timeSignature,
    repeatCount: document.repeatCount,
    measures: <DrumSheetNotationMeasure>[
      for (final DrumSheetNotationMeasure measure in document.measures)
        DrumSheetNotationMeasure(
          notes: <DrumSheetNotationNote>[
            for (final DrumSheetNotationNote note in measure.notes)
              if (note.rest)
                note
              else
                note.copyWith(
                  sticking: labelIndex < labels.length
                      ? labels[labelIndex++].toUpperCase()
                      : note.sticking,
                ),
          ],
        ),
    ],
  );
}

DrumSheetNoteValue? _subdivisionValue(String? value) {
  final String? normalized = _normalizedSubdivision(value);
  return switch (normalized) {
    '4' => DrumSheetNoteValue.quarter,
    '8' => DrumSheetNoteValue.eighth,
    'triplet' || '8_triplet' || 'eighth_triplet' => DrumSheetNoteValue.eighth,
    '16' => DrumSheetNoteValue.sixteenth,
    '16_triplet' ||
    'sixteenth_triplet' ||
    'sextuplet' => DrumSheetNoteValue.sixteenth,
    '32' => DrumSheetNoteValue.thirtySecond,
    _ => null,
  };
}

bool _isTripletSubdivision(String? value) {
  final String? normalized = _normalizedSubdivision(value);
  return normalized == 'triplet' ||
      normalized == '8_triplet' ||
      normalized == 'eighth_triplet' ||
      normalized == '16_triplet' ||
      normalized == 'sixteenth_triplet' ||
      normalized == 'sextuplet';
}

String? _normalizedSubdivision(String? value) {
  return value?.trim().toLowerCase().replaceAll('-', '_');
}
