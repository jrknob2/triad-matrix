import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../coach/lesson_detail_screen.dart';
import '../coach/lesson_plan.dart';
import '../coach/lesson_plan_loader.dart';
import '../coach/lesson_progress.dart';
import '../hardware/hardware_capabilities.dart';
import '../midi/midi_input_models.dart';
import '../midi/midi_input_service.dart';
import '../midi/serial_led_controller.dart';
import '../midi/shared_midi_input_service.dart';
import '../midi/shared_serial_led_controller.dart';

class TodayScreen extends StatefulWidget {
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenDevices;

  const TodayScreen({
    super.key,
    this.onOpenExplore,
    this.onOpenInsights,
    this.onOpenSettings,
    this.onOpenDevices,
  });

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Future<_TeachingFlowData> _dataFuture = _loadData();
  MidiInputService? _midiService;
  SerialLedController? _ledController;

  @override
  void initState() {
    super.initState();
    if (HardwareCapabilities.supportsDesktopHardware) {
      _midiService = SharedMidiInputService.instance
        ..addListener(_handleHardwareChanged);
      _ledController = SharedSerialLedController.instance
        ..addListener(_handleHardwareChanged);
      unawaited(_midiService!.start());
    }
  }

  @override
  void dispose() {
    _midiService?.removeListener(_handleHardwareChanged);
    _ledController?.removeListener(_handleHardwareChanged);
    super.dispose();
  }

  Future<_TeachingFlowData> _loadData() async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();
    final LessonProgressService progressService = LessonProgressService(
      const FileLessonProgressStore(),
    );
    await progressService.load();
    return _TeachingFlowData(
      library: library,
      progressService: progressService,
    );
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  void _handleHardwareChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: FutureBuilder<_TeachingFlowData>(
        future: _dataFuture,
        builder:
            (BuildContext context, AsyncSnapshot<_TeachingFlowData> snapshot) {
              if (snapshot.hasError) {
                return _LessonLoadError(error: snapshot.error);
              }
              final _TeachingFlowData? data = snapshot.data;
              if (data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _HomeView(
                data: data,
                hardwareStatus: _hardwareStatus,
                onProgressChanged: _refresh,
                onOpenExplore: widget.onOpenExplore,
                onOpenInsights: widget.onOpenInsights,
                onOpenSettings: widget.onOpenSettings,
                onOpenDevices: widget.onOpenDevices,
              );
            },
      ),
    );
  }

  _HomeHardwareStatus? get _hardwareStatus {
    final MidiInputService? midiService = _midiService;
    final SerialLedController? ledController = _ledController;
    if (midiService == null || ledController == null) return null;
    return _HomeHardwareStatus.from(
      midiService: midiService,
      ledController: ledController,
    );
  }
}

class ExploreLessonsScreen extends StatefulWidget {
  const ExploreLessonsScreen({super.key});

  @override
  State<ExploreLessonsScreen> createState() => _ExploreLessonsScreenState();
}

class _ExploreLessonsScreenState extends State<ExploreLessonsScreen> {
  late Future<_TeachingFlowData> _dataFuture = _loadData();

  Future<_TeachingFlowData> _loadData() async {
    final LessonContentLibrary library = await LessonPlanLoader.loadContent();
    final LessonProgressService progressService = LessonProgressService(
      const FileLessonProgressStore(),
    );
    await progressService.load();
    return _TeachingFlowData(
      library: library,
      progressService: progressService,
    );
  }

  void _refresh() {
    setState(() {
      _dataFuture = _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DrumScreen(
      child: FutureBuilder<_TeachingFlowData>(
        future: _dataFuture,
        builder:
            (BuildContext context, AsyncSnapshot<_TeachingFlowData> snapshot) {
              if (snapshot.hasError) {
                return _LessonLoadError(error: snapshot.error);
              }
              final _TeachingFlowData? data = snapshot.data;
              if (data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _LevelListView(data: data, onProgressChanged: _refresh);
            },
      ),
    );
  }
}

class _TeachingFlowData {
  final LessonContentLibrary library;
  final LessonProgressService progressService;

  const _TeachingFlowData({
    required this.library,
    required this.progressService,
  });
}

class _HomeView extends StatelessWidget {
  final _TeachingFlowData data;
  final _HomeHardwareStatus? hardwareStatus;
  final VoidCallback onProgressChanged;
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenDevices;

  const _HomeView({
    required this.data,
    required this.hardwareStatus,
    required this.onProgressChanged,
    required this.onOpenExplore,
    required this.onOpenInsights,
    required this.onOpenSettings,
    required this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    final List<Lesson> lessons = _orderedLessons(data.library);
    final _HomeLessonTarget? continueTarget = _continueTarget(lessons);
    final _HomeLessonTarget? nextTarget = _nextTarget(
      lessons,
      continueTarget?.lesson.id,
    );
    final _PracticeStats stats = _PracticeStats.from(
      lessons: lessons,
      progressService: data.progressService,
    );
    final bool firstRun = !stats.hasPracticeHistory;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: <Widget>[
        _HomeHeader(
          hardwareStatus: hardwareStatus,
          onOpenDevices: onOpenDevices,
        ),
        const SizedBox(height: 18),
        if (firstRun)
          _FirstRunPanel(
            onOpenExplore: onOpenExplore,
            onOpenSettings: onOpenSettings,
            onOpenDevices: hardwareStatus == null ? null : onOpenDevices,
          )
        else ...<Widget>[
          _ContinuePracticePanel(
            target: continueTarget ?? nextTarget,
            onResume: continueTarget == null && nextTarget == null
                ? null
                : () => _openLesson(
                    context,
                    (continueTarget ?? nextTarget)!.lesson,
                  ),
          ),
          const SizedBox(height: 14),
          _ProgressSummaryPanel(stats: stats, onOpenInsights: onOpenInsights),
          const SizedBox(height: 14),
          _UpNextPanel(
            target: nextTarget,
            onOpen: nextTarget == null
                ? onOpenExplore
                : () => _openLesson(context, nextTarget.lesson),
          ),
          if (stats.recentActivity.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            _RecentActivityPanel(activity: stats.recentActivity),
          ],
        ],
      ],
    );
  }

  Future<void> _openLesson(BuildContext context, Lesson lesson) async {
    await data.progressService.openLesson(lesson.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(
            lesson: lesson,
            progressService: data.progressService,
          );
        },
      ),
    );
    onProgressChanged();
  }

  _HomeLessonTarget? _continueTarget(List<Lesson> lessons) {
    _HomeLessonTarget? best;
    DateTime? bestDate;
    for (final Lesson lesson in lessons) {
      final LessonProgress progress = data.progressService.progressForLesson(
        lesson.id,
      );
      if (progress.status != LessonProgressStatus.inProgress) continue;
      final DateTime? date = progress.lastOpenedAt ?? progress.startedAt;
      if (best == null || _isAfterNullable(date, bestDate)) {
        best = _HomeLessonTarget.from(
          lesson: lesson,
          progressService: data.progressService,
        );
        bestDate = date;
      }
    }
    return best;
  }

  _HomeLessonTarget? _nextTarget(List<Lesson> lessons, String? activeLessonId) {
    for (final Lesson lesson in lessons) {
      if (lesson.id == activeLessonId) continue;
      final LessonProgress progress = data.progressService.progressForLesson(
        lesson.id,
      );
      if (progress.status != LessonProgressStatus.completed) {
        return _HomeLessonTarget.from(
          lesson: lesson,
          progressService: data.progressService,
        );
      }
    }
    return null;
  }
}

class _HomeHeader extends StatelessWidget {
  final _HomeHardwareStatus? hardwareStatus;
  final VoidCallback? onOpenDevices;

  const _HomeHeader({
    required this.hardwareStatus,
    required this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    final Widget greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _greeting(),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ready when you are.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.35,
          ),
        ),
      ],
    );

    final _HomeHardwareStatus? status = hardwareStatus;
    if (status == null) return greeting;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget devices = Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.end,
          children: <Widget>[
            _DeviceStatusChip(status: status.midi),
            _DeviceStatusChip(status: status.led),
            OutlinedButton.icon(
              onPressed: onOpenDevices,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('View Devices'),
            ),
          ],
        );
        if (constraints.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[greeting, const SizedBox(height: 14), devices],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: greeting),
            const SizedBox(width: 18),
            Flexible(child: devices),
          ],
        );
      },
    );
  }
}

class _DeviceStatusChip extends StatelessWidget {
  final _DeviceStatus status;

  const _DeviceStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(status.icon, color: DrumcabularyTheme.edgeTextPrimary),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    status.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: DrumcabularyTheme.edgeTextPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: status.connected
                              ? const Color(0xFF52D273)
                              : const Color(0xFFFFC857),
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(width: 8, height: 8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.subtitle,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: status.connected
                                  ? const Color(0xFF52D273)
                                  : DrumcabularyTheme.edgeTextSecondary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirstRunPanel extends StatelessWidget {
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenDevices;

  const _FirstRunPanel({
    required this.onOpenExplore,
    required this.onOpenSettings,
    required this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      tone: DrumPanelTone.warm,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Welcome to Drumcabulary',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Turn what you learn into focused practice.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onOpenExplore,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Explore Lessons'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.graphic_eq_rounded),
            label: const Text('Record Exercise'),
          ),
          if (onOpenDevices != null) ...<Widget>[
            const SizedBox(height: 14),
            const Divider(height: 1, color: DrumcabularyTheme.edgeBorder),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onOpenDevices,
              icon: const Icon(Icons.usb_rounded),
              label: const Text('Set Up Hardware'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContinuePracticePanel extends StatelessWidget {
  final _HomeLessonTarget? target;
  final VoidCallback? onResume;

  const _ContinuePracticePanel({required this.target, required this.onResume});

  @override
  Widget build(BuildContext context) {
    if (target == null) {
      return const DrumPanel(
        padding: EdgeInsets.all(18),
        child: Text('Choose a lesson to start practicing.'),
      );
    }
    final double progress = target!.exerciseCount == 0
        ? 0
        : target!.completedExerciseCount / target!.exerciseCount;
    return DrumPanel(
      tone: DrumPanelTone.warm,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DrumEyebrow(text: 'Keep Practicing This'),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 720;
              final Widget details = _LessonTargetDetails(target: target!);
              final Widget checklist = _ExerciseChecklist(target: target!);
              final Widget action = FilledButton.icon(
                onPressed: onResume,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume'),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    details,
                    const SizedBox(height: 14),
                    checklist,
                    const SizedBox(height: 14),
                    action,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: details),
                  const SizedBox(width: 20),
                  SizedBox(width: 310, child: checklist),
                  const SizedBox(width: 20),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 6,
              backgroundColor: DrumcabularyTheme.edgeBackground,
              color: DrumcabularyTheme.edgeOrange,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${target!.completedExerciseCount} of ${target!.exerciseCount} complete',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonTargetDetails extends StatelessWidget {
  final _HomeLessonTarget target;

  const _LessonTargetDetails({required this.target});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.36),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(
              Icons.music_note_rounded,
              color: DrumcabularyTheme.edgeOrange,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                target.lesson.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: DrumcabularyTheme.edgeTextPrimary,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                target.exercise == null
                    ? '${target.lesson.estimatedMinutes} min lesson'
                    : '${target.exercise!.title} · Exercise ${target.nextExerciseNumber} of ${target.exerciseCount}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: DrumcabularyTheme.edgeTextSecondary,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseChecklist extends StatelessWidget {
  final _HomeLessonTarget target;

  const _ExerciseChecklist({required this.target});

  @override
  Widget build(BuildContext context) {
    final List<_ExerciseChecklistItem> items = target.checklist;
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final _ExerciseChecklistItem item in items) ...<Widget>[
          _ExerciseChecklistRow(item: item),
          if (item != items.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ExerciseChecklistRow extends StatelessWidget {
  final _ExerciseChecklistItem item;

  const _ExerciseChecklistRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(5, (int index) {
            final bool filled = item.status == LessonProgressStatus.completed
                ? true
                : item.status == LessonProgressStatus.inProgress && index < 3;
            return Padding(
              padding: const EdgeInsets.only(left: 3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: filled
                      ? DrumcabularyTheme.edgeOrange
                      : DrumcabularyTheme.edgeSurfaceSecondary,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: DrumcabularyTheme.edgeBorder),
                ),
                child: const SizedBox(width: 12, height: 12),
              ),
            );
          }),
        ),
        const SizedBox(width: 8),
        if (item.status == LessonProgressStatus.completed)
          const Icon(Icons.check_circle, color: Color(0xFF52D273), size: 20)
        else
          const SizedBox(width: 20),
      ],
    );
  }
}

class _ProgressSummaryPanel extends StatelessWidget {
  final _PracticeStats stats;
  final VoidCallback? onOpenInsights;

  const _ProgressSummaryPanel({
    required this.stats,
    required this.onOpenInsights,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: SizedBox.shrink()),
              TextButton(
                onPressed: onOpenInsights,
                child: const Text('View My Insights'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 560;
              final List<Widget> metrics = <Widget>[
                _MetricBlock(
                  value: '${stats.currentStreakDays}',
                  label: 'Day Streak',
                  sublabel: stats.currentStreakDays > 0
                      ? 'Keep it going.'
                      : null,
                ),
                _MetricBlock(
                  value: _durationValue(stats.practiceSecondsThisWeek),
                  label: 'This Week',
                ),
                _MetricBlock(
                  value: '${stats.exercisesMastered}',
                  label: 'Exercises',
                  sublabel: stats.lessonsWithMasteredExercises == 0
                      ? null
                      : 'Across ${stats.lessonsWithMasteredExercises} lessons',
                ),
              ];
              if (compact) {
                return Column(
                  children: <Widget>[
                    for (final Widget metric in metrics) ...<Widget>[
                      metric,
                      if (metric != metrics.last)
                        const Divider(color: DrumcabularyTheme.edgeBorder),
                    ],
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  for (final Widget metric in metrics) ...<Widget>[
                    Expanded(child: metric),
                    if (metric != metrics.last)
                      const SizedBox(
                        height: 54,
                        child: VerticalDivider(
                          color: DrumcabularyTheme.edgeBorder,
                        ),
                      ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  final String value;
  final String label;
  final String? sublabel;

  const _MetricBlock({required this.value, required this.label, this.sublabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (sublabel != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              sublabel!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpNextPanel extends StatelessWidget {
  final _HomeLessonTarget? target;
  final VoidCallback? onOpen;

  const _UpNextPanel({required this.target, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const DrumSectionTitle(text: 'Up Next'),
                      const SizedBox(height: 12),
                      Text(
                        target?.lesson.title ?? 'Explore lessons',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: DrumcabularyTheme.edgeTextPrimary,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        target == null
                            ? 'Choose something focused to work on.'
                            : '${_labelFor(target!.lesson.skill)} · ${target!.lesson.level}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DrumcabularyTheme.edgeTextSecondary,
                        ),
                      ),
                      if (target != null) ...<Widget>[
                        const SizedBox(height: 12),
                        Text(
                          target!.lesson.overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: DrumcabularyTheme.edgeTextSecondary,
                                height: 1.35,
                              ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: onOpen,
                          icon: const Icon(Icons.explore_outlined),
                          label: const Text('Choose Something Else'),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: DrumcabularyTheme.edgeOrange,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentActivityPanel extends StatelessWidget {
  final List<_RecentPracticeActivity> activity;

  const _RecentActivityPanel({required this.activity});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DrumSectionTitle(text: 'Recent Activity'),
          const SizedBox(height: 10),
          for (final _RecentPracticeActivity item in activity) ...<Widget>[
            _RecentActivityRow(item: item),
            if (item != activity.last)
              const Divider(color: DrumcabularyTheme.edgeBorder),
          ],
        ],
      ),
    );
  }
}

class _RecentActivityRow extends StatelessWidget {
  final _RecentPracticeActivity item;

  const _RecentActivityRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          Icon(
            item.completed ? Icons.check_circle_outline : Icons.play_circle,
            size: 18,
            color: item.completed
                ? DrumcabularyTheme.edgeOrange
                : DrumcabularyTheme.edgeTextSecondary,
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(
              item.actionLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: item.completed
                    ? const Color(0xFF52D273)
                    : DrumcabularyTheme.edgeOrange,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              item.title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _relativeDay(item.date),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelListView extends StatelessWidget {
  final _TeachingFlowData data;
  final VoidCallback onProgressChanged;

  const _LevelListView({required this.data, required this.onProgressChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: <Widget>[
        Text(
          'Choose Level',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Start where the lessons match your playing today.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        for (final ContentLevel level in data.library.index.levels) ...[
          _LevelRow(
            level: level,
            summary: data.progressService.summaryForLevel(
              level,
              data.library.lessonsForLevel(level.id),
            ),
            onOpen: () => _openLevel(context, level),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Future<void> _openLevel(BuildContext context, ContentLevel level) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _SkillListScreen(
            data: data,
            level: level,
            onProgressChanged: onProgressChanged,
          );
        },
      ),
    );
    onProgressChanged();
  }
}

class _LevelRow extends StatelessWidget {
  final ContentLevel level;
  final LevelProgressSummary summary;
  final VoidCallback onOpen;

  const _LevelRow({
    required this.level,
    required this.summary,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _NavPanel(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        level.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: DrumcabularyTheme.edgeTextPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    if (summary.showsCompletionIndicator) ...<Widget>[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle,
                        color: DrumcabularyTheme.edgeOrange,
                        size: 20,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Pill(label: _durationLabel(summary.practicedSeconds)),
                    _Pill(
                      label:
                          '${summary.completedLessons}/${summary.totalLessons} complete',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            color: DrumcabularyTheme.edgeOrange,
          ),
        ],
      ),
    );
  }
}

class _SkillListScreen extends StatelessWidget {
  final _TeachingFlowData data;
  final ContentLevel level;
  final VoidCallback onProgressChanged;

  const _SkillListScreen({
    required this.data,
    required this.level,
    required this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> skills = data.library.skillsForLevel(level.id);
    return Scaffold(
      appBar: AppBar(title: Text(level.title)),
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: <Widget>[
            Text(
              'Choose Skill',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pick the area you want to work on.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            if (skills.isEmpty)
              const DrumPanel(
                padding: EdgeInsets.all(18),
                child: Text('No lessons have been added for this level yet.'),
              )
            else
              for (final String skill in skills) ...[
                _SkillRow(
                  skill: skill,
                  summary: data.progressService.summaryForSkill(
                    id: '${level.id}:$skill',
                    lessons: data.library.lessonsForSkill(
                      levelId: level.id,
                      skill: skill,
                    ),
                  ),
                  onOpen: () => _openSkill(context, skill),
                ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSkill(BuildContext context, String skill) async {
    final List<Lesson> lessons = data.library.lessonsForSkill(
      levelId: level.id,
      skill: skill,
    );
    if (lessons.length == 1) {
      await _openLesson(context, lessons.single);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return _SkillLessonsScreen(
            data: data,
            level: level,
            skill: skill,
            lessons: lessons,
            onProgressChanged: onProgressChanged,
          );
        },
      ),
    );
    onProgressChanged();
  }

  Future<void> _openLesson(BuildContext context, Lesson lesson) async {
    await data.progressService.openLesson(lesson.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(
            lesson: lesson,
            progressService: data.progressService,
          );
        },
      ),
    );
    onProgressChanged();
  }
}

class _SkillRow extends StatelessWidget {
  final String skill;
  final LevelProgressSummary summary;
  final VoidCallback onOpen;

  const _SkillRow({
    required this.skill,
    required this.summary,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _NavPanel(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _labelFor(skill),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DrumcabularyTheme.edgeTextPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Pill(label: _durationLabel(summary.practicedSeconds)),
                    _Pill(
                      label:
                          '${summary.completedLessons}/${summary.totalLessons} complete',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            color: DrumcabularyTheme.edgeOrange,
          ),
        ],
      ),
    );
  }
}

class _SkillLessonsScreen extends StatelessWidget {
  final _TeachingFlowData data;
  final ContentLevel level;
  final String skill;
  final List<Lesson> lessons;
  final VoidCallback onProgressChanged;

  const _SkillLessonsScreen({
    required this.data,
    required this.level,
    required this.skill,
    required this.lessons,
    required this.onProgressChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_labelFor(skill))),
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: <Widget>[
            Text(
              'Choose Lesson',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w900,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              level.title,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 18),
            for (final Lesson lesson in lessons) ...[
              _LessonRow(
                lesson: lesson,
                progress: data.progressService.progressForLesson(lesson.id),
                onOpen: () => _openLesson(context, lesson),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openLesson(BuildContext context, Lesson lesson) async {
    await data.progressService.openLesson(lesson.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(
            lesson: lesson,
            progressService: data.progressService,
          );
        },
      ),
    );
    onProgressChanged();
  }
}

class _LessonRow extends StatelessWidget {
  final Lesson lesson;
  final LessonProgress progress;
  final VoidCallback onOpen;

  const _LessonRow({
    required this.lesson,
    required this.progress,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return _NavPanel(
      onTap: onOpen,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  lesson.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: DrumcabularyTheme.edgeTextPrimary,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  lesson.overview,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: DrumcabularyTheme.edgeTextSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _Pill(label: 'Lesson ${lesson.order}'),
                    _Pill(label: '${lesson.estimatedMinutes} min'),
                    _Pill(label: _statusLabel(progress.status)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(
            Icons.chevron_right_rounded,
            color: DrumcabularyTheme.edgeOrange,
          ),
        ],
      ),
    );
  }
}

class _NavPanel extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _NavPanel({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LessonLoadError extends StatelessWidget {
  final Object? error;

  const _LessonLoadError({required this.error});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: <Widget>[
        DrumPanel(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const DrumSectionTitle(text: 'Lessons Unavailable'),
              const SizedBox(height: 10),
              Text(
                '$error',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _statusLabel(LessonProgressStatus status) {
  return switch (status) {
    LessonProgressStatus.inProgress => 'In Progress',
    LessonProgressStatus.completed => 'Complete',
    LessonProgressStatus.notStarted => 'Not Started',
  };
}

String _durationLabel(int seconds) {
  if (seconds <= 0) return '0m practiced';
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '${hours}h ${minutes}m practiced';
  return '${minutes}m practiced';
}

String _durationValue(int seconds) {
  if (seconds <= 0) return '0m';
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  return '${minutes}m';
}

String _greeting() {
  final int hour = DateTime.now().hour;
  if (hour < 12) return 'Good Morning';
  if (hour < 18) return 'Good Afternoon';
  return 'Good Evening';
}

String _relativeDay(DateTime date) {
  final DateTime today = _dateOnly(DateTime.now());
  final DateTime itemDate = _dateOnly(date);
  final int difference = today.difference(itemDate).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference < 7) return '${difference}d ago';
  return '${date.month}/${date.day}';
}

bool _isAfterNullable(DateTime? left, DateTime? right) {
  if (left == null) return right == null;
  if (right == null) return true;
  return left.isAfter(right);
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

List<Lesson> _orderedLessons(LessonContentLibrary library) {
  final List<Lesson> lessons = <Lesson>[];
  for (final ContentLevel level in library.index.levels) {
    final List<Lesson> levelLessons = <Lesson>[
      ...library.lessonsForLevel(level.id),
    ]..sort((Lesson a, Lesson b) => a.order.compareTo(b.order));
    lessons.addAll(levelLessons);
  }
  return lessons;
}

class _HomeHardwareStatus {
  final _DeviceStatus midi;
  final _DeviceStatus led;

  const _HomeHardwareStatus({required this.midi, required this.led});

  factory _HomeHardwareStatus.from({
    required MidiInputService midiService,
    required SerialLedController ledController,
  }) {
    return _HomeHardwareStatus(
      midi: _DeviceStatus(
        icon: Icons.graphic_eq_rounded,
        title: midiService.selectedDevice?.name ?? 'MIDI Kit',
        subtitle: _midiStatusLabel(midiService.status),
        connected: midiService.status == MidiInputStatus.connected,
      ),
      led: _DeviceStatus(
        icon: Icons.radio_button_checked_rounded,
        title: 'LED Controller',
        subtitle: _serialStatusLabel(ledController.status),
        connected: ledController.status == SerialLedConnectionStatus.connected,
      ),
    );
  }
}

class _DeviceStatus {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool connected;

  const _DeviceStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connected,
  });
}

String _midiStatusLabel(MidiInputStatus status) {
  return switch (status) {
    MidiInputStatus.connected => 'Connected',
    MidiInputStatus.scanning => 'Scanning',
    MidiInputStatus.connecting => 'Connecting',
    MidiInputStatus.noDevicesFound ||
    MidiInputStatus.disconnected => 'Not Connected',
    MidiInputStatus.connectionError => 'Connection Error',
  };
}

String _serialStatusLabel(SerialLedConnectionStatus status) {
  return switch (status) {
    SerialLedConnectionStatus.connected => 'Connected',
    SerialLedConnectionStatus.connecting => 'Connecting',
    SerialLedConnectionStatus.disconnected => 'Not Connected',
    SerialLedConnectionStatus.connectionError => 'Connection Error',
    SerialLedConnectionStatus.deviceRemoved => 'Device Removed',
  };
}

class _HomeLessonTarget {
  final Lesson lesson;
  final LessonExercise? exercise;
  final List<_ExerciseChecklistItem> checklist;
  final int completedExerciseCount;
  final int exerciseCount;
  final int nextExerciseNumber;

  const _HomeLessonTarget({
    required this.lesson,
    required this.exercise,
    required this.checklist,
    required this.completedExerciseCount,
    required this.exerciseCount,
    required this.nextExerciseNumber,
  });

  factory _HomeLessonTarget.from({
    required Lesson lesson,
    required LessonProgressService progressService,
  }) {
    int completed = 0;
    int index = 0;
    int nextIndex = 1;
    LessonExercise? nextExercise;
    final List<_ExerciseChecklistItem> checklist = <_ExerciseChecklistItem>[];
    for (final LessonExercise exercise in lesson.exercises) {
      index += 1;
      final ExerciseProgress progress = progressService.progressForExercise(
        lessonId: lesson.id,
        exerciseId: exercise.id,
      );
      checklist.add(
        _ExerciseChecklistItem(title: exercise.title, status: progress.status),
      );
      if (progress.status == LessonProgressStatus.completed) {
        completed += 1;
      } else {
        if (nextExercise == null) {
          nextExercise = exercise;
          nextIndex = index;
        }
      }
    }
    return _HomeLessonTarget(
      lesson: lesson,
      exercise: nextExercise,
      checklist: checklist,
      completedExerciseCount: completed,
      exerciseCount: lesson.exercises.length,
      nextExerciseNumber: nextExercise == null
          ? lesson.exercises.length
          : nextIndex,
    );
  }
}

class _ExerciseChecklistItem {
  final String title;
  final LessonProgressStatus status;

  const _ExerciseChecklistItem({required this.title, required this.status});
}

class _PracticeStats {
  final int currentStreakDays;
  final int practiceSecondsThisWeek;
  final int exercisesMastered;
  final int lessonsWithMasteredExercises;
  final List<_RecentPracticeActivity> recentActivity;

  const _PracticeStats({
    required this.currentStreakDays,
    required this.practiceSecondsThisWeek,
    required this.exercisesMastered,
    required this.lessonsWithMasteredExercises,
    required this.recentActivity,
  });

  bool get hasPracticeHistory {
    return currentStreakDays > 0 ||
        practiceSecondsThisWeek > 0 ||
        exercisesMastered > 0 ||
        recentActivity.isNotEmpty;
  }

  factory _PracticeStats.from({
    required List<Lesson> lessons,
    required LessonProgressService progressService,
  }) {
    final DateTime now = DateTime.now();
    final DateTime weekStart = _weekStart(now);
    final Set<DateTime> activityDays = <DateTime>{};
    final List<_RecentPracticeActivity> recent = <_RecentPracticeActivity>[];
    int weekSeconds = 0;
    int mastered = 0;
    final Set<String> masteredLessonIds = <String>{};

    for (final Lesson lesson in lessons) {
      final LessonProgress lessonProgress = progressService.progressForLesson(
        lesson.id,
      );
      final DateTime? lessonDate =
          lessonProgress.completedAt ??
          lessonProgress.lastOpenedAt ??
          lessonProgress.startedAt;
      if (lessonDate != null) {
        activityDays.add(_dateOnly(lessonDate));
        recent.add(
          _RecentPracticeActivity(
            date: lessonDate,
            title: lesson.title,
            completed: lessonProgress.status == LessonProgressStatus.completed,
          ),
        );
      }
      for (final LessonExercise exercise in lesson.exercises) {
        final ExerciseProgress exerciseProgress = progressService
            .progressForExercise(lessonId: lesson.id, exerciseId: exercise.id);
        final DateTime? exerciseDate =
            exerciseProgress.completedAt ??
            exerciseProgress.lastPracticedAt ??
            exerciseProgress.startedAt;
        if (exerciseProgress.status == LessonProgressStatus.completed) {
          mastered += 1;
          masteredLessonIds.add(lesson.id);
        }
        if (exerciseDate == null) continue;
        activityDays.add(_dateOnly(exerciseDate));
        if (!exerciseDate.isBefore(weekStart)) {
          weekSeconds += exerciseProgress.practicedSeconds;
        }
        recent.add(
          _RecentPracticeActivity(
            date: exerciseDate,
            title: exercise.title,
            completed:
                exerciseProgress.status == LessonProgressStatus.completed,
          ),
        );
      }
    }

    recent.sort(
      (_RecentPracticeActivity a, _RecentPracticeActivity b) =>
          b.date.compareTo(a.date),
    );

    return _PracticeStats(
      currentStreakDays: _currentStreak(activityDays),
      practiceSecondsThisWeek: weekSeconds,
      exercisesMastered: mastered,
      lessonsWithMasteredExercises: masteredLessonIds.length,
      recentActivity: recent.take(3).toList(growable: false),
    );
  }
}

class _RecentPracticeActivity {
  final DateTime date;
  final String title;
  final bool completed;

  const _RecentPracticeActivity({
    required this.date,
    required this.title,
    required this.completed,
  });

  String get actionLabel => completed ? 'Completed' : 'Practiced';
}

DateTime _weekStart(DateTime date) {
  final DateTime day = _dateOnly(date);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

int _currentStreak(Set<DateTime> activityDays) {
  if (activityDays.isEmpty) return 0;
  DateTime cursor = _dateOnly(DateTime.now());
  if (!activityDays.contains(cursor)) {
    final DateTime yesterday = cursor.subtract(const Duration(days: 1));
    if (!activityDays.contains(yesterday)) return 0;
    cursor = yesterday;
  }
  int count = 0;
  while (activityDays.contains(cursor)) {
    count += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
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
