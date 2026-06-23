import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_plan_loader.dart';
import 'package:drumcabulary/features/practice/widgets/sheet_notation_display.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the Flow Foundations lesson plan from assets', () async {
    final LessonPlan plan = await LessonPlanLoader.loadFlowFoundations();
    Lesson lessonById(String id) {
      return plan.lessons.singleWhere((Lesson lesson) => lesson.id == id);
    }

    expect(plan.id, 'flow-foundations');
    expect(plan.title, 'Flow Foundations');
    expect(plan.lessons, hasLength(9));
    expect(
      plan.lessons.map((Lesson lesson) => lesson.number),
      List<int>.generate(plan.lessons.length, (int index) => index + 1),
    );
    expect(plan.lessons.first.title, 'Groove Foundation');
    expect(
      plan.lessons.map((Lesson lesson) => lesson.id),
      isNot(contains('notation-basics')),
    );
    expect(
      plan.lessons.map((Lesson lesson) => lesson.id),
      contains('the-money-beat'),
    );
    expect(
      lessonById('groove-foundation').patterns.first.title,
      'Basic Rock Groove',
    );
    expect(
      lessonById('groove-to-fill-flow').exercises.single.flow,
      hasLength(2),
    );

    final Lesson moneyBeat = lessonById('the-money-beat');
    expect(moneyBeat.number, 2);
    expect(moneyBeat.title, 'The Money Beat');
    expect(moneyBeat.patterns, hasLength(3));
    expect(moneyBeat.exercises, hasLength(3));

    final Map<String, LessonPattern> moneyPatternsById =
        <String, LessonPattern>{
          for (final LessonPattern pattern in moneyBeat.patterns)
            pattern.id: pattern,
        };
    expect(
      moneyPatternsById['money-beat-one-bar']!.notation,
      '[HH K:R] [HH:R] [HH S:R] [HH:R] [HH K:R] [HH:R] [HH S:R] [HH:R]',
    );
    final List<DrumSheetNotationNote> moneyBeatNotes =
        DrumSheetNotationDocument.fromPattern(
          moneyPatternsById['money-beat-four-bars']!.notation,
        ).flattenedNotes;
    expect(moneyBeatNotes, hasLength(32));
    expect(moneyBeatNotes[0].voices, <DrumSheetVoice>[
      DrumSheetVoice.hihat,
      DrumSheetVoice.kick,
    ]);
    expect(moneyBeatNotes[2].voices, <DrumSheetVoice>[
      DrumSheetVoice.hihat,
      DrumSheetVoice.snare,
    ]);
    expect(moneyBeatNotes[24].sticking, 'XK');
    expect(moneyBeatNotes[24].voices, <DrumSheetVoice>[
      DrumSheetVoice.crash,
      DrumSheetVoice.kick,
    ]);
    expect(moneyBeatNotes[28].voices, <DrumSheetVoice>[
      DrumSheetVoice.hihat,
      DrumSheetVoice.kick,
    ]);

    final Lesson tripletVocabulary = lessonById('triplet-vocabulary-1');
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
