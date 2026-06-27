import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'lesson_plan.dart';
import 'lesson_sheet_notation_svg_renderer.dart';

class LessonPrintExportService {
  const LessonPrintExportService._();

  static Future<void> printLesson({required Lesson lesson}) async {
    final LessonSheetNotationSvgRenderer notationRenderer =
        LessonSheetNotationSvgRenderer();
    await Printing.layoutPdf(
      name: _fileNameFor(lesson: lesson),
      onLayout: (PdfPageFormat format) async {
        final Map<String, List<RenderedExerciseNotationSection>>
        notationSvgsByExerciseId = await notationRenderer.renderLesson(
          lesson: lesson,
          pageFormat: format,
        );
        return buildLessonPdf(
          lesson: lesson,
          pageFormat: format,
          notationSvgsByExerciseId: notationSvgsByExerciseId,
        );
      },
    );
  }

  static Future<void> shareLessonPdf({required Lesson lesson}) async {
    final Map<String, List<RenderedExerciseNotationSection>>
    notationSvgsByExerciseId = await LessonSheetNotationSvgRenderer()
        .renderLesson(lesson: lesson, pageFormat: PdfPageFormat.a4);
    final Uint8List bytes = await buildLessonPdf(
      lesson: lesson,
      notationSvgsByExerciseId: notationSvgsByExerciseId,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: _fileNameFor(lesson: lesson),
    );
  }

  static Future<Uint8List> buildLessonPdf({
    required Lesson lesson,
    required Map<String, List<RenderedExerciseNotationSection>>
    notationSvgsByExerciseId,
    PdfPageFormat pageFormat = PdfPageFormat.a4,
  }) async {
    final List<String> missingExerciseIds = <String>[
      for (final LessonExercise exercise in lesson.exercises)
        if (!notationSvgsByExerciseId.containsKey(exercise.id)) exercise.id,
    ];
    if (missingExerciseIds.isNotEmpty) {
      throw StateError(
        'Missing rendered sheet notation for exercises: ${missingExerciseIds.join(', ')}',
      );
    }

    final pw.Document document = pw.Document(
      title: lesson.title,
      author: 'Drumcabulary',
      creator: 'Drumcabulary',
    );

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
              '${_labelFor(lesson.level)} / ${_labelFor(lesson.skill)}',
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
              lesson.overview,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              lesson.objective,
              style: const pw.TextStyle(fontSize: 12, lineSpacing: 3),
            ),
            pw.SizedBox(height: 14),
            _metadataRow(<String>[
              'Lesson ${lesson.order}',
              '${lesson.estimatedMinutes} min',
            ]),
            pw.SizedBox(height: 22),
            _section('Progressive Exercises', <pw.Widget>[
              for (int index = 0; index < lesson.exercises.length; index += 1)
                _exerciseBlock(
                  number: index + 1,
                  exercise: lesson.exercises[index],
                  renderedSections:
                      notationSvgsByExerciseId[lesson.exercises[index].id]!,
                ),
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

  static pw.Widget _exerciseBlock({
    required int number,
    required LessonExercise exercise,
    required List<RenderedExerciseNotationSection> renderedSections,
  }) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 16),
      padding: const pw.EdgeInsets.only(left: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(left: pw.BorderSide(color: PdfColors.grey400)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Text(
            '$number. ${exercise.title}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 5),
          _labeledText('Why', exercise.why),
          _labeledText('What', exercise.what),
          _labeledText('How', exercise.how),
          if (exercise.tempo != null) ...<pw.Widget>[
            pw.SizedBox(height: 4),
            pw.Text(
              '${exercise.tempo!.start}-${exercise.tempo!.target} BPM',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 6),
          for (final RenderedExerciseNotationSection section
              in renderedSections) ...<pw.Widget>[
            if (renderedSections.length > 1 && section.title != null) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                section.title!,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            pw.SizedBox(height: 3),
            pw.Container(
              constraints: const pw.BoxConstraints(maxHeight: 98),
              child: pw.SvgImage(svg: section.svg, fit: pw.BoxFit.contain),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _labeledText(String label, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.RichText(
        text: pw.TextSpan(
          children: <pw.TextSpan>[
            pw.TextSpan(
              text: '$label: ',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.TextSpan(
              text: text,
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
            ),
          ],
        ),
      ),
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

  static String _fileNameFor({required Lesson lesson}) {
    return '${_slug(lesson.level)}-${_slug(lesson.skill)}-${lesson.order}-${_slug(lesson.title)}.pdf';
  }

  static String _slug(String value) {
    final String slug = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return slug.isEmpty ? 'lesson' : slug;
  }
}
