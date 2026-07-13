import 'package:flutter/foundation.dart';

@immutable
class ContentIndex {
  final int version;
  final List<ContentLevel> levels;

  const ContentIndex({required this.version, required this.levels});

  factory ContentIndex.fromYaml(Object? yaml) {
    final Map<dynamic, dynamic> root = _requiredMapValue(yaml, 'root');
    final Map<dynamic, dynamic> index = _requiredMap(
      root,
      'content_index',
      'root',
    );
    final List<ContentLevel> levels =
        _requiredMapList(index, 'levels', 'content_index').indexed
            .map((entry) {
              return ContentLevel.fromYaml(
                entry.$2,
                'content_index.levels[${entry.$1}]',
              );
            })
            .toList(growable: false);
    if (levels.isEmpty) {
      throw const LessonPlanLoadException(
        'content_index.levels must not be empty.',
      );
    }
    _validateUnique(
      values: levels.map((ContentLevel level) => level.id),
      label: 'content_index.levels.id',
    );
    return ContentIndex(
      version: _requiredInt(index, 'version', 'content_index'),
      levels: levels,
    );
  }
}

@immutable
class ContentLevel {
  final String id;
  final String title;
  final List<String> lessonFiles;

  const ContentLevel({
    required this.id,
    required this.title,
    required this.lessonFiles,
  });

  factory ContentLevel.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    return ContentLevel(
      id: _requiredString(yaml, 'id', path),
      title: _requiredString(yaml, 'title', path),
      lessonFiles: _optionalScalarStringList(yaml, 'lesson_files', path),
    );
  }
}

@immutable
class LessonContentLibrary {
  final ContentIndex index;
  final Map<String, Lesson> lessonsById;
  final Map<String, List<Lesson>> lessonsByLevelId;

  const LessonContentLibrary({
    required this.index,
    required this.lessonsById,
    required this.lessonsByLevelId,
  });

  List<Lesson> lessonsForLevel(String levelId) {
    return lessonsByLevelId[levelId] ?? const <Lesson>[];
  }

  List<String> skillsForLevel(String levelId) {
    final Set<String> skills = <String>{};
    for (final Lesson lesson in lessonsForLevel(levelId)) {
      skills.add(lesson.skill);
    }
    return skills.toList(growable: false)..sort(_compareSkillIds);
  }

  List<Lesson> lessonsForSkill({
    required String levelId,
    required String skill,
  }) {
    final List<Lesson> lessons = <Lesson>[
      for (final Lesson lesson in lessonsForLevel(levelId))
        if (lesson.skill == skill) lesson,
    ]..sort((Lesson a, Lesson b) => a.order.compareTo(b.order));
    return lessons;
  }
}

@immutable
class Lesson {
  final String id;
  final String title;
  final String level;
  final String skill;
  final int order;
  final int estimatedMinutes;
  final String overview;
  final String objective;
  final List<LessonExercise> exercises;

  const Lesson({
    required this.id,
    required this.title,
    required this.level,
    required this.skill,
    required this.order,
    required this.estimatedMinutes,
    required this.overview,
    required this.objective,
    required this.exercises,
  });

  factory Lesson.fromYaml(Object? yaml) {
    final Map<dynamic, dynamic> root = _requiredMapValue(yaml, 'root');
    final Map<dynamic, dynamic> lesson = _requiredMap(root, 'lesson', 'root');
    const String path = 'lesson';

    final int order = _requiredInt(lesson, 'order', path);
    if (order <= 0) {
      throw const LessonPlanLoadException('lesson.order must be positive.');
    }

    final int estimatedMinutes = _requiredInt(
      lesson,
      'estimated_minutes',
      path,
    );
    if (estimatedMinutes <= 0) {
      throw const LessonPlanLoadException(
        'lesson.estimated_minutes must be positive.',
      );
    }

    final List<LessonExercise> exercises =
        _requiredMapList(lesson, 'exercises', path).indexed
            .map((entry) {
              return LessonExercise.fromYaml(
                entry.$2,
                '$path.exercises[${entry.$1}]',
              );
            })
            .toList(growable: false);
    _validateUnique(
      values: exercises.map((LessonExercise exercise) => exercise.id),
      label: '$path.exercises.id',
    );

    return Lesson(
      id: _requiredString(lesson, 'id', path),
      title: _requiredString(lesson, 'title', path),
      level: _requiredString(lesson, 'level', path),
      skill: _requiredString(lesson, 'skill', path),
      order: order,
      estimatedMinutes: estimatedMinutes,
      overview: _requiredString(lesson, 'overview', path),
      objective: _requiredString(lesson, 'objective', path),
      exercises: exercises,
    );
  }
}

@immutable
class LessonExercise {
  final String id;
  final String title;
  final String why;
  final String what;
  final String how;
  final String? success;
  final TempoTarget? tempo;
  final ExerciseNotation notation;

  const LessonExercise({
    required this.id,
    required this.title,
    required this.why,
    required this.what,
    required this.how,
    this.success,
    this.tempo,
    required this.notation,
  });

  factory LessonExercise.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    return LessonExercise(
      id:
          _optionalString(yaml, 'id', path) ??
          _slugFromTitle(_requiredString(yaml, 'title', path)),
      title: _requiredString(yaml, 'title', path),
      why: _requiredString(yaml, 'why', path),
      what: _requiredString(yaml, 'what', path),
      how: _requiredString(yaml, 'how', path),
      success: _optionalString(yaml, 'success', path),
      tempo: _optionalTempo(yaml, 'tempo', path),
      notation: ExerciseNotation.fromYaml(
        _requiredMap(yaml, 'notation', path),
        '$path.notation',
      ),
    );
  }
}

@immutable
class ExerciseNotation {
  final List<ExerciseNotationSection> sections;

  const ExerciseNotation({required this.sections});

  factory ExerciseNotation.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    final List<ExerciseNotationSection> sections;
    if (yaml.containsKey('sections')) {
      sections = _requiredMapList(yaml, 'sections', path).indexed
          .map((entry) {
            return ExerciseNotationSection.fromYaml(
              entry.$2,
              '$path.sections[${entry.$1}]',
            );
          })
          .toList(growable: false);
    } else {
      sections = <ExerciseNotationSection>[
        ExerciseNotationSection.fromYaml(yaml, path),
      ];
    }
    if (sections.isEmpty) {
      throw LessonPlanLoadException('$path.sections must not be empty.');
    }
    return ExerciseNotation(sections: sections);
  }

  ExerciseNotationSection get primarySection => sections.first;
}

@immutable
class ExerciseNotationSection {
  final String? title;
  final String pattern;
  final String? subdivision;
  final String timeSignature;
  final int? repeatCount;
  final String? sticking;

  const ExerciseNotationSection({
    this.title,
    required this.pattern,
    this.subdivision,
    this.timeSignature = '4/4',
    this.repeatCount,
    this.sticking,
  });

  factory ExerciseNotationSection.fromYaml(
    Map<dynamic, dynamic> yaml,
    String path,
  ) {
    return ExerciseNotationSection(
      title: _optionalString(yaml, 'title', path),
      pattern: _requiredString(yaml, 'pattern', path),
      subdivision: _optionalScalarString(yaml, 'subdivision', path),
      timeSignature:
          _optionalScalarString(yaml, 'time_signature', path) ?? '4/4',
      repeatCount: _optionalPositiveInt(yaml, 'repeat_count', path),
      sticking: _optionalScalarString(yaml, 'sticking', path),
    );
  }
}

@immutable
class TempoTarget {
  final int start;
  final int target;

  const TempoTarget({required this.start, required this.target});

  factory TempoTarget.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    final int start = _requiredInt(yaml, 'start', path);
    final int target = _requiredInt(yaml, 'target', path);
    if (start <= 0 || target <= 0) {
      throw LessonPlanLoadException('$path start and target must be positive.');
    }
    if (target < start) {
      throw LessonPlanLoadException('$path.target must be >= $path.start.');
    }
    return TempoTarget(start: start, target: target);
  }
}

class LessonPlanLoadException implements Exception {
  final String message;

  const LessonPlanLoadException(this.message);

  @override
  String toString() => 'LessonPlanLoadException: $message';
}

void _validateUnique({
  required Iterable<String> values,
  required String label,
}) {
  final Set<String> seen = <String>{};
  for (final String value in values) {
    if (!seen.add(value)) {
      throw LessonPlanLoadException('$label must be unique: $value.');
    }
  }
}

int _compareSkillIds(String a, String b) {
  return _skillSortIndex(a).compareTo(_skillSortIndex(b));
}

int _skillSortIndex(String skill) {
  const List<String> order = <String>[
    'timing',
    'reading',
    'rudiments',
    'grooves',
    'fills',
    'chops',
    'dynamics',
    'independence',
    'vocabulary',
  ];
  final int index = order.indexOf(skill);
  return index < 0 ? order.length : index;
}

String _slugFromTitle(String title) {
  final String slug = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.isEmpty ? 'exercise' : slug;
}

Map<dynamic, dynamic> _requiredMap(
  Map<dynamic, dynamic> map,
  String key,
  String path,
) {
  return _requiredMapValue(map[key], '$path.$key');
}

Map<dynamic, dynamic> _requiredMapValue(Object? value, String path) {
  if (value is Map<dynamic, dynamic>) {
    return value;
  }
  throw LessonPlanLoadException('$path must be a map.');
}

List<Map<dynamic, dynamic>> _requiredMapList(
  Map<dynamic, dynamic> map,
  String key,
  String path,
) {
  final Object? value = map[key];
  if (value is! Iterable<Object?>) {
    throw LessonPlanLoadException('$path.$key must be a list.');
  }
  return value.indexed
      .map((entry) {
        return _requiredMapValue(entry.$2, '$path.$key[${entry.$1}]');
      })
      .toList(growable: false);
}

String _requiredString(Map<dynamic, dynamic> map, String key, String path) {
  final Object? value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw LessonPlanLoadException('$path.$key must be a non-empty string.');
}

String? _optionalString(Map<dynamic, dynamic> map, String key, String path) {
  final Object? value = map[key];
  if (value == null) return null;
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  throw LessonPlanLoadException('$path.$key must be a non-empty string.');
}

int _requiredInt(Map<dynamic, dynamic> map, String key, String path) {
  final Object? value = map[key];
  if (value is int) return value;
  throw LessonPlanLoadException('$path.$key must be an integer.');
}

int? _optionalPositiveInt(Map<dynamic, dynamic> map, String key, String path) {
  final Object? value = map[key];
  if (value == null) return null;
  if (value is int && value > 0) return value;
  throw LessonPlanLoadException('$path.$key must be a positive integer.');
}

List<String> _optionalScalarStringList(
  Map<dynamic, dynamic> map,
  String key,
  String path,
) {
  final Object? value = map[key];
  if (value == null) return const <String>[];
  if (value is! Iterable<Object?>) {
    throw LessonPlanLoadException('$path.$key must be a list.');
  }
  return value.indexed
      .map((entry) {
        final String? text = _scalarString(entry.$2);
        if (text != null && text.isNotEmpty) return text;
        throw LessonPlanLoadException(
          '$path.$key[${entry.$1}] must be a non-empty scalar.',
        );
      })
      .toList(growable: false);
}

String? _optionalScalarString(
  Map<dynamic, dynamic> map,
  String key,
  String path,
) {
  final Object? value = map[key];
  if (value == null) return null;
  final String? text = _scalarString(value);
  if (text != null && text.isNotEmpty) return text;
  throw LessonPlanLoadException('$path.$key must be a non-empty scalar.');
}

String? _scalarString(Object? value) {
  if (value is String) return value.trim();
  if (value is int || value is double || value is bool) return '$value';
  return null;
}

TempoTarget? _optionalTempo(
  Map<dynamic, dynamic> map,
  String key,
  String path,
) {
  final Object? value = map[key];
  if (value == null) return null;
  return TempoTarget.fromYaml(
    _requiredMapValue(value, '$path.$key'),
    '$path.$key',
  );
}
