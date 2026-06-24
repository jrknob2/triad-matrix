import 'package:flutter/foundation.dart';

@immutable
class LessonPlan {
  final String id;
  final String title;
  final String subtitle;
  final int version;
  final List<Lesson> lessons;

  const LessonPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.version,
    required this.lessons,
  });

  factory LessonPlan.fromYaml(Object? yaml) {
    final Map<dynamic, dynamic> root = _requiredMapValue(yaml, 'root');
    final Map<dynamic, dynamic> plan = _requiredMap(
      root,
      'lesson_plan',
      'root',
    );
    final List<Lesson> lessons =
        _requiredMapList(plan, 'lessons', 'lesson_plan').indexed
            .map((entry) {
              return Lesson.fromYaml(
                entry.$2,
                'lesson_plan.lessons[${entry.$1}]',
              );
            })
            .toList(growable: false);

    if (lessons.isEmpty) {
      throw const LessonPlanLoadException(
        'lesson_plan.lessons must contain at least one lesson.',
      );
    }

    final List<Lesson> orderedLessons = List<Lesson>.of(lessons)
      ..sort((Lesson a, Lesson b) => a.number.compareTo(b.number));

    return LessonPlan(
      id: _requiredString(plan, 'id', 'lesson_plan'),
      title: _requiredString(plan, 'title', 'lesson_plan'),
      subtitle: _requiredString(plan, 'subtitle', 'lesson_plan'),
      version: _requiredInt(plan, 'version', 'lesson_plan'),
      lessons: orderedLessons,
    );
  }
}

@immutable
class Lesson {
  final String id;
  final int number;
  final String title;
  final String objective;
  final String skillFocus;
  final int estimatedMinutes;
  final List<LessonPattern> patterns;
  final List<LessonExercise> exercises;
  final List<String> coachingNotes;
  final List<String> mastery;

  const Lesson({
    required this.id,
    required this.number,
    required this.title,
    required this.objective,
    required this.skillFocus,
    required this.estimatedMinutes,
    required this.patterns,
    required this.exercises,
    required this.coachingNotes,
    required this.mastery,
  });

  factory Lesson.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    final List<LessonPattern> patterns =
        _requiredMapList(yaml, 'patterns', path).indexed
            .map((entry) {
              return LessonPattern.fromYaml(
                entry.$2,
                '$path.patterns[${entry.$1}]',
              );
            })
            .toList(growable: false);

    final List<LessonExercise> exercises =
        _requiredMapList(yaml, 'exercises', path).indexed
            .map((entry) {
              return LessonExercise.fromYaml(
                entry.$2,
                '$path.exercises[${entry.$1}]',
              );
            })
            .toList(growable: false);

    return Lesson(
      id: _requiredString(yaml, 'id', path),
      number: _requiredInt(yaml, 'number', path),
      title: _requiredString(yaml, 'title', path),
      objective: _requiredString(yaml, 'objective', path),
      skillFocus: _requiredString(yaml, 'skill_focus', path),
      estimatedMinutes: _requiredInt(yaml, 'estimated_minutes', path),
      patterns: patterns,
      exercises: exercises,
      coachingNotes: _requiredStringList(yaml, 'coaching_notes', path),
      mastery: _requiredStringList(yaml, 'mastery', path),
    );
  }

  LessonPattern? get primaryPattern {
    if (patterns.isEmpty) return null;
    return patterns.first;
  }
}

@immutable
class LessonPattern {
  final String id;
  final String title;
  final String role;
  final String notation;
  final String? subdivision;
  final String timeSignature;
  final int? repeatCount;

  const LessonPattern({
    required this.id,
    required this.title,
    required this.role,
    required this.notation,
    this.subdivision,
    this.timeSignature = '4/4',
    this.repeatCount,
  });

  factory LessonPattern.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    return LessonPattern(
      id: _requiredString(yaml, 'id', path),
      title: _requiredString(yaml, 'title', path),
      role: _requiredString(yaml, 'role', path),
      notation: _requiredString(yaml, 'notation', path),
      subdivision: _optionalScalarString(yaml, 'subdivision', path),
      timeSignature:
          _optionalScalarString(yaml, 'time_signature', path) ?? '4/4',
      repeatCount: _optionalPositiveInt(yaml, 'repeat_count', path),
    );
  }
}

@immutable
class LessonExercise {
  final String title;
  final String instructions;
  final String? subdivision;
  final List<String> subdivisionSequence;
  final TempoTarget? tempo;
  final List<FlowStep> flow;

  const LessonExercise({
    required this.title,
    required this.instructions,
    this.subdivision,
    this.subdivisionSequence = const <String>[],
    this.tempo,
    this.flow = const <FlowStep>[],
  });

  factory LessonExercise.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    return LessonExercise(
      title: _requiredString(yaml, 'title', path),
      instructions: _requiredString(yaml, 'instructions', path),
      subdivision: _optionalScalarString(yaml, 'subdivision', path),
      subdivisionSequence: _optionalScalarStringList(
        yaml,
        'subdivision_sequence',
        path,
      ),
      tempo: _optionalTempo(yaml, 'tempo', path),
      flow: _optionalMapList(yaml, 'flow', path).indexed
          .map((entry) {
            return FlowStep.fromYaml(entry.$2, '$path.flow[${entry.$1}]');
          })
          .toList(growable: false),
    );
  }
}

@immutable
class TempoTarget {
  final int start;
  final int target;

  const TempoTarget({required this.start, required this.target});

  factory TempoTarget.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    return TempoTarget(
      start: _requiredInt(yaml, 'start', path),
      target: _requiredInt(yaml, 'target', path),
    );
  }
}

@immutable
class FlowStep {
  final String pattern;
  final int repeat;

  const FlowStep({required this.pattern, required this.repeat});

  factory FlowStep.fromYaml(Map<dynamic, dynamic> yaml, String path) {
    return FlowStep(
      pattern: _requiredString(yaml, 'pattern', path),
      repeat: _requiredInt(yaml, 'repeat', path),
    );
  }
}

class LessonPlanLoadException implements Exception {
  final String message;

  const LessonPlanLoadException(this.message);

  @override
  String toString() => 'LessonPlanLoadException: $message';
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
  return _mapListValue(map[key], '$path.$key', required: true);
}

List<Map<dynamic, dynamic>> _optionalMapList(
  Map<dynamic, dynamic> map,
  String key,
  String path,
) {
  return _mapListValue(map[key], '$path.$key', required: false);
}

List<Map<dynamic, dynamic>> _mapListValue(
  Object? value,
  String path, {
  required bool required,
}) {
  if (value == null && !required) return const <Map<dynamic, dynamic>>[];
  if (value is! Iterable<Object?>) {
    throw LessonPlanLoadException('$path must be a list.');
  }
  return value.indexed
      .map((entry) {
        return _requiredMapValue(entry.$2, '$path[${entry.$1}]');
      })
      .toList(growable: false);
}

String _requiredString(Map<dynamic, dynamic> map, String key, String path) {
  final Object? value = map[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
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

List<String> _requiredStringList(
  Map<dynamic, dynamic> map,
  String key,
  String path,
) {
  final Object? value = map[key];
  if (value is! Iterable<Object?>) {
    throw LessonPlanLoadException('$path.$key must be a list.');
  }
  final List<String> strings = value.indexed
      .map((entry) {
        final Object? item = entry.$2;
        if (item is String && item.trim().isNotEmpty) {
          return item;
        }
        throw LessonPlanLoadException(
          '$path.$key[${entry.$1}] must be a non-empty string.',
        );
      })
      .toList(growable: false);
  if (strings.isEmpty) {
    throw LessonPlanLoadException('$path.$key must contain at least one item.');
  }
  return strings;
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
