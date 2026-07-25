import 'package:drumcabulary/features/progress/practice_insights_screen.dart';
import 'package:drumcabulary/features/progress/skill_progress_lens_aggregator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('PracticeRadarChart selects a tapped spoke', (
    WidgetTester tester,
  ) async {
    String? selectedSkillId;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 360,
            height: 360,
            child: PracticeRadarChart(
              values: _practiceValues,
              selectedSkillId: 'timing',
              onSkillSelected: (String skillId) {
                selectedSkillId = skillId;
              },
            ),
          ),
        ),
      ),
    );

    final Offset center = tester.getCenter(find.byType(PracticeRadarChart));
    await tester.tapAt(center + const Offset(0, -120));

    expect(selectedSkillId, 'timing');
  });

  testWidgets('PracticeRadarChart handles one-skill edge state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeRadarChart(
          values: _practiceValues.take(1).toList(growable: false),
          selectedSkillId: 'timing',
          onSkillSelected: (_) {},
        ),
      ),
    );

    expect(find.text('One skill tracked'), findsOneWidget);
    expect(find.text('Timing'), findsOneWidget);
  });

  testWidgets('PracticeRadarChart handles two-skill edge state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeRadarChart(
          values: _practiceValues.take(2).toList(growable: false),
          selectedSkillId: 'timing',
          onSkillSelected: (_) {},
        ),
      ),
    );

    expect(find.text('Two skills tracked'), findsOneWidget);
  });

  testWidgets('PracticeInsightsScreen shows no-data state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: (PracticeInsightsLens lens) async =>
              SkillProgressLensSnapshot(
                lens: lens,
                values: const <SkillProgressLensValue>[],
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No curriculum skills yet'), findsOneWidget);
  });

  testWidgets('PracticeInsightsScreen starts on Practice Time lens', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(snapshotLoader: _snapshotForLens),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practice Time'), findsOneWidget);
    expect(find.text('Practice Portrait'), findsOneWidget);
    expect(
      find.text('Shows where your recorded practice time has been invested.'),
      findsOneWidget,
    );
    expect(find.text('Time invested'), findsOneWidget);
  });

  testWidgets(
    'sub-minute nonzero practice time displays as less than one minute',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeInsightsScreen(snapshotLoader: _snapshotForLens),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('< 1 min'), findsWidgets);
      expect(find.text('0 min'), findsWidgets);
    },
  );

  testWidgets('switching to Exercises Completed updates coordinated content', (
    WidgetTester tester,
  ) async {
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
        'Shows how completed exercises are distributed across your skills.',
      ),
      findsOneWidget,
    );
    expect(find.text('Exercises completed'), findsOneWidget);
    expect(find.text('2 of 3'), findsWidgets);
  });

  testWidgets('selected skill is preserved across lens changes', (
    WidgetTester tester,
  ) async {
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

    await tester.ensureVisible(find.text('Grooves').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grooves').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Exercises Completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exercises Completed'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View Lessons'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Lessons'));

    expect(openedSkillId, 'grooves');
  });

  testWidgets('completion lens shows all-zero empty state safely', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: (PracticeInsightsLens lens) async {
            if (lens == PracticeInsightsLens.practiceTime) {
              return SkillProgressLensSnapshot(
                lens: lens,
                values: _practiceValues,
              );
            }
            return SkillProgressLensSnapshot(
              lens: lens,
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
  });

  testWidgets('PracticeInsightsScreen opens selected skill in lesson flow', (
    WidgetTester tester,
  ) async {
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

    await tester.ensureVisible(find.text('View Lessons'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Lessons'));

    expect(openedSkillId, 'timing');
  });
}

Future<SkillProgressLensSnapshot> _snapshotForLens(
  PracticeInsightsLens lens,
) async {
  return SkillProgressLensSnapshot(
    lens: lens,
    values: switch (lens) {
      PracticeInsightsLens.practiceTime => _practiceValues,
      PracticeInsightsLens.exercisesCompleted => _completionValues,
    },
  );
}

const List<SkillProgressLensValue> _practiceValues = <SkillProgressLensValue>[
  SkillProgressLensValue(
    skillId: 'timing',
    label: 'Timing',
    practicedSeconds: 3600,
    normalizedValue: 1,
    practicedExerciseCount: 3,
    practicedLessonCount: 2,
    completedExerciseCount: 1,
    totalExerciseCount: 4,
    completedLessonCount: 1,
  ),
  SkillProgressLensValue(
    skillId: 'grooves',
    label: 'Grooves',
    practicedSeconds: 20,
    normalizedValue: 20 / 3600,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 2,
    totalExerciseCount: 3,
    completedLessonCount: 1,
  ),
  SkillProgressLensValue(
    skillId: 'rudiments',
    label: 'Rudiments',
    practicedSeconds: 0,
    normalizedValue: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 2,
    completedLessonCount: 0,
  ),
];

const List<SkillProgressLensValue> _completionValues = <SkillProgressLensValue>[
  SkillProgressLensValue(
    skillId: 'timing',
    label: 'Timing',
    practicedSeconds: 3600,
    normalizedValue: 0.25,
    practicedExerciseCount: 3,
    practicedLessonCount: 2,
    completedExerciseCount: 1,
    totalExerciseCount: 4,
    completedLessonCount: 1,
  ),
  SkillProgressLensValue(
    skillId: 'grooves',
    label: 'Grooves',
    practicedSeconds: 20,
    normalizedValue: 2 / 3,
    practicedExerciseCount: 1,
    practicedLessonCount: 1,
    completedExerciseCount: 2,
    totalExerciseCount: 3,
    completedLessonCount: 1,
  ),
  SkillProgressLensValue(
    skillId: 'rudiments',
    label: 'Rudiments',
    practicedSeconds: 0,
    normalizedValue: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
    completedExerciseCount: 0,
    totalExerciseCount: 2,
    completedLessonCount: 0,
  ),
];

const List<SkillProgressLensValue> _zeroCompletionValues =
    <SkillProgressLensValue>[
      SkillProgressLensValue(
        skillId: 'timing',
        label: 'Timing',
        practicedSeconds: 0,
        normalizedValue: 0,
        practicedExerciseCount: 0,
        practicedLessonCount: 0,
        completedExerciseCount: 0,
        totalExerciseCount: 4,
        completedLessonCount: 0,
      ),
      SkillProgressLensValue(
        skillId: 'grooves',
        label: 'Grooves',
        practicedSeconds: 0,
        normalizedValue: 0,
        practicedExerciseCount: 0,
        practicedLessonCount: 0,
        completedExerciseCount: 0,
        totalExerciseCount: 3,
        completedLessonCount: 0,
      ),
      SkillProgressLensValue(
        skillId: 'rudiments',
        label: 'Rudiments',
        practicedSeconds: 0,
        normalizedValue: 0,
        practicedExerciseCount: 0,
        practicedLessonCount: 0,
        completedExerciseCount: 0,
        totalExerciseCount: 2,
        completedLessonCount: 0,
      ),
    ];
