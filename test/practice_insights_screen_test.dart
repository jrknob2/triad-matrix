import 'package:drumcabulary/features/progress/practice_insights_screen.dart';
import 'package:drumcabulary/features/progress/skill_practice_time_aggregator.dart';
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
              values: _values,
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
          values: _values.take(1).toList(growable: false),
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
          values: _values.take(2).toList(growable: false),
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
          snapshotLoader: () async => const SkillPracticeTimeSnapshot(
            values: <SkillPracticeTimeValue>[],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No curriculum skills yet'), findsOneWidget);
  });

  testWidgets('PracticeInsightsScreen opens selected skill in lesson flow', (
    WidgetTester tester,
  ) async {
    String? openedSkillId;

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: () async =>
              SkillPracticeTimeSnapshot(values: _values),
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

  testWidgets('tapping a summary row selects that skill', (
    WidgetTester tester,
  ) async {
    String? openedSkillId;

    await tester.pumpWidget(
      MaterialApp(
        home: PracticeInsightsScreen(
          snapshotLoader: () async =>
              SkillPracticeTimeSnapshot(values: _values),
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
    await tester.ensureVisible(find.text('View Lessons'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Lessons'));

    expect(openedSkillId, 'grooves');
  });
}

const List<SkillPracticeTimeValue> _values = <SkillPracticeTimeValue>[
  SkillPracticeTimeValue(
    skillId: 'timing',
    label: 'Timing',
    practicedSeconds: 3600,
    normalizedValue: 1,
    practicedExerciseCount: 3,
    practicedLessonCount: 2,
  ),
  SkillPracticeTimeValue(
    skillId: 'grooves',
    label: 'Grooves',
    practicedSeconds: 1800,
    normalizedValue: 0.5,
    practicedExerciseCount: 2,
    practicedLessonCount: 1,
  ),
  SkillPracticeTimeValue(
    skillId: 'rudiments',
    label: 'Rudiments',
    practicedSeconds: 0,
    normalizedValue: 0,
    practicedExerciseCount: 0,
    practicedLessonCount: 0,
  ),
];
