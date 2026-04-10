import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import 'widgets/pattern_display_text.dart';
import 'widgets/pattern_voice_display.dart';
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

    final String primaryItemId =
        session.assessmentItemId ??
        (session.practiceItemIds.isEmpty ? '' : session.practiceItemIds.first);
    if (primaryItemId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Session not found.')));
    }
    final firstItem = widget.controller.itemById(primaryItemId);
    final bool isWorkingOnSource = session.sourceName == 'Working On';
    final _SessionRecommendation recommendation = _recommendationFor(session);

    return Scaffold(
      appBar: AppBar(title: const Text('Session Summary')),
      body: DrumScreen(
        warm: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DrumPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (session.practiceMode == PracticeModeV1.flow)
                    PatternVoiceDisplay(
                      tokens: widget.controller.noteTokensFor(primaryItemId),
                      markings: widget.controller.noteMarkingsFor(
                        primaryItemId,
                      ),
                      voices: widget.controller.noteVoicesFor(primaryItemId),
                      grouping: widget.controller.displayGroupingFor(
                        primaryItemId,
                      ),
                      patternStyle: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                      voiceStyle: Theme.of(context).textTheme.titleMedium,
                    )
                  else
                    PatternDisplayText(
                      tokens: widget.controller.noteTokensFor(primaryItemId),
                      markings: widget.controller.noteMarkingsFor(
                        primaryItemId,
                      ),
                      grouping: widget.controller.displayGroupingFor(
                        primaryItemId,
                      ),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                    ),
                  const SizedBox(height: 12),
                  _SummaryMetric(
                    label: 'Mode',
                    value: session.practiceMode.label,
                  ),
                  _SummaryMetric(label: 'Family', value: session.family.label),
                  _SummaryMetric(
                    label: 'Duration',
                    value: formatDuration(session.duration),
                  ),
                  _SummaryMetric(label: 'BPM', value: '${session.bpm}'),
                  _SummaryMetric(
                    label: 'Click',
                    value: session.clickEnabled ? 'On' : 'Off',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DrumPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const DrumSectionTitle(text: 'Check The Rep'),
                  const SizedBox(height: 8),
                  Text(
                    'Mark how it felt, then decide what the next rep needs.',
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
                  const SizedBox(height: 16),
                  _RecommendationPanel(recommendation: recommendation),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DrumActionRow(
              children: <Widget>[
                FilledButton(
                  onPressed: () {
                    if (!widget.controller.isInRoutine(firstItem.id)) {
                      widget.controller.toggleRoutineItem(firstItem.id);
                    }
                  },
                  child: Text(
                    widget.controller.isInRoutine(firstItem.id)
                        ? 'In Working On'
                        : 'Add to Working On',
                  ),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => PracticeSessionScreen(
                          controller: widget.controller,
                          setup:
                              (isWorkingOnSource
                                      ? widget.controller
                                            .buildSessionForWorkingOnSelection(
                                              session.practiceItemIds,
                                              practiceMode: session.practiceMode,
                                            )
                                      : widget.controller.buildSessionForItem(
                                          firstItem.id,
                                          practiceMode: session.practiceMode,
                                        ))
                                  .copyWith(
                                    bpm: recommendation.nextBpm(session.bpm),
                                  ),
                        ),
                      ),
                    );
                  },
                  child: Text(recommendation.practiceLabel),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
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

  _SessionRecommendation _recommendationFor(PracticeSessionLogV1 session) {
    final bool incomplete =
        _control == null || _tension == null || _tempoReadiness == null;
    if (incomplete) {
      return const _SessionRecommendation(
        title: 'Check this rep first',
        body: 'Answer the three checks above, then choose the next rep.',
        practiceLabel: 'Play It Again',
        bpmAdjustment: 0,
      );
    }

    final bool slowDown =
        _control == SelfReportControlV1.low ||
        _tension == SelfReportTensionV1.high ||
        _tempoReadiness == SelfReportTempoReadinessV1.decrease;
    if (slowDown) {
      return const _SessionRecommendation(
        title: 'Next rep: slow down',
        body:
            'Keep it smaller and cleaner. The next win is evenness and relaxed motion, not more tempo.',
        practiceLabel: 'Play It Slower',
        bpmAdjustment: -6,
      );
    }

    final bool bumpUp =
        _control == SelfReportControlV1.high &&
        _tension == SelfReportTensionV1.none &&
        _tempoReadiness == SelfReportTempoReadinessV1.increase;
    if (bumpUp) {
      return const _SessionRecommendation(
        title: 'Next rep: bring it up',
        body:
            'The phrase held together. Add a little tempo and make sure the sound stays relaxed.',
        practiceLabel: 'Bring It Up',
        bpmAdjustment: 4,
      );
    }

    return const _SessionRecommendation(
      title: 'Next rep: stay here',
      body:
          'This tempo still has work in it. Stay here until the motion and sound come back cleanly.',
      practiceLabel: 'Stay Here',
      bpmAdjustment: 0,
    );
  }
}

class _SessionRecommendation {
  final String title;
  final String body;
  final String practiceLabel;
  final int bpmAdjustment;

  const _SessionRecommendation({
    required this.title,
    required this.body,
    required this.practiceLabel,
    required this.bpmAdjustment,
  });

  int nextBpm(int currentBpm) => (currentBpm + bpmAdjustment).clamp(40, 240);
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: <Widget>[
          Text(
            '$label: ',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          Flexible(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _RecommendationPanel extends StatelessWidget {
  final _SessionRecommendation recommendation;

  const _RecommendationPanel({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      tone: DrumPanelTone.warm,
      padding: const EdgeInsets.all(14),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              recommendation.title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              recommendation.body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
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
                (T option) => DrumSelectablePill(
                  label: Text(labelFor(option)),
                  selected: value == option,
                  onPressed: () => onSelected(option),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}
