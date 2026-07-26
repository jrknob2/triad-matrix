import 'package:drumcabulary/features/coach/lesson_plan.dart';
import 'package:drumcabulary/features/coach/lesson_progress.dart';
import 'package:drumcabulary/features/progress/curriculum_compass_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds curriculum, category, topic, lesson, and exercise nodes', () {
    final CurriculumNode root = const CurriculumCompassTreeBuilder().build(
      _library(<Lesson>[
        _lesson(
          id: 'groove-one',
          skill: 'grooves',
          exercises: <String>['a', 'b'],
        ),
      ]),
    );

    expect(root.id, CurriculumCompassTreeBuilder.rootId);
    expect(root.kind, CompassNodeKind.curriculum);
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
      expect(topLevelNode.kind, CompassNodeKind.category);
      expect(topLevelNode.children, hasLength(10));
    }

    final CurriculumNode coreGrooves = _child(
      _child(root, 'grooves'),
      'core-grooves',
    );
    expect(coreGrooves.kind, CompassNodeKind.topic);
    expect(coreGrooves.children.single.kind, CompassNodeKind.lesson);
    expect(coreGrooves.children.single.children, hasLength(2));
    expect(
      coreGrooves.children.single.children.first.kind,
      CompassNodeKind.exercise,
    );

    final CurriculumNode vocabulary = _child(root, 'vocabulary');
    expect(
      vocabulary.children.map((CurriculumNode node) => node.title),
      contains('Triads'),
    );
  });

  test(
    'aggregates progress from completion ratio and keeps exact metrics',
    () async {
      final LessonContentLibrary library = _library(<Lesson>[
        _lesson(
          id: 'groove-one',
          skill: 'grooves',
          exercises: <String>['a', 'b'],
        ),
        _lesson(id: 'groove-two', skill: 'grooves', exercises: <String>['c']),
        _lesson(
          id: 'rudiment-one',
          skill: 'rudiments',
          exercises: <String>['d'],
        ),
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
        library.lessonsById['rudiment-one']!,
        'd',
        practicedDuration: const Duration(minutes: 60),
      );

      final CurriculumCompassSnapshot snapshot =
          const CurriculumCompassAggregator().build(
            root: const CurriculumCompassTreeBuilder().build(library),
            nodePath: const <String>[],
            progressService: progress,
          );

      final CurriculumCompassPoint rudiments = _value(snapshot, 'rudiments');
      final CurriculumCompassPoint grooves = _value(snapshot, 'grooves');
      expect(rudiments.progressRatio, 1);
      expect(rudiments.practicedSeconds, 3600);
      expect(rudiments.completedExerciseCount, 1);
      expect(rudiments.totalExerciseCount, 1);
      expect(grooves.progressRatio, 2 / 3);
      expect(grooves.practicedSeconds, 900);
      expect(grooves.completedExerciseCount, 2);
      expect(grooves.totalExerciseCount, 3);
      expect(grooves.practicedLessonCount, 1);
    },
  );

  test('builds topic compass values from selected category children', () async {
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
    expect(snapshot.childKind, CompassNodeKind.topic);
    expect(snapshot.values, hasLength(10));
    expect(
      snapshot.breadcrumbs.map((CurriculumBreadcrumb item) => item.title),
      <String>['Curriculum', 'Grooves'],
    );

    final CurriculumCompassPoint coreGrooves = _value(snapshot, 'core-grooves');
    expect(coreGrooves.lessonFilterId, 'grooves');
    expect(coreGrooves.completedExerciseCount, 1);
    expect(coreGrooves.totalExerciseCount, 2);
    expect(coreGrooves.progressRatio, 0.5);

    final CurriculumCompassPoint rockGrooves = _value(snapshot, 'rock-grooves');
    expect(rockGrooves.totalExerciseCount, 0);
    expect(rockGrooves.progressRatio, 0);
  });

  test(
    'lesson-level compass includes only interacted lessons and pages them',
    () async {
      final LessonContentLibrary library = _library(<Lesson>[
        for (int index = 0; index < 12; index += 1)
          _lesson(
            id: 'groove-$index',
            skill: 'grooves',
            order: index + 1,
            exercises: <String>['a'],
          ),
      ]);
      final LessonProgressService progress = LessonProgressService(
        MemoryLessonProgressStore(),
      );
      await progress.load();
      for (int index = 0; index < 12; index += 1) {
        await progress.openLesson(
          'groove-$index',
          at: DateTime.utc(2026, 1, index + 1),
        );
      }

      final CurriculumNode root = const CurriculumCompassTreeBuilder().build(
        library,
      );
      final CurriculumCompassSnapshot firstPage =
          const CurriculumCompassAggregator().build(
            root: root,
            nodePath: const <String>['grooves', 'core-grooves'],
            pageIndex: 0,
            progressService: progress,
          );
      final CurriculumCompassSnapshot secondPage =
          const CurriculumCompassAggregator().build(
            root: root,
            nodePath: const <String>['grooves', 'core-grooves'],
            pageIndex: 1,
            progressService: progress,
          );

      expect(firstPage.childKind, CompassNodeKind.lesson);
      expect(firstPage.valuesFilteredByInteraction, isTrue);
      expect(firstPage.values, hasLength(defaultMaxVisibleCompassPoints));
      expect(firstPage.pageCount, 2);
      expect(firstPage.values.first.nodeId, 'lesson:groove-11');
      expect(secondPage.values, hasLength(2));
      expect(secondPage.values.first.nodeId, 'lesson:groove-1');
    },
  );

  test(
    'untouched lessons are excluded but no-interaction state is explicit',
    () async {
      final LessonContentLibrary library = _library(<Lesson>[
        _lesson(id: 'groove-one', skill: 'grooves', exercises: <String>['a']),
      ]);
      final LessonProgressService progress = LessonProgressService(
        MemoryLessonProgressStore(),
      );
      await progress.load();

      final CurriculumCompassSnapshot snapshot =
          const CurriculumCompassAggregator().build(
            root: const CurriculumCompassTreeBuilder().build(library),
            nodePath: const <String>['grooves', 'core-grooves'],
            progressService: progress,
          );

      expect(snapshot.values, isEmpty);
      expect(snapshot.hasNoInteraction, isTrue);
      expect(snapshot.hasNoContent, isFalse);
      expect(snapshot.availableChildCount, 1);
    },
  );

  test('no-content state is distinct from no-interaction state', () async {
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
          nodePath: const <String>['vocabulary', 'triads'],
          progressService: progress,
        );

    expect(snapshot.values, isEmpty);
    expect(snapshot.hasNoContent, isTrue);
    expect(snapshot.hasNoInteraction, isFalse);
  });

  test(
    'exercise-level compass includes interacted exercises with binary progress',
    () async {
      final LessonContentLibrary library = _library(<Lesson>[
        _lesson(
          id: 'groove-one',
          skill: 'grooves',
          exercises: <String>['a', 'b', 'c'],
        ),
      ]);
      final LessonProgressService progress = LessonProgressService(
        MemoryLessonProgressStore(),
      );
      await progress.load();
      final Lesson lesson = library.lessonsById['groove-one']!;
      await progress.startExercise(lesson, 'b', at: DateTime.utc(2026, 1, 1));
      await progress.completeExercise(
        lesson,
        'a',
        at: DateTime.utc(2026, 1, 2),
        practicedDuration: const Duration(seconds: 30),
      );

      final CurriculumCompassSnapshot snapshot =
          const CurriculumCompassAggregator().build(
            root: const CurriculumCompassTreeBuilder().build(library),
            nodePath: const <String>[
              'grooves',
              'core-grooves',
              'lesson:groove-one',
            ],
            progressService: progress,
          );

      expect(snapshot.childKind, CompassNodeKind.exercise);
      expect(snapshot.valuesFilteredByInteraction, isTrue);
      expect(
        snapshot.values.map((CurriculumCompassPoint value) => value.nodeId),
        <String>['exercise:groove-one:a', 'exercise:groove-one:b'],
      );
      expect(_value(snapshot, 'exercise:groove-one:a').progressRatio, 1);
      expect(_value(snapshot, 'exercise:groove-one:b').progressRatio, 0);
    },
  );

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
  int order = 1,
}) {
  return Lesson(
    id: id,
    title: id,
    level: 'beginner',
    skill: skill,
    order: order,
    estimatedMinutes: 10,
    overview: 'Overview for $id.',
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
