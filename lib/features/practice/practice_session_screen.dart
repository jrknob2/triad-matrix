import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../features/app/drumcabulary_theme.dart';
import '../../state/app_controller.dart';
import '../../core/practice/practice_domain_v1.dart';
import 'metronome_service.dart';
import 'pattern_audio_service.dart';
import 'pattern_playback_scheduler.dart';
import 'widgets/pattern_voice_display.dart';
import 'session_summary_screen.dart';

class PracticeSessionScreen extends StatefulWidget {
  final AppController controller;
  final PracticeSessionSetupV1 setup;
  final ValueChanged<bool>? onFocusModeChanged;

  const PracticeSessionScreen({
    super.key,
    required this.controller,
    required this.setup,
    this.onFocusModeChanged,
  });

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _SessionTransportState {
  final Duration elapsed;
  final Duration? target;
  final String timerText;
  final String? statusText;
  final bool completed;

  const _SessionTransportState({
    required this.elapsed,
    required this.target,
    required this.timerText,
    required this.statusText,
    required this.completed,
  });
}

class PracticeSessionRuntimeMath {
  static int? activeTokenIndex({
    required List<PatternTokenV1> tokens,
    required PatternGroupingV1 grouping,
    required PatternTimingV1 timing,
    required Duration elapsed,
    required int bpm,
  }) {
    return PatternPlaybackSchedulerV1.activeTokenIndex(
      tokens: tokens,
      grouping: grouping,
      timing: timing,
      elapsed: elapsed,
      bpm: bpm,
    );
  }
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  static const String _metronomeAssetPath = 'assets/audio/metronome_beep.wav';
  static const Duration _focusTransitionDuration = Duration(milliseconds: 320);

  final Stopwatch _stopwatch = Stopwatch();
  final Stopwatch _patternPreviewStopwatch = Stopwatch();
  late final PracticeMetronomeService _metronome;
  late final PatternAudioService _patternAudio;
  Timer? _elapsedTicker;
  Timer? _patternPreviewTicker;
  bool _running = false;
  bool _warmupComplete = false;
  bool _completionChimed = false;
  bool _summaryOpenedForCurrentRun = false;
  bool _ephemeralItemsDiscarded = false;
  Duration _elapsedOffset = Duration.zero;
  int? _lastWarmupAutoIndex;
  int _lastSinglePatternCompletedCycle = 0;
  late Map<String, int> _itemBpmById;
  late Map<String, Duration> _itemActiveDurationById;
  late List<String> _practicedItemIds;
  late bool _pulseEnabled;
  late int _bpm;
  late bool _clickEnabled;
  bool _patternAudioEnabled = false;
  bool _patternHighlightEnabled = true;
  late PracticeSessionSetupV1 _setup;
  Duration _patternPreviewBaseElapsed = Duration.zero;
  Duration? _currentItemSegmentStartElapsed;
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _setup = widget.setup;
    _itemBpmById = Map<String, int>.from(_setup.itemBpmById);
    _itemActiveDurationById = <String, Duration>{};
    _practicedItemIds = <String>[];
    _bpm = _itemBpmById[_currentItemId] ?? _setup.bpm;
    _clickEnabled = _isWarmup ? false : _setup.clickEnabled;
    _pulseEnabled = !_isWarmup;
    _metronome = PracticeMetronomeService(assetPath: _metronomeAssetPath);
    _patternAudio = PatternAudioService();
    unawaited(_configureAudio());
  }

  @override
  void dispose() {
    widget.onFocusModeChanged?.call(false);
    _discardEphemeralItemsIfNeeded();
    _elapsedTicker?.cancel();
    _patternPreviewTicker?.cancel();
    unawaited(_metronome.dispose());
    unawaited(_patternAudio.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWarmup = _isWarmup;
    final bool focusMode = _running;
    final String currentItemId = _currentItemId;
    final List<PatternTokenV1> tokens = widget.controller.patternTokensFor(
      currentItemId,
    );
    final List<PatternNoteMarkingV1> markings = widget.controller
        .noteMarkingsFor(currentItemId);
    final List<DrumVoiceV1> voices = widget.controller.noteVoicesFor(
      currentItemId,
    );
    final _SessionTransportState transport = _transportState;
    final int? activeTokenIndex = _activeTokenIndexForCurrentItem(tokens);

    return Scaffold(
      body: DrumScreen(
        warm: false,
        child: SafeArea(
          child: AnimatedPadding(
            duration: _focusTransitionDuration,
            curve: Curves.easeInOut,
            padding: EdgeInsets.fromLTRB(
              focusMode ? 8 : 16,
              focusMode ? 8 : 12,
              focusMode ? 8 : 16,
              16,
            ),
            child: Column(
              children: <Widget>[
                _buildAnimatedHeader(context, isWarmup: isWarmup),
                AnimatedContainer(
                  duration: _focusTransitionDuration,
                  curve: Curves.easeInOut,
                  height: focusMode ? 8 : 12,
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                          final Widget defaultLayout = ListView(
                            padding: EdgeInsets.zero,
                            children: <Widget>[
                              _buildPlayerPanel(
                                context,
                                isWarmup: isWarmup,
                                currentItemId: currentItemId,
                                markings: markings,
                                tokens: tokens,
                                transport: transport,
                                voices: voices,
                                focusMode: false,
                                activeTokenIndex: activeTokenIndex,
                                availableWidth: constraints.maxWidth,
                              ),
                            ],
                          );
                          final Widget focusLayout = Align(
                            alignment: Alignment.topCenter,
                            child: _buildPlayerPanel(
                              context,
                              isWarmup: isWarmup,
                              currentItemId: currentItemId,
                              markings: markings,
                              tokens: tokens,
                              transport: transport,
                              voices: voices,
                              focusMode: true,
                              activeTokenIndex: activeTokenIndex,
                              availableWidth: constraints.maxWidth,
                            ),
                          );
                          return Stack(
                            fit: StackFit.expand,
                            children: <Widget>[
                              IgnorePointer(
                                ignoring: focusMode,
                                child: AnimatedSlide(
                                  duration: _focusTransitionDuration,
                                  curve: Curves.easeInOutCubic,
                                  offset: focusMode
                                      ? const Offset(0, -0.025)
                                      : Offset.zero,
                                  child: AnimatedOpacity(
                                    duration: _focusTransitionDuration,
                                    curve: Curves.easeInOut,
                                    opacity: focusMode ? 0 : 1,
                                    child: defaultLayout,
                                  ),
                                ),
                              ),
                              IgnorePointer(
                                ignoring: !focusMode,
                                child: AnimatedSlide(
                                  duration: _focusTransitionDuration,
                                  curve: Curves.easeInOutCubic,
                                  offset: focusMode
                                      ? Offset.zero
                                      : const Offset(0, 0.03),
                                  child: AnimatedOpacity(
                                    duration: _focusTransitionDuration,
                                    curve: Curves.easeInOut,
                                    opacity: focusMode ? 1 : 0,
                                    child: focusLayout,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedHeader(BuildContext context, {required bool isWarmup}) {
    final bool hidden = _running;
    return ClipRect(
      child: AnimatedContainer(
        duration: _focusTransitionDuration,
        curve: Curves.easeInOut,
        height: hidden ? 0 : 52,
        child: AnimatedOpacity(
          duration: _focusTransitionDuration,
          curve: Curves.easeInOut,
          opacity: hidden ? 0 : 1,
          child: IgnorePointer(
            ignoring: hidden,
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Back',
                ),
                Expanded(
                  child: Text(
                    isWarmup ? 'Warmup Session' : 'Practice Session',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _openSessionSettingsModal(context),
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Session settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerPanel(
    BuildContext context, {
    required bool isWarmup,
    required String currentItemId,
    required List<PatternNoteMarkingV1> markings,
    required List<PatternTokenV1> tokens,
    required _SessionTransportState transport,
    required List<DrumVoiceV1> voices,
    required bool focusMode,
    required int? activeTokenIndex,
    double? availableWidth,
  }) {
    final bool canEndSession = _canEndSession;
    final double panelPadding = focusMode ? 12 : 20;
    final double gaugeSize = focusMode
        ? ((availableWidth ?? MediaQuery.sizeOf(context).width) * 0.9).clamp(
            228.0,
            420.0,
          )
        : 228;
    final ButtonStyle secondaryTransportStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(116, 48)),
      maximumSize: const WidgetStatePropertyAll<Size>(Size(116, 48)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      shape: const WidgetStatePropertyAll<OutlinedBorder>(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return DrumcabularyTheme.creamText.withValues(alpha: 0.7);
        }
        return DrumcabularyTheme.creamText;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: Color(0x66FFF4DE));
        }
        return const BorderSide(color: DrumcabularyTheme.creamText);
      }),
    );
    final ButtonStyle primaryTransportStyle = FilledButton.styleFrom(
      minimumSize: const Size(116, 48),
      maximumSize: const Size(116, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: DrumcabularyTheme.creamText,
      foregroundColor: DrumcabularyTheme.ink,
      side: const BorderSide(color: DrumcabularyTheme.creamText),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
    );
    return DrumPanel(
      tone: DrumPanelTone.dark,
      padding: EdgeInsets.zero,
      child: AnimatedPadding(
        duration: _focusTransitionDuration,
        curve: Curves.easeInOut,
        padding: EdgeInsets.all(panelPadding),
        child: focusMode
            ? LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            if (_setup.practiceItemIds.length > 1) ...<Widget>[
                              _SessionStepper(
                                currentIndex: _currentItemIndex,
                                itemCount: _setup.practiceItemIds.length,
                                onPrevious: _currentItemIndex == 0
                                    ? null
                                    : () => _changeItem(_currentItemIndex - 1),
                                onNext:
                                    _currentItemIndex ==
                                        _setup.practiceItemIds.length - 1
                                    ? null
                                    : () => _changeItem(_currentItemIndex + 1),
                                dark: true,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildNotationBlock(
                              context,
                              isWarmup: isWarmup,
                              currentItemId: currentItemId,
                              tokens: tokens,
                              markings: markings,
                              voices: voices,
                              activeTokenIndex: activeTokenIndex,
                            ),
                          ],
                        ),
                        const Spacer(),
                        _BeatPulse(
                          pulseActiveListenable: _metronome.pulseActive,
                          bpm: _bpm,
                          enabled: _pulseEnabled,
                          progress: _sessionProgressFraction(transport),
                          target: transport.target,
                          size: gaugeSize,
                        ),
                        const Spacer(),
                        Column(
                          children: <Widget>[
                            Text(
                              transport.timerText,
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    fontFamily: 'Courier',
                                    color: DrumcabularyTheme.creamText,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                            if (_showsEarnedReps) ...<Widget>[
                              const SizedBox(height: 14),
                              _EarnedRepsDisplay(reps: _totalEarnedReps),
                            ],
                            if (transport.statusText != null) ...<Widget>[
                              const SizedBox(height: 8),
                              Text(
                                transport.statusText!,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: DrumcabularyTheme.pulseHover,
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                if (_running) ...<Widget>[
                                  SizedBox(
                                    height: 48,
                                    width: 108,
                                    child: FilledButton.icon(
                                      style: primaryTransportStyle,
                                      onPressed: _toggleRunning,
                                      icon: const Icon(Icons.pause),
                                      label: const Text('Pause'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (!isWarmup)
                                    SizedBox(
                                      height: 48,
                                      width: 108,
                                      child: OutlinedButton.icon(
                                        onPressed: _resetCurrentSessionRun,
                                        style: secondaryTransportStyle,
                                        icon: const Icon(Icons.restart_alt),
                                        label: const Text('Reset'),
                                      ),
                                    ),
                                  if (isWarmup)
                                    SizedBox(
                                      height: 48,
                                      width: 108,
                                      child: OutlinedButton(
                                        onPressed: _endSession,
                                        style: secondaryTransportStyle,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            const Icon(
                                              Icons.stop_rounded,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('End'),
                                          ],
                                        ),
                                      ),
                                    ),
                                ] else ...<Widget>[
                                  SizedBox(
                                    height: 48,
                                    width: 108,
                                    child: FilledButton.icon(
                                      style: primaryTransportStyle,
                                      onPressed: _toggleRunning,
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Play'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                ],
                                if (!_running || isWarmup)
                                  SizedBox(
                                    height: 48,
                                    width: 108,
                                    child: OutlinedButton(
                                      onPressed: canEndSession
                                          ? _endSession
                                          : null,
                                      style: secondaryTransportStyle,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          const Icon(
                                            Icons.stop_rounded,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text('End'),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              )
            : Column(
                children: <Widget>[
                  if (_setup.practiceItemIds.length > 1) ...<Widget>[
                    _SessionStepper(
                      currentIndex: _currentItemIndex,
                      itemCount: _setup.practiceItemIds.length,
                      onPrevious: _currentItemIndex == 0
                          ? null
                          : () => _changeItem(_currentItemIndex - 1),
                      onNext:
                          _currentItemIndex == _setup.practiceItemIds.length - 1
                          ? null
                          : () => _changeItem(_currentItemIndex + 1),
                      dark: true,
                    ),
                    const SizedBox(height: 16),
                  ],
                  _buildNotationBlock(
                    context,
                    isWarmup: isWarmup,
                    currentItemId: currentItemId,
                    tokens: tokens,
                    markings: markings,
                    voices: voices,
                    activeTokenIndex: activeTokenIndex,
                  ),
                  const SizedBox(height: 18),
                  _BeatPulse(
                    pulseActiveListenable: _metronome.pulseActive,
                    bpm: _bpm,
                    enabled: _pulseEnabled,
                    progress: _sessionProgressFraction(transport),
                    target: transport.target,
                    size: gaugeSize,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    transport.timerText,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: 'Courier',
                      color: DrumcabularyTheme.creamText,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_showsEarnedReps) ...<Widget>[
                    const SizedBox(height: 12),
                    _EarnedRepsDisplay(reps: _totalEarnedReps),
                  ],
                  if (transport.statusText != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      transport.statusText!,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: DrumcabularyTheme.pulseHover,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      if (_running) ...<Widget>[
                        SizedBox(
                          height: 48,
                          width: 108,
                          child: FilledButton.icon(
                            style: primaryTransportStyle,
                            onPressed: _toggleRunning,
                            icon: const Icon(Icons.pause),
                            label: const Text('Pause'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (!isWarmup)
                          SizedBox(
                            height: 48,
                            width: 108,
                            child: OutlinedButton.icon(
                              onPressed: _resetCurrentSessionRun,
                              style: secondaryTransportStyle,
                              icon: const Icon(Icons.restart_alt),
                              label: const Text('Reset'),
                            ),
                          ),
                        if (isWarmup)
                          SizedBox(
                            height: 48,
                            width: 108,
                            child: OutlinedButton(
                              onPressed: _endSession,
                              style: secondaryTransportStyle,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(Icons.stop_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  const Text('End'),
                                ],
                              ),
                            ),
                          ),
                      ] else ...<Widget>[
                        SizedBox(
                          height: 48,
                          width: 108,
                          child: FilledButton.icon(
                            style: primaryTransportStyle,
                            onPressed: _toggleRunning,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      if (!_running || isWarmup)
                        SizedBox(
                          height: 48,
                          width: 108,
                          child: OutlinedButton(
                            onPressed: canEndSession ? _endSession : null,
                            style: secondaryTransportStyle,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.stop_rounded, size: 18),
                                const SizedBox(width: 8),
                                const Text('End'),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildNotationBlock(
    BuildContext context, {
    required bool isWarmup,
    required String currentItemId,
    required List<PatternTokenV1> tokens,
    required List<PatternNoteMarkingV1> markings,
    required List<DrumVoiceV1> voices,
    required int? activeTokenIndex,
  }) {
    return Column(
      children: <Widget>[
        _PlayerNotation(
          setup: _setup,
          isWarmup: isWarmup,
          showVoices: widget.controller.hasNonSnareVoice(currentItemId),
          grouping: widget.controller.displayGroupingFor(currentItemId),
          tokens: tokens,
          markings: markings,
          voices: voices,
          activeTokenIndex: _patternHighlightEnabled ? activeTokenIndex : null,
        ),
        if (!isWarmup) ...<Widget>[
          const SizedBox(height: 10),
          _PatternAudioToggle(
            patternAudioEnabled: _patternAudioEnabled,
            onPatternAudioChanged: _updatePatternAudioEnabled,
          ),
        ],
      ],
    );
  }

  Future<void> _openSessionSettingsModal(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder:
              (
                BuildContext context,
                void Function(void Function()) sheetSetState,
              ) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: DrumPanel(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Text(
                              'Session Settings',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close),
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            Text(
                              'BPM',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Text(
                              '$_bpm',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                        Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: _bpm <= 30
                                  ? null
                                  : () {
                                      _updateBpm(_bpm - 1);
                                      sheetSetState(() {});
                                    },
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                            Expanded(
                              child: Slider(
                                value: _bpm.toDouble(),
                                min: 30,
                                max: 260,
                                divisions: 230,
                                label: '$_bpm BPM',
                                onChanged: (double value) {
                                  _updateBpm(value.round());
                                  sheetSetState(() {});
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: _bpm >= 260
                                  ? null
                                  : () {
                                      _updateBpm(_bpm + 1);
                                      sheetSetState(() {});
                                    },
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ],
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Click'),
                          value: _clickEnabled,
                          onChanged: (bool value) {
                            _updateClickEnabled(value);
                            sheetSetState(() {});
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pulse'),
                          value: _pulseEnabled,
                          onChanged: (bool value) {
                            _updatePulseEnabled(value);
                            sheetSetState(() {});
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Pattern Highlight'),
                          value: _patternHighlightEnabled,
                          onChanged: (bool value) {
                            _updatePatternHighlightEnabled(value);
                            sheetSetState(() {});
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
        );
      },
    );
  }

  void _toggleRunning() {
    final bool shouldStart = !_running;
    setState(() {
      if (shouldStart) {
        if (_summaryOpenedForCurrentRun) {
          _resetRunState(
            clearElapsed: true,
            clearFlags: true,
            clearPracticedItems: true,
          );
          _summaryOpenedForCurrentRun = false;
        }
        if (_isWarmup && _warmupComplete) {
          _elapsedOffset = Duration.zero;
          _stopwatch.reset();
          _currentItemIndex = 0;
          _warmupComplete = false;
          _completionChimed = false;
        }
        _running = true;
        _stopwatch.start();
        _markCurrentItemPracticed();
        _currentItemSegmentStartElapsed = _elapsed;
        _startElapsedTicker();
      } else {
        _accumulateCurrentItemActiveTime();
        _running = false;
        _stopwatch.stop();
        _elapsedTicker?.cancel();
        unawaited(_metronome.stop());
      }
    });
    widget.onFocusModeChanged?.call(shouldStart);
    if (shouldStart) {
      if (_shouldRunMetronome) {
        unawaited(
          _metronome.start(
            bpm: _bpm,
            clickEnabled: _clickEnabled,
            pulseEnabled: _pulseEnabled,
            pulseSchedule: _pulseScheduleForCurrentItem(),
          ),
        );
      }
    }
  }

  void _endSession() {
    if (!_canEndSession) return;
    _stopPatternPreviewClock(clearElapsed: true);
    unawaited(_patternAudio.stop());
    if (_isWarmup) {
      _resetRunState(clearElapsed: false);
      _discardEphemeralItemsIfNeeded();
      Navigator.of(context).pop();
      return;
    }

    if (_setup.endBehavior == PracticeSessionEndBehaviorV1.returnToPrevious) {
      _resetRunState(clearElapsed: false);
      _discardEphemeralItemsIfNeeded();
      Navigator.of(context).pop();
      return;
    }

    _resetRunState(clearElapsed: false);

    final PracticeSessionLogV1 session = widget.controller.completeSession(
      _setup.copyWith(clickEnabled: _clickEnabled),
      _elapsed,
      practicedItemIds: _practicedItemIds,
      activeDurationByItemId: _resolvedActiveDurationsForCompletedSession(),
      endingBpmByItemId: _itemBpmById,
      assessmentItemId: _practicedItemIds.isEmpty
          ? _currentItemId
          : _practicedItemIds.first,
    );
    if (session.earnedReps <= 0) {
      _discardEphemeralItemsIfNeeded();
      Navigator.of(context).pop();
      return;
    }
    _summaryOpenedForCurrentRun = true;
    unawaited(_openSessionSummary(session.id));
  }

  Future<void> _openSessionSummary(String sessionId) async {
    final PracticeSessionSetupV1? replaySetup = await Navigator.of(context)
        .push<PracticeSessionSetupV1>(
          MaterialPageRoute<PracticeSessionSetupV1>(
            builder: (_) => SessionSummaryScreen(
              controller: widget.controller,
              sessionId: sessionId,
            ),
          ),
        );
    if (!mounted || replaySetup == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(
          controller: widget.controller,
          setup: replaySetup,
          onFocusModeChanged: widget.onFocusModeChanged,
        ),
      ),
    );
  }

  void _discardEphemeralItemsIfNeeded() {
    if (_ephemeralItemsDiscarded) return;
    if (_setup.ephemeralItemIds.isEmpty) return;
    for (final String itemId in _setup.ephemeralItemIds) {
      widget.controller.discardUnsavedPracticeItem(itemId);
    }
    _ephemeralItemsDiscarded = true;
  }

  void _changeItem(int nextIndex) {
    if (_isWarmup) {
      final int itemCount = _setup.practiceItemIds.length;
      if (itemCount == 0) return;
      setState(() {
        _currentItemIndex = nextIndex.clamp(0, itemCount - 1);
      });
      return;
    }
    if (_running) {
      _accumulateCurrentItemActiveTime();
    }
    setState(() {
      _currentItemIndex = nextIndex;
      _bpm = _itemBpmById[_currentItemId] ?? _setup.bpm;
      if (_running) {
        _currentItemSegmentStartElapsed = _elapsed;
      }
    });
    if (_running && _shouldRunMetronome) {
      unawaited(
        _metronome.updateBpm(
          bpm: _bpm,
          pulseSchedule: _pulseScheduleForCurrentItem(),
        ),
      );
    }
    if (_patternAudioEnabled) {
      unawaited(_startPatternAudioForCurrentItem());
    }
  }

  void _resetRunState({
    bool clearElapsed = true,
    bool clearFlags = false,
    bool clearPracticedItems = false,
  }) {
    if (_running) {
      _accumulateCurrentItemActiveTime();
      _stopwatch.stop();
    }
    if (clearElapsed) {
      _elapsedOffset = Duration.zero;
      _stopwatch.reset();
      _lastWarmupAutoIndex = null;
      _currentItemSegmentStartElapsed = null;
    }
    _elapsedTicker?.cancel();
    unawaited(_metronome.stop());
    if (!_patternAudioEnabled) {
      _stopPatternPreviewClock(clearElapsed: true);
    }
    _running = false;
    if (clearFlags) {
      _warmupComplete = false;
      _completionChimed = false;
      _lastSinglePatternCompletedCycle = 0;
    }
    if (clearPracticedItems) {
      _practicedItemIds = <String>[];
      _itemActiveDurationById = <String, Duration>{};
    }
    widget.onFocusModeChanged?.call(false);
  }

  void _resetCurrentSessionRun() {
    if (_isWarmup) return;
    setState(() {
      _resetRunState(
        clearElapsed: true,
        clearFlags: true,
        clearPracticedItems: true,
      );
    });
  }

  Duration? _targetDuration() {
    if (_isWarmup) {
      return Duration(minutes: _setup.practiceItemIds.length);
    }
    if (_usesPerItemTargetTiming) {
      return timerPresetToDuration(
        widget.controller.launchTimerPresetForItem(_currentItemId),
      );
    }
    return timerPresetToDuration(_setup.timerPreset);
  }

  bool get _isWarmup => _setup.family == MaterialFamilyV1.warmup;

  bool get _showsEarnedReps =>
      !_isWarmup &&
      _setup.endBehavior == PracticeSessionEndBehaviorV1.openSummary;

  bool get _usesPerItemTargetTiming =>
      !_isWarmup && _setup.practiceItemIds.length > 1;

  String get _currentItemId => _setup.practiceItemIds[_currentItemIndex];

  Duration get _elapsed => _elapsedOffset + _stopwatch.elapsed;

  bool get _hasSessionData => _elapsed.inMilliseconds > 0;

  bool get _canEndSession => _hasSessionData && !_summaryOpenedForCurrentRun;

  int get _totalEarnedReps {
    return _setup.practiceItemIds.fold<int>(0, (int sum, String itemId) {
      return sum + (_activeDurationForItem(itemId).inSeconds ~/ 60);
    });
  }

  _SessionTransportState get _transportState {
    final Duration? target = _targetDuration();
    final Duration displayElapsed = _elapsed;
    final String timerText = target == null
        ? formatDuration(displayElapsed)
        : '${formatDuration(displayElapsed)} / ${formatDuration(target)}';
    final String? statusText = _warmupComplete ? 'Warmup complete' : null;
    return _SessionTransportState(
      elapsed: displayElapsed,
      target: target,
      timerText: timerText,
      statusText: statusText,
      completed: _warmupComplete,
    );
  }

  double _sessionProgressFraction(_SessionTransportState transport) {
    final Duration? target = transport.target;
    if (target == null || target.inMilliseconds <= 0) return 0.0;
    return (_cycleElapsedForTarget(target).inMilliseconds /
            target.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  Duration _cycleElapsedForTarget(Duration target) {
    if (_isWarmup) return _elapsed;
    if (_usesPerItemTargetTiming) {
      if (_currentItemSegmentStartElapsed == null) return Duration.zero;
      final Duration cycleElapsed = _elapsed - _currentItemSegmentStartElapsed!;
      return cycleElapsed.isNegative ? Duration.zero : cycleElapsed;
    }
    final int targetMs = target.inMilliseconds;
    if (targetMs <= 0) return _elapsed;
    final int cycleMs = _elapsed.inMilliseconds % targetMs;
    return Duration(milliseconds: cycleMs);
  }

  int? _activeTokenIndexForCurrentItem(List<PatternTokenV1> tokens) {
    if (_patternAudioEnabled) {
      return PracticeSessionRuntimeMath.activeTokenIndex(
        tokens: tokens,
        grouping: widget.controller.displayGroupingFor(_currentItemId),
        timing: widget.controller.patternTimingFor(_currentItemId),
        elapsed: _patternPreviewElapsed,
        bpm: _bpm,
      );
    }
    if (!_running && _elapsed == Duration.zero) return null;
    return PracticeSessionRuntimeMath.activeTokenIndex(
      tokens: tokens,
      grouping: widget.controller.displayGroupingFor(_currentItemId),
      timing: widget.controller.patternTimingFor(_currentItemId),
      elapsed: _tokenCycleElapsedForCurrentItem(),
      bpm: _bpm,
    );
  }

  Duration _tokenCycleElapsedForCurrentItem() {
    if (_isWarmup) {
      final Duration minuteOffset = Duration(minutes: _currentItemIndex);
      final Duration elapsedInCurrentMinute = _elapsed - minuteOffset;
      return elapsedInCurrentMinute.isNegative
          ? Duration.zero
          : elapsedInCurrentMinute;
    }
    if (_usesPerItemTargetTiming) {
      if (_currentItemSegmentStartElapsed == null) return Duration.zero;
      final Duration itemElapsed = _elapsed - _currentItemSegmentStartElapsed!;
      return itemElapsed.isNegative ? Duration.zero : itemElapsed;
    }
    return _elapsed;
  }

  Duration get _patternPreviewElapsed =>
      _patternPreviewBaseElapsed + _patternPreviewStopwatch.elapsed;

  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_running && !_isWarmup) {
        _markCurrentItemPracticed();
      }
      if (_isWarmup) {
        _syncWarmupProgress();
      } else {
        _syncPracticeTargetProgress();
      }
      if (mounted) setState(() {});
    });
  }

  void _syncWarmupProgress() {
    final int itemCount = _setup.practiceItemIds.length;
    if (itemCount == 0) return;

    final int elapsedSeconds = _elapsed.inSeconds;
    final int nextIndex = (elapsedSeconds ~/ 60).clamp(0, itemCount - 1);
    if (nextIndex != _lastWarmupAutoIndex && mounted) {
      setState(() {
        _currentItemIndex = nextIndex;
        _lastWarmupAutoIndex = nextIndex;
      });
    }

    final int totalSeconds = itemCount * 60;
    if (_running && elapsedSeconds >= totalSeconds) {
      _warmupComplete = true;
      _playCompletionChimeOnce();
      _resetRunState(clearElapsed: false);
    }
  }

  void _syncPracticeTargetProgress() {
    final Duration? target = _targetDuration();
    if (target == null) return;
    if (_usesPerItemTargetTiming) {
      final Duration cycleElapsed = _cycleElapsedForTarget(target);
      if (cycleElapsed < target) return;
      _playTargetReachedChime();
      final int nextIndex =
          (_currentItemIndex + 1) % _setup.practiceItemIds.length;
      _changeItem(nextIndex);
      return;
    }
    final int targetMs = target.inMilliseconds;
    if (targetMs <= 0) return;
    final int completedCycles = _elapsed.inMilliseconds ~/ targetMs;
    if (completedCycles > _lastSinglePatternCompletedCycle) {
      _lastSinglePatternCompletedCycle = completedCycles;
      _playTargetReachedChime();
    }
  }

  void _playTargetReachedChime() {
    unawaited(_metronome.playCompletionChime());
  }

  void _playCompletionChimeOnce() {
    if (_completionChimed) return;
    _completionChimed = true;
    unawaited(_metronome.playCompletionChime());
  }

  void _updateBpm(int bpm) {
    final int nextBpm = bpm.clamp(30, 260);
    setState(() {
      _bpm = nextBpm;
      _itemBpmById[_currentItemId] = nextBpm;
    });
    if (_running && _shouldRunMetronome) {
      unawaited(
        _metronome.updateBpm(
          bpm: nextBpm,
          pulseSchedule: _pulseScheduleForCurrentItem(),
        ),
      );
    }
    if (_patternAudioEnabled) {
      unawaited(_startPatternAudioForCurrentItem());
    }
  }

  void _updateClickEnabled(bool value) {
    setState(() {
      _clickEnabled = value;
    });
    if (!_running) return;
    if (!_shouldRunMetronome) {
      unawaited(_metronome.stop());
      return;
    }
    if (value) {
      unawaited(
        _metronome.start(
          bpm: _bpm,
          clickEnabled: true,
          pulseEnabled: _pulseEnabled,
          pulseSchedule: _pulseScheduleForCurrentItem(),
        ),
      );
    } else {
      unawaited(
        _metronome.start(
          bpm: _bpm,
          clickEnabled: false,
          pulseEnabled: _pulseEnabled,
          pulseSchedule: _pulseScheduleForCurrentItem(),
        ),
      );
    }
  }

  void _updatePulseEnabled(bool value) {
    setState(() {
      _pulseEnabled = value;
    });
    if (!_running) return;
    if (!_shouldRunMetronome) {
      unawaited(_metronome.stop());
      return;
    }
    unawaited(_metronome.setPulseEnabled(value));
  }

  void _updatePatternAudioEnabled(bool value) {
    setState(() {
      _patternAudioEnabled = value;
    });
    if (value) {
      unawaited(
        _restartPatternAudioPreview(
          startElapsed: _running
              ? _tokenCycleElapsedForCurrentItem()
              : Duration.zero,
        ),
      );
    } else {
      _stopPatternPreviewClock(clearElapsed: true);
      unawaited(_patternAudio.stop());
    }
  }

  void _updatePatternHighlightEnabled(bool value) {
    setState(() {
      _patternHighlightEnabled = value;
    });
  }

  Future<void> _configureAudio() async {
    await _metronome.prepare();
    await _patternAudio.prepare();
  }

  bool get _shouldRunMetronome => _clickEnabled || _pulseEnabled;

  PracticeMetronomePulseSchedule? _pulseScheduleForCurrentItem() {
    if (_isWarmup || _bpm <= 0) return null;
    final String itemId = _currentItemId;
    final PatternPlaybackPlanV1 plan = PatternPlaybackSchedulerV1.buildPlan(
      tokens: widget.controller.patternTokensFor(itemId),
      grouping: widget.controller.displayGroupingFor(itemId),
      timing: widget.controller.patternTimingFor(itemId),
    );
    if (plan.events.isEmpty || plan.totalBeatCount <= 0) return null;
    final double microsPerBeat = Duration.microsecondsPerMinute / _bpm;
    return PracticeMetronomePulseSchedule(
      pulseOffsets: plan.events
          .where((PatternPlaybackEventV1 event) => event.pulseStart)
          .map(
            (PatternPlaybackEventV1 event) => Duration(
              microseconds: (event.startBeat * microsPerBeat).round(),
            ),
          )
          .toList(growable: false),
      cycleDuration: Duration(
        microseconds: (plan.totalBeatCount * microsPerBeat).round(),
      ),
    );
  }

  Future<void> _startPatternAudioForCurrentItem() async {
    await _restartPatternAudioPreview(
      startElapsed: _running
          ? _tokenCycleElapsedForCurrentItem()
          : Duration.zero,
    );
  }

  Future<void> _restartPatternAudioPreview({
    required Duration startElapsed,
  }) async {
    final String itemId = _currentItemId;
    await _patternAudio.start(
      tokens: widget.controller.patternTokensFor(itemId),
      markings: widget.controller.noteMarkingsFor(itemId),
      voices: widget.controller.noteVoicesFor(itemId),
      grouping: widget.controller.displayGroupingFor(itemId),
      timing: widget.controller.patternTimingFor(itemId),
      bpm: _bpm,
      startElapsed: startElapsed,
    );
    if (!_patternAudioEnabled || !mounted) return;
    _startPatternPreviewClock(startElapsed);
  }

  void _startPatternPreviewClock(Duration startElapsed) {
    _patternPreviewTicker?.cancel();
    _patternPreviewBaseElapsed = startElapsed;
    _patternPreviewStopwatch
      ..reset()
      ..start();
    _patternPreviewTicker = Timer.periodic(const Duration(milliseconds: 50), (
      _,
    ) {
      if (!mounted || !_patternAudioEnabled) return;
      setState(() {});
    });
  }

  void _stopPatternPreviewClock({required bool clearElapsed}) {
    _patternPreviewTicker?.cancel();
    _patternPreviewTicker = null;
    _patternPreviewStopwatch.stop();
    if (clearElapsed) {
      _patternPreviewBaseElapsed = Duration.zero;
      _patternPreviewStopwatch.reset();
    }
  }

  void _markCurrentItemPracticed() {
    if (_isWarmup) return;
    final String itemId = _currentItemId;
    if (_practicedItemIds.contains(itemId)) return;
    _practicedItemIds = <String>[..._practicedItemIds, itemId];
  }

  Duration _activeDurationForItem(String itemId) {
    Duration total = _itemActiveDurationById[itemId] ?? Duration.zero;
    if (_running &&
        itemId == _currentItemId &&
        _currentItemSegmentStartElapsed != null) {
      final Duration liveDelta = _elapsed - _currentItemSegmentStartElapsed!;
      if (!liveDelta.isNegative) {
        total += liveDelta;
      }
    }
    return total;
  }

  void _accumulateCurrentItemActiveTime() {
    if (_isWarmup || !_running || _currentItemSegmentStartElapsed == null) {
      return;
    }
    final Duration liveDelta = _elapsed - _currentItemSegmentStartElapsed!;
    if (liveDelta.isNegative || liveDelta == Duration.zero) {
      _currentItemSegmentStartElapsed = _elapsed;
      return;
    }
    final String itemId = _currentItemId;
    _itemActiveDurationById = <String, Duration>{
      ..._itemActiveDurationById,
      itemId: (_itemActiveDurationById[itemId] ?? Duration.zero) + liveDelta,
    };
    _currentItemSegmentStartElapsed = _elapsed;
  }

  Map<String, Duration> _resolvedActiveDurationsForCompletedSession() {
    final Map<String, Duration> durations = <String, Duration>{
      ..._itemActiveDurationById,
    };
    if (_running && !_isWarmup && _currentItemSegmentStartElapsed != null) {
      final Duration liveDelta = _elapsed - _currentItemSegmentStartElapsed!;
      if (!liveDelta.isNegative && liveDelta > Duration.zero) {
        durations[_currentItemId] =
            (durations[_currentItemId] ?? Duration.zero) + liveDelta;
      }
    }
    return durations;
  }
}

class _BeatPulse extends StatefulWidget {
  final ValueListenable<bool> pulseActiveListenable;
  final int bpm;
  final bool enabled;
  final double progress;
  final Duration? target;
  final double size;

  const _BeatPulse({
    required this.pulseActiveListenable,
    required this.bpm,
    required this.enabled,
    required this.progress,
    required this.target,
    required this.size,
  });

  @override
  State<_BeatPulse> createState() => _BeatPulseState();
}

class _EarnedRepsDisplay extends StatelessWidget {
  final int reps;

  const _EarnedRepsDisplay({required this.reps});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DrumcabularyTheme.pulsePrimary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: DrumcabularyTheme.pulseHover, width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.add_circle_rounded,
              size: 18,
              color: DrumcabularyTheme.creamText,
            ),
            const SizedBox(width: 8),
            Text(
              '$reps Reps Earned',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: DrumcabularyTheme.creamText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeatPulseState extends State<_BeatPulse> {
  bool _flashActive = false;

  @override
  void initState() {
    super.initState();
    _flashActive = widget.pulseActiveListenable.value;
    widget.pulseActiveListenable.addListener(_handlePulseStateChanged);
  }

  @override
  void didUpdateWidget(covariant _BeatPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulseActiveListenable != widget.pulseActiveListenable) {
      oldWidget.pulseActiveListenable.removeListener(_handlePulseStateChanged);
      _flashActive = widget.pulseActiveListenable.value;
      widget.pulseActiveListenable.addListener(_handlePulseStateChanged);
    }
    if (!widget.enabled && _flashActive) {
      _flashActive = false;
    }
  }

  @override
  void dispose() {
    widget.pulseActiveListenable.removeListener(_handlePulseStateChanged);
    super.dispose();
  }

  void _handlePulseStateChanged() {
    if (!mounted) return;
    final bool nextValue = widget.enabled && widget.pulseActiveListenable.value;
    if (_flashActive == nextValue) return;
    setState(() {
      _flashActive = nextValue;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && _flashActive;
    const Color ringBase = DrumcabularyTheme.tickNeutral;
    final double gaugeDiameter = widget.size;
    final double tickDiameter = gaugeDiameter - 8;
    final double pulseDiameter = gaugeDiameter - 74;
    final double bpmCoreDiameter = gaugeDiameter - 102;
    return AnimatedContainer(
      duration: _PracticeSessionScreenState._focusTransitionDuration,
      curve: Curves.easeInOut,
      width: gaugeDiameter,
      height: gaugeDiameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (widget.enabled)
            SizedBox(
              width: tickDiameter,
              height: tickDiameter,
              child: CustomPaint(
                painter: _TickRingPainter(
                  progress: widget.progress,
                  target: widget.target,
                ),
              ),
            ),
          if (widget.enabled)
            _PulseGaugeRing(
              diameter: pulseDiameter,
              color: active ? DrumcabularyTheme.pulsePrimary : DrumcabularyTheme.tickNeutral,
              width: active ? 5.5 : 4.0,
            ),
          Container(
            width: bpmCoreDiameter,
            height: bpmCoreDiameter,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? DrumcabularyTheme.appBackground
                  : DrumcabularyTheme.appBackground,
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? DrumcabularyTheme.pulsePrimary.withValues(alpha: 0.86)
                    : ringBase.withValues(alpha: 0.5),
                width: active ? 1.9 : 1.1,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${widget.bpm}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: DrumcabularyTheme.creamText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    widget.enabled ? 'BPM' : 'PULSE OFF',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: DrumcabularyTheme.creamText,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TickRingPainter extends CustomPainter {
  final double progress;
  final Duration? target;

  const _TickRingPainter({required this.progress, required this.target});

  static const double _sweep = math.pi * 1.70;
  static const double _startAngle = math.pi * 0.64;
  static const double _majorTickWidth = 6.6;
  static const double _minorTickWidth = 5.8;
  static const double _majorTickLength = 21.7;
  static const double _minorTickLength = 13.3;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2 - 6;
    final double progressClamped = progress.clamp(0.0, 1.0);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;

    final int majorTickCount = _majorTickCount();
    final int tickIntervals = _tickIntervalsForRadius(radius);
    final Set<int> majorTickIndices = _majorTickIndices(
      majorTickCount,
      tickIntervals,
    );
    final int totalTickCount = tickIntervals + 1;

    for (int index = 0; index < totalTickCount; index++) {
      final bool majorTick = majorTickIndices.contains(index);
      final double tickT = totalTickCount == 1
          ? 1.0
          : index / (totalTickCount - 1);
      final double angle = _startAngle + (tickT * _sweep);
      final bool completed = progressClamped >= 1.0
          ? true
          : index == 0
          ? progressClamped > 0
          : tickT <= progressClamped;
      final Color tickColor = majorTick
          ? _majorTickColor(completed)
          : (completed ? _progressColor(tickT) : _inactiveColor());
      final double tickLength = majorTick ? _majorTickLength : _minorTickLength;
      paint
        ..color = tickColor
        ..strokeWidth = majorTick ? _majorTickWidth : _minorTickWidth;

      final Offset outer = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      final Offset inner = Offset(
        center.dx + math.cos(angle) * (radius - tickLength),
        center.dy + math.sin(angle) * (radius - tickLength),
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TickRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.target != target;
  }

  Color _inactiveColor() {
    return const Color(0x47636E62);
  }

  Color _progressColor(double t) {
    return DrumcabularyTheme.progressPrimary;
  }

  Color _majorTickColor(bool completed) {
    return completed ? DrumcabularyTheme.creamText : DrumcabularyTheme.creamText.withValues(alpha: 0.7);
  }

  int _majorTickCount() {
    final int? minutes = target?.inMinutes;
    if (minutes == null || minutes <= 0) return 10;
    return minutes.clamp(2, 20);
  }

  int _tickIntervalsForRadius(double radius) {
    final double sweepLength = radius * _sweep;
    final double tickPitch = _minorTickWidth * 2;
    return (sweepLength / tickPitch).round().clamp(24, 200);
  }

  Set<int> _majorTickIndices(int majorTickCount, int tickIntervals) {
    final Set<int> indices = <int>{};
    for (int step = 0; step <= majorTickCount; step++) {
      indices.add((step * tickIntervals / majorTickCount).round());
    }
    return indices;
  }
}

class _PulseGaugeRing extends StatelessWidget {
  final double diameter;
  final Color color;
  final double width;

  const _PulseGaugeRing({
    required this.diameter,
    required this.color,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: width),
          ),
        ),
      ),
    );
  }
}

class _PlayerNotation extends StatelessWidget {
  final PracticeSessionSetupV1 setup;
  final bool isWarmup;
  final bool showVoices;
  final PatternGroupingV1 grouping;
  final List<PatternTokenV1> tokens;
  final List<PatternNoteMarkingV1> markings;
  final List<DrumVoiceV1> voices;
  final int? activeTokenIndex;

  const _PlayerNotation({
    required this.setup,
    required this.isWarmup,
    required this.showVoices,
    required this.grouping,
    required this.tokens,
    required this.markings,
    required this.voices,
    required this.activeTokenIndex,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = switch (tokens.length) {
      >= 24 => 20,
      >= 16 => 25,
      >= 12 => 28,
      _ => 31,
    };
    final TextStyle patternStyle =
        Theme.of(context).textTheme.displaySmall?.copyWith(
          color: DrumcabularyTheme.creamText,
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.1,
          fontFamily: 'Courier',
          height: 1.0,
        ) ??
        const TextStyle(
          color: DrumcabularyTheme.creamText,
          fontWeight: FontWeight.w900,
          fontSize: 31,
          letterSpacing: 0.1,
          fontFamily: 'Courier',
          height: 1.0,
        );

    final TextStyle voiceStyle =
        Theme.of(context).textTheme.titleMedium?.copyWith(
          color: DrumcabularyTheme.line,
          fontWeight: FontWeight.w800,
          fontFamily: 'Courier',
        ) ??
        const TextStyle(
          color: DrumcabularyTheme.line,
          fontWeight: FontWeight.w800,
          fontSize: 16,
          fontFamily: 'Courier',
        );

    return SizedBox(
      width: double.infinity,
      child: Center(
        child: PatternVoiceDisplay(
          tokens: tokens,
          markings: markings,
          voices: voices,
          grouping: grouping,
          showRepeatIndicator: false,
          scrollable: false,
          showPatternRow: true,
          showVoiceRow: showVoices,
          wrap: true,
          cellWidth: tokens.length >= 24 ? 34 : (isWarmup ? 44 : 42),
          patternStyle: patternStyle,
          voiceStyle: voiceStyle,
          activeIndex: activeTokenIndex,
        ),
      ),
    );
  }
}

class _PatternAudioToggle extends StatelessWidget {
  final bool patternAudioEnabled;
  final ValueChanged<bool> onPatternAudioChanged;

  const _PatternAudioToggle({
    required this.patternAudioEnabled,
    required this.onPatternAudioChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _PatternToggleButton(
      value: patternAudioEnabled,
      tooltip: patternAudioEnabled
          ? 'Turn pattern audio off'
          : 'Turn pattern audio on',
      onPressed: () => onPatternAudioChanged(!patternAudioEnabled),
      icon: _EarToggleIcon(
        color: patternAudioEnabled
            ? DrumcabularyTheme.ink
            : DrumcabularyTheme.creamText,
      ),
    );
  }
}

class _PatternToggleButton extends StatelessWidget {
  final bool value;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget icon;

  const _PatternToggleButton({
    required this.value,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = value
        ? IconButton.styleFrom(
            backgroundColor: DrumcabularyTheme.creamText,
            foregroundColor: DrumcabularyTheme.ink,
            fixedSize: const Size(46, 46),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          )
        : IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: DrumcabularyTheme.creamText,
            fixedSize: const Size(46, 46),
            side: const BorderSide(color: DrumcabularyTheme.creamText),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          );
    return Tooltip(
      message: tooltip,
      child: IconButton(onPressed: onPressed, style: style, icon: icon),
    );
  }
}

class _EarToggleIcon extends StatelessWidget {
  final Color color;

  const _EarToggleIcon({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 24),
      painter: _EarToggleIconPainter(color),
    );
  }
}

class _EarToggleIconPainter extends CustomPainter {
  final Color color;

  const _EarToggleIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Path outer = Path()
      ..moveTo(size.width * 0.25, size.height * 0.42)
      ..cubicTo(
        size.width * 0.25,
        size.height * 0.14,
        size.width * 0.53,
        size.height * 0.05,
        size.width * 0.72,
        size.height * 0.15,
      )
      ..cubicTo(
        size.width * 0.92,
        size.height * 0.26,
        size.width * 0.95,
        size.height * 0.55,
        size.width * 0.81,
        size.height * 0.68,
      )
      ..cubicTo(
        size.width * 0.73,
        size.height * 0.75,
        size.width * 0.66,
        size.height * 0.79,
        size.width * 0.62,
        size.height * 0.90,
      )
      ..cubicTo(
        size.width * 0.58,
        size.height * 0.99,
        size.width * 0.43,
        size.height * 0.98,
        size.width * 0.36,
        size.height * 0.89,
      );
    canvas.drawPath(outer, stroke);

    final Path inner = Path()
      ..moveTo(size.width * 0.42, size.height * 0.43)
      ..cubicTo(
        size.width * 0.42,
        size.height * 0.31,
        size.width * 0.53,
        size.height * 0.24,
        size.width * 0.62,
        size.height * 0.29,
      )
      ..cubicTo(
        size.width * 0.69,
        size.height * 0.33,
        size.width * 0.71,
        size.height * 0.42,
        size.width * 0.66,
        size.height * 0.50,
      );
    canvas.drawPath(inner, stroke);
  }

  @override
  bool shouldRepaint(covariant _EarToggleIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _SessionStepper extends StatelessWidget {
  final int currentIndex;
  final int itemCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool dark;

  const _SessionStepper({
    required this.currentIndex,
    required this.itemCount,
    required this.onPrevious,
    required this.onNext,
    required this.dark,
  });

  @override
  Widget build(BuildContext context) {
    final Color textColor = dark
        ? DrumcabularyTheme.creamText
        : DrumcabularyTheme.ink;
    final Color mutedColor = dark
        ? const Color(0xCCFFF4DE)
        : DrumcabularyTheme.textSecondary;

    return Row(
      children: <Widget>[
        IconButton(
          onPressed: onPrevious,
          color: textColor,
          disabledColor: mutedColor.withValues(alpha: 0.35),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Center(
            child: Text(
              '${currentIndex + 1} / $itemCount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          color: textColor,
          disabledColor: mutedColor.withValues(alpha: 0.35),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}
