import 'package:flutter/foundation.dart';

import '../coach/lesson_plan.dart';
import '../coach/lesson_progress.dart';

enum PracticeInsightsLens { practiceTime, exercisesCompleted }

@immutable
class SkillProgressLensValue {
  final String skillId;
  final String label;
  final int practicedSeconds;
  final int practicedExerciseCount;
  final int practicedLessonCount;
  final int completedExerciseCount;
  final int totalExerciseCount;
  final int completedLessonCount;
  final double normalizedValue;

  const SkillProgressLensValue({
    required this.skillId,
    required this.label,
    required this.practicedSeconds,
    required this.practicedExerciseCount,
    required this.practicedLessonCount,
    required this.completedExerciseCount,
    required this.totalExerciseCount,
    required this.completedLessonCount,
    required this.normalizedValue,
  });

  bool get hasPractice => practicedSeconds > 0;
  bool get hasCompletions => completedExerciseCount > 0;
}

@immutable
class SkillProgressLensSnapshot {
  final PracticeInsightsLens lens;
  final List<SkillProgressLensValue> values;

  const SkillProgressLensSnapshot({required this.lens, required this.values});

  bool get hasSkills => values.isNotEmpty;

  bool get hasMetricData {
    return switch (lens) {
      PracticeInsightsLens.practiceTime => values.any(
        (SkillProgressLensValue value) => value.hasPractice,
      ),
      PracticeInsightsLens.exercisesCompleted => values.any(
        (SkillProgressLensValue value) => value.hasCompletions,
      ),
    };
  }

  int get totalPracticedSeconds => values.fold<int>(
    0,
    (int total, SkillProgressLensValue value) => total + value.practicedSeconds,
  );

  int get totalCompletedExercises => values.fold<int>(
    0,
    (int total, SkillProgressLensValue value) =>
        total + value.completedExerciseCount,
  );
}

class SkillProgressLensAggregator {
  const SkillProgressLensAggregator();

  SkillProgressLensSnapshot build({
    required PracticeInsightsLens lens,
    required LessonContentLibrary library,
    required LessonProgressService progressService,
  }) {
    final List<String> orderedSkillIds = _orderedSkillIds(library);
    final Map<String, _SkillProgressAccumulator> accumulators =
        <String, _SkillProgressAccumulator>{
          for (final String skillId in orderedSkillIds)
            skillId: _SkillProgressAccumulator(skillId),
        };

    for (final Lesson lesson in _orderedLessons(library)) {
      final _SkillProgressAccumulator accumulator = accumulators.putIfAbsent(
        lesson.skill,
        () => _SkillProgressAccumulator(lesson.skill),
      );

      bool lessonHasPracticedExercise = false;
      bool lessonHasCompletedExercise = false;
      for (final LessonExercise exercise in lesson.exercises) {
        final ExerciseProgress progress = progressService.progressForExercise(
          lessonId: lesson.id,
          exerciseId: exercise.id,
        );
        accumulator.totalExerciseCount += 1;

        final int practicedSeconds = progress.practicedSeconds;
        accumulator.practicedSeconds += practicedSeconds;
        if (practicedSeconds > 0) {
          accumulator.practicedExerciseCount += 1;
          lessonHasPracticedExercise = true;
        }

        if (progress.status == LessonProgressStatus.completed) {
          accumulator.completedExerciseCount += 1;
          lessonHasCompletedExercise = true;
        }
      }
      if (lessonHasPracticedExercise) {
        accumulator.practicedLessonIds.add(lesson.id);
      }
      if (lessonHasCompletedExercise) {
        accumulator.completedLessonIds.add(lesson.id);
      }
    }

    final int maxPracticedSeconds = accumulators.values.fold<int>(
      0,
      (int max, _SkillProgressAccumulator value) =>
          value.practicedSeconds > max ? value.practicedSeconds : max,
    );

    return SkillProgressLensSnapshot(
      lens: lens,
      values: <SkillProgressLensValue>[
        for (final String skillId in orderedSkillIds)
          _valueFor(
            accumulators[skillId]!,
            lens: lens,
            maxPracticedSeconds: maxPracticedSeconds,
          ),
      ],
    );
  }

  List<String> _orderedSkillIds(LessonContentLibrary library) {
    final List<String> result = <String>[];
    void add(String skillId) {
      if (skillId.trim().isNotEmpty && !result.contains(skillId)) {
        result.add(skillId);
      }
    }

    for (final ContentLevel level in library.index.levels) {
      for (final String skillId in library.skillsForLevel(level.id)) {
        add(skillId);
      }
    }
    for (final Lesson lesson in _orderedLessons(library)) {
      add(lesson.skill);
    }
    return result;
  }

  List<Lesson> _orderedLessons(LessonContentLibrary library) {
    return <Lesson>[
      for (final ContentLevel level in library.index.levels)
        ...library.lessonsForLevel(level.id),
    ];
  }

  SkillProgressLensValue _valueFor(
    _SkillProgressAccumulator accumulator, {
    required PracticeInsightsLens lens,
    required int maxPracticedSeconds,
  }) {
    final double normalizedValue = switch (lens) {
      PracticeInsightsLens.practiceTime =>
        maxPracticedSeconds == 0
            ? 0
            : accumulator.practicedSeconds / maxPracticedSeconds,
      PracticeInsightsLens.exercisesCompleted =>
        accumulator.totalExerciseCount == 0
            ? 0
            : accumulator.completedExerciseCount /
                  accumulator.totalExerciseCount,
    };

    return SkillProgressLensValue(
      skillId: accumulator.skillId,
      label: curriculumSkillLabel(accumulator.skillId),
      practicedSeconds: accumulator.practicedSeconds,
      practicedExerciseCount: accumulator.practicedExerciseCount,
      practicedLessonCount: accumulator.practicedLessonIds.length,
      completedExerciseCount: accumulator.completedExerciseCount,
      totalExerciseCount: accumulator.totalExerciseCount,
      completedLessonCount: accumulator.completedLessonIds.length,
      normalizedValue: normalizedValue,
    );
  }
}

String curriculumSkillLabel(String skillId) {
  return skillId
      .trim()
      .split(RegExp(r'[-_\s]+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        if (part.length == 1) return part.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}

class _SkillProgressAccumulator {
  final String skillId;
  int practicedSeconds = 0;
  int practicedExerciseCount = 0;
  int completedExerciseCount = 0;
  int totalExerciseCount = 0;
  final Set<String> practicedLessonIds = <String>{};
  final Set<String> completedLessonIds = <String>{};

  _SkillProgressAccumulator(this.skillId);
}
