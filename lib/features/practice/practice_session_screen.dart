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
  late int _bpm;
  late bool _clickEnabled;
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _bpm = widget.setup.bpm;
    _clickEnabled = widget.setup.clickEnabled;
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
    final currentItemId = widget.setup.practiceItemIds[_currentItemIndex];
    final List<String> tokens = widget.controller.noteTokensFor(currentItemId);
    final List<PatternNoteMarkingV1> markings = widget.controller
        .noteMarkingsFor(currentItemId);
    final List<DrumVoiceV1> voices = widget.controller.noteVoicesFor(
      currentItemId,
    );
    final Duration? target = timerPresetToDuration(widget.setup.timerPreset);
    final String timerText = target == null
        ? formatDuration(_stopwatch.elapsed)
        : '${formatDuration(_stopwatch.elapsed)} / ${formatDuration(target)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Session')),
      body: DrumScreen(
        warm: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DrumPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (widget.setup.practiceMode == PracticeModeV1.flow)
                    PatternVoiceDisplay(
                      tokens: tokens,
                      markings: markings,
                      voices: voices,
                      patternStyle: Theme.of(context).textTheme.displaySmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.0,
                          ),
                      voiceStyle: Theme.of(context).textTheme.titleMedium,
                    )
                  else
                    PatternDisplayText(
                      tokens: tokens,
                      markings: markings,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.0,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Chip(label: Text(widget.setup.practiceMode.label)),
                  const SizedBox(height: 12),
                  Text(
                    widget.controller.practiceGuidanceFor(
                      currentItemId,
                      practiceMode: widget.setup.practiceMode,
                    ),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF5B5345),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DrumPanel(
              tone: DrumPanelTone.dark,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  _BeatPulse(beatLit: _beatLit),
                  const SizedBox(height: 18),
                  Text(
                    timerText,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
                          icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                          label: Text(_running ? 'Pause' : 'Play'),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _endSession,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFFF4DE),
                          side: const BorderSide(color: Color(0xFFFFF4DE)),
                        ),
                        child: const Text('End Session'),
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
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
                ],
              ),
            ),
            if (widget.setup.practiceItemIds.length > 1) ...<Widget>[
              const SizedBox(height: 16),
              DrumPanel(
                child: Row(
                  children: <Widget>[
                    IconButton(
                      onPressed: _currentItemIndex == 0
                          ? null
                          : () => setState(() => _currentItemIndex -= 1),
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          '${_currentItemIndex + 1} / ${widget.setup.practiceItemIds.length}',
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed:
                          _currentItemIndex ==
                              widget.setup.practiceItemIds.length - 1
                          ? null
                          : () => setState(() => _currentItemIndex += 1),
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
            ],
          ],
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
    if (_running) {
      _stopwatch.stop();
      _elapsedTicker?.cancel();
      _beatTicker?.cancel();
      _beatFlashTimer?.cancel();
      _running = false;
      _beatLit = false;
    }

    final PracticeSessionLogV1 session = widget.controller.completeSession(
      widget.setup.copyWith(bpm: _bpm, clickEnabled: _clickEnabled),
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

  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
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
    _pulseBeat();
    if (_clickEnabled) {
      _playClick();
    }
  }

  void _pulseBeat() {
    if (!mounted) return;
    _beatFlashTimer?.cancel();
    setState(() => _beatLit = true);
    _beatFlashTimer = Timer(const Duration(milliseconds: 110), () {
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

  const _BeatPulse({required this.beatLit});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _PulseRing(
            active: beatLit,
            size: beatLit ? 188 : 118,
            opacity: beatLit ? 0.34 : 0,
            duration: const Duration(milliseconds: 260),
          ),
          _PulseRing(
            active: beatLit,
            size: beatLit ? 160 : 104,
            opacity: beatLit ? 0.42 : 0,
            duration: const Duration(milliseconds: 180),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            width: beatLit ? 132 : 120,
            height: beatLit ? 132 : 120,
            decoration: BoxDecoration(
              color: beatLit
                  ? const Color(0xFFF05A28)
                  : const Color(0xFF1F1A14),
              shape: BoxShape.circle,
              border: Border.all(
                color: beatLit
                    ? const Color(0xFFFFC08D)
                    : const Color(0xFF3A3329),
                width: beatLit ? 5 : 3,
              ),
              boxShadow: <BoxShadow>[
                if (beatLit)
                  const BoxShadow(
                    color: Color(0x88F05A28),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
              ],
            ),
            child: Center(
              child: Text(
                'Beat',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFF4DE),
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRing extends StatelessWidget {
  final bool active;
  final double size;
  final double opacity;
  final Duration duration;

  const _PulseRing({
    required this.active,
    required this.size,
    required this.opacity,
    required this.duration,
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
            color: active ? const Color(0xFFFFC08D) : Colors.transparent,
            width: 3,
          ),
        ),
      ),
    );
  }
}
