import 'dart:async';

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

  const PracticeSessionScreen({
    super.key,
    required this.controller,
    required this.setup,
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

  final Stopwatch _stopwatch = Stopwatch();
  late final PracticeMetronomeService _metronome;
  Timer? _elapsedTicker;
  bool _running = false;
  bool _targetReached = false;
  bool _warmupComplete = false;
  bool _completionChimed = false;
  bool _completionStateVisible = false;
  bool _summaryOpenedForCurrentRun = false;
  bool _ephemeralItemsDiscarded = false;
  Duration _elapsedOffset = Duration.zero;
  int? _lastWarmupAutoIndex;
  late Map<String, int> _itemBpmById;
  late List<String> _practicedItemIds;
  late bool _pulseEnabled;
  late int _bpm;
  late bool _clickEnabled;
  late PracticeSessionSetupV1 _setup;
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _setup = widget.setup;
    _itemBpmById = Map<String, int>.from(_setup.itemBpmById);
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
    _discardEphemeralItemsIfNeeded();
    _elapsedTicker?.cancel();
    unawaited(_metronome.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = AppViewport.isTablet(context);
    final bool isWarmup = _isWarmup;
    final String currentItemId = _currentItemId;
    final List<String> tokens = widget.controller.noteTokensFor(currentItemId);
    final List<PatternNoteMarkingV1> markings = widget.controller
        .noteMarkingsFor(currentItemId);
    final List<DrumVoiceV1> voices = widget.controller.noteVoicesFor(
      currentItemId,
    );
    final _SessionTransportState transport = _transportState;

    return Scaffold(
      appBar: AppBar(
        title: Text(isWarmup ? 'Warmup Session' : 'Practice Session'),
      ),
      body: DrumScreen(
        warm: false,
        child: isTablet
            ? Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
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
                      ),
                    ),
                    const SizedBox(width: AppViewport.splitPaneGap),
                    SizedBox(
                      width: 360,
                      child: _buildSessionControlsPanel(context),
                    ),
                  ],
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  _buildPlayerPanel(
                    context,
                    isWarmup: isWarmup,
                    currentItemId: currentItemId,
                    markings: markings,
                    tokens: tokens,
                    transport: transport,
                    voices: voices,
                  ),
                  const SizedBox(height: 16),
                  _buildSessionControlsPanel(context),
                ],
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
  }) {
    final bool canEndSession = _canEndSession;
    final ButtonStyle secondaryTransportStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(116, 48)),
      maximumSize: const WidgetStatePropertyAll<Size>(Size(116, 48)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
    );
    return DrumPanel(
      tone: DrumPanelTone.dark,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: <Widget>[
          if (_setup.practiceItemIds.length > 1) ...<Widget>[
            _SessionStepper(
              currentIndex: _currentItemIndex,
              itemCount: _setup.practiceItemIds.length,
              onPrevious: _currentItemIndex == 0
                  ? null
                  : () => _changeItem(_currentItemIndex - 1),
              onNext: _currentItemIndex == _setup.practiceItemIds.length - 1
                  ? null
                  : () => _changeItem(_currentItemIndex + 1),
              dark: true,
            ),
            const SizedBox(height: 16),
          ],
          _PlayerNotation(
            setup: _setup,
            isWarmup: isWarmup,
            grouping: widget.controller.displayGroupingFor(currentItemId),
            tokens: tokens,
            markings: markings,
            voices: voices,
          ),
          const SizedBox(height: 18),
          _BeatPulse(
            pulseActiveListenable: _metronome.pulseActive,
            bpm: _bpm,
            enabled: _pulseEnabled,
          ),
          const SizedBox(height: 18),
          Text(
            transport.timerText,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontFamily: 'Courier',
              color: _warmupComplete || _targetReached
                  ? const Color(0xFFFFC08D)
                  : const Color(0xFFFFF4DE),
              fontWeight: FontWeight.w900,
            ),
          ),
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
              SizedBox(
                height: 48,
                width: 108,
                child: FilledButton.icon(
                  style: primaryTransportStyle,
                  onPressed: _toggleRunning,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pause' : 'Play'),
                ),
              ),
              const SizedBox(width: 10),
              if (!isWarmup && _running) ...<Widget>[
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
                const SizedBox(width: 10),
              ],
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
    );
  }

  Widget _buildSessionControlsPanel(BuildContext context) {
    return DrumPanel(
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
          _targetReached = false;
          _completionChimed = false;
          _completionStateVisible = false;
        }
        _completionStateVisible = false;
        _running = true;
        _stopwatch.start();
        _markCurrentItemPracticed();
        _startElapsedTicker();
      } else {
        _running = false;
        _stopwatch.stop();
        _elapsedTicker?.cancel();
        unawaited(_metronome.stop());
      }
    });
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
      endingBpmByItemId: _itemBpmById,
      assessmentItemId: _practicedItemIds.isEmpty
          ? _currentItemId
          : _practicedItemIds.first,
    );
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
    setState(() {
      _currentItemIndex = nextIndex;
      _bpm = _itemBpmById[_currentItemId] ?? _setup.bpm;
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
      _stopwatch.stop();
    }
    if (clearElapsed) {
      _elapsedOffset = Duration.zero;
      _stopwatch.reset();
      _lastWarmupAutoIndex = null;
    }
    _elapsedTicker?.cancel();
    unawaited(_metronome.stop());
    _running = false;
    if (clearFlags) {
      _targetReached = false;
      _warmupComplete = false;
      _completionChimed = false;
      _completionStateVisible = false;
    }
    if (clearPracticedItems) {
      _practicedItemIds = <String>[];
    }
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
    return timerPresetToDuration(_setup.timerPreset);
  }

  bool get _isWarmup => _setup.family == MaterialFamilyV1.warmup;

  String get _currentItemId => _setup.practiceItemIds[_currentItemIndex];

  Duration get _elapsed => _elapsedOffset + _stopwatch.elapsed;

  bool get _hasSessionData => _elapsed.inMilliseconds > 0;

  bool get _canEndSession => _hasSessionData && !_summaryOpenedForCurrentRun;

  _SessionTransportState get _transportState {
    final Duration? target = _targetDuration();
    final String timerText = target == null
        ? formatDuration(_elapsed)
        : '${formatDuration(_elapsed)} / ${formatDuration(target)}';
    final String? statusText = _warmupComplete
        ? 'Warmup complete'
        : (_completionStateVisible ? 'Target reached' : null);
    return _SessionTransportState(
      elapsed: _elapsed,
      target: target,
      timerText: timerText,
      statusText: statusText,
      completed: _completionStateVisible || _warmupComplete,
    );
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
      _targetReached = true;
      _playCompletionChimeOnce();
      _resetRunState(clearElapsed: false);
    }
  }

  void _syncPracticeTargetProgress() {
    final Duration? target = _targetDuration();
    if (target == null) return;
    if (_elapsed >= target) {
      if (!_targetReached) {
        _targetReached = true;
        _completionStateVisible = true;
        _playCompletionChimeOnce();
      }
    }
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
      unawaited(_metronome.setClickEnabled(false));
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
}

class _BeatPulse extends StatefulWidget {
  final ValueListenable<bool> pulseActiveListenable;
  final int bpm;
  final bool enabled;

  const _BeatPulse({
    required this.pulseActiveListenable,
    required this.bpm,
    required this.enabled,
  });

  @override
  State<_BeatPulse> createState() => _BeatPulseState();
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
    const Color ringAccent = Color(0xFFFFC08D);
    return SizedBox(
      width: 170,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (widget.enabled)
            _PulseRing(
              diameter: 150,
              color: active
                  ? ringAccent.withValues(alpha: 0.20)
                  : ringBase.withValues(alpha: 0.18),
              width: 1.5,
            ),
          if (widget.enabled)
            _PulseRing(
              diameter: 136,
              color: active
                  ? ringAccent.withValues(alpha: 0.32)
                  : ringBase.withValues(alpha: 0.24),
              width: 1.8,
            ),
          if (widget.enabled)
            _PulseRing(
              diameter: 122,
              color: active
                  ? ringAccent.withValues(alpha: 0.46)
                  : ringBase.withValues(alpha: 0.30),
              width: 2.0,
            ),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              color: widget.enabled
                  ? const Color(0xFF1F1A14)
                  : const Color(0xFF14100C),
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? ringAccent : ringBase,
                width: active ? 4 : 3,
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

class _PulseRing extends StatelessWidget {
  final double diameter;
  final Color color;
  final double width;

  const _PulseRing({
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
                showRepeatIndicator: true,
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
                showRepeatIndicator: true,
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
