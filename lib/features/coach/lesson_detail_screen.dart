import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../guided_practice/guided_practice_controller.dart';
import '../guided_practice/guided_practice_sequence_builder.dart';
import '../midi/drum_kit_mapper.dart';
import '../midi/midi_input_models.dart';
import '../midi/midi_input_service.dart';
import '../midi/serial_led_controller.dart';
import '../midi/shared_midi_input_service.dart';
import '../midi/shared_serial_led_controller.dart';
import '../practice/pattern_led_playback_output.dart';
import '../practice/widgets/sheet_notation_display.dart';
import 'lesson_notation_document.dart';
import 'lesson_plan.dart';
import 'lesson_print_export_service.dart';
import 'lesson_progress.dart';

class LessonDetailScreen extends StatefulWidget {
  final Lesson lesson;
  final LessonProgressService? progressService;
  final VoidCallback? onOpenDevices;

  const LessonDetailScreen({
    super.key,
    required this.lesson,
    this.progressService,
    this.onOpenDevices,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  static const int _minPreviewBpm = 40;
  static const int _maxPreviewBpm = 220;
  static const int _previewBpmStep = 5;

  Timer? _practiceTimer;
  String? _selectedExerciseId;
  String? _activeExerciseId;
  DateTime? _practiceStartedAt;
  Duration _activeElapsed = Duration.zero;
  late int _previewBpm = _initialPreviewBpmFor(widget.lesson);
  late final MidiInputService _midiService = SharedMidiInputService.instance;
  late final SerialLedController _ledController =
      SharedSerialLedController.instance;
  final DrumKitMapper _drumKitMapper = const DrumKitMapper();
  late final Stream<DrumInputEvent> _mappedDrumEvents = _midiService.events
      .where(
        (RawMidiEvent event) =>
            event.messageType == MidiMessageType.noteOn && event.velocity > 0,
      )
      .map(_drumKitMapper.map)
      .where((DrumInputEvent event) => event.voice != DrumVoice.unknown);
  final GuidedPracticeSequenceBuilder _guidedSequenceBuilder =
      const GuidedPracticeSequenceBuilder();
  GuidedPracticeController? _guidedPracticeController;
  String? _guidedPracticeExerciseId;
  GuidedPracticeState _guidedPracticeState = GuidedPracticeState.idle;
  PatternLedPlaybackPresentation _ledPlaybackPresentation =
      PatternLedPlaybackPresentation.hearIt;
  final DrumSheetNotationController _activePreviewController =
      DrumSheetNotationController();

  @override
  void initState() {
    super.initState();
    _midiService.addListener(_handleMidiServiceChanged);
    _ledController.addListener(_handleLedControllerChanged);
    unawaited(_midiService.start());
  }

  @override
  void didUpdateWidget(covariant LessonDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lesson.id != widget.lesson.id) {
      _selectedExerciseId = null;
      _previewBpm = _initialPreviewBpmFor(widget.lesson);
      _clearGuidedPracticeController(stop: true);
    }
  }

  @override
  void dispose() {
    _practiceTimer?.cancel();
    _midiService.removeListener(_handleMidiServiceChanged);
    _ledController.removeListener(_handleLedControllerChanged);
    _clearGuidedPracticeController(stop: true, updateUi: false);
    unawaited(_activePreviewController.stopAudioPreview());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Lesson lesson = widget.lesson;
    final LessonProgressService? progressService = widget.progressService;
    final LessonExercise activeExercise = _selectedExerciseFor(
      lesson,
      progressService,
    );
    final int activeExerciseIndex = lesson.exercises.indexWhere(
      (LessonExercise exercise) => exercise.id == activeExercise.id,
    );
    final ExerciseProgress? activeProgress = progressService
        ?.progressForExercise(
          lessonId: lesson.id,
          exerciseId: activeExercise.id,
        );
    final bool active = _activeExerciseId == activeExercise.id;
    final int practicedSeconds =
        (activeProgress?.practicedSeconds ?? 0) +
        (active ? _activeElapsed.inSeconds : 0);
    final GuidedPracticeState? activeGuidedState =
        _guidedPracticeExerciseId == activeExercise.id
        ? _guidedPracticeState
        : null;

    return Scaffold(
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: <Widget>[
            _LessonHeader(
              lesson: lesson,
              completedExercises: _completedExerciseCount(
                lesson,
                progressService,
              ),
              totalExercises: lesson.exercises.length,
              midiService: _midiService,
              ledController: _ledController,
              onOpenDevices: widget.onOpenDevices,
              onPrint: () => _requestPrint(context),
            ),
            const SizedBox(height: 10),
            _ExerciseNavigator(
              lesson: lesson,
              selectedExerciseId: activeExercise.id,
              progressService: progressService,
              practicingExerciseId: _activeExerciseId,
              onSelected: _selectExercise,
            ),
            const SizedBox(height: 10),
            _ActiveExerciseCard(
              number: activeExerciseIndex + 1,
              totalExercises: lesson.exercises.length,
              exercise: activeExercise,
              primaryPreviewController: _activePreviewController,
              previewBpm: _previewBpm,
              ledController: _ledController,
              ledPlaybackEnabled: _ledController.isConnected,
              ledPlaybackPresentation: _ledPlaybackPresentation,
              playAlongDrumEvents: _mappedDrumEvents,
              playAlongInputEnabled:
                  _midiService.status == MidiInputStatus.connected,
              guidedPracticeState: activeGuidedState,
            ),
            const SizedBox(height: 10),
            _LessonPracticeFooter(
              bpm: _previewBpm,
              defaultBpm: _initialPreviewBpmFor(lesson),
              minBpm: _minPreviewBpm,
              maxBpm: _maxPreviewBpm,
              tempo: activeExercise.tempo,
              onBpmDecrease: () => _changePreviewBpm(-_previewBpmStep),
              onBpmIncrease: () => _changePreviewBpm(_previewBpmStep),
              onBpmReset: _resetPreviewBpm,
              active: active,
              practicedLabel: active
                  ? _durationLabel(_activeElapsed)
                  : _durationLabel(Duration(seconds: practicedSeconds)),
              guidedPracticeActive: activeGuidedState?.isActive == true,
              guidedPracticeAvailable: _canStartGuidedPractice(activeExercise),
              playAlongAvailable:
                  _midiService.status == MidiInputStatus.connected,
              onStartPractice: active
                  ? () => _completePractice(activeExercise)
                  : progressService == null
                  ? null
                  : () => _startPractice(activeExercise),
              onStartGuidedPractice: activeGuidedState?.isActive == true
                  ? _stopGuidedPractice
                  : _canStartGuidedPractice(activeExercise)
                  ? () => unawaited(_startGuidedPractice(activeExercise))
                  : null,
              onHearIt: () => unawaited(
                _toggleExercisePreview(
                  activeExercise,
                  PatternLedPlaybackPresentation.hearIt,
                ),
              ),
              onPlayAlong: _midiService.status == MidiInputStatus.connected
                  ? () => unawaited(
                      _toggleExercisePreview(
                        activeExercise,
                        PatternLedPlaybackPresentation.playAlong,
                      ),
                    )
                  : null,
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

  LessonExercise _selectedExerciseFor(
    Lesson lesson,
    LessonProgressService? progressService,
  ) {
    final String? selectedId = _selectedExerciseId;
    if (selectedId != null) {
      for (final LessonExercise exercise in lesson.exercises) {
        if (exercise.id == selectedId) return exercise;
      }
    }

    for (final LessonExercise exercise in lesson.exercises) {
      final ExerciseProgress? progress = progressService?.progressForExercise(
        lessonId: lesson.id,
        exerciseId: exercise.id,
      );
      if (progress?.status == LessonProgressStatus.inProgress) {
        return exercise;
      }
    }

    for (final LessonExercise exercise in lesson.exercises) {
      final ExerciseProgress? progress = progressService?.progressForExercise(
        lessonId: lesson.id,
        exerciseId: exercise.id,
      );
      if (progress?.status != LessonProgressStatus.completed) return exercise;
    }

    return lesson.exercises.first;
  }

  int _completedExerciseCount(
    Lesson lesson,
    LessonProgressService? progressService,
  ) {
    if (progressService == null) return 0;
    return lesson.exercises.where((LessonExercise exercise) {
      final ExerciseProgress progress = progressService.progressForExercise(
        lessonId: lesson.id,
        exerciseId: exercise.id,
      );
      return progress.status == LessonProgressStatus.completed;
    }).length;
  }

  void _selectExercise(String exerciseId) {
    if (_selectedExerciseId == exerciseId) return;
    unawaited(_activePreviewController.stopAudioPreview());
    if (_guidedPracticeState.isActive &&
        _guidedPracticeExerciseId != exerciseId) {
      _clearGuidedPracticeController(stop: true);
    }
    setState(() => _selectedExerciseId = exerciseId);
  }

  Future<void> _toggleExercisePreview(
    LessonExercise exercise,
    PatternLedPlaybackPresentation presentation,
  ) async {
    final bool needsRebuild =
        _selectedExerciseId != exercise.id ||
        _ledPlaybackPresentation != presentation;
    if (needsRebuild) {
      await _activePreviewController.stopAudioPreview();
      setState(() {
        _selectedExerciseId = exercise.id;
        _ledPlaybackPresentation = presentation;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
    }
    await _activePreviewController.toggleAudioPreview();
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

  void _handleLedControllerChanged() {
    if (!mounted) return;
    final bool shouldNotify =
        !_ledController.isConnected && _ledController.lastError != null;
    setState(() {});
    if (!_ledController.isConnected) {
      _guidedPracticeController?.handleSerialDisconnected();
    }
    if (shouldNotify) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(_ledController.lastError!)));
    }
  }

  void _handleMidiServiceChanged() {
    if (!mounted) return;
    setState(() {});
    if (_midiService.status != MidiInputStatus.connected) {
      _guidedPracticeController?.handleMidiDisconnected();
    }
  }

  bool _canStartGuidedPractice(LessonExercise exercise) {
    if (_guidedPracticeState.isActive) return false;
    if (_midiService.status != MidiInputStatus.connected) return false;
    if (!_ledController.isConnected) return false;
    return _guidedSequenceBuilder.buildForExercise(exercise).isNotEmpty;
  }

  Future<void> _startGuidedPractice(LessonExercise exercise) async {
    final List<GuidedPracticeExpectedEvent> expectedEvents =
        _guidedSequenceBuilder.buildForExercise(exercise);
    if (expectedEvents.isEmpty ||
        _midiService.status != MidiInputStatus.connected ||
        !_ledController.isConnected) {
      return;
    }

    await DrumSheetNotationController.stopActiveAudioPreview();
    _clearGuidedPracticeController(stop: true);
    final GuidedPracticeController controller = GuidedPracticeController(
      expectedEvents: expectedEvents,
      drumEvents: _midiService.events
          .where(
            (event) =>
                event.messageType == MidiMessageType.noteOn &&
                event.velocity > 0,
          )
          .map(_drumKitMapper.map),
      ledController: _ledController,
    )..addListener(_handleGuidedPracticeChanged);
    setState(() {
      _guidedPracticeController = controller;
      _guidedPracticeExerciseId = exercise.id;
      _selectedExerciseId = exercise.id;
      _guidedPracticeState = controller.state;
    });
    final bool started = controller.start();
    if (!started) {
      _clearGuidedPracticeController(stop: false);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Guided Practice could not start.')),
      );
    }
  }

  void _handleGuidedPracticeChanged() {
    final GuidedPracticeController? controller = _guidedPracticeController;
    if (controller == null || !mounted) return;
    final GuidedPracticeState state = controller.state;
    setState(() => _guidedPracticeState = state);
    if (state.status == GuidedPracticeStatus.error && state.message != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(state.message!)));
    }
  }

  void _stopGuidedPractice() {
    _clearGuidedPracticeController(stop: true);
  }

  void _clearGuidedPracticeController({
    required bool stop,
    bool updateUi = true,
  }) {
    final GuidedPracticeController? controller = _guidedPracticeController;
    if (controller == null) return;
    controller.removeListener(_handleGuidedPracticeChanged);
    if (stop) controller.stop();
    controller.dispose();
    if (mounted && updateUi) {
      setState(() {
        _guidedPracticeController = null;
        _guidedPracticeExerciseId = null;
        _guidedPracticeState = GuidedPracticeState.idle;
      });
    } else {
      _guidedPracticeController = null;
      _guidedPracticeExerciseId = null;
      _guidedPracticeState = GuidedPracticeState.idle;
    }
  }

  Future<void> _startPractice(LessonExercise exercise) async {
    await widget.progressService?.startExercise(widget.lesson, exercise.id);
    _practiceTimer?.cancel();
    setState(() {
      _selectedExerciseId = exercise.id;
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

class _LessonHeader extends StatelessWidget {
  final Lesson lesson;
  final int completedExercises;
  final int totalExercises;
  final MidiInputService midiService;
  final SerialLedController ledController;
  final VoidCallback? onOpenDevices;
  final VoidCallback onPrint;

  const _LessonHeader({
    required this.lesson,
    required this.completedExercises,
    required this.totalExercises,
    required this.midiService,
    required this.ledController,
    required this.onOpenDevices,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double completion = totalExercises == 0
        ? 0
        : completedExercises / totalExercises;
    final int percent = (completion * 100).round().clamp(0, 100).toInt();
    final _LessonHardwareStatus hardwareStatus = _LessonHardwareStatus.from(
      midiService: midiService,
      ledController: ledController,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final Widget controls = Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                _LessonDeviceStatusChip(
                  status: hardwareStatus.midi,
                  onPressed: onOpenDevices,
                ),
                _LessonDeviceStatusChip(
                  status: hardwareStatus.led,
                  onPressed: onOpenDevices,
                ),
                _LessonMoreActionsButton(onPrint: onPrint),
              ],
            );
            final Widget back = Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back'),
              ),
            );
            if (constraints.maxWidth < 780) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[back, const SizedBox(height: 8), controls],
              );
            }
            return Row(
              children: <Widget>[
                Expanded(child: back),
                Flexible(child: controls),
              ],
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          '${_labelFor(lesson.level)} • ${_labelFor(lesson.skill)}'
              .toUpperCase(),
          style: textTheme.labelLarge?.copyWith(
            color: DrumcabularyTheme.edgeOrange,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          lesson.title,
          style: textTheme.headlineMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          lesson.overview,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.32,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Text(
              '$completedExercises of $totalExercises exercises complete',
              style: textTheme.labelLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: completion.clamp(0.0, 1.0).toDouble(),
                  minHeight: 6,
                  backgroundColor: DrumcabularyTheme.edgeSurfaceSecondary,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    DrumcabularyTheme.edgeOrange,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$percent%',
              style: textTheme.labelLarge?.copyWith(
                color: DrumcabularyTheme.edgeOrange,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LessonMoreActionsButton extends StatelessWidget {
  final VoidCallback onPrint;

  const _LessonMoreActionsButton({required this.onPrint});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_LessonAction>(
      tooltip: 'More Actions',
      onSelected: (_LessonAction action) {
        switch (action) {
          case _LessonAction.print:
            onPrint();
        }
      },
      itemBuilder: (BuildContext context) {
        return const <PopupMenuEntry<_LessonAction>>[
          PopupMenuItem<_LessonAction>(
            value: _LessonAction.print,
            child: Row(
              children: <Widget>[
                Icon(Icons.print_outlined),
                SizedBox(width: 10),
                Text('Print Lesson'),
              ],
            ),
          ),
        ];
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: DrumcabularyTheme.edgeSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: DrumcabularyTheme.edgeBorder),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('More Actions'),
              SizedBox(width: 6),
              Icon(Icons.more_vert_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

enum _LessonAction { print }

class _LessonHardwareStatus {
  final _LessonDeviceStatus midi;
  final _LessonDeviceStatus led;

  const _LessonHardwareStatus({required this.midi, required this.led});

  factory _LessonHardwareStatus.from({
    required MidiInputService midiService,
    required SerialLedController ledController,
  }) {
    return _LessonHardwareStatus(
      midi: _LessonDeviceStatus(
        icon: Icons.graphic_eq_rounded,
        title: midiService.selectedDevice?.name ?? 'MIDI Kit',
        subtitle: _midiInputStatusLabel(midiService.status),
        connected: midiService.status == MidiInputStatus.connected,
      ),
      led: _LessonDeviceStatus(
        icon: Icons.radio_button_checked_rounded,
        title: 'LED Controller',
        subtitle: _serialLedConnectionLabel(ledController.status),
        connected: ledController.status == SerialLedConnectionStatus.connected,
      ),
    );
  }
}

class _LessonDeviceStatus {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool connected;

  const _LessonDeviceStatus({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.connected,
  });
}

class _LessonDeviceStatusChip extends StatelessWidget {
  final _LessonDeviceStatus status;
  final VoidCallback? onPressed;

  const _LessonDeviceStatusChip({
    required this.status,
    required this.onPressed,
  });

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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  status.icon,
                  color: DrumcabularyTheme.edgeTextPrimary,
                  size: 20,
                ),
                const SizedBox(width: 9),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
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

class _ExerciseNavigator extends StatelessWidget {
  final Lesson lesson;
  final String selectedExerciseId;
  final LessonProgressService? progressService;
  final String? practicingExerciseId;
  final ValueChanged<String> onSelected;

  const _ExerciseNavigator({
    required this.lesson,
    required this.selectedExerciseId,
    required this.progressService,
    required this.practicingExerciseId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: <Widget>[
            for (int index = 0; index < lesson.exercises.length; index += 1)
              Padding(
                padding: EdgeInsets.only(
                  right: index == lesson.exercises.length - 1 ? 0 : 10,
                ),
                child: _ExerciseStep(
                  number: index + 1,
                  exercise: lesson.exercises[index],
                  selected: selectedExerciseId == lesson.exercises[index].id,
                  practicing:
                      practicingExerciseId == lesson.exercises[index].id,
                  progress: progressService?.progressForExercise(
                    lessonId: lesson.id,
                    exerciseId: lesson.exercises[index].id,
                  ),
                  onPressed: () => onSelected(lesson.exercises[index].id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseStep extends StatelessWidget {
  final int number;
  final LessonExercise exercise;
  final bool selected;
  final bool practicing;
  final ExerciseProgress? progress;
  final VoidCallback onPressed;

  const _ExerciseStep({
    required this.number,
    required this.exercise,
    required this.selected,
    required this.practicing,
    required this.progress,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool complete = progress?.status == LessonProgressStatus.completed;
    final Color accent = complete
        ? const Color(0xFF49B860)
        : selected
        ? DrumcabularyTheme.edgeOrange
        : DrumcabularyTheme.edgeBorder;
    final Color surface = selected
        ? DrumcabularyTheme.edgeOrange.withValues(alpha: 0.14)
        : DrumcabularyTheme.edgeSurfaceSecondary;
    return SizedBox(
      width: 230,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accent),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: complete
                        ? const Color(0xFF17371F)
                        : selected
                        ? DrumcabularyTheme.edgeOrange
                        : DrumcabularyTheme.edgeBackground,
                    shape: BoxShape.circle,
                    border: Border.all(color: accent),
                  ),
                  child: SizedBox.square(
                    dimension: 38,
                    child: Center(
                      child: complete
                          ? const Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: DrumcabularyTheme.edgeTextPrimary,
                            )
                          : Text(
                              '$number',
                              style: textTheme.labelLarge?.copyWith(
                                color: DrumcabularyTheme.edgeTextPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        exercise.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          color: DrumcabularyTheme.edgeTextPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _statusLabel(progress?.status, active: practicing),
                        style: textTheme.labelMedium?.copyWith(
                          color: complete
                              ? const Color(0xFF63D46F)
                              : selected || practicing
                              ? DrumcabularyTheme.edgeOrange
                              : DrumcabularyTheme.edgeTextSecondary,
                          fontWeight: FontWeight.w900,
                        ),
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

class _ActiveExerciseCard extends StatelessWidget {
  final int number;
  final int totalExercises;
  final LessonExercise exercise;
  final DrumSheetNotationController? primaryPreviewController;
  final int previewBpm;
  final SerialLedController ledController;
  final bool ledPlaybackEnabled;
  final PatternLedPlaybackPresentation ledPlaybackPresentation;
  final Stream<DrumInputEvent> playAlongDrumEvents;
  final bool playAlongInputEnabled;
  final GuidedPracticeState? guidedPracticeState;

  const _ActiveExerciseCard({
    required this.number,
    required this.totalExercises,
    required this.exercise,
    required this.primaryPreviewController,
    required this.previewBpm,
    required this.ledController,
    required this.ledPlaybackEnabled,
    required this.ledPlaybackPresentation,
    required this.playAlongDrumEvents,
    required this.playAlongInputEnabled,
    required this.guidedPracticeState,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurface,
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
        borderRadius: BorderRadius.circular(8),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: DrumcabularyTheme.edgeShadow.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'EXERCISE $number OF $totalExercises',
              style: textTheme.labelMedium?.copyWith(
                color: DrumcabularyTheme.edgeOrange,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              exercise.title,
              style: textTheme.titleLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            _ExerciseTeachingPanels(exercise: exercise),
            const SizedBox(height: 10),
            for (
              int index = 0;
              index < exercise.notation.sections.length;
              index += 1
            ) ...[
              if (index > 0) const SizedBox(height: 10),
              if (exercise.notation.sections.length > 1 &&
                  exercise.notation.sections[index].title != null) ...<Widget>[
                Text(
                  exercise.notation.sections[index].title!,
                  style: textTheme.labelMedium?.copyWith(
                    color: DrumcabularyTheme.edgeTextSecondary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              _NotationPreview(
                section: exercise.notation.sections[index],
                previewBpm: previewBpm,
                ledController: ledController,
                ledPlaybackEnabled: ledPlaybackEnabled,
                ledPlaybackPresentation: ledPlaybackPresentation,
                playAlongDrumEvents: playAlongDrumEvents,
                playAlongInputEnabled: playAlongInputEnabled,
                selectedIndexes: _guidedSelectionForSection(
                  guidedPracticeState,
                  index,
                ),
                controller: index == 0 ? primaryPreviewController : null,
              ),
            ],
            if (guidedPracticeState != null) ...<Widget>[
              const SizedBox(height: 10),
              _GuidedPracticeStatusLine(state: guidedPracticeState!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExerciseTeachingPanels extends StatelessWidget {
  final LessonExercise exercise;

  const _ExerciseTeachingPanels({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final Widget goal = _TeachingInfoPanel(
      icon: Icons.flag_outlined,
      label: 'Goal',
      text: exercise.why,
    );
    final Widget focus = _TeachingInfoPanel(
      icon: Icons.center_focus_strong_rounded,
      label: 'Focus',
      text: exercise.what,
    );
    final Widget tip = _TeachingInfoPanel(
      icon: Icons.tips_and_updates_outlined,
      label: 'Tip',
      text: exercise.success == null
          ? exercise.how
          : '${exercise.how}\n\nTarget: ${exercise.success}',
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 820) {
          return Column(
            children: <Widget>[
              goal,
              const SizedBox(height: 10),
              focus,
              const SizedBox(height: 10),
              tip,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: goal),
            const SizedBox(width: 10),
            Expanded(child: focus),
            const SizedBox(width: 10),
            Expanded(child: tip),
          ],
        );
      },
    );
  }
}

class _TeachingInfoPanel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;

  const _TeachingInfoPanel({
    required this.icon,
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, color: DrumcabularyTheme.edgeOrange, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: textTheme.titleSmall?.copyWith(
                    color: DrumcabularyTheme.edgeTextPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: textTheme.bodyMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BpmInlineControl extends StatelessWidget {
  final int bpm;
  final int defaultBpm;
  final int minBpm;
  final int maxBpm;
  final TempoTarget? tempo;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onReset;

  const _BpmInlineControl({
    required this.bpm,
    required this.defaultBpm,
    required this.minBpm,
    required this.maxBpm,
    required this.tempo,
    required this.onDecrease,
    required this.onIncrease,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String guidance = tempo == null
        ? 'Preview tempo'
        : '${tempo!.start}-${tempo!.target} BPM goal';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              guidance,
              style: textTheme.labelMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                _SmallTempoButton(
                  tooltip: 'Slower',
                  icon: Icons.remove_rounded,
                  onPressed: bpm > minBpm ? onDecrease : null,
                ),
                Expanded(
                  child: Text(
                    '$bpm BPM',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium?.copyWith(
                      color: DrumcabularyTheme.edgeOrange,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _SmallTempoButton(
                  tooltip: 'Faster',
                  icon: Icons.add_rounded,
                  onPressed: bpm < maxBpm ? onIncrease : null,
                ),
                const SizedBox(width: 4),
                _SmallTempoButton(
                  tooltip: 'Reset BPM',
                  icon: Icons.restart_alt_rounded,
                  onPressed: bpm != defaultBpm ? onReset : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallTempoButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SmallTempoButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 34,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        style: IconButton.styleFrom(
          backgroundColor: DrumcabularyTheme.edgeSurface,
          foregroundColor: DrumcabularyTheme.edgeTextPrimary,
          disabledForegroundColor: DrumcabularyTheme.edgeTextMuted.withValues(
            alpha: 0.45,
          ),
          side: const BorderSide(color: DrumcabularyTheme.edgeBorder),
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

class _LessonPracticeFooter extends StatelessWidget {
  final int bpm;
  final int defaultBpm;
  final int minBpm;
  final int maxBpm;
  final TempoTarget? tempo;
  final VoidCallback onBpmDecrease;
  final VoidCallback onBpmIncrease;
  final VoidCallback onBpmReset;
  final bool active;
  final String practicedLabel;
  final bool guidedPracticeActive;
  final bool guidedPracticeAvailable;
  final bool playAlongAvailable;
  final VoidCallback? onStartPractice;
  final VoidCallback? onStartGuidedPractice;
  final VoidCallback onHearIt;
  final VoidCallback? onPlayAlong;

  const _LessonPracticeFooter({
    required this.bpm,
    required this.defaultBpm,
    required this.minBpm,
    required this.maxBpm,
    required this.tempo,
    required this.onBpmDecrease,
    required this.onBpmIncrease,
    required this.onBpmReset,
    required this.active,
    required this.practicedLabel,
    required this.guidedPracticeActive,
    required this.guidedPracticeAvailable,
    required this.playAlongAvailable,
    required this.onStartPractice,
    required this.onStartGuidedPractice,
    required this.onHearIt,
    required this.onPlayAlong,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double spacing = 10;
            const double minimumPanelWidth = 175;
            const double maximumPanelWidth = 230;

            final double availablePanelWidth =
                (constraints.maxWidth - (spacing * 4)) / 5;

            final double panelWidth =
                availablePanelWidth < minimumPanelWidth
                ? minimumPanelWidth
                : availablePanelWidth > maximumPanelWidth
                ? maximumPanelWidth
                : availablePanelWidth;

            final double panelHeight = panelWidth;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: panelWidth,
                    height: panelHeight,
                    child: _BpmInlineControl(
                      bpm: bpm,
                      defaultBpm: defaultBpm,
                      minBpm: minBpm,
                      maxBpm: maxBpm,
                      tempo: tempo,
                      onDecrease: onBpmDecrease,
                      onIncrease: onBpmIncrease,
                      onReset: onBpmReset,
                    ),
                  ),
                  const SizedBox(width: spacing),
                  _PracticeModeGrid(
                    cardWidth: panelWidth,
                    cardHeight: panelHeight,
                    active: active,
                    practicedLabel: practicedLabel,
                    guidedPracticeActive: guidedPracticeActive,
                    guidedPracticeAvailable: guidedPracticeAvailable,
                    playAlongAvailable: playAlongAvailable,
                    onStartPractice: onStartPractice,
                    onStartGuidedPractice: onStartGuidedPractice,
                    onHearIt: onHearIt,
                    onPlayAlong: onPlayAlong,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PracticeModeGrid extends StatelessWidget {
  final double cardWidth;
  final double cardHeight;
  final bool active;
  final String practicedLabel;
  final bool guidedPracticeActive;
  final bool guidedPracticeAvailable;
  final bool playAlongAvailable;
  final VoidCallback? onStartPractice;
  final VoidCallback? onStartGuidedPractice;
  final VoidCallback onHearIt;
  final VoidCallback? onPlayAlong;

  const _PracticeModeGrid({
    required this.cardWidth,
    required this.cardHeight,
    required this.active,
    required this.practicedLabel,
    required this.guidedPracticeActive,
    required this.guidedPracticeAvailable,
    required this.playAlongAvailable,
    required this.onStartPractice,
    required this.onStartGuidedPractice,
    required this.onHearIt,
    required this.onPlayAlong,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _PracticeModeCard(
          width: cardWidth,
          height: cardHeight,
          icon: active ? Icons.check_rounded : Icons.timer_outlined,
          title: 'Practice It',
          description: active
              ? 'Mark this exercise complete.'
              : 'Play at your own tempo.',
          detail: practicedLabel,
          accent: true,
          onPressed: onStartPractice,
        ),
        const SizedBox(width: 10),
        _PracticeModeCard(
          width: cardWidth,
          height: cardHeight,
          icon: guidedPracticeActive
              ? Icons.stop_rounded
              : Icons.lightbulb_outline_rounded,
          title: 'Guided Practice',
          description: guidedPracticeActive
              ? 'Stop the guided session.'
              : 'Step through one event at a time.',
          detail: guidedPracticeActive
              ? 'Running'
              : guidedPracticeAvailable
              ? 'MIDI + LEDs ready'
              : 'Connect MIDI + LEDs',
          onPressed: onStartGuidedPractice,
        ),
        const SizedBox(width: 10),
        _PracticeModeCard(
          width: cardWidth,
          height: cardHeight,
          icon: Icons.hearing_rounded,
          title: 'Hear It',
          description: 'Listen at the selected tempo.',
          detail: 'Uses current BPM',
          onPressed: onHearIt,
        ),
        const SizedBox(width: 10),
        _PracticeModeCard(
          width: cardWidth,
          height: cardHeight,
          icon: Icons.play_circle_outline_rounded,
          title: 'Play Along',
          description: 'Play while MIDI listens.',
          detail: playAlongAvailable ? 'MIDI ready' : 'Connect MIDI input',
          onPressed: onPlayAlong,
        ),
      ],
    );
  }
}

class _PracticeModeCard extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  final String title;
  final String description;
  final String detail;
  final bool accent;
  final VoidCallback? onPressed;

  const _PracticeModeCard({
    required this.width,
    required this.height,
    required this.icon,
    required this.title,
    required this.description,
    required this.detail,
    required this.onPressed,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool enabled = onPressed != null;

    final Color borderColor = accent && enabled
        ? DrumcabularyTheme.edgeOrange
        : DrumcabularyTheme.edgeBorder;

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Ink(
            decoration: BoxDecoration(
              color: accent && enabled
                  ? DrumcabularyTheme.edgeOrange.withValues(alpha: 0.10)
                  : DrumcabularyTheme.edgeSurfaceSecondary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Icon(
                        icon,
                        size: 22,
                        color: enabled
                            ? DrumcabularyTheme.edgeOrange
                            : DrumcabularyTheme.edgeTextMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            color: enabled
                                ? DrumcabularyTheme.edgeTextPrimary
                                : DrumcabularyTheme.edgeTextMuted,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: enabled
                          ? DrumcabularyTheme.edgeTextSecondary
                          : DrumcabularyTheme.edgeTextMuted,
                      height: 1.35,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelMedium?.copyWith(
                      color: enabled
                          ? DrumcabularyTheme.edgeOrange
                          : DrumcabularyTheme.edgeTextMuted,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
Set<int> _guidedSelectionForSection(
  GuidedPracticeState? state,
  int sectionIndex,
) {
  if (state?.isActive != true) return const <int>{};
  final GuidedPracticeExpectedEvent? event = state!.currentEvent;
  if (event == null || event.sectionIndex != sectionIndex) {
    return const <int>{};
  }
  return event.selectedIndexes;
}

class _GuidedPracticeStatusLine extends StatelessWidget {
  final GuidedPracticeState state;

  const _GuidedPracticeStatusLine({required this.state});

  @override
  Widget build(BuildContext context) {
    final String label = switch (state.status) {
      GuidedPracticeStatus.running => 'Guided Practice',
      GuidedPracticeStatus.completed => 'Guided Practice Complete',
      GuidedPracticeStatus.error => state.message ?? 'Guided Practice stopped',
      GuidedPracticeStatus.stopped => 'Guided Practice stopped',
      GuidedPracticeStatus.idle => '',
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return _MetadataPill(
      label: label,
      accent:
          state.status == GuidedPracticeStatus.running ||
          state.status == GuidedPracticeStatus.completed,
      outlinedAccent: state.status == GuidedPracticeStatus.error,
    );
  }
}

class _NotationPreview extends StatelessWidget {
  final ExerciseNotationSection section;
  final int previewBpm;
  final SerialLedController ledController;
  final bool ledPlaybackEnabled;
  final PatternLedPlaybackPresentation ledPlaybackPresentation;
  final Stream<DrumInputEvent> playAlongDrumEvents;
  final bool playAlongInputEnabled;
  final Set<int> selectedIndexes;
  final DrumSheetNotationController? controller;

  const _NotationPreview({
    required this.section,
    required this.previewBpm,
    required this.ledController,
    required this.ledPlaybackEnabled,
    required this.ledPlaybackPresentation,
    required this.playAlongDrumEvents,
    required this.playAlongInputEnabled,
    required this.selectedIndexes,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData notationTheme = Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: DrumcabularyTheme.edgeOrange,
        brightness: Brightness.light,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: DrumcabularyTheme.edgeNotationInk,
          disabledForegroundColor: DrumcabularyTheme.edgeNotationInk.withValues(
            alpha: 0.35,
          ),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeNotationPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D2C6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
        child: Theme(
          data: notationTheme,
          child: DrumSheetNotationDisplay(
            document: documentForNotationSection(section),
            grouping: groupingTextFromPattern(section.pattern),
            selection: selectedIndexes.isEmpty
                ? DrumSheetNotationSelection.empty
                : DrumSheetNotationSelection.guidedPractice(selectedIndexes),
            selectable: false,
            compactLayout: false,
            preserveMeasures: false,
            minNoteWidth: 54,
            showSticking: shouldShowStickingForNotationSection(section),
            audioPreviewEnabled: true,
            showAudioPreviewControl: false,
            audioPreviewBpm: previewBpm,
            ledController: ledController,
            ledPlaybackEnabled: ledPlaybackEnabled,
            ledPlaybackPresentation: ledPlaybackPresentation,
            playAlongDrumEvents: playAlongDrumEvents,
            playAlongInputEnabled: playAlongInputEnabled,
            backgroundColor: DrumcabularyTheme.edgeNotationPanel,
            noteColor: DrumcabularyTheme.edgeNotationInk,
            staffColor: DrumcabularyTheme.edgeNotationInk.withValues(
              alpha: 0.62,
            ),
            selectedColor: DrumcabularyTheme.edgeOrange,
            staffY: 4,
            staffHeight: 112,
            systemGapY: 122,
            controller: controller,
          ),
        ),
      ),
    );
  }
}

class _MetadataPill extends StatelessWidget {
  final String label;
  final bool accent;
  final bool outlinedAccent;

  const _MetadataPill({
    required this.label,
    this.accent = false,
    this.outlinedAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: accent
            ? DrumcabularyTheme.edgeOrange
            : DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent || outlinedAccent
              ? DrumcabularyTheme.edgeOrange
              : DrumcabularyTheme.edgeBorder,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: accent
                ? DrumcabularyTheme.edgeTextPrimary
                : outlinedAccent
                ? DrumcabularyTheme.edgeOrange
                : DrumcabularyTheme.edgeTextPrimary,
            fontWeight: FontWeight.w900,
          ),
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

String _midiInputStatusLabel(MidiInputStatus status) {
  return switch (status) {
    MidiInputStatus.connected => 'Connected',
    MidiInputStatus.scanning => 'Scanning',
    MidiInputStatus.connecting => 'Connecting',
    MidiInputStatus.noDevicesFound ||
    MidiInputStatus.disconnected => 'Not Connected',
    MidiInputStatus.connectionError => 'Connection Error',
  };
}

String _serialLedConnectionLabel(SerialLedConnectionStatus status) {
  return switch (status) {
    SerialLedConnectionStatus.connected => 'Connected',
    SerialLedConnectionStatus.connecting => 'Connecting',
    SerialLedConnectionStatus.disconnected => 'Not Connected',
    SerialLedConnectionStatus.connectionError => 'Connection Error',
    SerialLedConnectionStatus.deviceRemoved => 'Device Removed',
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