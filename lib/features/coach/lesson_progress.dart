import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'lesson_plan.dart';

enum LessonProgressStatus { notStarted, inProgress, completed }

@immutable
class UserProgress {
  final Map<String, LessonProgress> lessonsById;
  final Map<String, int> practicedSecondsByLevelId;

  const UserProgress({
    required this.lessonsById,
    required this.practicedSecondsByLevelId,
  });

  factory UserProgress.empty() {
    return const UserProgress(
      lessonsById: <String, LessonProgress>{},
      practicedSecondsByLevelId: <String, int>{},
    );
  }

  factory UserProgress.fromJson(Map<String, Object?> json) {
    final Object? lessons = json['lessonsById'];
    final Object? levelSeconds = json['practicedSecondsByLevelId'];
    return UserProgress(
      lessonsById: <String, LessonProgress>{
        if (lessons is Map<dynamic, dynamic>)
          for (final MapEntry<dynamic, dynamic> entry in lessons.entries)
            if (entry.key is String && entry.value is Map<dynamic, dynamic>)
              entry.key as String: LessonProgress.fromJson(
                (entry.value as Map<dynamic, dynamic>).cast<String, Object?>(),
              ),
      },
      practicedSecondsByLevelId: <String, int>{
        if (levelSeconds is Map<dynamic, dynamic>)
          for (final MapEntry<dynamic, dynamic> entry in levelSeconds.entries)
            if (entry.key is String && entry.value is int)
              entry.key as String: entry.value as int,
      },
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'lessonsById': <String, Object?>{
        for (final MapEntry<String, LessonProgress> entry
            in lessonsById.entries)
          entry.key: entry.value.toJson(),
      },
      'practicedSecondsByLevelId': practicedSecondsByLevelId,
    };
  }

  UserProgress copyWith({
    Map<String, LessonProgress>? lessonsById,
    Map<String, int>? practicedSecondsByLevelId,
  }) {
    return UserProgress(
      lessonsById:
          lessonsById ?? Map<String, LessonProgress>.of(this.lessonsById),
      practicedSecondsByLevelId:
          practicedSecondsByLevelId ??
          Map<String, int>.of(this.practicedSecondsByLevelId),
    );
  }
}

@immutable
class LessonProgress {
  final String lessonId;
  final LessonProgressStatus status;
  final DateTime? startedAt;
  final DateTime? lastOpenedAt;
  final DateTime? completedAt;
  final int practicedSeconds;
  final Map<String, ExerciseProgress> exerciseProgressById;

  const LessonProgress({
    required this.lessonId,
    required this.status,
    this.startedAt,
    this.lastOpenedAt,
    this.completedAt,
    this.practicedSeconds = 0,
    this.exerciseProgressById = const <String, ExerciseProgress>{},
  });

  factory LessonProgress.notStarted(String lessonId) {
    return LessonProgress(
      lessonId: lessonId,
      status: LessonProgressStatus.notStarted,
    );
  }

  factory LessonProgress.fromJson(Map<String, Object?> json) {
    final Object? exercises = json['exerciseProgressById'];
    return LessonProgress(
      lessonId: json['lessonId'] as String,
      status: _statusFromName(json['status'] as String?),
      startedAt: _dateFromJson(json['startedAt']),
      lastOpenedAt: _dateFromJson(json['lastOpenedAt']),
      completedAt: _dateFromJson(json['completedAt']),
      practicedSeconds: json['practicedSeconds'] as int? ?? 0,
      exerciseProgressById: <String, ExerciseProgress>{
        if (exercises is Map<dynamic, dynamic>)
          for (final MapEntry<dynamic, dynamic> entry in exercises.entries)
            if (entry.key is String && entry.value is Map<dynamic, dynamic>)
              entry.key as String: ExerciseProgress.fromJson(
                (entry.value as Map<dynamic, dynamic>).cast<String, Object?>(),
              ),
      },
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'lessonId': lessonId,
      'status': _statusName(status),
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
      if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      'practicedSeconds': practicedSeconds,
      'exerciseProgressById': <String, Object?>{
        for (final MapEntry<String, ExerciseProgress> entry
            in exerciseProgressById.entries)
          entry.key: entry.value.toJson(),
      },
    };
  }

  LessonProgress opened({DateTime? at}) {
    final DateTime now = at ?? DateTime.now();
    if (status == LessonProgressStatus.completed) {
      return copyWith(lastOpenedAt: now);
    }
    return copyWith(
      status: LessonProgressStatus.inProgress,
      startedAt: startedAt ?? now,
      lastOpenedAt: now,
    );
  }

  LessonProgress copyWith({
    LessonProgressStatus? status,
    DateTime? startedAt,
    DateTime? lastOpenedAt,
    DateTime? completedAt,
    int? practicedSeconds,
    Map<String, ExerciseProgress>? exerciseProgressById,
  }) {
    return LessonProgress(
      lessonId: lessonId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      completedAt: completedAt ?? this.completedAt,
      practicedSeconds: practicedSeconds ?? this.practicedSeconds,
      exerciseProgressById:
          exerciseProgressById ??
          Map<String, ExerciseProgress>.of(this.exerciseProgressById),
    );
  }
}

@immutable
class ExerciseProgress {
  final String lessonId;
  final String exerciseId;
  final LessonProgressStatus status;
  final DateTime? startedAt;
  final DateTime? lastPracticedAt;
  final DateTime? completedAt;
  final int practicedSeconds;

  const ExerciseProgress({
    required this.lessonId,
    required this.exerciseId,
    required this.status,
    this.startedAt,
    this.lastPracticedAt,
    this.completedAt,
    this.practicedSeconds = 0,
  });

  factory ExerciseProgress.notStarted({
    required String lessonId,
    required String exerciseId,
  }) {
    return ExerciseProgress(
      lessonId: lessonId,
      exerciseId: exerciseId,
      status: LessonProgressStatus.notStarted,
    );
  }

  factory ExerciseProgress.fromJson(Map<String, Object?> json) {
    return ExerciseProgress(
      lessonId: json['lessonId'] as String,
      exerciseId: json['exerciseId'] as String,
      status: _statusFromName(json['status'] as String?),
      startedAt: _dateFromJson(json['startedAt']),
      lastPracticedAt: _dateFromJson(json['lastPracticedAt']),
      completedAt: _dateFromJson(json['completedAt']),
      practicedSeconds: json['practicedSeconds'] as int? ?? 0,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'lessonId': lessonId,
      'exerciseId': exerciseId,
      'status': _statusName(status),
      if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
      if (lastPracticedAt != null)
        'lastPracticedAt': lastPracticedAt!.toIso8601String(),
      if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      'practicedSeconds': practicedSeconds,
    };
  }

  ExerciseProgress started({DateTime? at}) {
    final DateTime now = at ?? DateTime.now();
    if (status == LessonProgressStatus.completed) {
      return copyWith(lastPracticedAt: now);
    }
    return copyWith(
      status: LessonProgressStatus.inProgress,
      startedAt: startedAt ?? now,
      lastPracticedAt: now,
    );
  }

  ExerciseProgress completed({
    DateTime? at,
    Duration practiced = Duration.zero,
  }) {
    final DateTime now = at ?? DateTime.now();
    return copyWith(
      status: LessonProgressStatus.completed,
      startedAt: startedAt ?? now,
      lastPracticedAt: now,
      completedAt: now,
      practicedSeconds: practicedSeconds + practiced.inSeconds,
    );
  }

  ExerciseProgress copyWith({
    LessonProgressStatus? status,
    DateTime? startedAt,
    DateTime? lastPracticedAt,
    DateTime? completedAt,
    int? practicedSeconds,
  }) {
    return ExerciseProgress(
      lessonId: lessonId,
      exerciseId: exerciseId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      lastPracticedAt: lastPracticedAt ?? this.lastPracticedAt,
      completedAt: completedAt ?? this.completedAt,
      practicedSeconds: practicedSeconds ?? this.practicedSeconds,
    );
  }
}

@immutable
class LevelProgressSummary {
  final String levelId;
  final LessonProgressStatus status;
  final int totalLessons;
  final int completedLessons;
  final int inProgressLessons;
  final int practicedSeconds;

  const LevelProgressSummary({
    required this.levelId,
    required this.status,
    required this.totalLessons,
    required this.completedLessons,
    required this.inProgressLessons,
    required this.practicedSeconds,
  });

  bool get showsCompletionIndicator {
    if (totalLessons == 0) return false;
    return completedLessons == totalLessons ||
        completedLessons / totalLessons >= 0.8;
  }
}

abstract class LessonProgressStore {
  Future<UserProgress> load();
  Future<void> save(UserProgress progress);
}

class FileLessonProgressStore implements LessonProgressStore {
  static const String fileName = 'lesson_progress_v2.json';

  const FileLessonProgressStore();

  @override
  Future<UserProgress> load() async {
    final File file = await _file();
    if (!await file.exists()) return UserProgress.empty();
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<dynamic, dynamic>) return UserProgress.empty();
    return UserProgress.fromJson(decoded.cast<String, Object?>());
  }

  @override
  Future<void> save(UserProgress progress) async {
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(progress.toJson()));
  }

  Future<File> _file() async {
    final Directory directory = await getApplicationSupportDirectory();
    return File('${directory.path}/$fileName');
  }
}

class MemoryLessonProgressStore implements LessonProgressStore {
  UserProgress _progress;

  MemoryLessonProgressStore([UserProgress? initialProgress])
    : _progress = initialProgress ?? UserProgress.empty();

  @override
  Future<UserProgress> load() async {
    return _progress.copyWith();
  }

  @override
  Future<void> save(UserProgress progress) async {
    _progress = progress.copyWith();
  }
}

class LessonProgressService {
  final LessonProgressStore _store;
  UserProgress _progress = UserProgress.empty();

  LessonProgressService(this._store);

  Future<void> load() async {
    _progress = (await _store.load()).copyWith();
  }

  LessonProgress progressForLesson(String lessonId) {
    return _progress.lessonsById[lessonId] ??
        LessonProgress.notStarted(lessonId);
  }

  ExerciseProgress progressForExercise({
    required String lessonId,
    required String exerciseId,
  }) {
    return progressForLesson(lessonId).exerciseProgressById[exerciseId] ??
        ExerciseProgress.notStarted(lessonId: lessonId, exerciseId: exerciseId);
  }

  Future<LessonProgress> openLesson(String lessonId, {DateTime? at}) async {
    final LessonProgress next = progressForLesson(lessonId).opened(at: at);
    await _saveLessonProgress(next);
    return next;
  }

  Future<ExerciseProgress> startExercise(
    Lesson lesson,
    String exerciseId, {
    DateTime? at,
  }) async {
    final LessonProgress lessonProgress = progressForLesson(
      lesson.id,
    ).opened(at: at);
    final ExerciseProgress exerciseProgress = progressForExercise(
      lessonId: lesson.id,
      exerciseId: exerciseId,
    ).started(at: at);
    await _saveLessonProgress(
      _withExerciseProgress(lessonProgress, exerciseProgress),
    );
    return exerciseProgress;
  }

  Future<ExerciseProgress> completeExercise(
    Lesson lesson,
    String exerciseId, {
    DateTime? at,
    Duration practicedDuration = Duration.zero,
  }) async {
    final ExerciseProgress exerciseProgress = progressForExercise(
      lessonId: lesson.id,
      exerciseId: exerciseId,
    ).completed(at: at, practiced: practicedDuration);
    final LessonProgress baseLessonProgress = progressForLesson(
      lesson.id,
    ).opened(at: at);
    LessonProgress nextLessonProgress =
        _withExerciseProgress(baseLessonProgress, exerciseProgress).copyWith(
          practicedSeconds:
              baseLessonProgress.practicedSeconds + practicedDuration.inSeconds,
        );

    final bool allExercisesCompleted = lesson.exercises.every((
      LessonExercise exercise,
    ) {
      final ExerciseProgress progress =
          nextLessonProgress.exerciseProgressById[exercise.id] ??
          ExerciseProgress.notStarted(
            lessonId: lesson.id,
            exerciseId: exercise.id,
          );
      return progress.status == LessonProgressStatus.completed;
    });
    if (allExercisesCompleted) {
      final DateTime now = at ?? DateTime.now();
      nextLessonProgress = nextLessonProgress.copyWith(
        status: LessonProgressStatus.completed,
        completedAt: nextLessonProgress.completedAt ?? now,
        lastOpenedAt: now,
      );
    }

    await _saveLessonProgress(
      nextLessonProgress,
      levelId: lesson.level,
      practicedDuration: practicedDuration,
    );
    return exerciseProgress;
  }

  LevelProgressSummary summaryForLevel(
    ContentLevel level,
    List<Lesson> lessons,
  ) {
    return _summaryForLessons(
      id: level.id,
      practicedSeconds: _progress.practicedSecondsByLevelId[level.id] ?? 0,
      lessons: lessons,
    );
  }

  LevelProgressSummary summaryForSkill({
    required String id,
    required List<Lesson> lessons,
  }) {
    final int practicedSeconds = lessons.fold<int>(
      0,
      (int total, Lesson lesson) =>
          total + progressForLesson(lesson.id).practicedSeconds,
    );
    return _summaryForLessons(
      id: id,
      practicedSeconds: practicedSeconds,
      lessons: lessons,
    );
  }

  LevelProgressSummary _summaryForLessons({
    required String id,
    required int practicedSeconds,
    required List<Lesson> lessons,
  }) {
    int completed = 0;
    int inProgress = 0;
    for (final Lesson lesson in lessons) {
      final LessonProgressStatus status = progressForLesson(lesson.id).status;
      if (status == LessonProgressStatus.completed) {
        completed += 1;
      } else if (status == LessonProgressStatus.inProgress) {
        inProgress += 1;
      }
    }

    final LessonProgressStatus status;
    if (lessons.isNotEmpty && completed == lessons.length) {
      status = LessonProgressStatus.completed;
    } else if (completed > 0 || inProgress > 0) {
      status = LessonProgressStatus.inProgress;
    } else {
      status = LessonProgressStatus.notStarted;
    }

    return LevelProgressSummary(
      levelId: id,
      status: status,
      totalLessons: lessons.length,
      completedLessons: completed,
      inProgressLessons: inProgress,
      practicedSeconds: practicedSeconds,
    );
  }

  LessonProgress _withExerciseProgress(
    LessonProgress lessonProgress,
    ExerciseProgress exerciseProgress,
  ) {
    return lessonProgress.copyWith(
      exerciseProgressById: <String, ExerciseProgress>{
        ...lessonProgress.exerciseProgressById,
        exerciseProgress.exerciseId: exerciseProgress,
      },
    );
  }

  Future<void> _saveLessonProgress(
    LessonProgress lessonProgress, {
    String? levelId,
    Duration practicedDuration = Duration.zero,
  }) async {
    final Map<String, LessonProgress> lessonsById =
        Map<String, LessonProgress>.of(_progress.lessonsById);
    lessonsById[lessonProgress.lessonId] = lessonProgress;
    final Map<String, int> secondsByLevel = Map<String, int>.of(
      _progress.practicedSecondsByLevelId,
    );
    if (levelId != null && practicedDuration.inSeconds > 0) {
      secondsByLevel[levelId] =
          (secondsByLevel[levelId] ?? 0) + practicedDuration.inSeconds;
    }
    _progress = UserProgress(
      lessonsById: lessonsById,
      practicedSecondsByLevelId: secondsByLevel,
    );
    await _store.save(_progress);
  }
}

LessonProgressStatus _statusFromName(String? name) {
  return switch (name) {
    'inProgress' || 'in_progress' => LessonProgressStatus.inProgress,
    'completed' => LessonProgressStatus.completed,
    _ => LessonProgressStatus.notStarted,
  };
}

String _statusName(LessonProgressStatus status) {
  return switch (status) {
    LessonProgressStatus.notStarted => 'not_started',
    LessonProgressStatus.inProgress => 'in_progress',
    LessonProgressStatus.completed => 'completed',
  };
}

DateTime? _dateFromJson(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value);
}
