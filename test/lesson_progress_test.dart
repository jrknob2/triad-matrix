import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('opening a lesson moves not started progress to in progress', () async {
    final MemoryLessonProgressStore store = MemoryLessonProgressStore();
    final LessonProgressService service = LessonProgressService(store);
    final DateTime openedAt = DateTime.utc(2026, 6, 26, 12);

    await service.load();
    final LessonProgress progress = await service.openLesson(
      'money-beat',
      at: openedAt,
    );

    expect(progress.lessonId, 'money-beat');
    expect(progress.status, LessonProgressStatus.inProgress);
    expect(progress.startedAt, openedAt);
    expect(progress.lastOpenedAt, openedAt);
    expect(progress.completedAt, isNull);
  });

  test('starting Practice It marks an exercise in progress', () async {
    final Lesson lesson = _lesson();
    final MemoryLessonProgressStore store = MemoryLessonProgressStore();
    final LessonProgressService service = LessonProgressService(store);
    final DateTime startedAt = DateTime.utc(2026, 6, 26, 12);

    await service.load();
    final ExerciseProgress progress = await service.startExercise(
      lesson,
      'one',
      at: startedAt,
    );

    expect(progress.status, LessonProgressStatus.inProgress);
    expect(progress.startedAt, startedAt);
    expect(
      service.progressForLesson(lesson.id).status,
      LessonProgressStatus.inProgress,
    );
  });

  test(
    'completing exercises accumulates practiced time and completes lesson',
    () async {
      final Lesson lesson = _lesson();
      final MemoryLessonProgressStore store = MemoryLessonProgressStore();
      final LessonProgressService service = LessonProgressService(store);

      await service.load();
      await service.startExercise(
        lesson,
        'one',
        at: DateTime.utc(2026, 6, 26, 12),
      );
      ExerciseProgress exerciseProgress = await service.completeExercise(
        lesson,
        'one',
        at: DateTime.utc(2026, 6, 26, 12, 2),
        practicedDuration: const Duration(minutes: 2),
      );

      expect(exerciseProgress.status, LessonProgressStatus.completed);
      expect(exerciseProgress.practicedSeconds, 120);
      expect(
        service.progressForLesson(lesson.id).status,
        LessonProgressStatus.inProgress,
      );
      expect(service.progressForLesson(lesson.id).practicedSeconds, 120);

      await service.startExercise(
        lesson,
        'two',
        at: DateTime.utc(2026, 6, 26, 12, 3),
      );
      exerciseProgress = await service.completeExercise(
        lesson,
        'two',
        at: DateTime.utc(2026, 6, 26, 12, 6),
        practicedDuration: const Duration(minutes: 3),
      );

      expect(exerciseProgress.status, LessonProgressStatus.completed);
      final LessonProgress lessonProgress = service.progressForLesson(
        lesson.id,
      );
      expect(lessonProgress.status, LessonProgressStatus.completed);
      expect(lessonProgress.practicedSeconds, 300);
      expect(lessonProgress.completedAt, DateTime.utc(2026, 6, 26, 12, 6));
    },
  );

  test(
    'derives level progress summary and stores level practiced time',
    () async {
      final ContentLevel level = ContentLevel(
        id: 'beginner',
        title: 'Beginner',
        lessonFiles: const <String>['lessons/test.yaml'],
      );
      final Lesson lesson = _lesson();
      final MemoryLessonProgressStore store = MemoryLessonProgressStore();
      final LessonProgressService service = LessonProgressService(store);

      await service.load();
      LevelProgressSummary summary = service.summaryForLevel(level, <Lesson>[
        lesson,
      ]);
      expect(summary.status, LessonProgressStatus.notStarted);
      expect(summary.practicedSeconds, 0);
      expect(summary.showsCompletionIndicator, isFalse);

      await service.startExercise(lesson, 'one');
      await service.completeExercise(
        lesson,
        'one',
        practicedDuration: const Duration(minutes: 2),
      );
      await service.startExercise(lesson, 'two');
      await service.completeExercise(
        lesson,
        'two',
        practicedDuration: const Duration(minutes: 3),
      );

      summary = service.summaryForLevel(level, <Lesson>[lesson]);
      expect(summary.status, LessonProgressStatus.completed);
      expect(summary.completedLessons, 1);
      expect(summary.totalLessons, 1);
      expect(summary.practicedSeconds, 300);
      expect(summary.showsCompletionIndicator, isTrue);
    },
  );

  test('serializes progress statuses with content-safe names', () {
    final LessonProgress progress = LessonProgress(
      lessonId: 'money-beat',
      status: LessonProgressStatus.inProgress,
      startedAt: DateTime.utc(2026, 6, 26, 12),
    );

    final Map<String, Object?> json = progress.toJson();
    expect(json['status'], 'in_progress');

    final LessonProgress restored = LessonProgress.fromJson(json);
    expect(restored.status, LessonProgressStatus.inProgress);
    expect(restored.startedAt, DateTime.utc(2026, 6, 26, 12));
  });
}

Lesson _lesson() {
  return Lesson(
    id: 'money-beat',
    title: 'The Money Beat',
    level: 'beginner',
    skill: 'grooves',
    order: 1,
    estimatedMinutes: 20,
    overview: 'Learn the beat.',
    objective: 'Build the beat.',
    exercises: <LessonExercise>[_exercise('one'), _exercise('two')],
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
        ExerciseNotationSection(pattern: 'R L'),
      ],
    ),
  );
}
