import 'dart:math' as math;

import 'package:drumcabulary/features/progress/curriculum_progress_lens_aggregator.dart';
import 'package:drumcabulary/features/progress/practice_insights_screen.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PracticeRadarChart selects a tapped spoke', (
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
            child: PracticeRadarChart(
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

    final Offset center = tester.getCenter(find.byType(PracticeRadarChart));
    await tester.tapAt(center + const Offset(0, -120));
    await tester.pumpAndSettle();

    expect(selectedNodeId, 'timing');
  });

  test('radar rotation chooses the shortest path across angle boundaries', () {
    final double delta = shortestRadarRotationDelta(
      math.pi - 0.08,
      -math.pi + 0.08,
    );

    expect(delta, closeTo(0.16, 0.0001));
  });

  testWidgets('PracticeRadarChart rotates selected spoke to 12 o clock', (
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
                child: PracticeRadarChart(
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

    await tester.tapAt(_radarNodePosition(tester, 1, 3, 120));
    await _waitForRadarRotation(tester);
    expect(selectedNodeId, 'grooves');

    await tester.tapAt(
      tester.getCenter(find.byType(PracticeRadarChart)) + const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(selectedNodeId, 'grooves');
  });

  testWidgets('PracticeRadarChart waits before rotating after a single click', (
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
                child: PracticeRadarChart(
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

    await tester.tapAt(_radarNodePosition(tester, 1, 3, 120));
    await tester.pump(const Duration(milliseconds: 120));
    expect(selectedNodeId, 'grooves');

    await tester.tapAt(
      tester.getCenter(find.byType(PracticeRadarChart)) + const Offset(0, -120),
    );
    await tester.pumpAndSettle();

    expect(selectedNodeId, 'timing');
  });

  testWidgets('PracticeRadarChart handles one-node edge state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeRadarChart(
          values: _rootPracticeValues.take(1).toList(growable: false),
          selectedNodeId: 'timing',
          onNodeSelected: (_) {},
        ),
      ),
    );

    expect(find.text('One node tracked'), findsOneWidget);
    expect(find.text('Timing'), findsOneWidget);
  });

  testWidgets('PracticeRadarChart handles two-node edge state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeRadarChart(
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
          snapshotLoader:
              (PracticeInsightsLens lens, List<String> nodePath) async =>
                  CurriculumProgressLensSnapshot(
                    lens: lens,
                    currentNode: _rootNode,
                    breadcrumbs: _rootBreadcrumbs,
                    values: const <CurriculumProgressLensValue>[],
                  ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No curriculum nodes yet'), findsOneWidget);
  });

  testWidgets('PracticeInsightsScreen starts on Practice Time lens', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForLens),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Curriculum'), findsWidgets);
    expect(find.text('Practice Time'), findsOneWidget);
    expect(find.text('Practice Portrait'), findsOneWidget);
    expect(
      find.text('Shows where your recorded practice time has been invested.'),
      findsOneWidget,
    );
    expect(find.text('Time invested'), findsNothing);
    expect(find.byType(AnimatedSwitcher), findsWidgets);
  });

  testWidgets(
    'sub-minute nonzero practice time displays as less than one minute',
    (WidgetTester tester) async {
      _useLargeSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeInsightsScreen(snapshotLoader: _snapshotForLens),
        ),
      );
      await tester.pumpAndSettle();

      await _tapRadarNode(tester, 1);
      expect(find.text('< 1 min'), findsWidgets);

      await _tapRadarNode(tester, 2, selectedIndex: 1);
      expect(find.text('0 min'), findsWidgets);
      expect(find.text('Ready to begin'), findsOneWidget);
    },
  );

  testWidgets('switching to Exercises Completed updates coordinated content', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForLens),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exercises Completed'));
    await tester.pumpAndSettle();

    expect(find.text('Completion Portrait'), findsOneWidget);
    expect(
      find.text(
        'Shows how completed exercises are distributed across the curriculum.',
      ),
      findsOneWidget,
    );
    expect(find.text('Exercises completed'), findsWidgets);
    expect(find.text('1 of 4'), findsWidgets);
  });

  testWidgets('selected node is preserved across lens changes', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForLens),
      ),
    );
    await tester.pumpAndSettle();

    await _tapRadarNode(tester, 1);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Exercises Completed'));
    await tester.tap(find.text('Exercises Completed'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 3'), findsWidgets);
  });

  testWidgets('drill-in shows second-level radar and breadcrumbs', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: _snapshotForLens,
          onOpenSkill: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapRadarNode(tester, 1);
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
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForLens),
      ),
    );
    await tester.pumpAndSettle();

    await _tapRadarNode(tester, 1);

    expect(
      find.text('Develop the rhythmic patterns that support modern songs.'),
      findsOneWidget,
    );
  });

  testWidgets('breadcrumb return preserves the selected lens', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForLens),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exercises Completed'));
    await tester.pumpAndSettle();
    await _tapRadarNode(tester, 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Curriculum').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Curriculum').first);
    await tester.pumpAndSettle();

    expect(find.text('Completion Portrait'), findsOneWidget);
    expect(find.text('Timing'), findsWidgets);
  });

  testWidgets('double-clicking a root radar label drills into the category', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: _snapshotForLens,
          onOpenSkill: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _doubleTapRadarNode(tester, 1, distance: 168);

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
          snapshotLoader: _snapshotForLens,
          onOpenSkill: (String skillId) {
            openedSkillId = skillId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapRadarNode(tester, 1);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View Lessons'));
    await tester.tap(find.text('View Lessons'));

    expect(openedSkillId, 'grooves');
  });

  testWidgets('double-clicking a second-level radar point opens lessons', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    String? openedSkillId;

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: _snapshotForLens,
          onOpenSkill: (String skillId) {
            openedSkillId = skillId;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _tapRadarNode(tester, 1);
    await tester.tap(find.text('Explore Grooves'));
    await tester.pumpAndSettle();
    await _doubleTapRadarNode(tester, 0, distance: 126);

    expect(openedSkillId, 'grooves');
  });

  testWidgets('completion lens shows all-zero empty state safely', (
    WidgetTester tester,
  ) async {
    _useLargeSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader:
              (PracticeInsightsLens lens, List<String> nodePath) async {
                if (lens == PracticeInsightsLens.practiceTime) {
                  return _snapshot(
                    lens: lens,
                    currentNode: _rootNode,
                    breadcrumbs: _rootBreadcrumbs,
                    values: _rootPracticeValues,
                  );
                }
                return _snapshot(
                  lens: lens,
                  currentNode: _rootNode,
                  breadcrumbs: _rootBreadcrumbs,
                  values: _zeroCompletionValues,
                );
              },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Exercises Completed'));
    await tester.pumpAndSettle();

    expect(find.text('No completed exercises yet'), findsOneWidget);
    expect(
      find.text(
        'Complete an exercise to begin building your completion portrait.',
      ),
      findsOneWidget,
    );
    expect(find.text('No completions yet'), findsOneWidget);
  });
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1100, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _tapRadarNode(
  WidgetTester tester,
  int index, {
  int count = 3,
  double distance = 120,
  int selectedIndex = 0,
}) async {
  await tester.ensureVisible(find.byType(PracticeRadarChart));
  await tester.pumpAndSettle();
  await tester.tapAt(
    _radarNodePosition(
      tester,
      index,
      count,
      distance,
      selectedIndex: selectedIndex,
    ),
  );
  await _waitForRadarRotation(tester);
}

Future<void> _waitForRadarRotation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 370));
  await tester.pump(const Duration(milliseconds: 330));
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _doubleTapRadarNode(
  WidgetTester tester,
  int index, {
  int count = 3,
  double distance = 120,
}) async {
  await tester.ensureVisible(find.byType(PracticeRadarChart));
  await tester.pumpAndSettle();
  final Offset position = _radarNodePosition(tester, index, count, distance);
  await tester.tapAt(position);
  await tester.pump(kDoubleTapMinTime);
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

Offset _radarNodePosition(
  WidgetTester tester,
  int index,
  int count,
  double distance, {
  int selectedIndex = 0,
}) {
  final Offset center = tester.getCenter(find.byType(PracticeRadarChart));
  final double angle =
      -math.pi / 2 +
      (math.pi * 2 * index / count) +
      radarTargetRotationForIndex(selectedIndex, count);
  return center + Offset(math.cos(angle), math.sin(angle)) * distance;
}

Future<CurriculumProgressLensSnapshot> _snapshotForLens(
  PracticeInsightsLens lens,
  List<String> nodePath,
) async {
  final bool inGrooves = nodePath.isNotEmpty && nodePath.first == 'grooves';
  return _snapshot(
    lens: lens,
    currentNode: inGrooves ? _groovesNode : _rootNode,
    breadcrumbs: inGrooves ? _groovesBreadcrumbs : _rootBreadcrumbs,
    values: switch ((lens, inGrooves)) {
      (PracticeInsightsLens.practiceTime, false) => _rootPracticeValues,
      (PracticeInsightsLens.exercisesCompleted, false) => _rootCompletionValues,
      (PracticeInsightsLens.practiceTime, true) => _groovesPracticeValues,
      (PracticeInsightsLens.exercisesCompleted, true) =>
        _groovesCompletionValues,
    },
  );
}

CurriculumProgressLensSnapshot _snapshot({
  required PracticeInsightsLens lens,
  required CurriculumNode currentNode,
  required List<CurriculumBreadcrumb> breadcrumbs,
  required List<CurriculumProgressLensValue> values,
}) {
  return CurriculumProgressLensSnapshot(
    lens: lens,
    currentNode: currentNode,
    breadcrumbs: breadcrumbs,
    values: values,
  );
}

const CurriculumNode _rootNode = CurriculumNode(
  id: CurriculumRadarTreeBuilder.rootId,
  title: 'Curriculum',
);

const CurriculumNode _groovesNode = CurriculumNode(
  id: 'grooves',
  title: 'Grooves',
);

const List<CurriculumBreadcrumb> _rootBreadcrumbs = <CurriculumBreadcrumb>[
  CurriculumBreadcrumb(
    id: CurriculumRadarTreeBuilder.rootId,
    title: 'Curriculum',
  ),
];

const List<CurriculumBreadcrumb> _groovesBreadcrumbs = <CurriculumBreadcrumb>[
  CurriculumBreadcrumb(
    id: CurriculumRadarTreeBuilder.rootId,
    title: 'Curriculum',
  ),
  CurriculumBreadcrumb(id: 'grooves', title: 'Grooves'),
];

const List<CurriculumProgressLensValue> _rootPracticeValues =
    <CurriculumProgressLensValue>[
      CurriculumProgressLensValue(
        nodeId: 'timing',
        label: 'Timing',
        shortDescription:
            'Build steady pulse, subdivision control, and confident time feel.',
        lessonFilterId: 'timing',
        hasChildren: true,
        practicedSeconds: 3600,
        normalizedValue: 1,
        practicedExerciseCount: 3,
        practicedLessonCount: 2,
        completedExerciseCount: 1,
        totalExerciseCount: 4,
        completedLessonCount: 1,
      ),
      CurriculumProgressLensValue(
        nodeId: 'grooves',
        label: 'Grooves',
        shortDescription:
            'Develop the rhythmic patterns that support modern songs.',
        lessonFilterId: 'grooves',
        hasChildren: true,
        practicedSeconds: 20,
        normalizedValue: 20 / 3600,
        practicedExerciseCount: 1,
        practicedLessonCount: 1,
        completedExerciseCount: 2,
        totalExerciseCount: 3,
        completedLessonCount: 1,
      ),
      CurriculumProgressLensValue(
        nodeId: 'rudiments',
        label: 'Rudiments',
        shortDescription:
            'Strengthen the sticking vocabulary behind clean drum movement.',
        lessonFilterId: 'rudiments',
        hasChildren: true,
        practicedSeconds: 0,
        normalizedValue: 0,
        practicedExerciseCount: 0,
        practicedLessonCount: 0,
        completedExerciseCount: 0,
        totalExerciseCount: 2,
        completedLessonCount: 0,
      ),
    ];

const List<CurriculumProgressLensValue> _rootCompletionValues =
    <CurriculumProgressLensValue>[
      CurriculumProgressLensValue(
        nodeId: 'timing',
        label: 'Timing',
        shortDescription:
            'Build steady pulse, subdivision control, and confident time feel.',
        lessonFilterId: 'timing',
        hasChildren: true,
        practicedSeconds: 3600,
        normalizedValue: 0.25,
        practicedExerciseCount: 3,
        practicedLessonCount: 2,
        completedExerciseCount: 1,
        totalExerciseCount: 4,
        completedLessonCount: 1,
      ),
      CurriculumProgressLensValue(
        nodeId: 'grooves',
        label: 'Grooves',
        shortDescription:
            'Develop the rhythmic patterns that support modern songs.',
        lessonFilterId: 'grooves',
        hasChildren: true,
        practicedSeconds: 20,
        normalizedValue: 2 / 3,
        practicedExerciseCount: 1,
        practicedLessonCount: 1,
        completedExerciseCount: 2,
        totalExerciseCount: 3,
        completedLessonCount: 1,
      ),
      CurriculumProgressLensValue(
        nodeId: 'rudiments',
        label: 'Rudiments',
        shortDescription:
            'Strengthen the sticking vocabulary behind clean drum movement.',
        lessonFilterId: 'rudiments',
        hasChildren: true,
        practicedSeconds: 0,
        normalizedValue: 0,
        practicedExerciseCount: 0,
        practicedLessonCount: 0,
        completedExerciseCount: 0,
        totalExerciseCount: 2,
        completedLessonCount: 0,
      ),
    ];

const List<CurriculumProgressLensValue> _zeroCompletionValues =
    <CurriculumProgressLensValue>[
      CurriculumProgressLensValue(
        nodeId: 'timing',
        label: 'Timing',
        shortDescription:
            'Build steady pulse, subdivision control, and confident time feel.',
        lessonFilterId: 'timing',
        hasChildren: true,
        practicedSeconds: 0,
        normalizedValue: 0,
        practicedExerciseCount: 0,
        practicedLessonCount: 0,
        completedExerciseCount: 0,
        totalExerciseCount: 4,
        completedLessonCount: 0,
      ),
      CurriculumProgressLensValue(
        nodeId: 'grooves',
        label: 'Grooves',
        shortDescription:
            'Develop the rhythmic patterns that support modern songs.',
        lessonFilterId: 'grooves',
        hasChildren: true,
        practicedSeconds: 0,
        normalizedValue: 0,
        practicedExerciseCount: 0,
        practicedLessonCount: 0,
        completedExerciseCount: 0,
        totalExerciseCount: 3,
        completedLessonCount: 0,
      ),
      CurriculumProgressLensValue(
        nodeId: 'rudiments',
        label: 'Rudiments',
        shortDescription:
            'Strengthen the sticking vocabulary behind clean drum movement.',
        lessonFilterId: 'rudiments',
        hasChildren: true,
        practicedSeconds: 0,
        normalizedValue: 0,
        practicedExerciseCount: 0,
        practicedLessonCount: 0,
        completedExerciseCount: 0,
        totalExerciseCount: 2,
        completedLessonCount: 0,
      ),
    ];

const List<CurriculumProgressLensValue>
_groovesPracticeValues = <CurriculumProgressLensValue>[
  CurriculumProgressLensValue(
    nodeId: 'core-grooves',
    label: 'Core Grooves',
    shortDescription:
        'Build dependable foundational beats for common musical situations.',
    lessonFilterId: 'grooves',
    hasChildren: false,
    practicedSeconds: 20,
    normalizedValue: 1,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 2,
    totalExerciseCount: 3,
    completedLessonCount: 1,
  ),
  CurriculumProgressLensValue(
    nodeId: 'rock-grooves',
    label: 'Rock Grooves',
    lessonFilterId: 'rock-grooves',
    hasChildren: false,
    practicedSeconds: 0,
    normalizedValue: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 0,
    completedLessonCount: 0,
  ),
  CurriculumProgressLensValue(
    nodeId: 'funk-grooves',
    label: 'Funk Grooves',
    lessonFilterId: 'funk-grooves',
    hasChildren: false,
    practicedSeconds: 0,
    normalizedValue: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 0,
    completedLessonCount: 0,
  ),
];

const List<CurriculumProgressLensValue>
_groovesCompletionValues = <CurriculumProgressLensValue>[
  CurriculumProgressLensValue(
    nodeId: 'core-grooves',
    label: 'Core Grooves',
    shortDescription:
        'Build dependable foundational beats for common musical situations.',
    lessonFilterId: 'grooves',
    hasChildren: false,
    practicedSeconds: 20,
    normalizedValue: 2 / 3,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 2,
    totalExerciseCount: 3,
    completedLessonCount: 1,
  ),
  CurriculumProgressLensValue(
    nodeId: 'rock-grooves',
    label: 'Rock Grooves',
    lessonFilterId: 'rock-grooves',
    hasChildren: false,
    practicedSeconds: 0,
    normalizedValue: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 0,
    completedLessonCount: 0,
  ),
  CurriculumProgressLensValue(
    nodeId: 'funk-grooves',
    label: 'Funk Grooves',
    lessonFilterId: 'funk-grooves',
    hasChildren: false,
    practicedSeconds: 0,
    normalizedValue: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 0,
    completedLessonCount: 0,
  ),
];
