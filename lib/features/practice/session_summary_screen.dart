import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import 'practice_setup_screen.dart';

class SessionSummaryScreen extends StatefulWidget {
  final AppController controller;
  final String sessionId;

  const SessionSummaryScreen({
    super.key,
    required this.controller,
    required this.sessionId,
  });

  @override
  State<SessionSummaryScreen> createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen> {
  ReflectionRatingV1? _reflection;

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.sessionById(widget.sessionId);
    if (session == null) {
      return const Scaffold(
        body: Center(child: Text('Session not found.')),
      );
    }

    final firstItem = widget.controller.itemById(session.practiceItemIds.first);

    return Scaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(firstItem.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    '${session.family.label} · ${session.intent.label} · ${session.context.label}',
                  ),
                  const SizedBox(height: 12),
                  Text('Duration: ${formatDuration(session.duration)}'),
                  Text('BPM: ${session.bpm}'),
                  Text('Click: ${session.clickEnabled ? 'On' : 'Off'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Reflection', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ReflectionRatingV1.values
                        .map(
                          (rating) => ChoiceChip(
                            label: Text(rating.label),
                            selected: _reflection == rating,
                            onSelected: (_) {
                              setState(() => _reflection = rating);
                              widget.controller.updateSessionReflection(session.id, rating);
                            },
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              if (!widget.controller.isInRoutine(firstItem.id)) {
                widget.controller.toggleRoutineItem(firstItem.id);
              }
            },
            child: Text(
              widget.controller.isInRoutine(firstItem.id)
                  ? 'In Routine'
                  : 'Add to Routine',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => PracticeSetupScreen(
                    controller: widget.controller,
                    initialItemId: firstItem.id,
                  ),
                ),
              );
            },
            child: const Text('Practice Again'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
