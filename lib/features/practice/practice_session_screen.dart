import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../../core/practice/practice_domain_v1.dart';
import 'widgets/pattern_display_text.dart';
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

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  final AudioPlayer _clickPlayer = AudioPlayer();
  Timer? _elapsedTicker;
  Timer? _beatTicker;
  Timer? _beatFlashTimer;
  bool _running = false;
  bool _beatLit = false;
  late bool _pulseEnabled;
  late int _bpm;
  late bool _clickEnabled;
  late PracticeSessionSetupV1 _setup;
  PracticeSessionSetupV1? _returnSetup;
  int _returnItemIndex = 0;
  bool? _returnPulseEnabled;
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _setup = widget.setup;
    _bpm = _setup.bpm;
    _clickEnabled = _setup.family == MaterialFamilyV1.warmup
        ? false
        : _setup.clickEnabled;
    _pulseEnabled = _setup.family != MaterialFamilyV1.warmup;
    _configureAudio();
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    _beatTicker?.cancel();
    _beatFlashTimer?.cancel();
    _clickPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWarmup = _setup.family == MaterialFamilyV1.warmup;
    final currentItemId = _setup.practiceItemIds[_currentItemIndex];
    final currentItem = widget.controller.itemById(currentItemId);
    final List<String> tokens = widget.controller.noteTokensFor(currentItemId);
    final List<PatternNoteMarkingV1> markings = widget.controller
        .noteMarkingsFor(currentItemId);
    final List<DrumVoiceV1> voices = widget.controller.noteVoicesFor(
      currentItemId,
    );
    final Duration? target = isWarmup
        ? Duration(minutes: _setup.practiceItemIds.length)
        : timerPresetToDuration(_setup.timerPreset);
    final String timerText = target == null
        ? formatDuration(_stopwatch.elapsed)
        : '${formatDuration(_stopwatch.elapsed)} / ${formatDuration(target)}';

    return PopScope(
      canPop: !isWarmup || _returnSetup == null,
      onPopInvokedWithResult: (bool didPop, Object? _) {
        if (!didPop && isWarmup && _returnSetup != null) {
          _restoreFromWarmup();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: isWarmup && _returnSetup != null
              ? IconButton(
                  onPressed: _restoreFromWarmup,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          title: Text(isWarmup ? 'Warmup Session' : 'Practice Session'),
        ),
        body: DrumScreen(
          warm: false,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              DrumPanel(
                tone: DrumPanelTone.dark,
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    if (_setup.practiceItemIds.length > 1) ...<Widget>[
                      _SessionStepper(
                        currentIndex: _currentItemIndex,
                        itemCount: _setup.practiceItemIds.length,
                        label: currentItem.name,
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
                      beatLit: _beatLit,
                      bpm: _bpm,
                      enabled: _pulseEnabled,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      timerText,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFFFFF4DE),
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        SizedBox(
                          height: 58,
                          child: FilledButton.icon(
                            onPressed: _toggleRunning,
                            icon: Icon(
                              _running ? Icons.pause : Icons.play_arrow,
                            ),
                            label: Text(_running ? 'Pause' : 'Play'),
                          ),
                        ),
                        if (!isWarmup)
                          OutlinedButton.icon(
                            onPressed: _openWarmup,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFFF4DE),
                              side: const BorderSide(color: Color(0xFFFFF4DE)),
                            ),
                            icon: const Icon(
                              Icons.local_fire_department_outlined,
                            ),
                            label: const Text('Warm Up'),
                          ),
                        OutlinedButton(
                          onPressed: _endSession,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFFFF4DE),
                            side: const BorderSide(color: Color(0xFFFFF4DE)),
                          ),
                          child: Text(isWarmup ? 'End Warmup' : 'End Session'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              DrumPanel(
                child: Column(
                  children: <Widget>[
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
                              : () => _updateBpm(_bpm - 1),
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
                          onPressed: _bpm >= 260
                              ? null
                              : () => _updateBpm(_bpm + 1),
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
                          if (!value) {
                            _beatLit = false;
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleRunning() {
    final bool shouldStart = !_running;
    setState(() {
      if (shouldStart) {
        _running = true;
        _stopwatch.start();
        _startElapsedTicker();
      } else {
        _running = false;
        _stopwatch.stop();
        _elapsedTicker?.cancel();
        _beatTicker?.cancel();
        _beatFlashTimer?.cancel();
        _beatLit = false;
      }
    });
    if (shouldStart) {
      _restartBeatTicker();
    }
  }

  void _endSession() {
    if (_setup.family == MaterialFamilyV1.warmup) {
      _restoreFromWarmup();
      return;
    }

    _resetRunState(clearElapsed: false);

    final PracticeSessionLogV1 session = widget.controller.completeSession(
      _setup.copyWith(bpm: _bpm, clickEnabled: _clickEnabled),
      _stopwatch.elapsed,
    );

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => SessionSummaryScreen(
          controller: widget.controller,
          sessionId: session.id,
        ),
      ),
    );
  }

  void _openWarmup() {
    _returnSetup = _setup.copyWith(bpm: _bpm, clickEnabled: _clickEnabled);
    _returnItemIndex = _currentItemIndex;
    _returnPulseEnabled = _pulseEnabled;
    _resetRunState();

    setState(() {
      _setup = widget.controller.buildWarmupSession().copyWith(
        bpm: _bpm,
        clickEnabled: false,
      );
      _clickEnabled = false;
      _pulseEnabled = false;
      _currentItemIndex = 0;
    });
  }

  void _restoreFromWarmup() {
    final PracticeSessionSetupV1? returnSetup = _returnSetup;
    if (returnSetup == null) {
      Navigator.of(context).pop();
      return;
    }
    _resetRunState();
    setState(() {
      _setup = returnSetup;
      _bpm = returnSetup.bpm;
      _clickEnabled = returnSetup.clickEnabled;
      _pulseEnabled = _returnPulseEnabled ?? true;
      _currentItemIndex = _returnItemIndex.clamp(
        0,
        returnSetup.practiceItemIds.length - 1,
      );
      _returnSetup = null;
      _returnItemIndex = 0;
      _returnPulseEnabled = null;
    });
  }

  void _changeItem(int nextIndex) {
    setState(() {
      _currentItemIndex = nextIndex;
    });
  }

  void _resetRunState({bool clearElapsed = true}) {
    if (_running) {
      _stopwatch.stop();
    }
    if (clearElapsed) {
      _stopwatch.reset();
    }
    _elapsedTicker?.cancel();
    _beatTicker?.cancel();
    _beatFlashTimer?.cancel();
    _running = false;
    _beatLit = false;
  }

  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_setup.family == MaterialFamilyV1.warmup) {
        _syncWarmupProgress();
      }
      if (mounted) setState(() {});
    });
  }

  void _syncWarmupProgress() {
    final int itemCount = _setup.practiceItemIds.length;
    if (itemCount == 0) return;

    final int elapsedSeconds = _stopwatch.elapsed.inSeconds;
    final int nextIndex = (elapsedSeconds ~/ 60).clamp(0, itemCount - 1);
    if (nextIndex != _currentItemIndex && mounted) {
      setState(() {
        _currentItemIndex = nextIndex;
      });
    }

    final int totalSeconds = itemCount * 60;
    if (_running && elapsedSeconds >= totalSeconds) {
      _resetRunState(clearElapsed: false);
    }
  }

  void _restartBeatTicker() {
    _beatTicker?.cancel();
    if (!_running) return;

    final int intervalMs = (60000 / _bpm).round().clamp(120, 2000);
    _handleBeat();
    _beatTicker = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _handleBeat();
    });
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
    if (!mounted) return;
    _beatFlashTimer?.cancel();
    setState(() => _beatLit = true);
    _beatFlashTimer = Timer(const Duration(milliseconds: 170), () {
      if (mounted) setState(() => _beatLit = false);
    });
  }

  void _playClick() {
    unawaited(_triggerClick());
  }

  void _updateBpm(int bpm) {
    setState(() {
      _bpm = bpm.clamp(30, 260);
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
}

class _BeatPulse extends StatelessWidget {
  final bool beatLit;
  final int bpm;
  final bool enabled;

  const _BeatPulse({
    required this.beatLit,
    required this.bpm,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      height: 230,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _PulseRing(
            active: beatLit,
            size: beatLit ? 226 : 112,
            opacity: beatLit ? 0.48 : 0,
            width: 4,
            duration: const Duration(milliseconds: 360),
            color: const Color(0xFFFFC08D),
          ),
          _PulseRing(
            active: beatLit,
            size: beatLit ? 184 : 104,
            opacity: beatLit ? 0.58 : 0,
            width: 5,
            duration: const Duration(milliseconds: 250),
            color: const Color(0xFFF05A28),
          ),
          _PulseRing(
            active: beatLit,
            size: beatLit ? 150 : 96,
            opacity: beatLit ? 0.70 : 0,
            width: 6,
            duration: const Duration(milliseconds: 170),
            color: const Color(0xFFFFE2B5),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            width: beatLit ? 146 : 116,
            height: beatLit ? 146 : 116,
            decoration: BoxDecoration(
              color: beatLit
                  ? const Color(0xFFF05A28)
                  : enabled
                  ? const Color(0xFF1F1A14)
                  : const Color(0xFF14100C),
              shape: BoxShape.circle,
              border: Border.all(
                color: beatLit
                    ? const Color(0xFFFFC08D)
                    : enabled
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
                    '$bpm',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFFFFF4DE),
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  Text(
                    enabled ? 'BPM' : 'PULSE OFF',
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
      >= 24 => 24,
      >= 16 => 28,
      >= 12 => 31,
      _ => 34,
    };
    final TextStyle patternStyle =
        Theme.of(context).textTheme.displaySmall?.copyWith(
          color: const Color(0xFFFFF4DE),
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: isWarmup ? 1.3 : 0.4,
        ) ??
        TextStyle(
          color: Color(0xFFFFF4DE),
          fontWeight: FontWeight.w900,
          fontSize: fontSize,
          letterSpacing: 0.4,
        );

    final TextStyle voiceStyle =
        Theme.of(context).textTheme.titleMedium?.copyWith(
          color: const Color(0xFFE5D5BB),
          fontWeight: FontWeight.w800,
        ) ??
        const TextStyle(
          color: Color(0xFFE5D5BB),
          fontWeight: FontWeight.w800,
          fontSize: 16,
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
                cellWidth: tokens.length >= 24 ? 32 : (isWarmup ? 42 : 40),
                patternStyle: patternStyle,
                voiceStyle: voiceStyle,
              )
            : PatternDisplayText(
                tokens: tokens,
                markings: markings,
                grouping: grouping,
                showRepeatIndicator: true,
                style: patternStyle,
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
      ),
    );
  }
}

class _SessionStepper extends StatelessWidget {
  final int currentIndex;
  final int itemCount;
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final bool dark;

  const _SessionStepper({
    required this.currentIndex,
    required this.itemCount,
    required this.label,
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
          child: Column(
            children: <Widget>[
              Text(
                '${currentIndex + 1} / $itemCount',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
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
