import 'dart:async';
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../practice/widgets/sheet_notation_display.dart';
import 'lesson_plan.dart';

class LessonSheetNotationSvgRenderer {
  static const String _hostAsset = 'web/sheet_notation/app_host.html';
  static const Duration _loadTimeout = Duration(seconds: 10);

  final WebViewController _controller;
  late final Future<void> _ready;

  LessonSheetNotationSvgRenderer() : _controller = WebViewController() {
    final Completer<void> ready = Completer<void>();
    _ready = ready.future.timeout(
      _loadTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Sheet notation renderer did not load.',
          _loadTimeout,
        );
      },
    );

    _controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (!ready.isCompleted) ready.complete();
          },
          onWebResourceError: (WebResourceError error) {
            if (!ready.isCompleted) {
              ready.completeError(
                StateError(
                  'Sheet notation renderer failed to load: ${error.description}',
                ),
              );
            }
          },
        ),
      )
      ..loadFlutterAsset(_hostAsset);
  }

  Future<Map<String, String>> renderLesson({
    required Lesson lesson,
    required PdfPageFormat pageFormat,
  }) async {
    final Map<String, String> svgsByPatternId = <String, String>{};
    final DrumSheetNoteValue subdivision = _subdivisionForLesson(lesson);
    final double availableWidth = pageFormat.availableWidth.isFinite
        ? pageFormat.availableWidth
        : 520;

    for (final LessonPattern pattern in lesson.patterns) {
      svgsByPatternId[pattern.id] = await renderPattern(
        pattern: pattern,
        subdivision: subdivision,
        availableWidth: availableWidth,
      );
    }

    return svgsByPatternId;
  }

  Future<String> renderPattern({
    required LessonPattern pattern,
    required DrumSheetNoteValue subdivision,
    required double availableWidth,
  }) async {
    await _ready;

    final DrumSheetNotationDocument document =
        DrumSheetNotationDocument.fromPattern(
          pattern.notation,
          subdivision: subdivision,
          lenient: true,
        );
    final String documentJson = jsonEncode(_documentJson(document));
    final String optionsJson = jsonEncode(<String, Object?>{
      'availableWidth': availableWidth.floor(),
      'finalRepeat': true,
      'grouping': _groupingTextFromPattern(pattern.notation),
      'minNoteWidth': 32,
      'staffY': 0,
      'staffHeight': 124,
      'systemGapY': 126,
      'paddingRight': 34,
      'notesPerSystem': 'auto',
    });

    final Object result = await _controller.runJavaScriptReturningResult('''
(() => {
  if (typeof globalThis.renderDrumNotationSvgWithMetadata !== 'function') {
    throw new Error('Drumcabulary sheet notation renderer did not load.');
  }
  const result = globalThis.renderDrumNotationSvgWithMetadata(
    $documentJson,
    $optionsJson
  );
  return result.svg;
})()
''');

    final String svg = _jsString(result);
    if (!svg.trimLeft().startsWith('<svg')) {
      throw StateError('Sheet notation renderer returned invalid SVG.');
    }
    return svg;
  }
}

Map<String, Object?> _documentJson(DrumSheetNotationDocument document) {
  return <String, Object?>{
    'subdivision': document.subdivision.noteValueLabel,
    'measures': <Object?>[
      for (final DrumSheetNotationMeasure measure in document.measures)
        <String, Object?>{
          'notes': <Object?>[
            for (final DrumSheetNotationNote note in measure.notes)
              _noteJson(note),
          ],
        },
    ],
  };
}

Map<String, Object?> _noteJson(DrumSheetNotationNote note) {
  final String sticking = _displayStickingForNote(note);
  return <String, Object?>{
    if (note.value != null) 'value': note.value!.noteValueLabel,
    if (!note.rest)
      'voices': <String>[
        for (final DrumSheetVoice voice in note.voices) voice.id,
      ],
    if (note.rest) 'rest': true,
    if (sticking.isNotEmpty) 'sticking': sticking,
    if (note.accent) 'accent': true,
    if (note.flam) 'flam': true,
    if (note.ghost) 'ghost': true,
    if (note.tie) 'tie': true,
  };
}

String _displayStickingForNote(DrumSheetNotationNote note) {
  final String sticking = note.sticking.trim().toUpperCase();
  if (sticking.isEmpty) return '';
  if (note.rest || note.voices.length <= 1) return sticking;

  if (sticking.length == 1) return sticking;
  if (sticking.contains('R')) return 'R';
  if (sticking.contains('L')) return 'L';
  if (sticking.contains('K')) return 'K';
  if (sticking.contains('F')) return 'F';
  return '';
}

DrumSheetNoteValue _subdivisionForLesson(Lesson lesson) {
  for (final LessonExercise exercise in lesson.exercises) {
    final DrumSheetNoteValue? value = _subdivisionValue(exercise.subdivision);
    if (value != null) return value;
    if (exercise.subdivisionSequence.isNotEmpty) {
      final DrumSheetNoteValue? sequenceValue = _subdivisionValue(
        exercise.subdivisionSequence.first,
      );
      if (sequenceValue != null) return sequenceValue;
    }
  }
  return DrumSheetNoteValue.eighth;
}

DrumSheetNoteValue? _subdivisionValue(String? value) {
  return switch (value) {
    '4' => DrumSheetNoteValue.quarter,
    '8' => DrumSheetNoteValue.eighth,
    '16' => DrumSheetNoteValue.sixteenth,
    '32' => DrumSheetNoteValue.thirtySecond,
    _ => null,
  };
}

String _groupingTextFromPattern(String pattern) {
  final List<String> groups = _topLevelPatternGroups(pattern);
  if (groups.length <= 1) return '';
  final List<String> counts = <String>[];
  for (final String group in groups) {
    final int count = DrumSheetPatternParser.parse(group, lenient: true).length;
    if (count > 0) counts.add('$count');
  }
  return counts.length > 1 ? counts.join(' ') : '';
}

List<String> _topLevelPatternGroups(String pattern) {
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

String _jsString(Object value) {
  if (value is! String) return '$value';
  final String trimmed = value.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    final Object? decoded = jsonDecode(trimmed);
    if (decoded is String) return decoded;
  }
  return value;
}
