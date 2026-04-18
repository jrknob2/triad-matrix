import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/app/app_formatters.dart';
import '../../features/app/app_viewport.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../../core/practice/practice_domain_v1.dart';
import 'metronome_service.dart';
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

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  static const String _metronomeAssetPath = 'assets/audio/metronome_beep.wav';
  static const Duration _focusTransitionDuration = Duration(milliseconds: 320);

  final Stopwatch _stopwatch = Stopwatch();
  late final PracticeMetronomeService _metronome;
  Timer? _elapsedTicker;
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
  late PracticeSessionSetupV1 _setup;
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
    _clickEnabled = _setup.family == MaterialFamilyV1.warmup
        ? false
        : _setup.clickEnabled;
    _pulseEnabled = _setup.family != MaterialFamilyV1.warmup;
    _metronome = PracticeMetronomeService(assetPath: _metronomeAssetPath);
    _configureMetronome();
  }

  @override
  void dispose() {
    widget.onFocusModeChanged?.call(false);
    _discardEphemeralItemsIfNeeded();
    _elapsedTicker?.cancel();
    unawaited(_metronome.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = AppViewport.isTablet(context);
    final bool isWarmup = _isWarmup;
    final bool focusMode = _running;
    final String currentItemId = _currentItemId;
    final List<String> tokens = widget.controller.noteTokensFor(currentItemId);
    final List<PatternNoteMarkingV1> markings = widget.controller
        .noteMarkingsFor(currentItemId);
    final List<DrumVoiceV1> voices = widget.controller.noteVoicesFor(
      currentItemId,
    );
    final _SessionTransportState transport = _transportState;

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
                  child: isTablet
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              flex: 5,
                              child: _buildPlayerPanel(
                                context,
                                isWarmup: isWarmup,
                                currentItemId: currentItemId,
                                markings: markings,
                                tokens: tokens,
                                transport: transport,
                                voices: voices,
                                focusMode: focusMode,
                                availableWidth:
                                    MediaQuery.sizeOf(context).width * 0.52,
                              ),
                            ),
                            AnimatedContainer(
                              duration: _focusTransitionDuration,
                              curve: Curves.easeInOut,
                              width: AppViewport.splitPaneGap,
                            ),
                            SizedBox(
                              width: 360,
                              child: _buildSessionControlsPanel(context),
                            ),
                          ],
                        )
                      : LayoutBuilder(
                          builder:
                              (
                                BuildContext context,
                                BoxConstraints constraints,
                              ) {
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
                                    ),
                                    const SizedBox(height: 16),
                                    _buildSessionControlsPanel(context),
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
                const SizedBox(width: 48),
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
    required List<String> tokens,
    required _SessionTransportState transport,
    required List<DrumVoiceV1> voices,
    required bool focusMode,
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
          return const Color(0xB3FFF4DE);
        }
        return const Color(0xFFFFF4DE);
      }),
      side: WidgetStateProperty.resolveWith<BorderSide>((states) {
        if (states.contains(WidgetState.disabled)) {
          return const BorderSide(color: Color(0x66FFF4DE));
        }
        return const BorderSide(color: Color(0xFFFFF4DE));
      }),
    );
    final ButtonStyle primaryTransportStyle = FilledButton.styleFrom(
      minimumSize: const Size(116, 48),
      maximumSize: const Size(116, 48),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      backgroundColor: const Color(0xFFFFF4DE),
      foregroundColor: const Color(0xFF211B14),
      side: const BorderSide(color: Color(0xFFFFF4DE)),
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
                            _PlayerNotation(
                              setup: _setup,
                              isWarmup: isWarmup,
                              grouping: widget.controller.displayGroupingFor(
                                currentItemId,
                              ),
                              tokens: tokens,
                              markings: markings,
                              voices: voices,
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
                                    color: const Color(0xFFFFF4DE),
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
                                      color: const Color(0xFFFFC08D),
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
                  _PlayerNotation(
                    setup: _setup,
                    isWarmup: isWarmup,
                    grouping: widget.controller.displayGroupingFor(
                      currentItemId,
                    ),
                    tokens: tokens,
                    markings: markings,
                    voices: voices,
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
                      color: const Color(0xFFFFF4DE),
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
                        color: const Color(0xFFFFC08D),
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

  Widget _buildSessionControlsPanel(BuildContext context) {
    return DrumPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Text('BPM', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text(
                '$_bpm',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              IconButton(
                onPressed: _bpm <= 30 ? null : () => _updateBpm(_bpm - 1),
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
                  },
                ),
              ),
              IconButton(
                onPressed: _bpm >= 260 ? null : () => _updateBpm(_bpm + 1),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Click'),
            value: _clickEnabled,
            onChanged: _updateClickEnabled,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Pulse'),
            value: _pulseEnabled,
            onChanged: _updatePulseEnabled,
          ),
        ],
      ),
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
        if (_setup.family == MaterialFamilyV1.warmup && _warmupComplete) {
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
          ),
        );
      }
    }
  }

  void _endSession() {
    if (!_canEndSession) return;
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
    if (_setup.family == MaterialFamilyV1.warmup) {
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
      unawaited(_metronome.updateBpm(bpm: _bpm));
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

  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_running && !_isWarmup) {
        _markCurrentItemPracticed();
      }
      if (_setup.family == MaterialFamilyV1.warmup) {
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
      unawaited(_metronome.updateBpm(bpm: nextBpm));
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
        ),
      );
    } else {
      unawaited(
        _metronome.start(
          bpm: _bpm,
          clickEnabled: false,
          pulseEnabled: _pulseEnabled,
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

  Future<void> _configureMetronome() async {
    await _metronome.prepare();
  }

  bool get _shouldRunMetronome => _clickEnabled || _pulseEnabled;

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
        color: const Color(0xFFF05A28),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFF7B788), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.add_circle_rounded,
              size: 18,
              color: Color(0xFFFFF4DE),
            ),
            const SizedBox(width: 8),
            Text(
              '$reps Reps Earned',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: const Color(0xFFFFF4DE),
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
    const Color ringBase = Color(0xFF4A4337);
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
              color: active ? const Color(0xFFF05A28) : const Color(0xFF5A4A39),
              width: active ? 5.5 : 4.0,
            ),
          Container(
            width: bpmCoreDiameter,
            height: bpmCoreDiameter,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? const Color(0xFF1F1A14)
                  : const Color(0xFF14100C),
              shape: BoxShape.circle,
              border: Border.all(
                color: active
                    ? const Color(0xFFF05A28).withValues(alpha: 0.86)
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
                      color: const Color(0xFFFFF4DE),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    widget.enabled ? 'BPM' : 'PULSE OFF',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: const Color(0xFFFFF4DE),
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

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = math.min(size.width, size.height) / 2 - 6;
    final double progressClamped = progress.clamp(0.0, 1.0);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final int majorTickCount = _majorTickCount();
    final int minorTicksPerMajor = _minorTicksPerMajor(majorTickCount);
    final int totalTickCount = (majorTickCount * minorTicksPerMajor) + 1;

    for (int index = 0; index < totalTickCount; index++) {
      final bool majorTick = index % minorTicksPerMajor == 0;
      final double tickT = totalTickCount == 1
          ? 1.0
          : index / (totalTickCount - 1);
      final double angle = _startAngle + (tickT * _sweep);
      final bool completed = progressClamped >= 1.0
          ? true
          : index == 0
          ? progressClamped > 0
          : tickT <= progressClamped;
      final Color tickColor = completed
          ? _progressColor(tickT)
          : _inactiveColor();
      final double tickLength = majorTick ? 13 : 8;
      paint
        ..color = tickColor
        ..strokeWidth = majorTick ? 6.6 : 5.8;

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
    return const Color(0xFFA1D46E);
  }

  int _majorTickCount() {
    final int? minutes = target?.inMinutes;
    if (minutes == null || minutes <= 0) return 10;
    return minutes.clamp(2, 20);
  }

  int _minorTicksPerMajor(int majorTickCount) {
    const int minimumVisibleTickCount = 25;
    final int densityFromTarget =
        ((minimumVisibleTickCount - 1) / majorTickCount).ceil();
    return densityFromTarget.clamp(6, 12);
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
  final PatternGroupingV1 grouping;
  final List<String> tokens;
  final List<PatternNoteMarkingV1> markings;
  final List<DrumVoiceV1> voices;

  const _PlayerNotation({
    required this.setup,
    required this.isWarmup,
    required this.grouping,
    required this.tokens,
    required this.markings,
    required this.voices,
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
          color: const Color(0xFFFFF4DE),
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.1,
          fontFamily: 'Courier',
          height: 1.0,
        ) ??
        const TextStyle(
          color: Color(0xFFFFF4DE),
          fontWeight: FontWeight.w900,
          fontSize: 31,
          letterSpacing: 0.1,
          fontFamily: 'Courier',
          height: 1.0,
        );

    final TextStyle voiceStyle =
        Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFFE5D5BB),
          fontWeight: FontWeight.w800,
          fontFamily: 'Courier',
        ) ??
        const TextStyle(
          color: Color(0xFFE5D5BB),
          fontWeight: FontWeight.w800,
          fontSize: 16,
          fontFamily: 'Courier',
        );

    return SizedBox(
      width: double.infinity,
      child: Center(
        child: setup.practiceMode == PracticeModeV1.flow
            ? PatternVoiceDisplay(
                tokens: tokens,
                markings: markings,
                voices: voices,
                grouping: grouping,
                showRepeatIndicator: false,
                scrollable: false,
                wrap: true,
                cellWidth: tokens.length >= 24 ? 34 : (isWarmup ? 44 : 42),
                patternStyle: patternStyle,
                voiceStyle: voiceStyle,
              )
            : PatternVoiceDisplay(
                tokens: tokens,
                markings: markings,
                voices: List<DrumVoiceV1>.filled(
                  tokens.length,
                  DrumVoiceV1.snare,
                  growable: false,
                ),
                grouping: grouping,
                showRepeatIndicator: false,
                scrollable: false,
                showPatternRow: true,
                showVoiceRow: false,
                wrap: true,
                cellWidth: tokens.length >= 24 ? 34 : (isWarmup ? 44 : 42),
                patternStyle: patternStyle,
                voiceStyle: voiceStyle,
              ),
      ),
    );
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
        ? const Color(0xFFFFF4DE)
        : const Color(0xFF211B14);
    final Color mutedColor = dark
        ? const Color(0xCCFFF4DE)
        : const Color(0xFF5B5345);

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
