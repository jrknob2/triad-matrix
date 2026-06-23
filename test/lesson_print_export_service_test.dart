import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_plan_loader.dart';
import 'package:drumcabulary/features/coach/lesson_print_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a printable lesson PDF', () async {
    final LessonPlan plan = await LessonPlanLoader.loadFlowFoundations();
    final Lesson lesson = plan.lessons.singleWhere(
      (Lesson lesson) => lesson.id == 'the-money-beat',
    );
    final Map<String, String> notationSvgsByPatternId = <String, String>{
      for (final LessonPattern pattern in lesson.patterns)
        pattern.id: '''
<svg xmlns="http://www.w3.org/2000/svg" width="240" height="60" viewBox="0 0 240 60">
  <line x1="12" y1="20" x2="228" y2="20" stroke="#17130f" stroke-width="1"/>
  <line x1="12" y1="30" x2="228" y2="30" stroke="#17130f" stroke-width="1"/>
  <line x1="12" y1="40" x2="228" y2="40" stroke="#17130f" stroke-width="1"/>
  <circle cx="60" cy="30" r="6" fill="#17130f"/>
  <circle cx="96" cy="30" r="6" fill="#17130f"/>
  <circle cx="132" cy="30" r="6" fill="#17130f"/>
</svg>
''',
    };

    final List<int> bytes = await LessonPrintExportService.buildLessonPdf(
      lessonPlan: plan,
      lesson: lesson,
      notationSvgsByPatternId: notationSvgsByPatternId,
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('refuses to export when rendered notation is missing', () async {
    final LessonPlan plan = await LessonPlanLoader.loadFlowFoundations();
    final Lesson lesson = plan.lessons.singleWhere(
      (Lesson lesson) => lesson.id == 'the-money-beat',
    );

    expect(
      () => LessonPrintExportService.buildLessonPdf(
        lessonPlan: plan,
        lesson: lesson,
        notationSvgsByPatternId: const <String, String>{},
      ),
      throwsStateError,
    );
  });
}
