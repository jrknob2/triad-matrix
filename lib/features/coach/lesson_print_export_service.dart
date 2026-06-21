import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'lesson_plan.dart';
import 'lesson_sheet_notation_svg_renderer.dart';

class LessonPrintExportService {
  const LessonPrintExportService._();

  static Future<void> printLesson({
    required LessonPlan lessonPlan,
    required Lesson lesson,
  }) async {
    final LessonSheetNotationSvgRenderer notationRenderer =
        LessonSheetNotationSvgRenderer();
    await Printing.layoutPdf(
      name: _fileNameFor(lessonPlan: lessonPlan, lesson: lesson),
      onLayout: (PdfPageFormat format) async {
        final Map<String, String> notationSvgsByPatternId =
            await notationRenderer.renderLesson(
              lesson: lesson,
              pageFormat: format,
            );
        return buildLessonPdf(
          lessonPlan: lessonPlan,
          lesson: lesson,
          pageFormat: format,
          notationSvgsByPatternId: notationSvgsByPatternId,
        );
      },
    );
  }

  static Future<void> shareLessonPdf({
    required LessonPlan lessonPlan,
    required Lesson lesson,
  }) async {
    final Map<String, String> notationSvgsByPatternId =
        await LessonSheetNotationSvgRenderer().renderLesson(
          lesson: lesson,
          pageFormat: PdfPageFormat.a4,
        );
    final Uint8List bytes = await buildLessonPdf(
      lessonPlan: lessonPlan,
      lesson: lesson,
      notationSvgsByPatternId: notationSvgsByPatternId,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileNameFor(lessonPlan: lessonPlan, lesson: lesson),
    );
  }

  static Future<Uint8List> buildLessonPdf({
    required LessonPlan lessonPlan,
    required Lesson lesson,
    required Map<String, String> notationSvgsByPatternId,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final List<String> missingPatternIds = <String>[
      for (final LessonPattern pattern in lesson.patterns)
        if (!notationSvgsByPatternId.containsKey(pattern.id)) pattern.id,
    ];
    if (missingPatternIds.isNotEmpty) {
      throw StateError(
        'Missing rendered sheet notation for patterns: ${missingPatternIds.join(', ')}',
      );
    }

    final pw.Document document = pw.Document(
      title: '${lessonPlan.title} - ${lesson.title}',
      author: 'Drumcabulary',
      creator: 'Drumcabulary',
    );
    final Map<String, LessonPattern> patternsById = <String, LessonPattern>{
      for (final LessonPattern pattern in lesson.patterns) pattern.id: pattern,
    };

    document.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.fromLTRB(42, 40, 42, 44),
        footer: (pw.Context context) {
          return pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          );
        },
        build: (pw.Context context) {
          return <pw.Widget>[
            pw.Text(
              lessonPlan.title,
              style: pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey700,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              lesson.title,
              style: pw.TextStyle(
                fontSize: 26,
                fontWeight: pw.FontWeight.bold,
                lineSpacing: 2,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              lesson.objective,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
            ),
            pw.SizedBox(height: 14),
            _metadataRow(<String>[
              'Lesson ${lesson.number}',
              _labelFor(lesson.skillFocus),
              '${lesson.estimatedMinutes} min',
            ]),
            pw.SizedBox(height: 22),
            _section('Required Concepts', <pw.Widget>[
              _bulletList(lesson.requiredConcepts),
            ]),
            _section('Patterns', <pw.Widget>[
              for (final LessonPattern pattern in lesson.patterns)
                _patternBlock(pattern, notationSvgsByPatternId[pattern.id]!),
            ]),
            _section('Exercises', <pw.Widget>[
              for (final LessonExercise exercise in lesson.exercises)
                _exerciseBlock(exercise, patternsById),
            ]),
            _section('Coaching Notes', <pw.Widget>[
              _bulletList(lesson.coachingNotes),
            ]),
            _section('Mastery Target', <pw.Widget>[
              _bulletList(lesson.mastery),
            ]),
          ];
        },
      ),
    );

    return document.save();
  }

  static pw.Widget _section(String title, List<pw.Widget> children) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 18),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _patternBlock(LessonPattern pattern, String notationSvg) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.only(left: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            '${pattern.title} (${_labelFor(pattern.role)})',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Container(
            constraints: const pw.BoxConstraints(maxHeight: 98),
            child: pw.SvgImage(svg: notationSvg, fit: pw.BoxFit.contain),
          ),
        ],
      ),
    );
  }

  static pw.Widget _exerciseBlock(
    LessonExercise exercise,
    Map<String, LessonPattern> patternsById,
  ) {
    final List<String> metadata = <String>[
      if (exercise.subdivision != null) 'Subdivision ${exercise.subdivision}',
      if (exercise.subdivisionSequence.isNotEmpty)
        'Sequence ${exercise.subdivisionSequence.join(' to ')}',
      if (exercise.tempo != null)
        '${exercise.tempo!.start}-${exercise.tempo!.target} BPM',
    ];

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            exercise.title,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            exercise.instructions,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
          ),
          if (metadata.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 5),
            pw.Text(
              metadata.join(' | '),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
          if (exercise.flow.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 5),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                for (final FlowStep step in exercise.flow)
                  pw.Text(
                    '- ${patternsById[step.pattern]?.title ?? step.pattern} x${step.repeat}',
                    style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _bulletList(List<String> items) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        for (final String item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(
              '- $item',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
          ),
      ],
    );
  }

  static pw.Widget _metadataRow(List<String> items) {
    return pw.Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <pw.Widget>[
        for (final String item in items)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.5),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(
              item,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
      ],
    );
  }

  static String _labelFor(String value) {
    return value
        .split(RegExp(r'[_\s-]+'))
        .where((String part) => part.isNotEmpty)
        .map((String part) {
          if (part.length == 1) return part.toUpperCase();
          return '${part[0].toUpperCase()}${part.substring(1)}';
        })
        .join(' ');
  }

  static String _fileNameFor({
    required LessonPlan lessonPlan,
    required Lesson lesson,
  }) {
    return '${_slug(lessonPlan.title)}-${lesson.number}-${_slug(lesson.title)}.pdf';
  }

  static String _slug(String value) {
    final String slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'lesson' : slug;
  }
}
