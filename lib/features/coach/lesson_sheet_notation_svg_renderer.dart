import 'dart:async';
import 'dart:convert';

import 'package:pdf/pdf.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../practice/widgets/sheet_notation_display.dart';
import 'lesson_notation_document.dart';
import 'lesson_plan.dart';

class RenderedExerciseNotationSection {
  final String? title;
  final String svg;

  const RenderedExerciseNotationSection({
    required this.title,
    required this.svg,
  });
}

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

  Future<Map<String, List<RenderedExerciseNotationSection>>> renderLesson({
    required Lesson lesson,
    required PdfPageFormat pageFormat,
  }) async {
    final Map<String, List<RenderedExerciseNotationSection>> svgsByExerciseId =
        <String, List<RenderedExerciseNotationSection>>{};
    final double availableWidth = pageFormat.availableWidth.isFinite
        ? pageFormat.availableWidth
        : 520;

    for (final LessonExercise exercise in lesson.exercises) {
      svgsByExerciseId[exercise.id] = await renderExercise(
        exercise: exercise,
        availableWidth: availableWidth,
      );
    }

    return svgsByExerciseId;
  }

  Future<List<RenderedExerciseNotationSection>> renderExercise({
    required LessonExercise exercise,
    required double availableWidth,
  }) async {
    await _ready;

    return <RenderedExerciseNotationSection>[
      for (final ExerciseNotationSection section in exercise.notation.sections)
        RenderedExerciseNotationSection(
          title: section.title,
          svg: await _renderSection(
            section: section,
            availableWidth: availableWidth,
          ),
        ),
    ];
  }

  Future<String> _renderSection({
    required ExerciseNotationSection section,
    required double availableWidth,
  }) async {
    final DrumSheetNotationDocument document = documentForNotationSection(
      section,
    );
    final String documentJson = jsonEncode(
      _documentJson(
        document,
        showSticking: shouldShowStickingForNotationSection(section),
      ),
    );
    final String optionsJson = jsonEncode(<String, Object?>{
      'availableWidth': availableWidth.floor(),
      'finalRepeat': true,
      'grouping': groupingTextFromPattern(section.pattern),
      'minNoteWidth': 32,
      'staffY': 34,
      'staffHeight': 124,
      'systemGapY': 126,
      'groupGap': 14,
      'timeSignatureReserve': 52,
      'stemLength': 28,
      'paddingRight': 34,
      'preserveMeasures': true,
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

Map<String, Object?> _documentJson(
  DrumSheetNotationDocument document, {
  required bool showSticking,
}) {
  return <String, Object?>{
    'subdivision': document.subdivision.noteValueLabel,
    'feel': document.feel.name,
    'timeSignature': document.timeSignature,
    if (document.repeatCount != null) 'repeatCount': document.repeatCount,
    'measures': <Object?>[
      for (final DrumSheetNotationMeasure measure in document.measures)
        <String, Object?>{
          'notes': <Object?>[
            for (final DrumSheetNotationNote note in measure.notes)
              _noteJson(note, showSticking: showSticking),
          ],
        },
    ],
  };
}

Map<String, Object?> _noteJson(
  DrumSheetNotationNote note, {
  required bool showSticking,
}) {
  final String sticking = _displayStickingForNote(note);
  return <String, Object?>{
    if (note.value != null) 'value': note.value!.noteValueLabel,
    if (!note.rest)
      'voices': <String>[
        for (final DrumSheetVoice voice in note.voices) voice.id,
      ],
    if (note.rest) 'rest': true,
    if (showSticking && sticking.isNotEmpty) 'sticking': sticking,
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

String _jsString(Object value) {
  if (value is! String) return '$value';
  final String trimmed = value.trim();
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    final Object? decoded = jsonDecode(trimmed);
    if (decoded is String) return decoded;
  }
  return value;
}
