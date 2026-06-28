import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../practice/widgets/sheet_notation_display.dart';
import 'lesson_notation_document.dart';
import 'lesson_plan.dart';
import 'lesson_print_export_service.dart';
import 'lesson_progress.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  final LessonProgressService? progressService;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
    this.progressService,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  static const int _minPreviewBpm = 40;
  static const int _maxPreviewBpm = 220;
  static const int _previewBpmStep = 5;

  Timer? _practiceTimer;
  String? _activeExerciseId;
  DateTime? _practiceStartedAt;
  Duration _activeElapsed = Duration.zero;
  late int _previewBpm = _initialPreviewBpmFor(widget.lesson);

  @override
  void didUpdateWidget(covariant LessonDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson.id != widget.lesson.id) {
      _previewBpm = _initialPreviewBpmFor(widget.lesson);
    }
  }

  @override
  void dispose() {
    _practiceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Lesson lesson = widget.lesson;
    return Scaffold(
      appBar: AppBar(title: Text(lesson.title)),
      bottomNavigationBar: _LessonTempoFooter(
        bpm: _previewBpm,
        defaultBpm: _initialPreviewBpmFor(lesson),
        minBpm: _minPreviewBpm,
        maxBpm: _maxPreviewBpm,
        onBack: () => Navigator.of(context).maybePop(),
        onDecrease: () => _changePreviewBpm(-_previewBpmStep),
        onIncrease: () => _changePreviewBpm(_previewBpmStep),
        onReset: _resetPreviewBpm,
      ),
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
          children: <Widget>[
            _LessonHeader(
              lesson: lesson,
              onPrint: () => _requestPrint(context),
            ),
            const SizedBox(height: 14),
            _LessonSection(
              title: 'Exercises',
              child: Column(
                children: <Widget>[
                  for (
                    int index = 0;
                    index < lesson.exercises.length;
                    index += 1
                  )
                    Padding(
                      padding: EdgeInsets.only(
                        bottom: index == lesson.exercises.length - 1 ? 0 : 14,
                      ),
                      child: _ExerciseCard(
                        number: index + 1,
                        lesson: lesson,
                        exercise: lesson.exercises[index],
                        progress: widget.progressService?.progressForExercise(
                          lessonId: lesson.id,
                          exerciseId: lesson.exercises[index].id,
                        ),
                        previewBpm: _previewBpm,
                        active: _activeExerciseId == lesson.exercises[index].id,
                        activeElapsed: _activeElapsed,
                        onStartPractice: widget.progressService == null
                            ? null
                            : () => _startPractice(lesson.exercises[index]),
                        onCompletePractice:
                            _activeExerciseId == lesson.exercises[index].id
                            ? () => _completePractice(lesson.exercises[index])
                            : null,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPrint(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await LessonPrintExportService.printLesson(lesson: widget.lesson);
    } on Object catch (error, stackTrace) {
      debugPrint('Lesson print failed: $error\n$stackTrace');
      messenger.showSnackBar(
        const SnackBar(content: Text('Lesson print failed.')),
      );
    }
  }

  void _changePreviewBpm(int delta) {
    setState(() {
      _previewBpm = (_previewBpm + delta).clamp(_minPreviewBpm, _maxPreviewBpm);
    });
  }

  void _resetPreviewBpm() {
    setState(() {
      _previewBpm = _initialPreviewBpmFor(widget.lesson);
    });
  }

  Future<void> _startPractice(LessonExercise exercise) async {
    await widget.progressService?.startExercise(widget.lesson, exercise.id);
    _practiceTimer?.cancel();
    setState(() {
      _activeExerciseId = exercise.id;
      _practiceStartedAt = DateTime.now();
      _activeElapsed = Duration.zero;
    });
    _practiceTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final DateTime? startedAt = _practiceStartedAt;
      if (startedAt == null || !mounted) return;
      setState(() => _activeElapsed = DateTime.now().difference(startedAt));
    });
  }

  Future<void> _completePractice(LessonExercise exercise) async {
    final DateTime? startedAt = _practiceStartedAt;
    final Duration practiced = startedAt == null
        ? Duration.zero
        : DateTime.now().difference(startedAt);
    _practiceTimer?.cancel();
    await widget.progressService?.completeExercise(
      widget.lesson,
      exercise.id,
      practicedDuration: practiced,
    );
    if (!mounted) return;
    setState(() {
      _activeExerciseId = null;
      _practiceStartedAt = null;
      _activeElapsed = Duration.zero;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Exercise completed.')));
  }
}

class _LessonTempoFooter extends StatelessWidget {
  final int bpm;
  final int defaultBpm;
  final int minBpm;
  final int maxBpm;
  final VoidCallback onBack;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onReset;

  const _LessonTempoFooter({
    required this.bpm,
    required this.defaultBpm,
    required this.minBpm,
    required this.maxBpm,
    required this.onBack,
    required this.onDecrease,
    required this.onIncrease,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool canDecrease = bpm > minBpm;
    final bool canIncrease = bpm < maxBpm;
    final bool canReset = bpm != defaultBpm;
    return Material(
      color: DrumcabularyTheme.paper,
      elevation: 12,
      shadowColor: DrumcabularyTheme.ink.withValues(alpha: 0.18),
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: DrumcabularyTheme.line)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Row(
              children: <Widget>[
                _FooterIconButton(
                  tooltip: 'Back',
                  icon: Icons.arrow_back_rounded,
                  onPressed: onBack,
                ),
                const Spacer(),
                _TempoControl(
                  bpm: bpm,
                  canDecrease: canDecrease,
                  canIncrease: canIncrease,
                  onDecrease: onDecrease,
                  onIncrease: onIncrease,
                ),
                const Spacer(),
                _FooterIconButton(
                  tooltip: 'Reset tempo',
                  icon: Icons.refresh_rounded,
                  onPressed: canReset ? onReset : null,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 42,
                  child: Text(
                    'BPM',
                    textAlign: TextAlign.center,
                    style: textTheme.labelSmall?.copyWith(
                      color: DrumcabularyTheme.mutedInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TempoControl extends StatelessWidget {
  final int bpm;
  final bool canDecrease;
  final bool canIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _TempoControl({
    required this.bpm,
    required this.canDecrease,
    required this.canIncrease,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DrumcabularyTheme.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: SizedBox(
        height: 58,
        width: 172,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              tooltip: 'Slower',
              onPressed: canDecrease ? onDecrease : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            SizedBox(
              width: 62,
              child: Text(
                '$bpm',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: DrumcabularyTheme.blue,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Faster',
              onPressed: canIncrease ? onIncrease : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _FooterIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 54,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: DrumcabularyTheme.surface,
          foregroundColor: DrumcabularyTheme.ink,
          disabledForegroundColor: DrumcabularyTheme.mutedInk.withValues(
            alpha: 0.45,
          ),
          side: const BorderSide(color: DrumcabularyTheme.line),
        ),
      ),
    );
  }
}

class _LessonHeader extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onPrint;

  const _LessonHeader({required this.lesson, required this.onPrint});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DrumPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${_labelFor(lesson.level)} / ${_labelFor(lesson.skill)}',
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
            lesson.overview,
            style: textTheme.bodyLarge?.copyWith(height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            lesson.objective,
            style: textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.mutedInk,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _MetadataPill(label: 'Lesson ${lesson.order}'),
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

class _ExerciseCard extends StatelessWidget {
  final int number;
  final Lesson lesson;
  final LessonExercise exercise;
  final ExerciseProgress? progress;
  final int previewBpm;
  final bool active;
  final Duration activeElapsed;
  final VoidCallback? onStartPractice;
  final VoidCallback? onCompletePractice;

  const _ExerciseCard({
    required this.number,
    required this.lesson,
    required this.exercise,
    required this.progress,
    required this.previewBpm,
    required this.active,
    required this.activeElapsed,
    required this.onStartPractice,
    required this.onCompletePractice,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ExerciseProgress? progress = this.progress;
    final int practicedSeconds =
        (progress?.practicedSeconds ?? 0) +
        (active ? activeElapsed.inSeconds : 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: DrumcabularyTheme.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    '$number. ${exercise.title}',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.08,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _MetadataPill(
                  label: _statusLabel(progress?.status, active: active),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _TeachingText(label: 'Why', text: exercise.why),
            _TeachingText(label: 'What', text: exercise.what),
            _TeachingText(label: 'How', text: exercise.how),
            if (exercise.tempo != null) ...<Widget>[
              const SizedBox(height: 8),
              _MetadataPill(
                label: '${exercise.tempo!.start}-${exercise.tempo!.target} BPM',
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Hear It',
              style: textTheme.labelLarge?.copyWith(
                color: DrumcabularyTheme.mutedInk,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            for (
              int index = 0;
              index < exercise.notation.sections.length;
              index += 1
            ) ...[
              if (exercise.notation.sections.length > 1 &&
                  exercise.notation.sections[index].title != null) ...<Widget>[
                if (index > 0) const SizedBox(height: 12),
                Text(
                  exercise.notation.sections[index].title!,
                  style: textTheme.labelMedium?.copyWith(
                    color: DrumcabularyTheme.mutedInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              _NotationPreview(
                section: exercise.notation.sections[index],
                previewBpm: previewBpm,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                if (active)
                  FilledButton.icon(
                    onPressed: onCompletePractice,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Complete Exercise'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onStartPractice,
                    icon: const Icon(Icons.timer_outlined),
                    label: const Text('Practice It'),
                  ),
                Text(
                  active
                      ? _durationLabel(activeElapsed)
                      : _durationLabel(Duration(seconds: practicedSeconds)),
                  style: textTheme.labelLarge?.copyWith(
                    color: DrumcabularyTheme.mutedInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TeachingText extends StatelessWidget {
  final String label;
  final String text;

  const _TeachingText({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: <TextSpan>[
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}

class _NotationPreview extends StatelessWidget {
  final ExerciseNotationSection section;
  final int previewBpm;

  const _NotationPreview({required this.section, required this.previewBpm});

  @override
  Widget build(BuildContext context) {
    return DrumSheetNotationDisplay(
      document: documentForNotationSection(section),
      grouping: groupingTextFromPattern(section.pattern),
      selectable: false,
      compactLayout: true,
      minNoteWidth: 32,
      showSticking: shouldShowStickingForNotationSection(section),
      audioPreviewEnabled: true,
      audioPreviewBpm: previewBpm,
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

String _statusLabel(LessonProgressStatus? status, {required bool active}) {
  if (active) return 'Practicing';
  return switch (status) {
    LessonProgressStatus.inProgress => 'In Progress',
    LessonProgressStatus.completed => 'Complete',
    _ => 'Not Started',
  };
}

String _durationLabel(Duration duration) {
  final int minutes = duration.inMinutes;
  final int seconds = duration.inSeconds.remainder(60);
  if (minutes == 0) return '${seconds}s';
  return '${minutes}m ${seconds}s';
}

int _initialPreviewBpmFor(Lesson lesson) {
  for (final LessonExercise exercise in lesson.exercises) {
    final TempoTarget? tempo = exercise.tempo;
    if (tempo != null) {
      return tempo.start.clamp(
        _LessonDetailScreenState._minPreviewBpm,
        _LessonDetailScreenState._maxPreviewBpm,
      );
    }
  }
  return 60;
}

String _labelFor(String value) {
  return value
      .split(RegExp(r'[_\s-]+'))
      .where((String part) => part.isNotEmpty)
      .map((String part) {
        if (part.length == 1) return part.toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}
