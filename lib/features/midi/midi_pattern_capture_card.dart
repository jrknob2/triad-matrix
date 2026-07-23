import 'dart:async';

import 'package:flutter/material.dart';

import '../app/drumcabulary_theme.dart';
import '../app/drumcabulary_ui.dart';
import '../guided_practice/guided_practice_controller.dart';
import '../midi/led_frame_command_encoder.dart';
import '../midi/midi_input_models.dart';
import '../midi/serial_led_controller.dart';
import '../practice/pattern_audio_service.dart';
import '../practice/pattern_led_playback_output.dart';
import '../practice/playback_drum_voice_mapper.dart';
import '../practice/widgets/sheet_notation_display.dart';
import 'midi_pattern_capture.dart';

class MidiPatternCaptureCard extends StatefulWidget {
  final MidiPatternCaptureController controller;
  final MidiInputStatus? midiStatus;
  final Stream<DrumInputEvent>? drumEvents;
  final bool playAlongInputEnabled;
  final SerialLedController? ledController;
  final int playbackBpm;
  final ValueChanged<String>? onCreateExercise;
  final VoidCallback? onOpenDevices;

  const MidiPatternCaptureCard({
    super.key,
    required this.controller,
    this.midiStatus,
    this.drumEvents,
    this.playAlongInputEnabled = false,
    this.ledController,
    this.playbackBpm = 92,
    this.onCreateExercise,
    this.onOpenDevices,
  });

  @override
  State<MidiPatternCaptureCard> createState() => _MidiPatternCaptureCardState();
}

class _MidiPatternCaptureCardState extends State<MidiPatternCaptureCard> {
  static const Duration _manualEditDebounce = Duration(milliseconds: 250);

  late final TextEditingController _patternController;
  final DrumSheetNotationController _notationController =
      DrumSheetNotationController();
  Timer? _manualEditTimer;
  DrumSheetNotationDocument? _renderedDocument;
  GuidedPracticeController? _guidedPracticeController;
  _CapturePlaybackMode? _activePlaybackMode;
  _CapturePlaybackMode _previewPlaybackMode = _CapturePlaybackMode.hearIt;
  String? _validationError;
  String? _practiceMessage;
  bool _syncingText = false;

  @override
  void initState() {
    super.initState();
    _patternController = TextEditingController(
      text: widget.controller.generatedPattern,
    );
    widget.controller.addListener(_handleCaptureChanged);
    widget.ledController?.addListener(_handleLedControllerChanged);
    _syncFromCaptureController();
  }

  @override
  void didUpdateWidget(covariant MidiPatternCaptureCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleCaptureChanged);
      widget.controller.addListener(_handleCaptureChanged);
      _syncFromCaptureController();
    }
    if (oldWidget.ledController != widget.ledController) {
      oldWidget.ledController?.removeListener(_handleLedControllerChanged);
      widget.ledController?.addListener(_handleLedControllerChanged);
      if (widget.ledController?.isConnected != true) {
        _guidedPracticeController?.handleSerialDisconnected();
      }
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleCaptureChanged);
    widget.ledController?.removeListener(_handleLedControllerChanged);
    _manualEditTimer?.cancel();
    _disposeGuidedPractice(sendStop: true);
    unawaited(_notationController.stopAudioPreview());
    _patternController.dispose();
    super.dispose();
  }

  void _handleCaptureChanged() {
    _syncFromCaptureController();
  }

  void _syncFromCaptureController() {
    _manualEditTimer?.cancel();
    final String pattern = widget.controller.generatedPattern;
    _syncingText = true;
    if (_patternController.text != pattern) {
      _patternController.value = TextEditingValue(
        text: pattern,
        selection: TextSelection.collapsed(offset: pattern.length),
      );
    }
    _syncingText = false;
    _validateAndRender(pattern, clearPreviewWhenEmpty: true);
  }

  void _handleManualEdit(String value) {
    if (_syncingText || widget.controller.isRecording) {
      return;
    }
    _manualEditTimer?.cancel();
    _manualEditTimer = Timer(_manualEditDebounce, () {
      if (!mounted) return;
      _validateAndRender(value, clearPreviewWhenEmpty: true);
    });
  }

  void _validateAndRender(String value, {required bool clearPreviewWhenEmpty}) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      _disposeGuidedPractice(sendStop: true);
      unawaited(_notationController.stopAudioPreview());
      if (!mounted) return;
      setState(() {
        if (clearPreviewWhenEmpty) _renderedDocument = null;
        _validationError = null;
        _activePlaybackMode = null;
        _practiceMessage = null;
      });
      return;
    }

    try {
      final DrumSheetNotationDocument document =
          DrumSheetNotationDocument.fromPattern(trimmed);
      if (_renderedDocument != document) {
        _disposeGuidedPractice(sendStop: true);
        unawaited(_notationController.stopAudioPreview());
      }
      if (!mounted) return;
      setState(() {
        _renderedDocument = document;
        _validationError = null;
        _activePlaybackMode = null;
        _practiceMessage = null;
      });
    } on FormatException catch (error) {
      _setValidationError(error.message);
    } on ArgumentError catch (error) {
      _setValidationError(error.message ?? 'Invalid pattern.');
    } on Object catch (error) {
      _setValidationError('$error');
    }
  }

  void _setValidationError(String message) {
    _disposeGuidedPractice(sendStop: true);
    unawaited(_notationController.stopAudioPreview());
    if (!mounted) return;
    setState(() {
      _validationError = message;
      _activePlaybackMode = null;
      _practiceMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'MIDI Pattern Capture',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          DrumActionRow(
            children: <Widget>[
              FilledButton.icon(
                onPressed: !widget.controller.isRecording && _canRecordFromMidi
                    ? widget.controller.record
                    : null,
                icon: const Icon(Icons.fiber_manual_record_rounded),
                label: const Text('Record'),
              ),
              OutlinedButton.icon(
                onPressed: widget.controller.isRecording
                    ? widget.controller.stop
                    : null,
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Stop'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _CaptureStatusChip(
                  icon: Icons.graphic_eq_rounded,
                  label: _midiStatusLabel(widget.midiStatus),
                  connected: widget.midiStatus == MidiInputStatus.connected,
                  onPressed: widget.onOpenDevices,
                ),
                if (widget.onOpenDevices != null)
                  _CaptureStatusChip(
                    icon: Icons.radio_button_checked_rounded,
                    label: _ledStatusLabel(widget.ledController),
                    connected: widget.ledController?.isConnected == true,
                    onPressed: widget.onOpenDevices,
                  ),
                Chip(
                  label: Text(
                    'Estimated BPM ${_tempoEstimateLabel(widget.controller.tempoEstimate)}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Generated pattern string',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.edgeOrange,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _patternController,
            readOnly: widget.controller.isRecording,
            minLines: 2,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            smartDashesType: SmartDashesType.disabled,
            smartQuotesType: SmartQuotesType.disabled,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.edgeTextPrimary,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              height: 1.35,
            ),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: DrumcabularyTheme.edgeSurfaceSecondary,
              errorText: _validationError,
              errorMaxLines: 2,
              contentPadding: const EdgeInsets.all(12),
            ),
            onChanged: _handleManualEdit,
          ),
          const SizedBox(height: 14),
          Text(
            'Rendered notation preview',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: DrumcabularyTheme.edgeOrange,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          _CapturedPatternPreview(
            document: _renderedDocument,
            controller: _notationController,
            selection: _guidedPracticeSelection,
            ledController: widget.ledController,
            ledPlaybackEnabled: widget.ledController?.isConnected == true,
            playAlongDrumEvents: widget.drumEvents,
            playAlongInputEnabled: widget.playAlongInputEnabled,
            ledPlaybackPresentation: switch (_previewPlaybackMode) {
              _CapturePlaybackMode.hearIt =>
                PatternLedPlaybackPresentation.hearIt,
              _CapturePlaybackMode.playAlong =>
                PatternLedPlaybackPresentation.playAlong,
            },
            playbackBpm: widget.playbackBpm,
          ),
          const SizedBox(height: 12),
          _PracticeControls(
            canPlay: _hasPlayablePattern,
            canCreateExercise:
                widget.onCreateExercise != null &&
                _hasPlayablePattern &&
                _validationError == null,
            ledAvailable: widget.ledController?.isConnected == true,
            guidedAvailable:
                _hasPlayablePattern &&
                widget.drumEvents != null &&
                widget.ledController?.isConnected == true,
            activePlaybackMode: _activePlaybackMode,
            guidedState: _guidedPracticeController?.state,
            message: _practiceMessage,
            onHearIt: () => _togglePlayback(_CapturePlaybackMode.hearIt),
            onPlayAlong: () => _togglePlayback(_CapturePlaybackMode.playAlong),
            onGuidedPractice: _toggleGuidedPractice,
            onCreateExercise: _createExerciseFromCurrentPattern,
          ),
        ],
      ),
    );
  }

  bool get _hasPlayablePattern {
    return _renderedDocument?.flattenedNotes.any(
          (DrumSheetNotationNote note) => !note.rest,
        ) ??
        false;
  }

  bool get _canRecordFromMidi {
    final MidiInputStatus? status = widget.midiStatus;
    return status == null || status == MidiInputStatus.connected;
  }

  void _createExerciseFromCurrentPattern() {
    final ValueChanged<String>? onCreateExercise = widget.onCreateExercise;
    if (onCreateExercise == null) return;
    final String pattern = _patternController.text.trim();
    if (pattern.isEmpty) {
      setState(() => _validationError = 'Capture or enter a pattern first.');
      return;
    }
    try {
      final DrumSheetNotationDocument document =
          DrumSheetNotationDocument.fromPattern(pattern);
      final bool hasPlayableNotes = document.flattenedNotes.any(
        (DrumSheetNotationNote note) => !note.rest,
      );
      if (!hasPlayableNotes) {
        setState(() => _validationError = 'Enter a playable pattern first.');
        return;
      }
      setState(() {
        _renderedDocument = document;
        _validationError = null;
      });
      onCreateExercise(pattern);
    } on FormatException catch (error) {
      _setValidationError(error.message);
    } on ArgumentError catch (error) {
      _setValidationError(error.message ?? 'Invalid pattern.');
    } on Object catch (error) {
      _setValidationError('$error');
    }
  }

  DrumSheetNotationSelection? get _guidedPracticeSelection {
    final GuidedPracticeState? state = _guidedPracticeController?.state;
    final GuidedPracticeExpectedEvent? event = state?.currentEvent;
    if (state?.isActive != true || event == null) return null;
    return DrumSheetNotationSelection.guidedPractice(event.selectedIndexes);
  }

  Future<void> _togglePlayback(_CapturePlaybackMode mode) async {
    if (!_hasPlayablePattern) return;
    if (_activePlaybackMode == mode) {
      await _notationController.stopAudioPreview();
      if (!mounted) return;
      setState(() => _activePlaybackMode = null);
      return;
    }
    _disposeGuidedPractice(sendStop: true);
    await _notationController.stopAudioPreview();
    if (!mounted) return;
    setState(() {
      _previewPlaybackMode = mode;
      _activePlaybackMode = mode;
      _practiceMessage = null;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _activePlaybackMode != mode) return;
    await _notationController.startAudioPreview();
  }

  void _toggleGuidedPractice() {
    final GuidedPracticeController? existing = _guidedPracticeController;
    if (existing?.isRunning == true) {
      _disposeGuidedPractice(sendStop: true);
      if (mounted) {
        setState(() => _practiceMessage = 'Guided Practice stopped.');
      }
      return;
    }
    _startGuidedPractice();
  }

  void _startGuidedPractice() {
    final DrumSheetNotationDocument? document = _renderedDocument;
    final Stream<DrumInputEvent>? drumEvents = widget.drumEvents;
    final SerialLedController? ledController = widget.ledController;
    if (document == null || !_hasPlayablePattern) return;
    if (drumEvents == null) {
      setState(() => _practiceMessage = 'Connect MIDI input first.');
      return;
    }
    if (ledController == null || !ledController.isConnected) {
      setState(() => _practiceMessage = 'Connect the LED controller first.');
      return;
    }

    final List<GuidedPracticeExpectedEvent> expectedEvents =
        _guidedPracticeEventsForDocument(document);
    if (expectedEvents.isEmpty) {
      setState(() => _practiceMessage = 'No playable events found.');
      return;
    }

    unawaited(_notationController.stopAudioPreview());
    _activePlaybackMode = null;
    _disposeGuidedPractice(sendStop: true);
    final GuidedPracticeController controller = GuidedPracticeController(
      expectedEvents: expectedEvents,
      drumEvents: drumEvents,
      ledController: ledController,
    )..addListener(_handleGuidedPracticeChanged);
    _guidedPracticeController = controller;
    final bool started = controller.start();
    if (!started) {
      controller
        ..removeListener(_handleGuidedPracticeChanged)
        ..dispose();
      _guidedPracticeController = null;
      setState(() => _practiceMessage = 'Guided Practice could not start.');
      return;
    }
    setState(() => _practiceMessage = 'Guided Practice active.');
  }

  void _handleGuidedPracticeChanged() {
    final GuidedPracticeState? state = _guidedPracticeController?.state;
    if (!mounted || state == null) return;
    setState(() {
      _practiceMessage = switch (state.status) {
        GuidedPracticeStatus.running =>
          state.message ?? 'Guided Practice active.',
        GuidedPracticeStatus.completed => 'Guided Practice complete.',
        GuidedPracticeStatus.stopped => 'Guided Practice stopped.',
        GuidedPracticeStatus.error =>
          state.message ?? 'Guided Practice stopped.',
        _ => null,
      };
    });
  }

  void _handleLedControllerChanged() {
    if (widget.ledController?.isConnected != true) {
      _guidedPracticeController?.handleSerialDisconnected();
    }
    if (mounted) setState(() {});
  }

  void _disposeGuidedPractice({required bool sendStop}) {
    final GuidedPracticeController? controller = _guidedPracticeController;
    if (controller == null) return;
    if (sendStop && controller.isRunning) {
      controller.stop();
    }
    controller
      ..removeListener(_handleGuidedPracticeChanged)
      ..dispose();
    _guidedPracticeController = null;
  }

  List<GuidedPracticeExpectedEvent> _guidedPracticeEventsForDocument(
    DrumSheetNotationDocument document,
  ) {
    final DrumSheetAudioPreviewPlan previewPlan =
        buildSheetNotationAudioPreviewPlanDetails(document);
    final PatternAudioPlanV1 plan = previewPlan.audioPlan;
    final List<GuidedPracticeExpectedEvent> events =
        <GuidedPracticeExpectedEvent>[];
    Duration? currentOffset;
    final List<LedCue> currentCues = <LedCue>[];
    final Set<int> currentSelectedIndexes = <int>{};

    void flush() {
      if (currentCues.isEmpty) return;
      final GuidedPracticeExpectedEvent event =
          GuidedPracticeExpectedEvent.fromCues(
            currentCues,
            selectedIndexes: currentSelectedIndexes,
          );
      if (!event.isEmpty) events.add(event);
      currentCues.clear();
      currentSelectedIndexes.clear();
    }

    for (final PatternAudioCueV1 cue in plan.cues) {
      if (currentOffset == null || cue.offset != currentOffset) {
        flush();
        currentOffset = cue.offset;
      }
      currentCues.add(
        LedCue(
          midiDrumVoiceForPlaybackVoice(cue.voice),
          sticking: cue.sticking,
        ),
      );
      final int? displayIndex = previewPlan.displayIndexForTokenIndex(
        cue.tokenIndex,
      );
      if (displayIndex != null) currentSelectedIndexes.add(displayIndex);
    }
    flush();
    return events;
  }
}

class _CapturedPatternPreview extends StatelessWidget {
  static const DrumSheetNotationDocument _emptyDocument =
      DrumSheetNotationDocument(
        measures: <DrumSheetNotationMeasure>[
          DrumSheetNotationMeasure(notes: <DrumSheetNotationNote>[]),
        ],
      );

  final DrumSheetNotationDocument? document;
  final DrumSheetNotationController controller;
  final DrumSheetNotationSelection? selection;
  final SerialLedController? ledController;
  final bool ledPlaybackEnabled;
  final Stream<DrumInputEvent>? playAlongDrumEvents;
  final bool playAlongInputEnabled;
  final PatternLedPlaybackPresentation ledPlaybackPresentation;
  final int playbackBpm;

  const _CapturedPatternPreview({
    required this.document,
    required this.controller,
    required this.selection,
    required this.ledController,
    required this.ledPlaybackEnabled,
    required this.playAlongDrumEvents,
    required this.playAlongInputEnabled,
    required this.ledPlaybackPresentation,
    required this.playbackBpm,
  });

  @override
  Widget build(BuildContext context) {
    final DrumSheetNotationDocument document = this.document ?? _emptyDocument;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.edgeNotationPanel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD9D2C6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: DrumSheetNotationDisplay(
          document: document,
          controller: controller,
          selection: selection,
          selectable: false,
          compactLayout: true,
          preserveMeasures: false,
          minNoteWidth: 34,
          showSticking: false,
          audioPreviewBpm: playbackBpm,
          ledController: ledController,
          ledPlaybackEnabled: ledPlaybackEnabled,
          playAlongDrumEvents: playAlongDrumEvents,
          playAlongInputEnabled: playAlongInputEnabled,
          ledPlaybackPresentation: ledPlaybackPresentation,
          backgroundColor: DrumcabularyTheme.edgeNotationPanel,
          noteColor: DrumcabularyTheme.edgeNotationInk,
          staffColor: DrumcabularyTheme.edgeNotationInk.withValues(alpha: 0.62),
          selectedColor: DrumcabularyTheme.edgeOrange,
        ),
      ),
    );
  }
}

enum _CapturePlaybackMode { hearIt, playAlong }

class _PracticeControls extends StatelessWidget {
  final bool canPlay;
  final bool canCreateExercise;
  final bool ledAvailable;
  final bool guidedAvailable;
  final _CapturePlaybackMode? activePlaybackMode;
  final GuidedPracticeState? guidedState;
  final String? message;
  final VoidCallback onHearIt;
  final VoidCallback onPlayAlong;
  final VoidCallback onGuidedPractice;
  final VoidCallback onCreateExercise;

  const _PracticeControls({
    required this.canPlay,
    required this.canCreateExercise,
    required this.ledAvailable,
    required this.guidedAvailable,
    required this.activePlaybackMode,
    required this.guidedState,
    required this.message,
    required this.onHearIt,
    required this.onPlayAlong,
    required this.onGuidedPractice,
    required this.onCreateExercise,
  });

  @override
  Widget build(BuildContext context) {
    final bool guidedRunning = guidedState?.isActive ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Practice from capture',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: DrumcabularyTheme.edgeOrange,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        DrumActionRow(
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: canPlay ? onHearIt : null,
              icon: Icon(
                activePlaybackMode == _CapturePlaybackMode.hearIt
                    ? Icons.stop_rounded
                    : Icons.hearing_rounded,
              ),
              label: Text(
                activePlaybackMode == _CapturePlaybackMode.hearIt
                    ? 'Stop Hear It'
                    : 'Hear It',
              ),
            ),
            OutlinedButton.icon(
              onPressed: canPlay ? onPlayAlong : null,
              icon: Icon(
                activePlaybackMode == _CapturePlaybackMode.playAlong
                    ? Icons.stop_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                activePlaybackMode == _CapturePlaybackMode.playAlong
                    ? 'Stop Play Along'
                    : 'Play Along',
              ),
            ),
            FilledButton.icon(
              onPressed: guidedRunning || guidedAvailable
                  ? onGuidedPractice
                  : null,
              icon: Icon(
                guidedRunning ? Icons.stop_rounded : Icons.flag_rounded,
              ),
              label: Text(
                guidedRunning ? 'Stop Guided Practice' : 'Guided Practice',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: canCreateExercise ? onCreateExercise : null,
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Create Exercise'),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            Chip(label: Text(ledAvailable ? 'LEDs available' : 'Audio only')),
            if (guidedRunning) const Chip(label: Text('Waiting for input')),
          ],
        ),
        if (message != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(message!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _CaptureStatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool connected;
  final VoidCallback? onPressed;

  const _CaptureStatusChip({
    required this.icon,
    required this.label,
    required this.connected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor = connected
        ? const Color(0xFF52D273)
        : const Color(0xFFFFC857);
    final Widget chipLabel = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 16, color: DrumcabularyTheme.edgeTextSecondary),
        const SizedBox(width: 6),
        DecoratedBox(
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          child: const SizedBox(width: 7, height: 7),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );

    if (onPressed == null) {
      return Chip(label: chipLabel);
    }
    return ActionChip(
      label: chipLabel,
      onPressed: onPressed,
      tooltip: 'Open device connections',
    );
  }
}

String _tempoEstimateLabel(MidiTempoEstimate? estimate) {
  if (estimate == null) return '--';
  return '${estimate.roundedBpm}';
}

String _midiStatusLabel(MidiInputStatus? status) {
  return switch (status) {
    MidiInputStatus.connected => 'MIDI connected',
    MidiInputStatus.connecting => 'MIDI connecting',
    MidiInputStatus.scanning => 'MIDI scanning',
    MidiInputStatus.noDevicesFound => 'No MIDI devices',
    MidiInputStatus.connectionError => 'MIDI connection error',
    MidiInputStatus.disconnected => 'Connect MIDI input',
    null => 'MIDI input',
  };
}

String _ledStatusLabel(SerialLedController? controller) {
  return switch (controller?.status) {
    SerialLedConnectionStatus.connected => 'LED connected',
    SerialLedConnectionStatus.connecting => 'LED connecting',
    SerialLedConnectionStatus.connectionError => 'LED connection error',
    SerialLedConnectionStatus.deviceRemoved => 'LED device removed',
    SerialLedConnectionStatus.disconnected => 'Connect LED controller',
    null => 'LED controller',
  };
}
