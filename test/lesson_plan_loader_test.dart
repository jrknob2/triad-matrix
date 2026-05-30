import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_plan_loader.dart';
import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the Flow Foundations lesson plan from assets', () async {
    final LessonPlan plan = await LessonPlanLoader.loadFlowFoundations();

    expect(plan.id, 'flow-foundations');
    expect(plan.title, 'Flow Foundations');
    expect(plan.lessons, hasLength(8));
    expect(plan.lessons.map((Lesson lesson) => lesson.number), <int>[
      1,
      2,
      3,
      4,
      5,
      6,
      7,
      8,
    ]);
    expect(plan.lessons.first.title, 'Notation Basics');
    expect(plan.lessons.first.patterns.first.notation, 'R L R L');
    expect(plan.lessons[5].exercises.single.flow, hasLength(2));

    for (final Lesson lesson in plan.lessons) {
      for (final LessonPattern pattern in lesson.patterns) {
        expect(
          () => DrumSheetNotationDocument.fromPattern(
            pattern.notation,
            lenient: true,
          ),
          returnsNormally,
          reason: '${lesson.id}/${pattern.id} must be renderable notation.',
        );
      }
    }
  });

  test('rejects missing required fields', () {
    expect(
      () => LessonPlanLoader.parse('''
lesson_plan:
  id: broken-plan
  title: Broken Plan
  subtitle: Missing lessons should fail.
  version: 1
'''),
      throwsA(
        isA<LessonPlanLoadException>().having(
          (LessonPlanLoadException error) => error.message,
          'message',
          contains('lesson_plan.lessons'),
        ),
      ),
    );
  });
}
