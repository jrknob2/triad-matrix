import 'package:flutter/foundation.dart';

import '../coach/lesson_plan.dart';
import '../coach/lesson_progress.dart';

enum PracticePortraitLens { practiceTime }

@immutable
class SkillPracticeTimeValue {
  final String skillId;
  final String label;
  final int practicedSeconds;
  final double normalizedValue;
  final int practicedExerciseCount;
  final int practicedLessonCount;

  const SkillPracticeTimeValue({
    required this.skillId,
    required this.label,
    required this.practicedSeconds,
    required this.normalizedValue,
    required this.practicedExerciseCount,
    required this.practicedLessonCount,
  });

  bool get hasPractice => practicedSeconds > 0;
}

@immutable
class SkillPracticeTimeSnapshot {
  final PracticePortraitLens lens;
  final List<SkillPracticeTimeValue> values;

  const SkillPracticeTimeSnapshot({
    this.lens = PracticePortraitLens.practiceTime,
    required this.values,
  });

  bool get hasSkills => values.isNotEmpty;
  bool get hasPractice =>
      values.any((SkillPracticeTimeValue value) => value.hasPractice);
  int get totalPracticedSeconds => values.fold<int>(
    0,
    (int total, SkillPracticeTimeValue value) => total + value.practicedSeconds,
  );
}

class SkillPracticeTimeAggregator {
  const SkillPracticeTimeAggregator();

  SkillPracticeTimeSnapshot build({
    required LessonContentLibrary library,
    required LessonProgressService progressService,
  }) {
    final List<String> orderedSkillIds = _orderedSkillIds(library);
    final Map<String, _SkillPracticeAccumulator> accumulators =
        <String, _SkillPracticeAccumulator>{
          for (final String skillId in orderedSkillIds)
            skillId: _SkillPracticeAccumulator(skillId),
        };

    for (final Lesson lesson in _orderedLessons(library)) {
      final _SkillPracticeAccumulator accumulator = accumulators.putIfAbsent(
        lesson.skill,
        () => _SkillPracticeAccumulator(lesson.skill),
      );

      bool lessonHasPracticedExercise = false;
      for (final LessonExercise exercise in lesson.exercises) {
        final ExerciseProgress progress = progressService.progressForExercise(
          lessonId: lesson.id,
          exerciseId: exercise.id,
        );
        final int practicedSeconds = progress.practicedSeconds;
        accumulator.practicedSeconds += practicedSeconds;
        if (practicedSeconds > 0) {
          accumulator.practicedExerciseCount += 1;
          lessonHasPracticedExercise = true;
        }
      }
      if (lessonHasPracticedExercise) {
        accumulator.practicedLessonIds.add(lesson.id);
      }
    }

    final int maxPracticedSeconds = accumulators.values.fold<int>(
      0,
      (int max, _SkillPracticeAccumulator value) =>
          value.practicedSeconds > max ? value.practicedSeconds : max,
    );

    return SkillPracticeTimeSnapshot(
      values: <SkillPracticeTimeValue>[
        for (final String skillId in orderedSkillIds)
          _valueFor(
            accumulators[skillId]!,
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

  SkillPracticeTimeValue _valueFor(
    _SkillPracticeAccumulator accumulator, {
    required int maxPracticedSeconds,
  }) {
    return SkillPracticeTimeValue(
      skillId: accumulator.skillId,
      label: curriculumSkillLabel(accumulator.skillId),
      practicedSeconds: accumulator.practicedSeconds,
      normalizedValue: maxPracticedSeconds == 0
          ? 0
          : accumulator.practicedSeconds / maxPracticedSeconds,
      practicedExerciseCount: accumulator.practicedExerciseCount,
      practicedLessonCount: accumulator.practicedLessonIds.length,
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

class _SkillPracticeAccumulator {
  final String skillId;
  int practicedSeconds = 0;
  int practicedExerciseCount = 0;
  final Set<String> practicedLessonIds = <String>{};

  _SkillPracticeAccumulator(this.skillId);
}
