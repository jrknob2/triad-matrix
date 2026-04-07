import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../../core/practice/practice_domain_v1.dart';
import 'widgets/pattern_display_text.dart';
import 'widgets/pattern_marking_editor.dart';
import 'widgets/pattern_voice_display.dart';
import 'widgets/voice_assignment_editor.dart';
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
  final Map<String, List<PatternNoteMarkingV1>> _sessionMarkingsByItemId =
      <String, List<PatternNoteMarkingV1>>{};
  final Map<String, List<DrumVoiceV1>> _sessionVoicesByItemId =
      <String, List<DrumVoiceV1>>{};
  Timer? _elapsedTicker;
  Timer? _beatTicker;
  bool _running = false;
  late PracticeModeV1 _practiceMode;
  late int _bpm;
  late bool _clickEnabled;
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _practiceMode = widget.setup.practiceMode;
    _bpm = widget.setup.bpm;
    _clickEnabled = widget.setup.clickEnabled;
    for (final String itemId in widget.setup.practiceItemIds) {
      _sessionMarkingsByItemId[itemId] = List<PatternNoteMarkingV1>.from(
        widget.controller.noteMarkingsFor(itemId),
      );
      _sessionVoicesByItemId[itemId] = List<DrumVoiceV1>.from(
        widget.controller.noteVoicesFor(itemId),
      );
    }
    _configureAudio();
  }

  @override
  void dispose() {
    _elapsedTicker?.cancel();
    _beatTicker?.cancel();
    _clickPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentItemId = widget.setup.practiceItemIds[_currentItemIndex];
    final List<String> tokens = widget.controller.noteTokensFor(currentItemId);
    final List<PatternNoteMarkingV1> markings =
        _sessionMarkingsByItemId[currentItemId]!;
    final List<DrumVoiceV1> voices = _sessionVoicesByItemId[currentItemId]!;
    final Duration? target = timerPresetToDuration(widget.setup.timerPreset);
    final String timerText = target == null
        ? formatDuration(_stopwatch.elapsed)
        : '${formatDuration(_stopwatch.elapsed)} / ${formatDuration(target)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Session')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_practiceMode == PracticeModeV1.flow)
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
                  Text(
                    widget.controller.practiceGuidanceFor(
                      currentItemId,
                      practiceMode: _practiceMode,
                    ),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF5B5345),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PatternMarkingEditor(
                    tokens: tokens,
                    markings: markings,
                    onTapNote: (int noteIndex) {
                      _toggleSessionMarking(
                        itemId: currentItemId,
                        noteIndex: noteIndex,
                      );
                    },
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Practice Mode',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<PracticeModeV1>(
                    segments: PracticeModeV1.values
                        .map(
                          (PracticeModeV1 mode) =>
                              ButtonSegment<PracticeModeV1>(
                                value: mode,
                                label: Text(mode.label),
                              ),
                        )
                        .toList(growable: false),
                    selected: <PracticeModeV1>{_practiceMode},
                    onSelectionChanged: (Set<PracticeModeV1> selection) {
                      setState(() => _practiceMode = selection.first);
                    },
                  ),
                  if (_practiceMode == PracticeModeV1.flow) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      'Voice Assignment',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    VoiceAssignmentEditor(
                      tokens: tokens,
                      voices: voices,
                      onTapNote: (int noteIndex) {
                        _toggleSessionVoice(
                          itemId: currentItemId,
                          noteIndex: noteIndex,
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Keep the route intentional. The phrase should read clearly from surface to surface.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  Text(
                    timerText,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _toggleRunning,
                        icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                        label: Text(_running ? 'Pause' : 'Play'),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _endSession,
                        child: const Text('End Session'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
          ),
          if (widget.setup.practiceItemIds.length > 1) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
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
            ),
          ],
        ],
      ),
    );
  }

  void _toggleRunning() {
    setState(() {
      if (_running) {
        _running = false;
        _stopwatch.stop();
        _elapsedTicker?.cancel();
        _beatTicker?.cancel();
      } else {
        _running = true;
        _stopwatch.start();
        _startElapsedTicker();
        _restartBeatTicker();
      }
    });
  }

  void _endSession() {
    if (_running) {
      _stopwatch.stop();
      _elapsedTicker?.cancel();
      _beatTicker?.cancel();
      _running = false;
    }

    final PracticeSessionLogV1 session = widget.controller.completeSession(
      widget.setup.copyWith(
        practiceMode: _practiceMode,
        bpm: _bpm,
        clickEnabled: _clickEnabled,
      ),
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

  void _toggleSessionMarking({required String itemId, required int noteIndex}) {
    final List<PatternNoteMarkingV1> current =
        _sessionMarkingsByItemId[itemId]!;
    final String token = widget.controller.noteTokensFor(itemId)[noteIndex];
    final PatternNoteMarkingV1 next = switch (current[noteIndex]) {
      PatternNoteMarkingV1.normal =>
        token == 'K' ? PatternNoteMarkingV1.ghost : PatternNoteMarkingV1.accent,
      PatternNoteMarkingV1.accent => PatternNoteMarkingV1.ghost,
      PatternNoteMarkingV1.ghost => PatternNoteMarkingV1.normal,
    };

    setState(() {
      final List<PatternNoteMarkingV1> updated =
          List<PatternNoteMarkingV1>.from(current);
      updated[noteIndex] = next;
      _sessionMarkingsByItemId[itemId] = updated;
    });
  }

  void _toggleSessionVoice({required String itemId, required int noteIndex}) {
    final List<DrumVoiceV1> current = _sessionVoicesByItemId[itemId]!;
    final String token = widget.controller.noteTokensFor(itemId)[noteIndex];

    final DrumVoiceV1 next;
    if (token == 'K') {
      next = DrumVoiceV1.kick;
    } else {
      const List<DrumVoiceV1> cycle = <DrumVoiceV1>[
        DrumVoiceV1.snare,
        DrumVoiceV1.rackTom,
        DrumVoiceV1.tom2,
        DrumVoiceV1.floorTom,
        DrumVoiceV1.hihat,
      ];
      final int currentIndex = cycle.indexOf(current[noteIndex]);
      next = cycle[(currentIndex + 1) % cycle.length];
    }

    setState(() {
      final List<DrumVoiceV1> updated = List<DrumVoiceV1>.from(current);
      updated[noteIndex] = next;
      _sessionVoicesByItemId[itemId] = updated;
    });
  }

  void _startElapsedTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  void _restartBeatTicker() {
    _beatTicker?.cancel();
    if (!_running || !_clickEnabled) return;

    final int intervalMs = (60000 / _bpm).round().clamp(120, 2000);
    _playClick();
    _beatTicker = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      _playClick();
    });
  }

  void _playClick() {
    unawaited(_triggerClick());
  }

  void _updateBpm(int bpm) {
    setState(() {
      _bpm = bpm.clamp(30, 260);
      _restartBeatTicker();
    });
  }

  void _updateClickEnabled(bool value) {
    setState(() {
      _clickEnabled = value;
      _restartBeatTicker();
    });
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
