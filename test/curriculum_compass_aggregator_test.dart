import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_progress.dart';
import 'package:drumcabulary/features/progress/curriculum_compass_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds the temporary top-level curriculum compass tree', () {
    final CurriculumNode root = const CurriculumCompassTreeBuilder().build(
      _library(<Lesson>[]),
    );

    expect(root.id, CurriculumCompassTreeBuilder.rootId);
    expect(root.children.map((CurriculumNode node) => node.title), <String>[
      'Timing',
      'Grooves',
      'Rudiments',
      'Technique',
      'Coordination',
      'Dynamics',
      'Vocabulary',
      'Reading',
      'Musicianship',
      'Improvisation',
    ]);
    for (final CurriculumNode topLevelNode in root.children) {
      expect(topLevelNode.children, hasLength(10));
    }

    final CurriculumNode vocabulary = _child(root, 'vocabulary');
    expect(
      vocabulary.children.map((CurriculumNode node) => node.title),
      contains('Triads'),
    );
  });

  test('aggregates practice investment and completion together', () async {
    final LessonContentLibrary library = _library(<Lesson>[
      _lesson(
        id: 'groove-one',
        skill: 'grooves',
        exercises: <String>['a', 'b'],
      ),
      _lesson(id: 'groove-two', skill: 'grooves', exercises: <String>['c']),
      _lesson(id: 'rudiment-one', skill: 'rudiments', exercises: <String>['d']),
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
      library.lessonsById['rudiment-one']!,
      'd',
      practicedDuration: const Duration(minutes: 60),
    );

    final CurriculumNode root = const CurriculumCompassTreeBuilder().build(
      library,
    );
    final CurriculumCompassSnapshot snapshot =
        const CurriculumCompassAggregator().build(
          root: root,
          nodePath: const <String>[],
          progressService: progress,
        );

    final CurriculumCompassPoint rudiments = _value(snapshot, 'rudiments');
    final CurriculumCompassPoint grooves = _value(snapshot, 'grooves');
    expect(rudiments.practicedSeconds, 3600);
    expect(rudiments.practiceInvestmentRatio, 1);
    expect(rudiments.completionRatio, 1);
    expect(rudiments.practicedExerciseCount, 1);
    expect(rudiments.practicedLessonCount, 1);
    expect(grooves.practicedSeconds, 1800);
    expect(grooves.practiceInvestmentRatio, 0.5);
    expect(grooves.completedExerciseCount, 3);
    expect(grooves.totalExerciseCount, 3);
    expect(grooves.completionRatio, 1);
    expect(grooves.practicedExerciseCount, 3);
    expect(grooves.practicedLessonCount, 2);
  });

  test(
    'builds second-level compass values from selected category children',
    () async {
      final LessonContentLibrary library = _library(<Lesson>[
        _lesson(
          id: 'groove-one',
          skill: 'grooves',
          exercises: <String>['a', 'b'],
        ),
      ]);
      final LessonProgressService progress = LessonProgressService(
        MemoryLessonProgressStore(),
      );
      await progress.load();
      await progress.completeExercise(
        library.lessonsById['groove-one']!,
        'a',
        practicedDuration: const Duration(minutes: 8),
      );

      final CurriculumCompassSnapshot snapshot =
          const CurriculumCompassAggregator().build(
            root: const CurriculumCompassTreeBuilder().build(library),
            nodePath: const <String>['grooves'],
            progressService: progress,
          );

      expect(snapshot.currentNode.id, 'grooves');
      expect(snapshot.isRoot, isFalse);
      expect(
        snapshot.breadcrumbs.map((CurriculumBreadcrumb item) => item.title),
        <String>['Curriculum', 'Grooves'],
      );
      expect(snapshot.values, hasLength(10));

      final CurriculumCompassPoint coreGrooves = _value(
        snapshot,
        'core-grooves',
      );
      expect(coreGrooves.lessonFilterId, 'grooves');
      expect(coreGrooves.completedExerciseCount, 1);
      expect(coreGrooves.totalExerciseCount, 2);
      expect(coreGrooves.practiceInvestmentRatio, 1);
      expect(coreGrooves.completionRatio, 0.5);

      final CurriculumCompassPoint rockGrooves = _value(
        snapshot,
        'rock-grooves',
      );
      expect(rockGrooves.totalExerciseCount, 0);
      expect(rockGrooves.practiceInvestmentRatio, 0);
      expect(rockGrooves.completionRatio, 0);
    },
  );

  test('keeps temporary nodes visible without fabricated metrics', () async {
    final LessonProgressService progress = LessonProgressService(
      MemoryLessonProgressStore(),
    );
    await progress.load();

    final CurriculumCompassSnapshot snapshot =
        const CurriculumCompassAggregator().build(
          root: const CurriculumCompassTreeBuilder().build(
            LessonContentLibrary(
              index: ContentIndex(version: 1, levels: <ContentLevel>[]),
              lessonsById: <String, Lesson>{},
              lessonsByLevelId: <String, List<Lesson>>{},
            ),
          ),
          nodePath: const <String>['vocabulary'],
          progressService: progress,
        );

    expect(snapshot.hasMetricData, isFalse);
    expect(_value(snapshot, 'triads').label, 'Triads');
    for (final CurriculumCompassPoint value in snapshot.values) {
      expect(value.practicedSeconds, 0);
      expect(value.totalExerciseCount, 0);
      expect(value.practiceInvestmentRatio, 0);
      expect(value.completionRatio, 0);
    }
  });

  test('unknown node path falls back to the root compass safely', () async {
    final LessonProgressService progress = LessonProgressService(
      MemoryLessonProgressStore(),
    );
    await progress.load();

    final CurriculumCompassSnapshot snapshot =
        const CurriculumCompassAggregator().build(
          root: const CurriculumCompassTreeBuilder().build(
            LessonContentLibrary(
              index: ContentIndex(version: 1, levels: <ContentLevel>[]),
              lessonsById: <String, Lesson>{},
              lessonsByLevelId: <String, List<Lesson>>{},
            ),
          ),
          nodePath: const <String>['missing'],
          progressService: progress,
        );

    expect(snapshot.currentNode.id, CurriculumCompassTreeBuilder.rootId);
    expect(snapshot.breadcrumbs, hasLength(1));
    expect(snapshot.values, hasLength(10));
  });
}

CurriculumCompassPoint _value(
  CurriculumCompassSnapshot snapshot,
  String nodeId,
) {
  return snapshot.values.singleWhere(
    (CurriculumCompassPoint value) => value.nodeId == nodeId,
  );
}

CurriculumNode _child(CurriculumNode node, String id) {
  return node.children.singleWhere((CurriculumNode child) => child.id == id);
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
    tempo: const TempoTarget(start: 60, target: 90),
    notation: const ExerciseNotation(
      sections: <ExerciseNotationSection>[
        ExerciseNotationSection(pattern: '[S]'),
      ],
    ),
  );
}
