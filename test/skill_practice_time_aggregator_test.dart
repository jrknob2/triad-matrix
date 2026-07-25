import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_progress.dart';
import 'package:drumcabulary/features/progress/skill_practice_time_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aggregates practiced seconds by lesson skill from exercises', () async {
    final LessonContentLibrary library = _library(<Lesson>[
      _lesson(
        id: 'groove-one',
        skill: 'grooves',
        exercises: <String>['a', 'b'],
      ),
      _lesson(id: 'groove-two', skill: 'grooves', exercises: <String>['c']),
      _lesson(id: 'timing-one', skill: 'timing', exercises: <String>['d']),
    ]);
    final LessonProgressService progress = LessonProgressService(
      MemoryLessonProgressStore(),
    );
    await progress.load();

    await progress.completeExercise(
      library.lessonsById['groove-one']!,
      'a',
      practicedDuration: const Duration(minutes: 10),
    );
    await progress.completeExercise(
      library.lessonsById['groove-one']!,
      'b',
      practicedDuration: const Duration(minutes: 5),
    );
    await progress.completeExercise(
      library.lessonsById['groove-two']!,
      'c',
      practicedDuration: const Duration(minutes: 15),
    );
    await progress.completeExercise(
      library.lessonsById['timing-one']!,
      'd',
      practicedDuration: const Duration(minutes: 60),
    );

    final SkillPracticeTimeSnapshot snapshot =
        const SkillPracticeTimeAggregator().build(
          library: library,
          progressService: progress,
        );

    final SkillPracticeTimeValue timing = _value(snapshot, 'timing');
    final SkillPracticeTimeValue grooves = _value(snapshot, 'grooves');
    expect(timing.practicedSeconds, 3600);
    expect(timing.normalizedValue, 1);
    expect(timing.practicedExerciseCount, 1);
    expect(timing.practicedLessonCount, 1);
    expect(grooves.practicedSeconds, 1800);
    expect(grooves.normalizedValue, 0.5);
    expect(grooves.practicedExerciseCount, 3);
    expect(grooves.practicedLessonCount, 2);
  });

  test('keeps unpracticed skills visible and avoids divide by zero', () async {
    final LessonContentLibrary library = _library(<Lesson>[
      _lesson(id: 'rudiment-one', skill: 'rudiments', exercises: <String>['a']),
      _lesson(id: 'groove-one', skill: 'grooves', exercises: <String>['b']),
    ]);
    final LessonProgressService progress = LessonProgressService(
      MemoryLessonProgressStore(),
    );
    await progress.load();

    final SkillPracticeTimeSnapshot snapshot =
        const SkillPracticeTimeAggregator().build(
          library: library,
          progressService: progress,
        );

    expect(snapshot.hasPractice, isFalse);
    expect(
      snapshot.values.map((SkillPracticeTimeValue value) => value.skillId),
      <String>['rudiments', 'grooves'],
    );
    for (final SkillPracticeTimeValue value in snapshot.values) {
      expect(value.practicedSeconds, 0);
      expect(value.normalizedValue, 0);
      expect(value.practicedExerciseCount, 0);
      expect(value.practicedLessonCount, 0);
    }
  });

  test('uses stable curriculum skill ordering', () async {
    final LessonContentLibrary library = _library(<Lesson>[
      _lesson(id: 'fill-one', skill: 'fills', exercises: <String>['a']),
      _lesson(id: 'timing-one', skill: 'timing', exercises: <String>['b']),
      _lesson(id: 'reading-one', skill: 'reading', exercises: <String>['c']),
    ]);
    final LessonProgressService progress = LessonProgressService(
      MemoryLessonProgressStore(),
    );
    await progress.load();

    final SkillPracticeTimeSnapshot snapshot =
        const SkillPracticeTimeAggregator().build(
          library: library,
          progressService: progress,
        );

    expect(
      snapshot.values.map((SkillPracticeTimeValue value) => value.skillId),
      <String>['timing', 'reading', 'fills'],
    );
  });

  test('labels skill ids safely for display', () {
    expect(curriculumSkillLabel('grooves'), 'Grooves');
    expect(curriculumSkillLabel('odd-meter'), 'Odd Meter');
    expect(curriculumSkillLabel('hand_focus'), 'Hand Focus');
  });
}

SkillPracticeTimeValue _value(
  SkillPracticeTimeSnapshot snapshot,
  String skillId,
) {
  return snapshot.values.singleWhere(
    (SkillPracticeTimeValue value) => value.skillId == skillId,
  );
}

LessonContentLibrary _library(List<Lesson> lessons) {
  final List<ContentLevel> levels = <ContentLevel>[
    ContentLevel(
      id: 'beginner',
      title: 'Beginner',
      lessonFiles: <String>[
        for (final Lesson lesson in lessons)
          if (lesson.level == 'beginner') '${lesson.id}.yaml',
      ],
    ),
  ];
  return LessonContentLibrary(
    index: ContentIndex(version: 1, levels: levels),
    lessonsById: <String, Lesson>{
      for (final Lesson lesson in lessons) lesson.id: lesson,
    },
    lessonsByLevelId: <String, List<Lesson>>{
      'beginner': lessons
          .where((Lesson lesson) => lesson.level == 'beginner')
          .toList(growable: false),
    },
  );
}

Lesson _lesson({
  required String id,
  required String skill,
  required List<String> exercises,
}) {
  return Lesson(
    id: id,
    title: id,
    level: 'beginner',
    skill: skill,
    order: 1,
    estimatedMinutes: 10,
    overview: 'Overview.',
    objective: 'Objective.',
    exercises: <LessonExercise>[
      for (final String exerciseId in exercises) _exercise(exerciseId),
    ],
  );
}

LessonExercise _exercise(String id) {
  return LessonExercise(
    id: id,
    title: id,
    why: 'Why.',
    what: 'What.',
    how: 'How.',
    notation: const ExerciseNotation(
      sections: <ExerciseNotationSection>[
        ExerciseNotationSection(pattern: '[S:R]'),
      ],
    ),
  );
}
