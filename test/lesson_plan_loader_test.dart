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
    expect(plan.lessons.first.title, 'Groove Foundation');
    expect(
      plan.lessons.map((Lesson lesson) => lesson.id),
      isNot(contains('notation-basics')),
    );
    expect(plan.lessons.first.patterns.first.title, 'Basic Rock Groove');
    expect(plan.lessons[4].exercises.single.flow, hasLength(2));

    final Lesson tripletVocabulary = plan.lessons.last;
    expect(tripletVocabulary.id, 'triplet-vocabulary-1');
    expect(tripletVocabulary.title, 'Triplet Vocabulary 1');
    expect(tripletVocabulary.patterns, hasLength(14));
    expect(tripletVocabulary.exercises, hasLength(19));

    final Map<String, LessonPattern> patternsById = <String, LessonPattern>{
      for (final LessonPattern pattern in tripletVocabulary.patterns)
        pattern.id: pattern,
    };
    expect(patternsById['triplet-vocab-a']!.notation, 'R(L)(L)');
    expect(patternsById['triplet-vocab-b']!.notation, 'RLK');
    expect(patternsById['triplet-vocab-c']!.notation, 'RKL');
    expect(patternsById['triplet-vocab-d']!.notation, 'KRL');
    expect(patternsById['triplet-vocab-f']!.notation, '(R)(R)L');
    expect(patternsById['six-ab']!.notation, 'R(L)(L) RLK');
    expect(patternsById['six-ad']!.notation, 'R(L)(L) KRL');
    expect(patternsById['six-fc']!.notation, '(R)(R)L RKL');
    expect(
      tripletVocabulary.exercises.map(
        (LessonExercise exercise) => exercise.title,
      ),
      containsAll(<String>[
        'Move A Between Voices',
        'Move F Between Voices',
        'Voice A + D Around The Kit',
      ]),
    );

    for (final Lesson lesson in plan.lessons) {
      final Set<String> lessonPatternIds = lesson.patterns
          .map((LessonPattern pattern) => pattern.id)
          .toSet();
      for (final LessonExercise exercise in lesson.exercises) {
        for (final FlowStep step in exercise.flow) {
          expect(
            lessonPatternIds,
            contains(step.pattern),
            reason:
                '${lesson.id}/${exercise.title} references ${step.pattern}.',
          );
        }
      }
    }

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
