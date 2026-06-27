import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'lesson_notation_document.dart';
import 'lesson_plan.dart';

class LessonPlanLoader {
  static const String contentRoot = 'assets/content';
  static const String indexAssetPath = '$contentRoot/index.yaml';

  const LessonPlanLoader._();

  static Future<LessonContentLibrary> loadContent({AssetBundle? bundle}) async {
    final AssetBundle assetBundle = bundle ?? rootBundle;
    final ContentIndex index = parseIndex(
      await _loadAsset(assetBundle, indexAssetPath),
      sourceDescription: indexAssetPath,
    );

    final List<Lesson> lessons = <Lesson>[];
    for (final ContentLevel level in index.levels) {
      for (final String file in level.lessonFiles) {
        final Lesson lesson = parseLesson(
          await _loadAsset(assetBundle, _contentAssetPath(file)),
          sourceDescription: _contentAssetPath(file),
        );
        if (lesson.level != level.id) {
          throw LessonPlanLoadException(
            'lesson ${lesson.id} declares level ${lesson.level} but is listed under ${level.id}.',
          );
        }
        lessons.add(lesson);
      }
    }

    final Map<String, Lesson> lessonsById = _mapByUniqueId(
      lessons,
      label: 'lesson.id',
      idFor: (Lesson lesson) => lesson.id,
    );
    final Map<String, List<Lesson>> lessonsByLevelId = <String, List<Lesson>>{};
    for (final ContentLevel level in index.levels) {
      final List<Lesson> levelLessons = <Lesson>[
        for (final Lesson lesson in lessons)
          if (lesson.level == level.id) lesson,
      ]..sort((Lesson a, Lesson b) => a.order.compareTo(b.order));
      lessonsByLevelId[level.id] = levelLessons;
    }

    final LessonContentLibrary library = LessonContentLibrary(
      index: index,
      lessonsById: lessonsById,
      lessonsByLevelId: lessonsByLevelId,
    );
    _validateLibrary(library);
    return library;
  }

  static ContentIndex parseIndex(
    String yamlSource, {
    String sourceDescription = 'content index YAML',
  }) {
    return _parseYaml(
      yamlSource,
      sourceDescription: sourceDescription,
      parse: ContentIndex.fromYaml,
    );
  }

  static Lesson parseLesson(
    String yamlSource, {
    String sourceDescription = 'lesson YAML',
  }) {
    return _parseYaml(
      yamlSource,
      sourceDescription: sourceDescription,
      parse: Lesson.fromYaml,
    );
  }

  static T _parseYaml<T>(
    String yamlSource, {
    required String sourceDescription,
    required T Function(Object? decoded) parse,
  }) {
    final Object? decoded = _decodeYaml(
      yamlSource,
      sourceDescription: sourceDescription,
    );
    try {
      return parse(decoded);
    } on LessonPlanLoadException {
      rethrow;
    } on Object catch (error) {
      throw LessonPlanLoadException(
        '$sourceDescription has an invalid content shape: $error',
      );
    }
  }

  static Object? _decodeYaml(
    String yamlSource, {
    required String sourceDescription,
  }) {
    try {
      return loadYaml(yamlSource);
    } on Object catch (error) {
      throw LessonPlanLoadException(
        '$sourceDescription could not be parsed as YAML: $error',
      );
    }
  }

  static Future<String> _loadAsset(AssetBundle bundle, String assetPath) async {
    try {
      return await bundle.loadString(assetPath);
    } on Object catch (error) {
      throw LessonPlanLoadException('$assetPath could not be loaded: $error');
    }
  }

  static String _contentAssetPath(String file) {
    final String normalized = file.startsWith('/') ? file.substring(1) : file;
    return '$contentRoot/$normalized';
  }

  static Map<String, T> _mapByUniqueId<T>(
    Iterable<T> items, {
    required String label,
    required String Function(T item) idFor,
  }) {
    final Map<String, T> result = <String, T>{};
    for (final T item in items) {
      final String id = idFor(item);
      if (result.containsKey(id)) {
        throw LessonPlanLoadException('$label must be unique: $id.');
      }
      result[id] = item;
    }
    return result;
  }

  static void _validateLibrary(LessonContentLibrary library) {
    final Set<String> levelIds = library.index.levels
        .map((ContentLevel level) => level.id)
        .toSet();
    for (final Lesson lesson in library.lessonsById.values) {
      if (!levelIds.contains(lesson.level)) {
        throw LessonPlanLoadException(
          'lesson ${lesson.id} references missing level ${lesson.level}.',
        );
      }
      if (lesson.skill.trim().isEmpty) {
        throw LessonPlanLoadException('lesson ${lesson.id}.skill is required.');
      }
      _validateLessonNotation(lesson);
    }
  }

  static void _validateLessonNotation(Lesson lesson) {
    for (final LessonExercise exercise in lesson.exercises) {
      for (
        int index = 0;
        index < exercise.notation.sections.length;
        index += 1
      ) {
        final ExerciseNotationSection section =
            exercise.notation.sections[index];
        validateNotationSection(
          section,
          path:
              'lesson ${lesson.id}.exercises.${exercise.id}.notation.sections[$index]',
        );
      }
    }
  }
}
