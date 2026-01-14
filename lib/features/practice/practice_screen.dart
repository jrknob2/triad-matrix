// lib/features/practice/practice_screen.dart
//
// Triad Trainer — Practice Screen (v1)
//
// Responsibilities:
// - Layout + wiring only.
// - Compose modular widgets (PatternCard, KitDiagram, etc.).
// - Talk to PracticeController for state + intents.
// - No domain models, no generator math, no painters.
//
// Notes:
// - This screen uses ChangeNotifier directly via AnimatedBuilder to avoid
//   assuming Provider/Riverpod is in use.

import 'package:flutter/material.dart';

import '../../core/instrument/instrument_context_v1.dart';
import '../../core/pattern/pattern_engine.dart';
import '../../core/practice/practice_models.dart';
import '../../state/practice_controller.dart';
import '../settings/settings_screen.dart';
import 'widgets/pattern_card.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  late final PracticeController _c;

  @override
  void initState() {
    super.initState();
    _c = PracticeController();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  Future<void> _pickTimerTarget() async {
    final Duration? selected = await showModalBottomSheet<Duration?>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: const <Widget>[
              _TimerChoiceTile(label: 'No timer', value: null),
              _TimerChoiceTile(label: '5 min', value: Duration(minutes: 5)),
              _TimerChoiceTile(label: '10 min', value: Duration(minutes: 10)),
              _TimerChoiceTile(label: '30 min', value: Duration(minutes: 30)),
            ],
          ),
        );
      },
    );

    if (!mounted) return;

    // For now, both "dismiss" and "No timer" result in null.
    // If you want dismiss to do nothing, we can return a sentinel instead.
    _c.setTimerTarget(selected);
  }

  Map<DrumSurfaceV1, String> _defaultVoiceLabels() {
    return const <DrumSurfaceV1, String>{
      DrumSurfaceV1.snare: 'S',
      DrumSurfaceV1.tom1: '1',
      DrumSurfaceV1.tom2: '2',
      DrumSurfaceV1.floorTom: 'F',
      DrumSurfaceV1.hiHat: 'H',
      DrumSurfaceV1.ride: 'R',
      DrumSurfaceV1.kick: 'K',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (BuildContext context, _) {
        final Pattern? p = _c.pattern;
        final String timerLabel = _formatTimer(_c.timer);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Triad Trainer'),
            actions: <Widget>[
              IconButton(
                onPressed: _openSettings,
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: DropdownButtonFormField<PracticeModeV1>(
                          initialValue: _c.mode,
                          items: PracticeModeV1.values
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text(
                                    m == PracticeModeV1.training
                                        ? 'Training'
                                        : 'Flow',
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) {
                            if (v != null) _c.setMode(v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Mode',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<InstrumentContextV1>(
                          initialValue: _c.instrument,
                          items: InstrumentContextV1.values
                              .map(
                                (i) => DropdownMenuItem(
                                  value: i,
                                  child: Text(
                                    switch (i) {
                                      InstrumentContextV1.pad => 'Pad',
                                      InstrumentContextV1.padKick =>
                                        'Pad + Kick',
                                      InstrumentContextV1.kit => 'Kit',
                                    },
                                  ),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (v) {
                            if (v != null) _c.setInstrument(v);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Instrument',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: _c.toggleTimerRunning,
                        icon: Icon(
                          _c.timer.running ? Icons.pause : Icons.play_arrow,
                        ),
                        tooltip:
                            _c.timer.running ? 'Pause timer' : 'Start timer',
                      ),
                      const Icon(Icons.timer, size: 18),
                      const SizedBox(width: 6),
                      Text(timerLabel),
                      IconButton(
                        icon: const Icon(Icons.restart_alt),
                        tooltip: 'Reset timer',
                        onPressed: _c.resetTimer,
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _pickTimerTarget,
                        icon: const Icon(Icons.more_time),
                        label: const Text('Timer'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 920),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: PatternCard(
                          pattern: p,
                          focus: _c.focus,
                          instrument: _c.instrument,
                          kit: _c.kit,
                          voiceLabels: _defaultVoiceLabels(),
                          showKitDiagram: true,
                          showVoiceRow: false,
                        ),
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    child: Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            IconButton(
                              onPressed: _c.restartSame,
                              icon: const Icon(Icons.replay),
                              tooltip: 'Restart',
                            ),
                            const SizedBox(width: 6),
                            ElevatedButton.icon(
                              onPressed: () {
                                // v1: “Play” starts timer and shows placeholder.
                                _c.startTimer();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Audio playback coming soon'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play'),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => _c.bpmStep(-1),
                              icon: const Icon(Icons.remove),
                              tooltip: 'BPM -',
                            ),
                            Text(
                              '${_c.bpm} BPM',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            IconButton(
                              onPressed: () => _c.bpmStep(1),
                              icon: const Icon(Icons.add),
                              tooltip: 'BPM +',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _c.toggleClick,
                              tooltip:
                                  _c.clickEnabled ? 'Click: On' : 'Click: Off',
                              icon: Icon(
                                _c.clickEnabled
                                    ? Icons.music_note
                                    : Icons.music_off,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _c.generateNext,
                              icon: const Icon(Icons.casino),
                              label: const Text('Next'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimer(PracticeTimerState t) {
    String mmss(Duration d) {
      final int m = d.inMinutes;
      final int s = d.inSeconds % 60;
      return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    if (t.target == null) return mmss(t.elapsed);
    return '${mmss(t.elapsed)} / ${mmss(t.target!)}';
  }
}

class _TimerChoiceTile extends StatelessWidget {
  final String label;
  final Duration? value;

  const _TimerChoiceTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      onTap: () => Navigator.of(context).pop(value),
    );
  }
}
