import 'dart:async';

import 'package:flutter/material.dart';

import '../../state/app_controller.dart';
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
  final AppController controller;
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenDevices;

  const TodayScreen({
    super.key,
    required this.controller,
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
                studentName: widget.controller.profile.studentName,
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
  final VoidCallback? onOpenDevices;

  const ExploreLessonsScreen({super.key, this.onOpenDevices});

  @override
  State<ExploreLessonsScreen> createState() => _ExploreLessonsScreenState();
}

class _ExploreLessonsScreenState extends State<ExploreLessonsScreen> {
  late Future<_TeachingFlowData> _dataFuture = _loadData();
  late final TextEditingController _searchController;
  String _query = '';
  bool _filterPanelExpanded = false;
  _ExploreSort _sort = _ExploreSort.relevance;
  final Map<_ExploreFilterGroupKey, Set<String>> _selectedFilters =
      <_ExploreFilterGroupKey, Set<String>>{
        for (final _ExploreFilterGroupKey key in _ExploreFilterGroupKey.values)
          key: <String>{},
      };

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
              return _ExploreSearchView(
                data: data,
                searchController: _searchController,
                query: _query,
                selectedFilters: _selectedFilters,
                filterPanelExpanded: _filterPanelExpanded,
                sort: _sort,
                onQueryChanged: _setQuery,
                onFilterToggled: _toggleFilter,
                onFilterRemoved: _removeFilter,
                onFilterPanelToggled: _toggleFilterPanel,
                onSortChanged: _setSort,
                onClearFilters: _clearFilters,
                onProgressChanged: _refresh,
                onOpenDevices: widget.onOpenDevices,
              );
            },
      ),
    );
  }

  void _setQuery(String value) {
    setState(() {
      _query = value;
      _enforceStatusGate();
    });
  }

  void _toggleFilter(_ExploreFilterGroupKey key, String value) {
    setState(() {
      final Set<String> values = _selectedFilters[key]!;
      if (key == _ExploreFilterGroupKey.status) {
        if (values.contains(value)) {
          values.clear();
        } else {
          values
            ..clear()
            ..add(value);
        }
        _enforceStatusGate();
        return;
      }
      if (!values.add(value)) {
        values.remove(value);
      }
      _enforceStatusGate();
    });
  }

  void _removeFilter(_ExploreFilterGroupKey key, String value) {
    setState(() {
      _selectedFilters[key]?.remove(value);
      _enforceStatusGate();
    });
  }

  void _toggleFilterPanel() {
    setState(() {
      _filterPanelExpanded = !_filterPanelExpanded;
    });
  }

  void _setSort(_ExploreSort? sort) {
    if (sort == null) return;
    setState(() {
      _sort = sort;
    });
  }

  void _clearFilters() {
    setState(() {
      for (final Set<String> values in _selectedFilters.values) {
        values.clear();
      }
    });
  }

  void _enforceStatusGate() {
    if (_statusNotStartedEnabled(_query, _selectedFilters)) return;
    _selectedFilters[_ExploreFilterGroupKey.status]?.remove(_notStartedStatus);
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
  final String studentName;
  final _HomeHardwareStatus? hardwareStatus;
  final VoidCallback onProgressChanged;
  final VoidCallback? onOpenExplore;
  final VoidCallback? onOpenInsights;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onOpenDevices;

  const _HomeView({
    required this.data,
    required this.studentName,
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
          studentName: studentName,
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
          _ProgressPanel(stats: stats, onOpenInsights: onOpenInsights),
          const SizedBox(height: 14),
          _UpNextPanel(
            target: nextTarget,
            onOpenTarget: nextTarget == null
                ? onOpenExplore
                : () => _openLesson(context, nextTarget.lesson),
            onChooseSomethingElse: onOpenExplore,
          ),
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
            onOpenDevices: onOpenDevices,
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
  final String studentName;
  final _HomeHardwareStatus? hardwareStatus;
  final VoidCallback? onOpenDevices;

  const _HomeHeader({
    required this.studentName,
    required this.hardwareStatus,
    required this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    final Widget greeting = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _greeting(studentName),
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
            _DeviceStatusChip(status: status.midi, onPressed: onOpenDevices),
            _DeviceStatusChip(status: status.led, onPressed: onOpenDevices),
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
  final VoidCallback? onPressed;

  const _DeviceStatusChip({required this.status, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(14);
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: DrumcabularyTheme.edgeSurface,
          borderRadius: borderRadius,
          border: Border.all(color: DrumcabularyTheme.edgeBorder),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          hoverColor: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.10),
          focusColor: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.14),
          splashColor: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.18),
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
                          fontWeight: FontWeight.w700,
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
                                  fontWeight: FontWeight.w700,
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
              fontWeight: FontWeight.w700,
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
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
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
                  Flexible(flex: 5, child: details),
                  const SizedBox(width: 14),
                  Flexible(
                    flex: 4,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 330),
                        child: checklist,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Align(alignment: Alignment.centerRight, child: action),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
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
                  fontWeight: FontWeight.w800,
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(5, (int index) {
            final bool completed =
                item.status == LessonProgressStatus.completed;
            final bool current = item.status == LessonProgressStatus.inProgress;
            final Color borderColor = completed || current
                ? DrumcabularyTheme.edgeOrange
                : DrumcabularyTheme.edgeOrange.withValues(alpha: 0.34);
            return Padding(
              padding: const EdgeInsets.only(left: 3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: completed
                      ? DrumcabularyTheme.edgeOrange
                      : DrumcabularyTheme.edgeSurface,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: borderColor,
                    width: current ? 1.4 : 1.1,
                  ),
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

class _ProgressPanel extends StatelessWidget {
  final _PracticeStats stats;
  final VoidCallback? onOpenInsights;

  const _ProgressPanel({required this.stats, required this.onOpenInsights});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(child: DrumSectionTitle(text: 'Progress')),
              if (onOpenInsights != null)
                TextButton(
                  onPressed: onOpenInsights,
                  child: const Text('View My Insights'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressSummary(stats: stats),
          if (stats.recentActivity.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            const Divider(color: DrumcabularyTheme.edgeBorder),
            const SizedBox(height: 14),
            _RecentActivityList(activity: stats.recentActivity),
          ],
        ],
      ),
    );
  }
}

class _ProgressSummary extends StatelessWidget {
  final _PracticeStats stats;

  const _ProgressSummary({required this.stats});

  @override
  Widget build(BuildContext context) {
    final List<Widget> metrics = <Widget>[
      _MetricBlock(
        value: '${stats.currentStreakDays}',
        label: 'Day Streak',
        sublabel: stats.currentStreakDays > 0 ? 'Keep it going.' : null,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (constraints.maxWidth < 520) {
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
    );
  }
}

class _ProgressSubsectionTitle extends StatelessWidget {
  final String text;

  const _ProgressSubsectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: DrumcabularyTheme.edgeTextPrimary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
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
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (sublabel != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              sublabel!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                fontWeight: FontWeight.w600,
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
  final VoidCallback? onOpenTarget;
  final VoidCallback? onChooseSomethingElse;

  const _UpNextPanel({
    required this.target,
    required this.onOpenTarget,
    required this.onChooseSomethingElse,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const DrumSectionTitle(text: 'Up Next'),
            const SizedBox(height: 12),
            _UpNextContentLink(target: target, onOpen: onOpenTarget),
            if (target != null) ...<Widget>[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onChooseSomethingElse,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Choose Something Else'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpNextContentLink extends StatelessWidget {
  final _HomeLessonTarget? target;
  final VoidCallback? onOpen;

  const _UpNextContentLink({required this.target, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      target?.lesson.title ?? 'Explore lessons',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: DrumcabularyTheme.edgeTextPrimary,
                        fontWeight: FontWeight.w800,
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
                      const SizedBox(height: 10),
                      Text(
                        target!.lesson.overview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DrumcabularyTheme.edgeTextSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: DrumcabularyTheme.edgeSurfaceSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DrumcabularyTheme.edgeBorder),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: DrumcabularyTheme.edgeOrange,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<_RecentPracticeActivity> activity;

  const _RecentActivityList({required this.activity});

  @override
  Widget build(BuildContext context) {
    if (activity.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _ProgressSubsectionTitle(text: 'Recent Activity'),
        const SizedBox(height: 10),
        for (final _RecentPracticeActivity item in activity) ...<Widget>[
          _RecentActivityRow(item: item),
          if (item != activity.last)
            const Divider(color: DrumcabularyTheme.edgeBorder),
        ],
      ],
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
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget icon = Icon(
            item.completed ? Icons.check_circle_outline : Icons.play_circle,
            size: 18,
            color: item.completed
                ? DrumcabularyTheme.edgeOrange
                : DrumcabularyTheme.edgeTextSecondary,
          );
          final Widget action = Text(
            item.actionLabel,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: item.completed
                  ? const Color(0xFF52D273)
                  : DrumcabularyTheme.edgeOrange,
              fontWeight: FontWeight.w800,
            ),
          );
          final Widget title = Text(
            item.title,
            maxLines: constraints.maxWidth < 440 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          );
          final Widget date = Text(
            _relativeDay(item.date),
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
              fontWeight: FontWeight.w700,
            ),
          );

          if (constraints.maxWidth < 440) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    icon,
                    const SizedBox(width: 10),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 82),
                      child: action,
                    ),
                    const Spacer(),
                    date,
                  ],
                ),
                const SizedBox(height: 5),
                Padding(padding: const EdgeInsets.only(left: 28), child: title),
              ],
            );
          }

          return Row(
            children: <Widget>[
              icon,
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 86, maxWidth: 106),
                child: action,
              ),
              const SizedBox(width: 10),
              Expanded(child: title),
              const SizedBox(width: 8),
              Align(alignment: Alignment.centerRight, child: date),
            ],
          );
        },
      ),
    );
  }
}

enum _ExploreFilterGroupKey {
  skills,
  difficulty,
  genre,
  status,
  timeSignature,
  rudiments,
  tempoRange,
  equipment,
  feel,
  subdivision,
  handFocus,
  footFocus,
}

const String _notStartedStatus = 'Not Started';

enum _ExploreSort {
  relevance('Relevance'),
  alphabetical('Alphabetical'),
  newest('Newest'),
  shortest('Shortest'),
  longest('Longest');

  final String label;

  const _ExploreSort(this.label);
}

class _ExploreSearchView extends StatelessWidget {
  final _TeachingFlowData data;
  final TextEditingController searchController;
  final String query;
  final Map<_ExploreFilterGroupKey, Set<String>> selectedFilters;
  final bool filterPanelExpanded;
  final _ExploreSort sort;
  final ValueChanged<String> onQueryChanged;
  final void Function(_ExploreFilterGroupKey key, String value) onFilterToggled;
  final void Function(_ExploreFilterGroupKey key, String value) onFilterRemoved;
  final VoidCallback onFilterPanelToggled;
  final ValueChanged<_ExploreSort?> onSortChanged;
  final VoidCallback onClearFilters;
  final VoidCallback onProgressChanged;
  final VoidCallback? onOpenDevices;

  const _ExploreSearchView({
    required this.data,
    required this.searchController,
    required this.query,
    required this.selectedFilters,
    required this.filterPanelExpanded,
    required this.sort,
    required this.onQueryChanged,
    required this.onFilterToggled,
    required this.onFilterRemoved,
    required this.onFilterPanelToggled,
    required this.onSortChanged,
    required this.onClearFilters,
    required this.onProgressChanged,
    required this.onOpenDevices,
  });

  @override
  Widget build(BuildContext context) {
    final List<_ExploreLessonItem> items = _exploreLessonItems(data);
    final List<_ExploreLessonItem> results =
        <_ExploreLessonItem>[
          for (final _ExploreLessonItem item in items)
            if (item.matches(query: query, selectedFilters: selectedFilters))
              item,
        ]..sort(
          (_ExploreLessonItem a, _ExploreLessonItem b) =>
              _compareExploreItems(a, b, sort, query, selectedFilters),
        );
    final bool hasActiveSearch = _hasActiveExploreSearch(
      query,
      selectedFilters,
    );
    final bool hasActiveFilters = _hasActiveExploreFilters(selectedFilters);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
      children: <Widget>[
        _ExploreHeader(
          searchController: searchController,
          query: query,
          onQueryChanged: onQueryChanged,
        ),
        const SizedBox(height: 12),
        _ExploreFilters(
          items: items,
          query: query,
          selectedFilters: selectedFilters,
          filterPanelExpanded: filterPanelExpanded,
          hasActiveFilters: hasActiveFilters,
          onFilterToggled: onFilterToggled,
          onFilterRemoved: onFilterRemoved,
          onFilterPanelToggled: onFilterPanelToggled,
          onClearFilters: onClearFilters,
        ),
        const SizedBox(height: 22),
        _ExploreResultsHeader(
          count: results.length,
          sort: sort,
          onSortChanged: onSortChanged,
        ),
        const SizedBox(height: 12),
        if (results.isEmpty)
          _ExploreEmptyState(
            hasActiveSearch: hasActiveSearch,
            hasActiveFilters: hasActiveFilters,
            onClearFilters: onClearFilters,
          )
        else
          for (final _ExploreLessonItem item in results) ...<Widget>[
            _ExploreLessonCard(
              item: item,
              onOpen: () => _openLesson(context, item),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  Future<void> _openLesson(
    BuildContext context,
    _ExploreLessonItem item,
  ) async {
    await data.progressService.openLesson(item.lesson.id);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return LessonDetailScreen(
            lesson: item.lesson,
            progressService: data.progressService,
            onOpenDevices: onOpenDevices,
          );
        },
      ),
    );
    onProgressChanged();
  }
}

class _ExploreHeader extends StatelessWidget {
  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;

  const _ExploreHeader({
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'What are you working on today?',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Search lessons and exercises or filter by what matters to you.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: searchController,
          onChanged: onQueryChanged,
          textInputAction: TextInputAction.search,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w800,
          ),
          decoration: InputDecoration(
            hintText: 'Search lessons or exercises',
            hintStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextMuted,
              fontWeight: FontWeight.w700,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: DrumcabularyTheme.edgeTextSecondary,
            ),
            suffixIcon: query.trim().isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      searchController.clear();
                      onQueryChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: DrumcabularyTheme.edgeSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: DrumcabularyTheme.edgeBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: DrumcabularyTheme.edgeOrange,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExploreFilters extends StatelessWidget {
  final List<_ExploreLessonItem> items;
  final String query;
  final Map<_ExploreFilterGroupKey, Set<String>> selectedFilters;
  final bool filterPanelExpanded;
  final bool hasActiveFilters;
  final void Function(_ExploreFilterGroupKey key, String value) onFilterToggled;
  final void Function(_ExploreFilterGroupKey key, String value) onFilterRemoved;
  final VoidCallback onFilterPanelToggled;
  final VoidCallback onClearFilters;

  const _ExploreFilters({
    required this.items,
    required this.query,
    required this.selectedFilters,
    required this.filterPanelExpanded,
    required this.hasActiveFilters,
    required this.onFilterToggled,
    required this.onFilterRemoved,
    required this.onFilterPanelToggled,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final List<_ExploreFilterGroup> groups = _exploreFilterGroups(items);
    final bool notStartedEnabled = _statusNotStartedEnabled(
      query,
      selectedFilters,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (hasActiveFilters) ...<Widget>[
          _ExploreActiveFilterBadges(
            groups: groups,
            selectedFilters: selectedFilters,
            onRemoved: onFilterRemoved,
            onClearFilters: onClearFilters,
          ),
          const SizedBox(height: 12),
        ],
        _AddFilterButton(
          expanded: filterPanelExpanded,
          onPressed: onFilterPanelToggled,
        ),
        if (filterPanelExpanded) ...<Widget>[
          const SizedBox(height: 12),
          DrumPanel(
            tone: DrumPanelTone.dark,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final _ExploreFilterGroup group in groups)
                  _ExploreFilterGroupView(
                    group: group,
                    selectedValues:
                        selectedFilters[group.key] ?? const <String>{},
                    notStartedEnabled: notStartedEnabled,
                    onToggled: (String value) =>
                        onFilterToggled(group.key, value),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ExploreActiveFilterBadges extends StatelessWidget {
  final List<_ExploreFilterGroup> groups;
  final Map<_ExploreFilterGroupKey, Set<String>> selectedFilters;
  final void Function(_ExploreFilterGroupKey key, String value) onRemoved;
  final VoidCallback onClearFilters;

  const _ExploreActiveFilterBadges({
    required this.groups,
    required this.selectedFilters,
    required this.onRemoved,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> badges = <Widget>[];
    for (final _ExploreFilterGroup group in groups) {
      final Set<String> values = selectedFilters[group.key] ?? const <String>{};
      for (final String value in values) {
        badges.add(
          InputChip(
            label: Text(value),
            onDeleted: () => onRemoved(group.key, value),
            deleteIcon: const Icon(Icons.close_rounded, size: 16),
            visualDensity: VisualDensity.compact,
            backgroundColor: DrumcabularyTheme.edgeSurfaceSecondary,
            deleteIconColor: DrumcabularyTheme.edgeTextSecondary,
            side: const BorderSide(color: DrumcabularyTheme.edgeOrange),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        );
      }
    }

    if (badges.isEmpty) return const SizedBox.shrink();
    badges.add(
      TextButton(onPressed: onClearFilters, child: const Text('Clear All')),
    );

    return Wrap(spacing: 8, runSpacing: 8, children: badges);
  }
}

class _AddFilterButton extends StatelessWidget {
  final bool expanded;
  final VoidCallback onPressed;

  const _AddFilterButton({required this.expanded, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(expanded ? Icons.remove_rounded : Icons.add_rounded),
      label: Text(expanded ? 'Hide Filters' : 'Add Filter'),
    );
  }
}

class _ExploreFilterGroupView extends StatelessWidget {
  final _ExploreFilterGroup group;
  final Set<String> selectedValues;
  final bool notStartedEnabled;
  final ValueChanged<String> onToggled;

  const _ExploreFilterGroupView({
    required this.group,
    required this.selectedValues,
    required this.notStartedEnabled,
    required this.onToggled,
  });

  @override
  Widget build(BuildContext context) {
    if (group.values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final Widget label = Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              group.label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          );
          final Widget chips = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String value in group.values) _chipForValue(value),
            ],
          );
          final Widget content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              chips,
              if (group.key == _ExploreFilterGroupKey.status &&
                  !notStartedEnabled) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  'Narrow the catalog first to use Not Started.',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: DrumcabularyTheme.edgeTextMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );

          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[label, const SizedBox(height: 8), content],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(width: 140, child: label),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _chipForValue(String value) {
    final bool disabled =
        group.key == _ExploreFilterGroupKey.status &&
        value == _notStartedStatus &&
        !notStartedEnabled;
    final Widget chip = DrumSelectablePill(
      selected: selectedValues.contains(value),
      onPressed: disabled ? null : () => onToggled(value),
      label: Text(value),
    );
    if (!disabled) return chip;
    return Tooltip(
      message: 'Narrow the catalog first to use Not Started.',
      child: chip,
    );
  }
}

class _ExploreResultsHeader extends StatelessWidget {
  final int count;
  final _ExploreSort sort;
  final ValueChanged<_ExploreSort?> onSortChanged;

  const _ExploreResultsHeader({
    required this.count,
    required this.sort,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    final String noun = count == 1 ? 'Lesson' : 'Lessons';
    return Wrap(
      spacing: 14,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      children: <Widget>[
        Text(
          '$count $noun Found',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Sort By',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            _ExploreSortDropdown(sort: sort, onChanged: onSortChanged),
          ],
        ),
      ],
    );
  }
}

class _ExploreSortDropdown extends StatelessWidget {
  final _ExploreSort sort;
  final ValueChanged<_ExploreSort?> onChanged;

  const _ExploreSortDropdown({required this.sort, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<_ExploreSort>(
            value: sort,
            dropdownColor: DrumcabularyTheme.edgeSurfaceSecondary,
            iconEnabledColor: DrumcabularyTheme.edgeTextSecondary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w800,
            ),
            items: <DropdownMenuItem<_ExploreSort>>[
              for (final _ExploreSort option in _ExploreSort.values)
                DropdownMenuItem<_ExploreSort>(
                  value: option,
                  child: Text(option.label),
                ),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _ExploreLessonCard extends StatelessWidget {
  final _ExploreLessonItem item;
  final VoidCallback onOpen;

  const _ExploreLessonCard({required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _NavPanel(
      onTap: onOpen,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 680;
          final Widget thumbnail = _ExploreLessonThumbnail(item: item);
          final Widget content = _ExploreLessonCardContent(item: item);
          final Widget meta = _ExploreLessonCardMeta(item: item);

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    thumbnail,
                    const SizedBox(width: 14),
                    Expanded(child: content),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.bookmark_border_rounded,
                      color: DrumcabularyTheme.edgeTextSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                meta,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              thumbnail,
              const SizedBox(width: 16),
              Expanded(child: content),
              const SizedBox(width: 16),
              SizedBox(width: 168, child: meta),
              const SizedBox(width: 10),
              const Icon(
                Icons.bookmark_border_rounded,
                color: DrumcabularyTheme.edgeTextSecondary,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ExploreLessonThumbnail extends StatelessWidget {
  final _ExploreLessonItem item;

  const _ExploreLessonThumbnail({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 72,
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: DrumcabularyTheme.edgeOrange.withValues(alpha: 0.32),
        ),
      ),
      child: Center(
        child: Icon(
          _exploreIconFor(item),
          color: DrumcabularyTheme.edgeOrange,
          size: 34,
        ),
      ),
    );
  }
}

class _ExploreLessonCardContent extends StatelessWidget {
  final _ExploreLessonItem item;

  const _ExploreLessonCardContent({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          item.lesson.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          item.lesson.overview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            for (final String chip in item.visibleChips.take(5))
              _ExploreMetadataPill(label: chip),
          ],
        ),
      ],
    );
  }
}

class _ExploreLessonCardMeta extends StatelessWidget {
  final _ExploreLessonItem item;

  const _ExploreLessonCardMeta({required this.item});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        _ExploreDifficultyBadge(difficulty: item.difficulty),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.schedule_rounded,
              color: DrumcabularyTheme.edgeTextSecondary,
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(
              '${item.lesson.estimatedMinutes} min',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        if (item.progress.status != LessonProgressStatus.notStarted)
          _ExploreMetadataPill(label: _statusLabel(item.progress.status)),
      ],
    );
  }
}

class _ExploreDifficultyBadge extends StatelessWidget {
  final String difficulty;

  const _ExploreDifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final int activeBars = switch (difficulty.toLowerCase()) {
      'advanced' => 3,
      'intermediate' => 2,
      _ => 1,
    };
    final Color color = switch (difficulty.toLowerCase()) {
      'advanced' => const Color(0xFFFF4F6D),
      'intermediate' => DrumcabularyTheme.edgeOrange,
      _ => const Color(0xFF52D273),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List<Widget>.generate(3, (int index) {
            return Padding(
              padding: const EdgeInsets.only(right: 3),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: index < activeBars
                      ? color
                      : DrumcabularyTheme.edgeBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const SizedBox(width: 7, height: 14),
              ),
            );
          }),
        ),
        const SizedBox(width: 7),
        Text(
          difficulty,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ExploreMetadataPill extends StatelessWidget {
  final String label;

  const _ExploreMetadataPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ExploreEmptyState extends StatelessWidget {
  final bool hasActiveSearch;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  const _ExploreEmptyState({
    required this.hasActiveSearch,
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'No lessons found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasActiveSearch
                ? 'Try removing a filter or searching for a different term.'
                : 'No lessons are available yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextSecondary,
            ),
          ),
          if (hasActiveFilters) ...<Widget>[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onClearFilters,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ExploreFilterGroup {
  final _ExploreFilterGroupKey key;
  final String label;
  final List<String> values;

  const _ExploreFilterGroup({
    required this.key,
    required this.label,
    required this.values,
  });
}

class _ExploreLessonItem {
  final Lesson lesson;
  final LessonProgress progress;
  final int contentOrder;
  final String difficulty;
  final Set<String> skills;
  final Set<String> genres;
  final Set<String> timeSignatures;
  final Set<String> rudiments;
  final Set<String> tempoRanges;
  final Set<String> equipment;
  final Set<String> feel;
  final Set<String> subdivisions;
  final Set<String> handFocus;
  final Set<String> footFocus;
  final String searchText;

  const _ExploreLessonItem({
    required this.lesson,
    required this.progress,
    required this.contentOrder,
    required this.difficulty,
    required this.skills,
    required this.genres,
    required this.timeSignatures,
    required this.rudiments,
    required this.tempoRanges,
    required this.equipment,
    required this.feel,
    required this.subdivisions,
    required this.handFocus,
    required this.footFocus,
    required this.searchText,
  });

  factory _ExploreLessonItem.fromLesson({
    required Lesson lesson,
    required LessonProgress progress,
    required int contentOrder,
  }) {
    final String text = _lessonText(lesson).toLowerCase();
    final Set<String> voices = _notationVoiceTokens(lesson).toSet();
    final Set<String> strokes = _notationStrokeSequences(lesson).toSet();
    final Set<String> skills = _inferSkills(lesson, text);
    final Set<String> genres = _inferGenres(text);
    final Set<String> timeSignatures = <String>{
      for (final LessonExercise exercise in lesson.exercises)
        for (final ExerciseNotationSection section
            in exercise.notation.sections)
          section.timeSignature,
    };
    final Set<String> rudiments = _inferRudiments(text);
    final Set<String> tempoRanges = _inferTempoRanges(lesson);
    final Set<String> equipment = _inferEquipment(voices);
    final Set<String> feel = _inferFeel(lesson, text);
    final Set<String> subdivisions = _inferSubdivisions(lesson);
    final Set<String> handFocus = _inferHandFocus(strokes, text);
    final Set<String> footFocus = _inferFootFocus(voices, text);
    final Set<String> searchTerms = <String>{
      ...skills,
      _labelFor(lesson.level),
      ...genres,
      ...timeSignatures,
      ...rudiments,
      ...tempoRanges,
      ...equipment,
      ...feel,
      ...subdivisions,
      ...handFocus,
      ...footFocus,
    };

    return _ExploreLessonItem(
      lesson: lesson,
      progress: progress,
      contentOrder: contentOrder,
      difficulty: _labelFor(lesson.level),
      skills: skills,
      genres: genres,
      timeSignatures: timeSignatures.isEmpty
          ? const <String>{'4/4'}
          : timeSignatures,
      rudiments: rudiments,
      tempoRanges: tempoRanges,
      equipment: equipment,
      feel: feel,
      subdivisions: subdivisions,
      handFocus: handFocus,
      footFocus: footFocus,
      searchText: '${_lessonText(lesson)} ${searchTerms.join(' ')}'
          .toLowerCase(),
    );
  }

  List<String> get visibleChips {
    final List<String> chips = <String>[];
    void addAll(Iterable<String> values) {
      for (final String value in values) {
        if (!chips.contains(value)) chips.add(value);
      }
    }

    addAll(skills);
    addAll(genres);
    addAll(timeSignatures);
    return chips;
  }

  Set<String> valuesFor(_ExploreFilterGroupKey key) {
    return switch (key) {
      _ExploreFilterGroupKey.skills => skills,
      _ExploreFilterGroupKey.difficulty => <String>{difficulty},
      _ExploreFilterGroupKey.genre => genres,
      _ExploreFilterGroupKey.status => <String>{_statusLabel(progress.status)},
      _ExploreFilterGroupKey.timeSignature => timeSignatures,
      _ExploreFilterGroupKey.rudiments => rudiments,
      _ExploreFilterGroupKey.tempoRange => tempoRanges,
      _ExploreFilterGroupKey.equipment => equipment,
      _ExploreFilterGroupKey.feel => feel,
      _ExploreFilterGroupKey.subdivision => subdivisions,
      _ExploreFilterGroupKey.handFocus => handFocus,
      _ExploreFilterGroupKey.footFocus => footFocus,
    };
  }

  bool matches({
    required String query,
    required Map<_ExploreFilterGroupKey, Set<String>> selectedFilters,
  }) {
    final List<String> queryTerms = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String term) => term.isNotEmpty)
        .toList(growable: false);
    if (!queryTerms.every(searchText.contains)) return false;

    for (final MapEntry<_ExploreFilterGroupKey, Set<String>> entry
        in selectedFilters.entries) {
      if (entry.value.isEmpty) continue;
      final Set<String> itemValues = valuesFor(entry.key);
      if (!entry.value.any(itemValues.contains)) return false;
    }
    return true;
  }

  int relevanceScore({
    required String query,
    required Map<_ExploreFilterGroupKey, Set<String>> selectedFilters,
  }) {
    int score = 0;
    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isNotEmpty) {
      if (lesson.title.toLowerCase().contains(normalizedQuery)) score += 80;
      if (lesson.overview.toLowerCase().contains(normalizedQuery)) score += 32;
      for (final String term
          in normalizedQuery
              .split(RegExp(r'\s+'))
              .where((String term) => term.isNotEmpty)) {
        if (lesson.title.toLowerCase().contains(term)) score += 18;
        if (searchText.contains(term)) score += 4;
      }
    }

    for (final MapEntry<_ExploreFilterGroupKey, Set<String>> entry
        in selectedFilters.entries) {
      final Set<String> itemValues = valuesFor(entry.key);
      for (final String value in entry.value) {
        if (itemValues.contains(value)) score += 10;
      }
    }
    if (progress.status == LessonProgressStatus.inProgress) score += 2;
    return score;
  }
}

List<_ExploreLessonItem> _exploreLessonItems(_TeachingFlowData data) {
  final List<Lesson> lessons = _orderedLessons(data.library);
  final List<_ExploreLessonItem> items = <_ExploreLessonItem>[];
  for (int index = 0; index < lessons.length; index += 1) {
    final Lesson lesson = lessons[index];
    items.add(
      _ExploreLessonItem.fromLesson(
        lesson: lesson,
        progress: data.progressService.progressForLesson(lesson.id),
        contentOrder: index,
      ),
    );
  }
  return items;
}

List<_ExploreFilterGroup> _exploreFilterGroups(List<_ExploreLessonItem> items) {
  return <_ExploreFilterGroup>[
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.skills,
      label: 'Skills',
      values: _filterValues(
        preferred: const <String>[
          'Grooves',
          'Dynamics',
          'Independence',
          'Timing',
          'Reading',
          'Linear',
          'Coordination',
          'Chops',
          'Fills',
        ],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.skills),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.difficulty,
      label: 'Difficulty',
      values: _filterValues(
        preferred: const <String>['Beginner', 'Intermediate', 'Advanced'],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.difficulty),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.genre,
      label: 'Genre',
      values: _filterValues(
        preferred: const <String>[
          'Rock',
          'Blues',
          'Jazz',
          'Funk',
          'Latin',
          'Country',
          'Pop',
          'Metal',
          'Reggae',
          'Other',
        ],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.genre),
      ),
    ),
    const _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.status,
      label: 'Status',
      values: <String>['In Progress', 'Completed', _notStartedStatus],
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.timeSignature,
      label: 'Time Signature',
      values: _filterValues(
        preferred: const <String>['4/4', '3/4', '6/8', '5/4', '7/8', 'Other'],
        actual: _actualFilterValues(
          items,
          _ExploreFilterGroupKey.timeSignature,
        ),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.rudiments,
      label: 'Rudiments',
      values: _filterValues(
        preferred: const <String>[
          'Single Stroke Roll',
          'Double Stroke Roll',
          'Six Stroke Roll',
          'Paradiddle',
        ],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.rudiments),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.tempoRange,
      label: 'Tempo Range',
      values: _filterValues(
        preferred: const <String>['Slow', 'Moderate', 'Fast'],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.tempoRange),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.equipment,
      label: 'Equipment',
      values: _filterValues(
        preferred: const <String>[
          'Snare',
          'Kick',
          'Hi-Hat',
          'Open Hi-Hat',
          'Toms',
          'Cymbals',
        ],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.equipment),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.feel,
      label: 'Feel',
      values: _filterValues(
        preferred: const <String>['Straight', 'Triplet', 'Swing', 'Shuffle'],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.feel),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.subdivision,
      label: 'Subdivision',
      values: _filterValues(
        preferred: const <String>[
          'Eighth',
          'Triplet',
          'Sixteenth',
          'Sixteenth Triplet',
        ],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.subdivision),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.handFocus,
      label: 'Hand Focus',
      values: _filterValues(
        preferred: const <String>[
          'Left Hand',
          'Right Hand',
          'Ghost Notes',
          'Accents',
        ],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.handFocus),
      ),
    ),
    _ExploreFilterGroup(
      key: _ExploreFilterGroupKey.footFocus,
      label: 'Foot Focus',
      values: _filterValues(
        preferred: const <String>['Kick', 'Hi-Hat Pedal'],
        actual: _actualFilterValues(items, _ExploreFilterGroupKey.footFocus),
      ),
    ),
  ];
}

Iterable<String> _actualFilterValues(
  List<_ExploreLessonItem> items,
  _ExploreFilterGroupKey key,
) {
  return <String>{
    for (final _ExploreLessonItem item in items) ...item.valuesFor(key),
  };
}

List<String> _filterValues({
  required List<String> preferred,
  required Iterable<String> actual,
}) {
  final List<String> values = <String>[];
  void add(String value) {
    final String normalized = value.trim();
    if (normalized.isNotEmpty && !values.contains(normalized)) {
      values.add(normalized);
    }
  }

  for (final String value in preferred) {
    add(value);
  }
  final List<String> extras = actual.toSet().toList(growable: false)..sort();
  for (final String value in extras) {
    add(value);
  }
  return values;
}

bool _hasActiveExploreSearch(
  String query,
  Map<_ExploreFilterGroupKey, Set<String>> selectedFilters,
) {
  return query.trim().isNotEmpty || _hasActiveExploreFilters(selectedFilters);
}

bool _hasActiveExploreFilters(
  Map<_ExploreFilterGroupKey, Set<String>> selectedFilters,
) {
  return selectedFilters.values.any((Set<String> values) => values.isNotEmpty);
}

bool _statusNotStartedEnabled(
  String query,
  Map<_ExploreFilterGroupKey, Set<String>> selectedFilters,
) {
  return query.trim().isNotEmpty ||
      selectedFilters.entries.any(
        (MapEntry<_ExploreFilterGroupKey, Set<String>> entry) =>
            entry.key != _ExploreFilterGroupKey.status &&
            entry.value.isNotEmpty,
      );
}

int _compareExploreItems(
  _ExploreLessonItem a,
  _ExploreLessonItem b,
  _ExploreSort sort,
  String query,
  Map<_ExploreFilterGroupKey, Set<String>> selectedFilters,
) {
  final int primary = switch (sort) {
    _ExploreSort.relevance =>
      b
          .relevanceScore(query: query, selectedFilters: selectedFilters)
          .compareTo(
            a.relevanceScore(query: query, selectedFilters: selectedFilters),
          ),
    _ExploreSort.alphabetical => a.lesson.title.compareTo(b.lesson.title),
    _ExploreSort.newest => b.contentOrder.compareTo(a.contentOrder),
    _ExploreSort.shortest => a.lesson.estimatedMinutes.compareTo(
      b.lesson.estimatedMinutes,
    ),
    _ExploreSort.longest => b.lesson.estimatedMinutes.compareTo(
      a.lesson.estimatedMinutes,
    ),
  };
  if (primary != 0) return primary;
  return a.contentOrder.compareTo(b.contentOrder);
}

String _lessonText(Lesson lesson) {
  final List<String> parts = <String>[
    lesson.title,
    lesson.level,
    lesson.skill,
    lesson.overview,
    lesson.objective,
  ];
  for (final LessonExercise exercise in lesson.exercises) {
    parts.addAll(<String>[
      exercise.title,
      exercise.why,
      exercise.what,
      exercise.how,
      if (exercise.success != null) exercise.success!,
      if (exercise.tempo != null)
        '${exercise.tempo!.start} ${exercise.tempo!.target}',
    ]);
    for (final ExerciseNotationSection section in exercise.notation.sections) {
      parts.addAll(<String>[
        if (section.title != null) section.title!,
        section.pattern,
        section.timeSignature,
        if (section.subdivision != null) section.subdivision!,
        if (section.sticking != null) section.sticking!,
      ]);
    }
  }
  return parts.join(' ');
}

Iterable<String> _notationVoiceTokens(Lesson lesson) sync* {
  for (final LessonExercise exercise in lesson.exercises) {
    for (final ExerciseNotationSection section in exercise.notation.sections) {
      for (final RegExpMatch event in RegExp(
        r'\[([^\]]+)\]',
      ).allMatches(section.pattern)) {
        final String body = event.group(1)?.trim() ?? '';
        if (body.isEmpty) continue;
        for (final String spec in body.split(RegExp(r'\s+'))) {
          final String voice = spec.split(':').first.trim();
          if (voice.isNotEmpty) yield voice;
        }
      }
    }
  }
}

Iterable<String> _notationStrokeSequences(Lesson lesson) sync* {
  for (final LessonExercise exercise in lesson.exercises) {
    for (final ExerciseNotationSection section in exercise.notation.sections) {
      for (final RegExpMatch event in RegExp(
        r'\[([^\]]+)\]',
      ).allMatches(section.pattern)) {
        final String body = event.group(1)?.trim() ?? '';
        if (body.isEmpty) continue;
        for (final String spec in body.split(RegExp(r'\s+'))) {
          final int separator = spec.indexOf(':');
          if (separator >= 0 && separator < spec.length - 1) {
            yield spec.substring(separator + 1);
          }
        }
      }
    }
  }
}

Set<String> _inferSkills(Lesson lesson, String text) {
  final Set<String> skills = <String>{_labelFor(lesson.skill)};
  if (_containsAny(text, const <String>['groove', 'beat', 'backbeat'])) {
    skills.add('Grooves');
  }
  if (_containsAny(text, const <String>['fill', 'resolution'])) {
    skills.add('Fills');
  }
  if (_containsAny(text, const <String>['rudiment', 'roll', 'paradiddle'])) {
    skills.add('Rudiments');
  }
  if (_containsAny(text, const <String>['accent', 'ghost', 'dynamic'])) {
    skills.add('Dynamics');
  }
  if (text.contains('independence')) {
    skills.add('Independence');
  }
  if (_containsAny(text, const <String>['coordination', 'limb'])) {
    skills.add('Coordination');
  }
  if (_containsAny(text, const <String>['timing', 'time', 'pulse', 'tempo'])) {
    skills.add('Timing');
  }
  if (_containsAny(text, const <String>['reading', 'notation', 'vocabulary'])) {
    skills.add('Reading');
  }
  if (text.contains('linear')) {
    skills.add('Linear');
  }
  if (_containsAny(text, const <String>['chop', 'triplet vocabulary'])) {
    skills.add('Chops');
  }
  if (lesson.skill == 'vocabulary') {
    skills.addAll(const <String>['Chops', 'Reading']);
  }
  return skills;
}

Set<String> _inferGenres(String text) {
  final Set<String> genres = <String>{};
  if (_containsAny(text, const <String>['rock', 'money beat', 'backbeat'])) {
    genres.add('Rock');
  }
  if (text.contains('blues')) genres.add('Blues');
  if (text.contains('jazz')) genres.add('Jazz');
  if (text.contains('funk')) genres.add('Funk');
  if (text.contains('latin')) genres.add('Latin');
  if (text.contains('country')) genres.add('Country');
  if (text.contains('pop')) genres.add('Pop');
  if (text.contains('metal')) genres.add('Metal');
  if (text.contains('reggae')) genres.add('Reggae');
  if (genres.isEmpty) genres.add('Other');
  return genres;
}

Set<String> _inferRudiments(String text) {
  final Set<String> rudiments = <String>{};
  if (text.contains('single stroke')) rudiments.add('Single Stroke Roll');
  if (text.contains('double stroke')) rudiments.add('Double Stroke Roll');
  if (text.contains('six stroke')) rudiments.add('Six Stroke Roll');
  if (text.contains('paradiddle')) rudiments.add('Paradiddle');
  return rudiments;
}

Set<String> _inferTempoRanges(Lesson lesson) {
  final Set<String> ranges = <String>{};
  for (final LessonExercise exercise in lesson.exercises) {
    final TempoTarget? tempo = exercise.tempo;
    if (tempo == null) continue;
    if (tempo.target <= 70) {
      ranges.add('Slow');
    } else if (tempo.target <= 110) {
      ranges.add('Moderate');
    } else {
      ranges.add('Fast');
    }
  }
  return ranges;
}

Set<String> _inferEquipment(Set<String> voices) {
  final Set<String> equipment = <String>{};
  if (voices.contains('S')) equipment.add('Snare');
  if (voices.contains('K')) equipment.add('Kick');
  if (voices.contains('HH')) equipment.add('Hi-Hat');
  if (voices.contains('OHH')) {
    equipment.addAll(const <String>['Hi-Hat', 'Open Hi-Hat']);
  }
  if (voices.any(const <String>{'T1', 'T2', 'FT'}.contains)) {
    equipment.add('Toms');
  }
  if (voices.any(const <String>{'CR', 'RD'}.contains)) {
    equipment.add('Cymbals');
  }
  return equipment;
}

Set<String> _inferFeel(Lesson lesson, String text) {
  final Set<String> feel = <String>{};
  if (_containsAny(text, const <String>['swing', 'swung'])) {
    feel.add('Swing');
  }
  if (text.contains('shuffle')) feel.add('Shuffle');
  if (_inferSubdivisions(lesson).contains('Triplet') ||
      _inferSubdivisions(lesson).contains('Sixteenth Triplet')) {
    feel.add('Triplet');
  }
  if (feel.isEmpty) feel.add('Straight');
  return feel;
}

Set<String> _inferSubdivisions(Lesson lesson) {
  final Set<String> subdivisions = <String>{};
  for (final LessonExercise exercise in lesson.exercises) {
    for (final ExerciseNotationSection section in exercise.notation.sections) {
      final String? subdivision = section.subdivision;
      if (subdivision == null || subdivision.trim().isEmpty) continue;
      subdivisions.add(_subdivisionLabel(subdivision));
    }
  }
  return subdivisions;
}

Set<String> _inferHandFocus(Set<String> strokes, String text) {
  final Set<String> focus = <String>{};
  if (strokes.any((String stroke) => stroke.contains('L'))) {
    focus.add('Left Hand');
  }
  if (strokes.any((String stroke) => stroke.contains('R'))) {
    focus.add('Right Hand');
  }
  if (strokes.any((String stroke) => stroke.contains('(')) ||
      text.contains('ghost')) {
    focus.add('Ghost Notes');
  }
  if (strokes.any((String stroke) => stroke.contains('^')) ||
      text.contains('accent')) {
    focus.add('Accents');
  }
  return focus;
}

Set<String> _inferFootFocus(Set<String> voices, String text) {
  final Set<String> focus = <String>{};
  if (voices.contains('K')) focus.add('Kick');
  if (text.contains('pedal')) focus.add('Hi-Hat Pedal');
  return focus;
}

String _subdivisionLabel(String value) {
  final String normalized = value.toLowerCase();
  if (normalized.contains('16') && normalized.contains('triplet')) {
    return 'Sixteenth Triplet';
  }
  if (normalized.contains('triplet')) return 'Triplet';
  if (normalized == '16' || normalized.contains('sixteenth')) {
    return 'Sixteenth';
  }
  if (normalized == '8' || normalized.contains('eighth')) {
    return 'Eighth';
  }
  return _labelFor(value);
}

bool _containsAny(String text, List<String> terms) {
  return terms.any(text.contains);
}

IconData _exploreIconFor(_ExploreLessonItem item) {
  if (item.skills.contains('Rudiments')) return Icons.graphic_eq_rounded;
  if (item.skills.contains('Fills')) return Icons.auto_awesome_motion_rounded;
  if (item.skills.contains('Dynamics')) return Icons.tune_rounded;
  if (item.skills.contains('Independence')) return Icons.account_tree_rounded;
  if (item.skills.contains('Timing')) return Icons.timer_rounded;
  if (item.skills.contains('Reading')) return Icons.menu_book_rounded;
  if (item.skills.contains('Linear')) return Icons.linear_scale_rounded;
  if (item.skills.contains('Chops')) return Icons.local_fire_department_rounded;
  return Icons.music_note_rounded;
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
    LessonProgressStatus.completed => 'Completed',
    LessonProgressStatus.notStarted => 'Not Started',
  };
}

String _durationValue(int seconds) {
  if (seconds <= 0) return '0m';
  final int hours = seconds ~/ 3600;
  final int minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return minutes == 0 ? '${hours}h' : '${hours}h ${minutes}m';
  return '${minutes}m';
}

String _greeting(String studentName) {
  final int hour = DateTime.now().hour;
  final String period = hour < 12
      ? 'Good Morning'
      : hour < 18
      ? 'Good Afternoon'
      : 'Good Evening';
  final String name = studentName.trim();
  return name.isEmpty ? period : '$period $name';
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
