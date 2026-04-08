import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import 'practice_session_screen.dart';

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
  SelfReportControlV1? _control;
  SelfReportTensionV1? _tension;
  SelfReportTempoReadinessV1? _tempoReadiness;
  bool _assessmentLoaded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.sessionById(widget.sessionId);
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Session not found.')));
    }
    _loadAssessmentOnce(session.id);

    final String sessionTitle = session.practiceItemIds.length == 1
        ? widget.controller.itemById(session.practiceItemIds.first).name
        : widget.controller.comboDisplayName(session.practiceItemIds);
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
                  Text(
                    sessionTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(session.family.label),
                  const SizedBox(height: 4),
                  Text(session.practiceMode.label),
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
                  Text(
                    'Session Check',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use this to guide the next recommendation. This is not a test.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _AssessmentChoiceGroup<SelfReportControlV1>(
                    title: 'Control',
                    value: _control,
                    values: SelfReportControlV1.values,
                    labelFor: (SelfReportControlV1 value) => value.label,
                    onSelected: (SelfReportControlV1 value) {
                      setState(() => _control = value);
                      _saveAssessment(session.id);
                    },
                  ),
                  const SizedBox(height: 16),
                  _AssessmentChoiceGroup<SelfReportTensionV1>(
                    title: 'Tension',
                    value: _tension,
                    values: SelfReportTensionV1.values,
                    labelFor: (SelfReportTensionV1 value) => value.label,
                    onSelected: (SelfReportTensionV1 value) {
                      setState(() => _tension = value);
                      _saveAssessment(session.id);
                    },
                  ),
                  const SizedBox(height: 16),
                  _AssessmentChoiceGroup<SelfReportTempoReadinessV1>(
                    title: 'Tempo',
                    value: _tempoReadiness,
                    values: SelfReportTempoReadinessV1.values,
                    labelFor: (SelfReportTempoReadinessV1 value) => value.label,
                    onSelected: (SelfReportTempoReadinessV1 value) {
                      setState(() => _tempoReadiness = value);
                      _saveAssessment(session.id);
                    },
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
                  builder: (_) => PracticeSessionScreen(
                    controller: widget.controller,
                    setup: widget.controller.buildSessionForItem(firstItem.id),
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

  void _loadAssessmentOnce(String sessionId) {
    if (_assessmentLoaded) return;
    _assessmentLoaded = true;
    final SessionAssessmentResultV1? result = widget.controller
        .assessmentForSession(sessionId);
    _control = result?.selfReportControl;
    _tension = result?.selfReportTension;
    _tempoReadiness = result?.selfReportTempoReadiness;
  }

  void _saveAssessment(String sessionId) {
    widget.controller.updateSessionAssessment(
      sessionId: sessionId,
      selfReportControl: _control,
      selfReportTension: _tension,
      selfReportTempoReadiness: _tempoReadiness,
    );
  }
}

class _AssessmentChoiceGroup<T> extends StatelessWidget {
  final String title;
  final T? value;
  final List<T> values;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;

  const _AssessmentChoiceGroup({
    required this.title,
    required this.value,
    required this.values,
    required this.labelFor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (T option) => ChoiceChip(
                  label: Text(labelFor(option)),
                  selected: value == option,
                  onSelected: (_) => onSelected(option),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
