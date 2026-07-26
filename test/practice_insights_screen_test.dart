import 'dart:math' as math;

import 'package:drumcabulary/features/progress/curriculum_compass_aggregator.dart';
import 'package:drumcabulary/features/progress/practice_insights_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('CurriculumCompassChart selects a tapped spoke', (
    WidgetTester tester,
  ) async {
    String? selectedNodeId;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 360,
            height: 360,
            child: CurriculumCompassChart(
              values: _rootValues,
              selectedNodeId: 'timing',
              onNodeSelected: (String nodeId) {
                selectedNodeId = nodeId;
              },
            ),
          ),
        ),
      ),
    );

    final Offset center = tester.getCenter(find.byType(CurriculumCompassChart));
    await tester.tapAt(center + const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(selectedNodeId, 'timing');
  });

  test(
    'compass rotation chooses the shortest path across angle boundaries',
    () {
      final double delta = shortestCompassRotationDelta(
        math.pi - 0.08,
        -math.pi + 0.08,
      );

      expect(delta, closeTo(0.16, 0.0001));
    },
  );

  test('inner zero ring maps progress without using the center', () {
    const double outerRadius = 100;

    expect(
      curriculumCompassDisplayRadiusForProgress(
        outerRadius: outerRadius,
        progressRatio: 0,
      ),
      closeTo(outerRadius * curriculumCompassInnerZeroRadiusFactor, 0.0001),
    );
    expect(
      curriculumCompassDisplayRadiusForProgress(
        outerRadius: outerRadius,
        progressRatio: 1,
      ),
      outerRadius,
    );
    expect(
      curriculumCompassDisplayRadiusForProgress(
        outerRadius: outerRadius,
        progressRatio: 0.5,
      ),
      closeTo(
        outerRadius * curriculumCompassInnerZeroRadiusFactor +
            (outerRadius -
                    outerRadius * curriculumCompassInnerZeroRadiusFactor) *
                0.5,
        0.0001,
      ),
    );
  });

  testWidgets('CurriculumCompassChart rotates selected spoke to 12 o clock', (
    WidgetTester tester,
  ) async {
    String selectedNodeId = 'timing';

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return SizedBox(
                width: 360,
                height: 360,
                child: CurriculumCompassChart(
                  values: _rootValues,
                  selectedNodeId: selectedNodeId,
                  onNodeSelected: (String nodeId) {
                    setState(() => selectedNodeId = nodeId);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tapAt(_compassNodePosition(tester, 1, 3, 120));
    await _waitForCompassRotation(tester);
    expect(selectedNodeId, 'grooves');

    await tester.tapAt(
      tester.getCenter(find.byType(CurriculumCompassChart)) +
          const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(selectedNodeId, 'grooves');
  });

  testWidgets(
    'CurriculumCompassChart waits before rotating after a single click',
    (WidgetTester tester) async {
      String selectedNodeId = 'timing';

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.ltr,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setState) {
                return SizedBox(
                  width: 360,
                  height: 360,
                  child: CurriculumCompassChart(
                    values: _rootValues,
                    selectedNodeId: selectedNodeId,
                    onNodeSelected: (String nodeId) {
                      setState(() => selectedNodeId = nodeId);
                    },
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tapAt(_compassNodePosition(tester, 1, 3, 120));
      await tester.pump(const Duration(milliseconds: 120));
      expect(selectedNodeId, 'grooves');

      await tester.tapAt(
        tester.getCenter(find.byType(CurriculumCompassChart)) +
            const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      expect(selectedNodeId, 'timing');
    },
  );

  testWidgets('CurriculumCompassChart handles one-node edge state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CurriculumCompassChart(
          values: _rootValues.take(1).toList(growable: false),
          selectedNodeId: 'timing',
          onNodeSelected: (_) {},
        ),
      ),
    );

    expect(find.text('One node tracked'), findsOneWidget);
    expect(find.text('Timing'), findsOneWidget);
    expect(find.text('Progress'), findsWidgets);
  });

  testWidgets('CurriculumCompassChart handles two-node edge state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CurriculumCompassChart(
          values: _rootValues.take(2).toList(growable: false),
          selectedNodeId: 'timing',
          onNodeSelected: (_) {},
        ),
      ),
    );

    expect(find.text('Two nodes tracked'), findsOneWidget);
  });

  testWidgets('PracticeInsightsScreen shows no-data state', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: (List<String> nodePath, int pageIndex) async =>
              const CurriculumCompassSnapshot(
                currentNode: _rootNode,
                breadcrumbs: _rootBreadcrumbs,
                values: <CurriculumCompassPoint>[],
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No curriculum nodes yet'), findsOneWidget);
  });

  testWidgets(
    'PracticeInsightsScreen shows a single Progress compass without metric lenses',
    (WidgetTester tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeInsightsScreen(snapshotLoader: _snapshotForPath),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Curriculum'), findsWidgets);
      expect(find.text('Practice Time'), findsNothing);
      expect(find.text('Exercises Completed'), findsNothing);
      expect(find.text('Practice Investment'), findsNothing);
      expect(find.text('Curriculum Completion'), findsNothing);
      expect(find.text('Curriculum Compass'), findsOneWidget);
      expect(
        find.text(
          'Maps curriculum progress while keeping practice time in context.',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('selected summary shows exact progress and supporting metrics', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForPath),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Progress'), findsWidgets);
    expect(find.text('25%'), findsWidgets);
    expect(find.text('1 hr'), findsWidgets);
    expect(find.text('Exercises completed'), findsWidgets);
    expect(find.text('1 of 4'), findsWidgets);
    expect(find.text('Lessons touched'), findsOneWidget);
  });

  testWidgets('zero-progress selected node shows intentional empty states', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForPath),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCompassNode(tester, 2);

    expect(find.text('Not practiced yet'), findsOneWidget);
    expect(find.text('No completions yet'), findsOneWidget);
    expect(find.text('0 of 2'), findsWidgets);
  });

  testWidgets(
    'sub-minute nonzero practice time displays as less than one minute',
    (WidgetTester tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeInsightsScreen(snapshotLoader: _snapshotForPath),
        ),
      );
      await tester.pumpAndSettle();

      await _tapCompassNode(tester, 1);

      expect(find.text('< 1 min'), findsWidgets);
    },
  );

  testWidgets('drill-in supports category, topic, and lesson breadcrumbs', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForPath),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCompassNode(tester, 1);
    expect(find.text('Explore Grooves'), findsOneWidget);
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    expect(find.text('Core Grooves'), findsWidgets);
    expect(find.text('Explore Core Grooves'), findsOneWidget);

    await tester.tap(find.text('Explore Core Grooves'));
    await tester.pumpAndSettle();
    expect(find.text('Money Beat'), findsWidgets);
    expect(find.text('Curriculum'), findsWidgets);
    expect(find.text('Grooves'), findsWidgets);
    expect(find.text('Core Grooves'), findsWidgets);
  });

  testWidgets('breadcrumb return preserves compass navigation', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForPath),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCompassNode(tester, 1);
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Curriculum').first);
    await tester.pumpAndSettle();

    expect(find.text('Curriculum Compass'), findsOneWidget);
    expect(find.text('Timing'), findsWidgets);
  });

  testWidgets('double-clicking a root compass label drills into the category', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForPath),
      ),
    );
    await tester.pumpAndSettle();

    await _doubleTapCompassNode(tester, 1, distance: 168);

    expect(find.text('Core Grooves'), findsWidgets);
  });

  testWidgets('no-interaction lesson state offers browse-all lessons', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    String? openedSkillId;
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: _snapshotForPath,
          onOpenSkill: (String skillId) {
            openedSkillId = skillId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCompassNode(tester, 1);
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await _tapCompassNode(tester, 1, count: 3, distance: 126);
    await tester.tap(find.text('Explore Empty Topic'));
    await tester.pumpAndSettle();

    expect(find.text('No lesson activity yet'), findsOneWidget);
    expect(find.text('View All Lessons'), findsOneWidget);
    await tester.tap(find.text('View All Lessons'));
    expect(openedSkillId, 'grooves');
  });

  testWidgets('pagination changes visible compass page and resets selection', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    final List<int> requestedPages = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: (List<String> path, int pageIndex) {
            requestedPages.add(pageIndex);
            return _snapshotForPath(path, pageIndex);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCompassNode(tester, 1);
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Core Grooves'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsWidgets);

    await tester.tap(find.text('Next set'));
    await tester.pumpAndSettle();

    expect(requestedPages, contains(1));
    expect(find.text('Lesson 10'), findsWidgets);
  });

  testWidgets('lesson and exercise contextual callbacks are available', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    String? openedLessonId;
    String? openedExerciseKey;
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: _snapshotForPath,
          onOpenLesson: (String lessonId) {
            openedLessonId = lessonId;
          },
          onOpenExercise: (String lessonId, String exerciseId) {
            openedExerciseKey = '$lessonId/$exerciseId';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCompassNode(tester, 1);
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Core Grooves'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Lesson'));
    expect(openedLessonId, 'money-beat');

    await tester.tap(find.text('Explore Money Beat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Practice Exercise'));
    expect(openedExerciseKey, 'money-beat/add-snare');
  });
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1100, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapCompassNode(
  WidgetTester tester,
  int index, {
  int count = 3,
  double distance = 120,
  int selectedIndex = 0,
}) async {
  await tester.ensureVisible(find.byType(CurriculumCompassChart));
  await tester.pumpAndSettle();
  await tester.tapAt(
    _compassNodePosition(
      tester,
      index,
      count,
      distance,
      selectedIndex: selectedIndex,
    ),
  );
  await _waitForCompassRotation(tester);
}

Future<void> _waitForCompassRotation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 370));
  await tester.pump(const Duration(milliseconds: 330));
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _doubleTapCompassNode(
  WidgetTester tester,
  int index, {
  int count = 3,
  double distance = 120,
}) async {
  await tester.ensureVisible(find.byType(CurriculumCompassChart));
  await tester.pumpAndSettle();
  final Offset position = _compassNodePosition(tester, index, count, distance);
  await tester.tapAt(position);
  await tester.pump(kDoubleTapMinTime);
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

Offset _compassNodePosition(
  WidgetTester tester,
  int index,
  int count,
  double distance, {
  int selectedIndex = 0,
}) {
  final Offset center = tester.getCenter(find.byType(CurriculumCompassChart));
  final double angle =
      -math.pi / 2 +
      (math.pi * 2 * index / count) +
      curriculumCompassTargetRotationForIndex(selectedIndex, count);
  return center + Offset(math.cos(angle), math.sin(angle)) * distance;
}

Future<CurriculumCompassSnapshot> _snapshotForPath(
  List<String> nodePath,
  int pageIndex,
) async {
  if (_samePath(nodePath, const <String>['grooves'])) {
    return _snapshot(
      currentNode: _groovesNode,
      breadcrumbs: _groovesBreadcrumbs,
      values: _groovesValues,
      childKind: CompassNodeKind.topic,
      availableChildCount: 3,
    );
  }
  if (_samePath(nodePath, const <String>['grooves', 'core-grooves'])) {
    final List<CurriculumCompassPoint> allValues = _lessonValues;
    final int start = pageIndex == 0 ? 0 : 10;
    final int end = pageIndex == 0 ? 10 : allValues.length;
    return _snapshot(
      currentNode: _coreGroovesNode,
      breadcrumbs: _coreGroovesBreadcrumbs,
      values: allValues.sublist(start, end),
      childKind: CompassNodeKind.lesson,
      availableChildCount: allValues.length,
      valuesFilteredByInteraction: true,
      pageIndex: pageIndex,
      pageCount: 2,
      totalValueCount: allValues.length,
    );
  }
  if (_samePath(nodePath, const <String>['grooves', 'empty-topic'])) {
    return _snapshot(
      currentNode: _emptyTopicNode,
      breadcrumbs: _emptyTopicBreadcrumbs,
      values: const <CurriculumCompassPoint>[],
      childKind: CompassNodeKind.lesson,
      availableChildCount: 1,
      valuesFilteredByInteraction: true,
    );
  }
  if (_samePath(nodePath, const <String>[
    'grooves',
    'core-grooves',
    'lesson:money-beat',
  ])) {
    return _snapshot(
      currentNode: _moneyBeatNode,
      breadcrumbs: _moneyBeatBreadcrumbs,
      values: _exerciseValues,
      childKind: CompassNodeKind.exercise,
      availableChildCount: 2,
      valuesFilteredByInteraction: true,
    );
  }
  return _snapshot(
    currentNode: _rootNode,
    breadcrumbs: _rootBreadcrumbs,
    values: _rootValues,
    childKind: CompassNodeKind.category,
    availableChildCount: 3,
  );
}

bool _samePath(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

CurriculumCompassSnapshot _snapshot({
  required CurriculumNode currentNode,
  required List<CurriculumBreadcrumb> breadcrumbs,
  required List<CurriculumCompassPoint> values,
  int pageIndex = 0,
  int pageCount = 0,
  int totalValueCount = 0,
  int availableChildCount = 0,
  bool valuesFilteredByInteraction = false,
  CompassNodeKind? childKind,
}) {
  return CurriculumCompassSnapshot(
    currentNode: currentNode,
    breadcrumbs: breadcrumbs,
    values: values,
    pageIndex: pageIndex,
    pageCount: pageCount,
    totalValueCount: totalValueCount == 0 ? values.length : totalValueCount,
    availableChildCount: availableChildCount,
    valuesFilteredByInteraction: valuesFilteredByInteraction,
    childKind: childKind,
  );
}

const CurriculumNode _rootNode = CurriculumNode(
  id: CurriculumCompassTreeBuilder.rootId,
  title: 'Curriculum',
  kind: CompassNodeKind.curriculum,
);

const CurriculumNode _groovesNode = CurriculumNode(
  id: 'grooves',
  title: 'Grooves',
  kind: CompassNodeKind.category,
);

const CurriculumNode _coreGroovesNode = CurriculumNode(
  id: 'core-grooves',
  title: 'Core Grooves',
  kind: CompassNodeKind.topic,
  lessonFilterId: 'grooves',
);

const CurriculumNode _emptyTopicNode = CurriculumNode(
  id: 'empty-topic',
  title: 'Empty Topic',
  kind: CompassNodeKind.topic,
  lessonFilterId: 'grooves',
);

const CurriculumNode _moneyBeatNode = CurriculumNode(
  id: 'lesson:money-beat',
  title: 'Money Beat',
  kind: CompassNodeKind.lesson,
);

const List<CurriculumBreadcrumb> _rootBreadcrumbs = <CurriculumBreadcrumb>[
  CurriculumBreadcrumb(
    id: CurriculumCompassTreeBuilder.rootId,
    title: 'Curriculum',
    kind: CompassNodeKind.curriculum,
  ),
];

const List<CurriculumBreadcrumb> _groovesBreadcrumbs = <CurriculumBreadcrumb>[
  CurriculumBreadcrumb(
    id: CurriculumCompassTreeBuilder.rootId,
    title: 'Curriculum',
    kind: CompassNodeKind.curriculum,
  ),
  CurriculumBreadcrumb(
    id: 'grooves',
    title: 'Grooves',
    kind: CompassNodeKind.category,
  ),
];

const List<CurriculumBreadcrumb> _coreGroovesBreadcrumbs =
    <CurriculumBreadcrumb>[
      CurriculumBreadcrumb(
        id: CurriculumCompassTreeBuilder.rootId,
        title: 'Curriculum',
        kind: CompassNodeKind.curriculum,
      ),
      CurriculumBreadcrumb(
        id: 'grooves',
        title: 'Grooves',
        kind: CompassNodeKind.category,
      ),
      CurriculumBreadcrumb(
        id: 'core-grooves',
        title: 'Core Grooves',
        kind: CompassNodeKind.topic,
      ),
    ];

const List<CurriculumBreadcrumb> _emptyTopicBreadcrumbs =
    <CurriculumBreadcrumb>[
      CurriculumBreadcrumb(
        id: CurriculumCompassTreeBuilder.rootId,
        title: 'Curriculum',
        kind: CompassNodeKind.curriculum,
      ),
      CurriculumBreadcrumb(
        id: 'grooves',
        title: 'Grooves',
        kind: CompassNodeKind.category,
      ),
      CurriculumBreadcrumb(
        id: 'empty-topic',
        title: 'Empty Topic',
        kind: CompassNodeKind.topic,
      ),
    ];

const List<CurriculumBreadcrumb> _moneyBeatBreadcrumbs = <CurriculumBreadcrumb>[
  CurriculumBreadcrumb(
    id: CurriculumCompassTreeBuilder.rootId,
    title: 'Curriculum',
    kind: CompassNodeKind.curriculum,
  ),
  CurriculumBreadcrumb(
    id: 'grooves',
    title: 'Grooves',
    kind: CompassNodeKind.category,
  ),
  CurriculumBreadcrumb(
    id: 'core-grooves',
    title: 'Core Grooves',
    kind: CompassNodeKind.topic,
  ),
  CurriculumBreadcrumb(
    id: 'lesson:money-beat',
    title: 'Money Beat',
    kind: CompassNodeKind.lesson,
  ),
];

const List<CurriculumCompassPoint> _rootValues = <CurriculumCompassPoint>[
  CurriculumCompassPoint(
    nodeId: 'timing',
    label: 'Timing',
    kind: CompassNodeKind.category,
    shortDescription:
        'Build steady pulse, subdivision control, and confident time feel.',
    lessonFilterId: 'timing',
    hasChildren: true,
    practicedSeconds: 3600,
    progressRatio: 0.25,
    practicedExerciseCount: 3,
    practicedLessonCount: 2,
    completedExerciseCount: 1,
    totalExerciseCount: 4,
    completedLessonCount: 1,
  ),
  CurriculumCompassPoint(
    nodeId: 'grooves',
    label: 'Grooves',
    kind: CompassNodeKind.category,
    shortDescription:
        'Develop the rhythmic patterns that support modern songs.',
    lessonFilterId: 'grooves',
    hasChildren: true,
    practicedSeconds: 20,
    progressRatio: 2 / 3,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 2,
    totalExerciseCount: 3,
    completedLessonCount: 1,
  ),
  CurriculumCompassPoint(
    nodeId: 'rudiments',
    label: 'Rudiments',
    kind: CompassNodeKind.category,
    shortDescription:
        'Strengthen the sticking vocabulary behind clean drum movement.',
    lessonFilterId: 'rudiments',
    hasChildren: true,
    practicedSeconds: 0,
    progressRatio: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 2,
    completedLessonCount: 0,
  ),
];

const List<CurriculumCompassPoint> _groovesValues = <CurriculumCompassPoint>[
  CurriculumCompassPoint(
    nodeId: 'core-grooves',
    label: 'Core Grooves',
    kind: CompassNodeKind.topic,
    shortDescription:
        'Build dependable foundational beats for common musical situations.',
    lessonFilterId: 'grooves',
    hasChildren: true,
    practicedSeconds: 20,
    progressRatio: 2 / 3,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 2,
    totalExerciseCount: 3,
    completedLessonCount: 1,
  ),
  CurriculumCompassPoint(
    nodeId: 'empty-topic',
    label: 'Empty Topic',
    kind: CompassNodeKind.topic,
    lessonFilterId: 'grooves',
    hasChildren: true,
    practicedSeconds: 0,
    progressRatio: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 1,
    completedLessonCount: 0,
  ),
  CurriculumCompassPoint(
    nodeId: 'rock-grooves',
    label: 'Rock Grooves',
    kind: CompassNodeKind.topic,
    lessonFilterId: 'rock-grooves',
    hasChildren: false,
    practicedSeconds: 0,
    progressRatio: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 0,
    completedLessonCount: 0,
  ),
];

final List<CurriculumCompassPoint> _lessonValues = <CurriculumCompassPoint>[
  _lessonPoint(
    nodeId: 'lesson:money-beat',
    label: 'Money Beat',
    lessonId: 'money-beat',
    progressRatio: 0.5,
    practicedSeconds: 120,
  ),
  for (int index = 1; index <= 10; index += 1)
    _lessonPoint(
      nodeId: 'lesson:lesson-$index',
      label: 'Lesson $index',
      lessonId: 'lesson-$index',
      progressRatio: 0,
      practicedSeconds: 30,
    ),
];

const List<CurriculumCompassPoint> _exerciseValues = <CurriculumCompassPoint>[
  CurriculumCompassPoint(
    nodeId: 'exercise:money-beat:add-snare',
    label: 'Add Snare',
    kind: CompassNodeKind.exercise,
    lessonFilterId: 'grooves',
    hasChildren: false,
    lessonId: 'money-beat',
    exerciseId: 'add-snare',
    practicedSeconds: 45,
    progressRatio: 1,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 1,
    totalExerciseCount: 1,
    completedLessonCount: 1,
  ),
  CurriculumCompassPoint(
    nodeId: 'exercise:money-beat:add-kick',
    label: 'Add Kick',
    kind: CompassNodeKind.exercise,
    lessonFilterId: 'grooves',
    hasChildren: false,
    lessonId: 'money-beat',
    exerciseId: 'add-kick',
    practicedSeconds: 10,
    progressRatio: 0,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 0,
    totalExerciseCount: 1,
    completedLessonCount: 0,
  ),
];

CurriculumCompassPoint _lessonPoint({
  required String nodeId,
  required String label,
  required String lessonId,
  required double progressRatio,
  required int practicedSeconds,
}) {
  return CurriculumCompassPoint(
    nodeId: nodeId,
    label: label,
    kind: CompassNodeKind.lesson,
    lessonFilterId: 'grooves',
    hasChildren: true,
    lessonId: lessonId,
    practicedSeconds: practicedSeconds,
    progressRatio: progressRatio,
    practicedExerciseCount: practicedSeconds > 0 ? 1 : 0,
    practicedLessonCount: practicedSeconds > 0 ? 1 : 0,
    completedExerciseCount: (progressRatio * 2).round(),
    totalExerciseCount: 2,
    completedLessonCount: progressRatio >= 1 ? 1 : 0,
  );
}
