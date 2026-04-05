import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../../core/practice/practice_domain_v1.dart';
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
  Timer? _ticker;
  bool _running = false;
  late int _bpm;
  late bool _clickEnabled;
  int _currentItemIndex = 0;

  @override
  void initState() {
    super.initState();
    _bpm = widget.setup.bpm;
    _clickEnabled = widget.setup.clickEnabled;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentItemId = widget.setup.practiceItemIds[_currentItemIndex];
    final currentItem = widget.controller.itemById(currentItemId);
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
                  Text(currentItem.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.setup.intent.label} · ${widget.setup.context.label}',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentItem.sticking,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  if (widget.setup.intent == PracticeIntentV1.flow) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      'Landing: resolve to beat 1 in 4/4',
                      style: Theme.of(context).textTheme.bodyMedium,
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
                  Text(timerText, style: Theme.of(context).textTheme.headlineMedium),
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
                      Expanded(
                        child: Text('BPM', style: Theme.of(context).textTheme.titleMedium),
                      ),
                      IconButton(
                        onPressed: _bpm <= 30 ? null : () => setState(() => _bpm -= 1),
                        icon: const Icon(Icons.remove),
                      ),
                      Text('$_bpm'),
                      IconButton(
                        onPressed: _bpm >= 260 ? null : () => setState(() => _bpm += 1),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Click'),
                    value: _clickEnabled,
                    onChanged: (bool value) => setState(() => _clickEnabled = value),
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
                      onPressed: _currentItemIndex == widget.setup.practiceItemIds.length - 1
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
        _ticker?.cancel();
      } else {
        _running = true;
        _stopwatch.start();
        _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  void _endSession() {
    if (_running) {
      _stopwatch.stop();
      _ticker?.cancel();
      _running = false;
    }

    final PracticeSessionLogV1 session = widget.controller.completeSession(
      widget.setup.copyWith(
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
}
