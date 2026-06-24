import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../practice/widgets/sheet_notation_display.dart';
import 'lesson_plan.dart';
import 'lesson_print_export_service.dart';

class LessonDetailScreen extends StatelessWidget {
  final LessonPlan lessonPlan;
  final Lesson lesson;

  const LessonDetailScreen({
    super.key,
    required this.lessonPlan,
    required this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: <Widget>[
            _LessonHeader(
              lessonPlan: lessonPlan,
              lesson: lesson,
              onPrint: () => _requestPrint(context),
            ),
            const SizedBox(height: 14),
            _LessonSection(
              title: 'Patterns',
              child: _PatternList(lesson: lesson),
            ),
            const SizedBox(height: 14),
            _LessonSection(
              title: 'Exercises',
              child: _ExerciseList(lesson: lesson),
            ),
            const SizedBox(height: 14),
            _LessonSection(
              title: 'Coaching Notes',
              child: _TextList(items: lesson.coachingNotes),
            ),
            const SizedBox(height: 14),
            _LessonSection(
              title: 'Mastery Target',
              child: _TextList(items: lesson.mastery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPrint(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await LessonPrintExportService.printLesson(
        lessonPlan: lessonPlan,
        lesson: lesson,
      );
    } on Object catch (error, stackTrace) {
      debugPrint('Lesson print failed: $error\n$stackTrace');
      messenger.showSnackBar(
        const SnackBar(content: Text('Lesson print failed.')),
      );
    }
  }
}

class _LessonHeader extends StatelessWidget {
  final LessonPlan lessonPlan;
  final Lesson lesson;
  final VoidCallback onPrint;

  const _LessonHeader({
    required this.lessonPlan,
    required this.lesson,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DrumPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            lessonPlan.title,
            style: textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.mutedInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lesson.title,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            lesson.objective,
            style: textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetadataPill(label: 'Lesson ${lesson.number}'),
              _MetadataPill(label: lesson.skillFocus),
              _MetadataPill(label: '${lesson.estimatedMinutes} min'),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onPrint,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print'),
          ),
        ],
      ),
    );
  }
}

class _LessonSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _LessonSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DrumSectionTitle(text: title),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PatternList extends StatelessWidget {
  final Lesson lesson;

  const _PatternList({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int index = 0; index < lesson.patterns.length; index += 1) ...[
          if (index > 0) const Divider(height: 28),
          _PatternRow(pattern: lesson.patterns[index]),
        ],
      ],
    );
  }
}

class _PatternRow extends StatelessWidget {
  final LessonPattern pattern;

  const _PatternRow({required this.pattern});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
                pattern.title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _MetadataPill(label: pattern.role),
          ],
        ),
        const SizedBox(height: 10),
        DrumSheetNotationDisplay(
          document: DrumSheetNotationDocument.fromPattern(
            pattern.notation,
            subdivision: _subdivisionForPattern(pattern),
            feel: _feelForPattern(pattern),
            timeSignature: pattern.timeSignature,
            repeatCount: pattern.repeatCount,
            lenient: true,
          ),
          grouping: _groupingTextFromPattern(pattern.notation),
          selectable: false,
          compactLayout: true,
          minNoteWidth: 32,
          audioPreviewEnabled: true,
        ),
      ],
    );
  }
}

class _ExerciseList extends StatelessWidget {
  final Lesson lesson;

  const _ExerciseList({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int index = 0; index < lesson.exercises.length; index += 1) ...[
          if (index > 0) const Divider(height: 28),
          _ExerciseRow(exercise: lesson.exercises[index], lesson: lesson),
        ],
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final LessonExercise exercise;
  final Lesson lesson;

  const _ExerciseRow({required this.exercise, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<String> metadata = <String>[
      if (exercise.subdivision != null) 'Subdivision ${exercise.subdivision}',
      if (exercise.subdivisionSequence.isNotEmpty)
        'Sequence ${exercise.subdivisionSequence.join(' to ')}',
      if (exercise.tempo != null)
        '${exercise.tempo!.start}-${exercise.tempo!.target} BPM',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          exercise.title,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(exercise.instructions, style: textTheme.bodyMedium),
        if (metadata.isNotEmpty) ...<Widget>[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String item in metadata) _MetadataPill(label: item),
            ],
          ),
        ],
        if (exercise.flow.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _FlowSequence(flow: exercise.flow, lesson: lesson),
        ],
      ],
    );
  }
}

class _FlowSequence extends StatelessWidget {
  final List<FlowStep> flow;
  final Lesson lesson;

  const _FlowSequence({required this.flow, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final Map<String, LessonPattern> patternsById = <String, LessonPattern>{
      for (final LessonPattern pattern in lesson.patterns) pattern.id: pattern,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Flow',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        for (final FlowStep step in flow)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(Icons.arrow_right_rounded, size: 22),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${patternsById[step.pattern]?.title ?? step.pattern} x${step.repeat}',
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TextList extends StatelessWidget {
  final List<String> items;

  const _TextList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 6),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetadataPill extends StatelessWidget {
  final String label;

  const _MetadataPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.surfaceStrong,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DrumcabularyTheme.line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

DrumSheetNoteValue _subdivisionForPattern(LessonPattern pattern) {
  return _subdivisionValue(pattern.subdivision) ?? DrumSheetNoteValue.eighth;
}

DrumSheetFeel _feelForPattern(LessonPattern pattern) {
  return pattern.subdivision == 'triplet'
      ? DrumSheetFeel.triplet
      : DrumSheetFeel.straight;
}

DrumSheetNoteValue? _subdivisionValue(String? value) {
  return switch (value) {
    '4' => DrumSheetNoteValue.quarter,
    '8' => DrumSheetNoteValue.eighth,
    'triplet' => DrumSheetNoteValue.eighth,
    '16' => DrumSheetNoteValue.sixteenth,
    '32' => DrumSheetNoteValue.thirtySecond,
    _ => null,
  };
}

String _groupingTextFromPattern(String pattern) {
  final List<String> groups = _topLevelPatternGroups(pattern);
  if (groups.length <= 1) return '';
  final List<String> counts = <String>[];
  for (final String group in groups) {
    final int count = DrumSheetPatternParser.parse(group, lenient: true).length;
    if (count > 0) counts.add('$count');
  }
  return counts.length > 1 ? counts.join(' ') : '';
}

List<String> _topLevelPatternGroups(String pattern) {
  final List<String> groups = <String>[];
  final StringBuffer current = StringBuffer();
  int bracketDepth = 0;
  int parenDepth = 0;
  for (int index = 0; index < pattern.length; index += 1) {
    final String char = pattern[index];
    if (char == '[') bracketDepth += 1;
    if (char == ']' && bracketDepth > 0) bracketDepth -= 1;
    if (char == '(') parenDepth += 1;
    if (char == ')' && parenDepth > 0) parenDepth -= 1;
    if (char.trim().isEmpty && bracketDepth == 0 && parenDepth == 0) {
      if (current.isNotEmpty) {
        groups.add(current.toString());
        current.clear();
      }
      continue;
    }
    current.write(char);
  }
  if (current.isNotEmpty) groups.add(current.toString());
  return groups;
}
