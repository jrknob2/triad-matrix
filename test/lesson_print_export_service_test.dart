import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_plan_loader.dart';
import 'package:drumcabulary/features/coach/lesson_print_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a printable lesson PDF', () async {
    final LessonPlan plan = await LessonPlanLoader.loadFlowFoundations();
    final Lesson lesson = plan.lessons.last;

    final List<int> bytes = await LessonPrintExportService.buildLessonPdf(
      lessonPlan: plan,
      lesson: lesson,
    );

    expect(bytes.length, greaterThan(1000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
