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
  late final MidiInputService _midiService = SharedMidiInputService.instance;
  late final SerialLedController _ledController =
      SharedSerialLedController.instance;
  final DrumKitMapper _drumKitMapper = const DrumKitMapper();
  final GuidedPracticeSequenceBuilder _guidedSequenceBuilder =
      const GuidedPracticeSequenceBuilder();
  GuidedPracticeController? _guidedPracticeController;
  String? _guidedPracticeExerciseId;
  GuidedPracticeState _guidedPracticeState = GuidedPracticeState.idle;
  bool _ledPlaybackEnabled = false;
  final DrumSheetNotationController _footerPreviewController =
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
    unawaited(_footerPreviewController.stopAudioPreview());
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
        onDecrease: () => _changePreviewBpm(-_previewBpmStep),
        onIncrease: () => _changePreviewBpm(_previewBpmStep),
        onReset: _resetPreviewBpm,
        onPlay: () => unawaited(_footerPreviewController.toggleAudioPreview()),
        ledPlaybackAvailable: _ledController.isConnected,
        ledPlaybackEnabled: _ledPlaybackEnabled && _ledController.isConnected,
        onLedPlaybackChanged: _setLedPlaybackEnabled,
      ),
      body: DrumScreen(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 176),
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
                        primaryPreviewController: index == 0
                            ? _footerPreviewController
                            : null,
                        progress: widget.progressService?.progressForExercise(
                          lessonId: lesson.id,
                          exerciseId: lesson.exercises[index].id,
                        ),
                        previewBpm: _previewBpm,
                        ledController: _ledController,
                        ledPlaybackEnabled:
                            _ledPlaybackEnabled && _ledController.isConnected,
                        guidedPracticeState:
                            _guidedPracticeExerciseId ==
                                lesson.exercises[index].id
                            ? _guidedPracticeState
                            : null,
                        active: _activeExerciseId == lesson.exercises[index].id,
                        activeElapsed: _activeElapsed,
                        onStartPractice: widget.progressService == null
                            ? null
                            : () => _startPractice(lesson.exercises[index]),
                        onCompletePractice:
                            _activeExerciseId == lesson.exercises[index].id
                            ? () => _completePractice(lesson.exercises[index])
                            : null,
                        onStartGuidedPractice:
                            _canStartGuidedPractice(lesson.exercises[index])
                            ? () => unawaited(
                                _startGuidedPractice(lesson.exercises[index]),
                              )
                            : null,
                        onStopGuidedPractice:
                            _guidedPracticeExerciseId ==
                                    lesson.exercises[index].id &&
                                _guidedPracticeState.isActive
                            ? _stopGuidedPractice
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

  void _handleLedControllerChanged() {
    if (!mounted) return;
    final bool shouldNotify =
        _ledPlaybackEnabled &&
        !_ledController.isConnected &&
        _ledController.lastError != null;
    setState(() {
      if (!_ledController.isConnected) {
        _ledPlaybackEnabled = false;
      }
    });
    if (!_ledController.isConnected) {
      _guidedPracticeController?.handleSerialDisconnected();
    }
    if (shouldNotify) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(_ledController.lastError!)));
    }
  }

  void _setLedPlaybackEnabled(bool value) {
    if (!_ledController.isConnected && value) return;
    setState(() => _ledPlaybackEnabled = value);
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
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onReset;
  final VoidCallback onPlay;
  final bool ledPlaybackAvailable;
  final bool ledPlaybackEnabled;
  final ValueChanged<bool> onLedPlaybackChanged;

  const _LessonTempoFooter({
    required this.bpm,
    required this.defaultBpm,
    required this.minBpm,
    required this.maxBpm,
    required this.onDecrease,
    required this.onIncrease,
    required this.onReset,
    required this.onPlay,
    required this.ledPlaybackAvailable,
    required this.ledPlaybackEnabled,
    required this.onLedPlaybackChanged,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool canDecrease = bpm > minBpm;
    final bool canIncrease = bpm < maxBpm;
    return Material(
      color: DrumcabularyTheme.edgeSurface,
      elevation: 18,
      shadowColor: DrumcabularyTheme.edgeShadow,
      child: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: DrumcabularyTheme.edgeBorder),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _FooterIconButton(
                      tooltip: 'Reset BPM to default',
                      icon: Icons.restart_alt_rounded,
                      onPressed: bpm != defaultBpm ? onReset : null,
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
                    _FooterPlayButton(onPressed: onPlay),
                    const SizedBox(width: 10),
                    Text(
                      'BPM',
                      textAlign: TextAlign.center,
                      style: textTheme.labelSmall?.copyWith(
                        color: DrumcabularyTheme.edgeTextMuted,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _LedPlaybackToggle(
                  available: ledPlaybackAvailable,
                  enabled: ledPlaybackEnabled,
                  onChanged: onLedPlaybackChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LedPlaybackToggle extends StatelessWidget {
  final bool available;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _LedPlaybackToggle({
    required this.available,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Switch(
          value: available && enabled,
          onChanged: available ? onChanged : null,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'Enable LED Playback',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelLarge?.copyWith(
              color: available
                  ? DrumcabularyTheme.edgeTextPrimary
                  : DrumcabularyTheme.edgeTextMuted,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
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
        color: DrumcabularyTheme.edgeSurfaceSecondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: DrumcabularyTheme.edgeShadow.withValues(alpha: 0.24),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
              color: DrumcabularyTheme.edgeTextPrimary,
            ),
            SizedBox(
              width: 62,
              child: Text(
                '$bpm',
                textAlign: TextAlign.center,
                style: textTheme.headlineSmall?.copyWith(
                  color: DrumcabularyTheme.edgeOrange,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Faster',
              onPressed: canIncrease ? onIncrease : null,
              icon: const Icon(Icons.add_rounded),
              color: DrumcabularyTheme.edgeTextPrimary,
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
          backgroundColor: DrumcabularyTheme.edgeSurfaceSecondary,
          foregroundColor: DrumcabularyTheme.edgeTextPrimary,
          disabledForegroundColor: DrumcabularyTheme.edgeTextMuted.withValues(
            alpha: 0.45,
          ),
          side: const BorderSide(color: DrumcabularyTheme.edgeBorder),
        ),
      ),
    );
  }
}

class _FooterPlayButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _FooterPlayButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 54,
      child: IconButton(
        tooltip: 'Play first exercise',
        onPressed: onPressed,
        icon: const Icon(Icons.play_arrow_rounded),
        style: IconButton.styleFrom(
          backgroundColor: DrumcabularyTheme.edgeOrange,
          foregroundColor: DrumcabularyTheme.edgeTextPrimary,
          side: const BorderSide(color: DrumcabularyTheme.edgeOrange),
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DrumcabularyTheme.edgeBorder),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            DrumcabularyTheme.edgeSurfaceSecondary,
            DrumcabularyTheme.edgeSurface,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: DrumcabularyTheme.edgeShadow.withValues(alpha: 0.20),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '${_labelFor(lesson.level)} • ${_labelFor(lesson.skill)}'
                  .toUpperCase(),
              style: textTheme.labelLarge?.copyWith(
                color: DrumcabularyTheme.edgeOrange,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              lesson.title,
              style: textTheme.headlineMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w900,
                height: 1.02,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lesson.overview,
              style: textTheme.bodyLarge?.copyWith(
                color: DrumcabularyTheme.edgeTextPrimary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lesson.objective,
              style: textTheme.bodyMedium?.copyWith(
                color: DrumcabularyTheme.edgeTextSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _MetadataPill(label: 'Lesson ${lesson.order}', accent: true),
                _MetadataPill(label: '${lesson.estimatedMinutes} min'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPrint,
                icon: const Icon(Icons.print_outlined),
                label: const Text('Print Lesson'),
                style: FilledButton.styleFrom(
                  backgroundColor: DrumcabularyTheme.edgeBackground,
                  foregroundColor: DrumcabularyTheme.edgeTextPrimary,
                  side: const BorderSide(color: DrumcabularyTheme.edgeOrange),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: DrumcabularyTheme.edgeOrange,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final int number;
  final Lesson lesson;
  final LessonExercise exercise;
  final DrumSheetNotationController? primaryPreviewController;
  final ExerciseProgress? progress;
  final int previewBpm;
  final SerialLedController ledController;
  final bool ledPlaybackEnabled;
  final GuidedPracticeState? guidedPracticeState;
  final bool active;
  final Duration activeElapsed;
  final VoidCallback? onStartPractice;
  final VoidCallback? onCompletePractice;
  final VoidCallback? onStartGuidedPractice;
  final VoidCallback? onStopGuidedPractice;

  const _ExerciseCard({
    required this.number,
    required this.lesson,
    required this.exercise,
    required this.primaryPreviewController,
    required this.progress,
    required this.previewBpm,
    required this.ledController,
    required this.ledPlaybackEnabled,
    required this.guidedPracticeState,
    required this.active,
    required this.activeElapsed,
    required this.onStartPractice,
    required this.onCompletePractice,
    required this.onStartGuidedPractice,
    required this.onStopGuidedPractice,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'EXERCISE ${number.toString().padLeft(2, '0')}',
                        style: textTheme.labelMedium?.copyWith(
                          color: DrumcabularyTheme.edgeOrange,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        exercise.title,
                        style: textTheme.titleLarge?.copyWith(
                          color: DrumcabularyTheme.edgeTextPrimary,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _MetadataPill(
                  label: _statusLabel(progress?.status, active: active),
                  accent:
                      active ||
                      progress?.status == LessonProgressStatus.completed ||
                      progress?.status == LessonProgressStatus.inProgress,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TeachingText(label: 'Why', text: exercise.why),
            _TeachingText(label: 'What', text: exercise.what),
            _TeachingText(label: 'How', text: exercise.how),
            if (exercise.success != null)
              _TeachingText(label: 'Success', text: exercise.success!),
            if (exercise.tempo != null) ...<Widget>[
              const SizedBox(height: 8),
              _MetadataPill(
                label: '${exercise.tempo!.start}-${exercise.tempo!.target} BPM',
                outlinedAccent: true,
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'HEAR IT',
              style: textTheme.labelLarge?.copyWith(
                color: DrumcabularyTheme.edgeOrange,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 6),
            for (
              int index = 0;
              index < exercise.notation.sections.length;
              index += 1
            ) ...[
              if (index > 0) const SizedBox(height: 12),
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
                selectedIndexes: _guidedSelectionForSection(
                  guidedPracticeState,
                  index,
                ),
                controller: index == 0 ? primaryPreviewController : null,
              ),
            ],
            const SizedBox(height: 12),
            if (guidedPracticeState != null) ...<Widget>[
              _GuidedPracticeStatusLine(state: guidedPracticeState!),
              const SizedBox(height: 10),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: guidedPracticeState?.isActive == true
                  ? <Widget>[
                      FilledButton.icon(
                        onPressed: onStopGuidedPractice,
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('Stop Guided Practice'),
                      ),
                    ]
                  : <Widget>[
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
                      OutlinedButton.icon(
                        onPressed: onStartGuidedPractice,
                        icon: const Icon(Icons.lightbulb_outline_rounded),
                        label: const Text('Guided Practice'),
                      ),
                      Text(
                        active
                            ? _durationLabel(activeElapsed)
                            : _durationLabel(
                                Duration(seconds: practicedSeconds),
                              ),
                        style: textTheme.labelLarge?.copyWith(
                          color: DrumcabularyTheme.edgeTextSecondary,
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

class _TeachingText extends StatelessWidget {
  final String label;
  final String text;

  const _TeachingText({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: DrumcabularyTheme.edgeTextSecondary,
            height: 1.35,
          ),
          children: <TextSpan>[
            TextSpan(
              text: '${label.toUpperCase()}: ',
              style: const TextStyle(
                color: DrumcabularyTheme.edgeTextPrimary,
                fontWeight: FontWeight.w900,
              ),
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
  final SerialLedController ledController;
  final bool ledPlaybackEnabled;
  final Set<int> selectedIndexes;
  final DrumSheetNotationController? controller;

  const _NotationPreview({
    required this.section,
    required this.previewBpm,
    required this.ledController,
    required this.ledPlaybackEnabled,
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
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Theme(
          data: notationTheme,
          child: DrumSheetNotationDisplay(
            document: documentForNotationSection(section),
            grouping: groupingTextFromPattern(section.pattern),
            selection: selectedIndexes.isEmpty
                ? DrumSheetNotationSelection.empty
                : DrumSheetNotationSelection.guidedPractice(selectedIndexes),
            selectable: false,
            compactLayout: true,
            minNoteWidth: 40,
            showSticking: shouldShowStickingForNotationSection(section),
            audioPreviewEnabled: true,
            audioPreviewBpm: previewBpm,
            ledController: ledController,
            ledPlaybackEnabled: ledPlaybackEnabled,
            backgroundColor: DrumcabularyTheme.edgeNotationPanel,
            noteColor: DrumcabularyTheme.edgeNotationInk,
            staffColor: DrumcabularyTheme.edgeNotationInk.withValues(
              alpha: 0.62,
            ),
            selectedColor: DrumcabularyTheme.edgeOrange,
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
