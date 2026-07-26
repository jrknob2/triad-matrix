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
              values: _rootPracticeValues,
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
                  values: _rootPracticeValues,
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
                    values: _rootPracticeValues,
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
          values: _rootPracticeValues.take(1).toList(growable: false),
          selectedNodeId: 'timing',
          onNodeSelected: (_) {},
        ),
      ),
    );

    expect(find.text('One node tracked'), findsOneWidget);
    expect(find.text('Timing'), findsOneWidget);
  });

  testWidgets('CurriculumCompassChart handles two-node edge state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CurriculumCompassChart(
          values: _rootPracticeValues.take(2).toList(growable: false),
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
          snapshotLoader: (List<String> nodePath) async =>
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
    'PracticeInsightsScreen shows Curriculum Compass without a lens selector',
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
      expect(find.text('Curriculum Compass'), findsOneWidget);
      expect(find.text('Practice Investment'), findsOneWidget);
      expect(find.text('Curriculum Completion'), findsOneWidget);
      expect(
        find.text(
          'Maps where practice time is invested and how much curriculum work is complete.',
        ),
        findsOneWidget,
      );
      expect(find.byType(AnimatedSwitcher), findsWidgets);
    },
  );

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

      await _tapCompassNode(tester, 2, selectedIndex: 1);
      expect(find.text('0 min'), findsWidgets);
      expect(find.text('Not practiced yet'), findsOneWidget);
    },
  );

  testWidgets('selected summary shows exact practice and completion metrics', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForPath),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 hr'), findsWidgets);
    expect(find.text('Exercises completed'), findsWidgets);
    expect(find.text('1 of 4'), findsWidgets);
    expect(find.text('Lessons touched'), findsOneWidget);
    expect(find.text('2'), findsWidgets);
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

  testWidgets('drill-in shows second-level compass and breadcrumbs', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: _snapshotForPath,
          onOpenSkill: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapCompassNode(tester, 1);
    await tester.pumpAndSettle();
    expect(find.text('Explore Grooves'), findsOneWidget);
    expect(find.text('Open Category'), findsNothing);
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();

    expect(find.text('Curriculum'), findsWidgets);
    expect(find.text('Grooves'), findsWidgets);
    expect(find.text('Core Grooves'), findsWidgets);
    expect(find.text('View Lessons'), findsOneWidget);
  });

  testWidgets('selected nodes can show short descriptions', (
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

    expect(
      find.text('Develop the rhythmic patterns that support modern songs.'),
      findsOneWidget,
    );
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Curriculum').first);
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
        home: PracticeInsightsScreen(
          snapshotLoader: _snapshotForPath,
          onOpenSkill: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _doubleTapCompassNode(tester, 1, distance: 168);

    expect(find.text('Core Grooves'), findsWidgets);
  });

  testWidgets('second-level View Lessons opens the existing lesson flow', (
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View Lessons'));
    await tester.tap(find.text('View Lessons'));

    expect(openedSkillId, 'grooves');
  });

  testWidgets('double-clicking a second-level compass point opens lessons', (
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
    await _doubleTapCompassNode(tester, 0, distance: 126);

    expect(openedSkillId, 'grooves');
  });

  testWidgets('no-content selected node shows no-exercises state', (
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
    await _tapCompassNode(tester, 1, count: 3, distance: 126);

    expect(find.text('No exercises yet'), findsWidgets);
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
) async {
  final bool inGrooves = nodePath.isNotEmpty && nodePath.first == 'grooves';
  return _snapshot(
    currentNode: inGrooves ? _groovesNode : _rootNode,
    breadcrumbs: inGrooves ? _groovesBreadcrumbs : _rootBreadcrumbs,
    values: inGrooves ? _groovesValues : _rootPracticeValues,
  );
}

CurriculumCompassSnapshot _snapshot({
  required CurriculumNode currentNode,
  required List<CurriculumBreadcrumb> breadcrumbs,
  required List<CurriculumCompassPoint> values,
}) {
  return CurriculumCompassSnapshot(
    currentNode: currentNode,
    breadcrumbs: breadcrumbs,
    values: values,
  );
}

const CurriculumNode _rootNode = CurriculumNode(
  id: CurriculumCompassTreeBuilder.rootId,
  title: 'Curriculum',
);

const CurriculumNode _groovesNode = CurriculumNode(
  id: 'grooves',
  title: 'Grooves',
);

const List<CurriculumBreadcrumb> _rootBreadcrumbs = <CurriculumBreadcrumb>[
  CurriculumBreadcrumb(
    id: CurriculumCompassTreeBuilder.rootId,
    title: 'Curriculum',
  ),
];

const List<CurriculumBreadcrumb> _groovesBreadcrumbs = <CurriculumBreadcrumb>[
  CurriculumBreadcrumb(
    id: CurriculumCompassTreeBuilder.rootId,
    title: 'Curriculum',
  ),
  CurriculumBreadcrumb(id: 'grooves', title: 'Grooves'),
];

const List<CurriculumCompassPoint> _rootPracticeValues =
    <CurriculumCompassPoint>[
      CurriculumCompassPoint(
        nodeId: 'timing',
        label: 'Timing',
        shortDescription:
            'Build steady pulse, subdivision control, and confident time feel.',
        lessonFilterId: 'timing',
        hasChildren: true,
        practicedSeconds: 3600,
        practiceInvestmentRatio: 1,
        completionRatio: 0.25,
        practicedExerciseCount: 3,
        practicedLessonCount: 2,
        completedExerciseCount: 1,
        totalExerciseCount: 4,
        completedLessonCount: 1,
      ),
      CurriculumCompassPoint(
        nodeId: 'grooves',
        label: 'Grooves',
        shortDescription:
            'Develop the rhythmic patterns that support modern songs.',
        lessonFilterId: 'grooves',
        hasChildren: true,
        practicedSeconds: 20,
        practiceInvestmentRatio: 20 / 3600,
        completionRatio: 2 / 3,
        practicedExerciseCount: 1,
        practicedLessonCount: 1,
        completedExerciseCount: 2,
        totalExerciseCount: 3,
        completedLessonCount: 1,
      ),
      CurriculumCompassPoint(
        nodeId: 'rudiments',
        label: 'Rudiments',
        shortDescription:
            'Strengthen the sticking vocabulary behind clean drum movement.',
        lessonFilterId: 'rudiments',
        hasChildren: true,
        practicedSeconds: 0,
        practiceInvestmentRatio: 0,
        completionRatio: 0,
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
    shortDescription:
        'Build dependable foundational beats for common musical situations.',
    lessonFilterId: 'grooves',
    hasChildren: false,
    practicedSeconds: 20,
    practiceInvestmentRatio: 1,
    completionRatio: 2 / 3,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 2,
    totalExerciseCount: 3,
    completedLessonCount: 1,
  ),
  CurriculumCompassPoint(
    nodeId: 'rock-grooves',
    label: 'Rock Grooves',
    lessonFilterId: 'rock-grooves',
    hasChildren: false,
    practicedSeconds: 0,
    practiceInvestmentRatio: 0,
    completionRatio: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 0,
    completedLessonCount: 0,
  ),
  CurriculumCompassPoint(
    nodeId: 'funk-grooves',
    label: 'Funk Grooves',
    lessonFilterId: 'funk-grooves',
    hasChildren: false,
    practicedSeconds: 0,
    practiceInvestmentRatio: 0,
    completionRatio: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 0,
    completedLessonCount: 0,
  ),
];
