import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/app/app_formatters.dart';
import '../../features/app/app_viewport.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../../core/practice/practice_domain_v1.dart';
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

class _PracticeSessionScreenState extends State<PracticeSessionScreen>
    with TickerProviderStateMixin {
  final Stopwatch _stopwatch = Stopwatch();
  final Stopwatch _beatClock = Stopwatch();
  final AudioPlayer _clickPlayer = AudioPlayer();
  final ValueNotifier<int> _beatPulseToken = ValueNotifier<int>(0);
  Timer? _elapsedTicker;
  late final Ticker _beatFrameTicker;
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
  int _lastBeatIndex = -1;

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
    _beatFrameTicker = createTicker(_onBeatFrame);
    _configureAudio();
  }

  @override
  void dispose() {
    _discardEphemeralItemsIfNeeded();
    _elapsedTicker?.cancel();
    _beatFrameTicker.dispose();
    _beatPulseToken.dispose();
    _clickPlayer.dispose();
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
            beatTokenListenable: _beatPulseToken,
            bpm: _bpm,
            enabled: _pulseEnabled,
            vsync: this,
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
            onChanged: (bool value) {
              setState(() {
                _pulseEnabled = value;
              });
            },
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
        _beatClock.stop();
        _elapsedTicker?.cancel();
        _beatFrameTicker.stop();
      }
    });
    if (shouldStart) {
      _restartBeatTicker();
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

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SessionSummaryScreen(
          controller: widget.controller,
          sessionId: session.id,
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
    _restartBeatTicker();
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
    _beatFrameTicker.stop();
    _beatClock.stop();
    _beatClock.reset();
    _running = false;
    _lastBeatIndex = -1;
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

  void _restartBeatTicker() {
    if (!_running) return;
    _beatFrameTicker.stop();
    _beatClock
      ..stop()
      ..reset()
      ..start();
    _lastBeatIndex = -1;
    _handleBeat();
    _lastBeatIndex = 0;
    _beatFrameTicker.start();
  }

  void _onBeatFrame(Duration _) {
    if (!_running || !_beatFrameTicker.isActive) return;
    final int microsPerBeat = (60000000 / _bpm).round().clamp(1, 2000000);
    final int beatIndex = _beatClock.elapsedMicroseconds ~/ microsPerBeat;
    if (beatIndex <= _lastBeatIndex) return;
    _lastBeatIndex = beatIndex;
    _handleBeat();
  }

  void _handleBeat() {
    if (_pulseEnabled) {
      _pulseBeat();
    }
    if (_clickEnabled) {
      _playClick();
    }
  }

  void _pulseBeat() {
    _beatPulseToken.value += 1;
  }

  void _playClick() {
    unawaited(_triggerClick());
  }

  void _playCompletionChimeOnce() {
    if (_completionChimed) return;
    _completionChimed = true;
    unawaited(_triggerCompletionChime());
  }

  void _updateBpm(int bpm) {
    final int nextBpm = bpm.clamp(30, 260);
    setState(() {
      _bpm = nextBpm;
      _itemBpmById[_currentItemId] = nextBpm;
    });
    _restartBeatTicker();
  }

  void _updateClickEnabled(bool value) {
    setState(() {
      _clickEnabled = value;
    });
    _restartBeatTicker();
  }

  Future<void> _configureAudio() async {
    final AudioSession session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    await _clickPlayer.setAsset('assets/audio/metronome_beep.wav');
    await _clickPlayer.setVolume(1.0);
  }

  Future<void> _triggerClick() async {
    try {
      await _clickPlayer.seek(Duration.zero);
      await _clickPlayer.play();
    } catch (_) {
      // Ignore transient playback errors during rapid BPM changes.
    }
  }

  Future<void> _triggerCompletionChime() async {
    try {
      await _clickPlayer.seek(Duration.zero);
      await _clickPlayer.play();
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await _clickPlayer.seek(Duration.zero);
      await _clickPlayer.play();
    } catch (_) {
      // Ignore transient playback errors during completion chime.
    }
  }

  void _markCurrentItemPracticed() {
    if (_isWarmup) return;
    final String itemId = _currentItemId;
    if (_practicedItemIds.contains(itemId)) return;
    _practicedItemIds = <String>[..._practicedItemIds, itemId];
  }
}

class _BeatPulse extends StatefulWidget {
  final ValueListenable<int> beatTokenListenable;
  final int bpm;
  final bool enabled;
  final TickerProvider vsync;

  const _BeatPulse({
    required this.beatTokenListenable,
    required this.bpm,
    required this.enabled,
    required this.vsync,
  });

  @override
  State<_BeatPulse> createState() => _BeatPulseState();
}

class _BeatPulseState extends State<_BeatPulse> {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: widget.vsync,
      duration: _pulseDurationFor(widget.bpm),
      value: 1,
    );
    widget.beatTokenListenable.addListener(_handleBeatTokenChanged);
  }

  @override
  void didUpdateWidget(covariant _BeatPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.beatTokenListenable != widget.beatTokenListenable) {
      oldWidget.beatTokenListenable.removeListener(_handleBeatTokenChanged);
      widget.beatTokenListenable.addListener(_handleBeatTokenChanged);
    }
    final Duration nextDuration = _pulseDurationFor(widget.bpm);
    if (_controller.duration != nextDuration) {
      _controller.duration = nextDuration;
    }
  }

  @override
  void dispose() {
    widget.beatTokenListenable.removeListener(_handleBeatTokenChanged);
    _controller.dispose();
    super.dispose();
  }

  Duration _pulseDurationFor(int bpm) {
    final int beatMs = (60000 / bpm).round();
    return Duration(milliseconds: (beatMs * 0.58).round().clamp(120, 240));
  }

  void _handleBeatTokenChanged() {
    if (!mounted || !widget.enabled) return;
    _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final double pulse = widget.enabled
        ? Curves.easeOutCubic.transform(1 - _controller.value)
        : 0;
    final bool beatLit = widget.enabled && pulse > 0.03;
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _PulseRing(
            active: beatLit,
            size: 112 + (114 * pulse),
            opacity: 0.48 * pulse,
            width: 4,
            duration: Duration.zero,
            color: const Color(0xFFFFC08D),
          ),
          _PulseRing(
            active: beatLit,
            size: 104 + (80 * pulse),
            opacity: 0.58 * pulse,
            width: 5,
            duration: Duration.zero,
            color: const Color(0xFFF05A28),
          ),
          _PulseRing(
            active: beatLit,
            size: 96 + (54 * pulse),
            opacity: 0.70 * pulse,
            width: 6,
            duration: Duration.zero,
            color: const Color(0xFFFFE2B5),
          ),
          Container(
            width: 116 + (30 * pulse),
            height: 116 + (30 * pulse),
            decoration: BoxDecoration(
              color: beatLit
                  ? const Color(0xFFF05A28)
                  : widget.enabled
                  ? const Color(0xFF1F1A14)
                  : const Color(0xFF14100C),
              shape: BoxShape.circle,
              border: Border.all(
                color: beatLit
                    ? const Color(0xFFFFC08D)
                    : widget.enabled
                    ? const Color(0xFF3A3329)
                    : const Color(0xFF2A231C),
                width: beatLit ? 5 : 3,
              ),
              boxShadow: <BoxShadow>[
                if (beatLit)
                  const BoxShadow(
                    color: Color(0x88F05A28),
                    blurRadius: 42,
                    spreadRadius: 9,
                  ),
              ],
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

class _PulseRing extends StatelessWidget {
  final bool active;
  final double size;
  final double opacity;
  final Duration duration;
  final double width;
  final Color color;

  const _PulseRing({
    required this.active,
    required this.size,
    required this.opacity,
    required this.duration,
    required this.width,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: duration,
      curve: Curves.easeOut,
      opacity: opacity,
      child: AnimatedContainer(
        duration: duration,
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? color : Colors.transparent,
            width: width,
          ),
        ),
      ),
    );
  }
}
