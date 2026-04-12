import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import 'practice_session_screen.dart';
import 'widgets/pattern_display_text.dart';
import 'widgets/pattern_voice_display.dart';

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
  final Set<String> _savedBpmItemIds = <String>{};
  late int _currentItemIndex;

  @override
  void initState() {
    super.initState();
    final PracticeSessionLogV1? session = widget.controller.sessionById(
      widget.sessionId,
    );
    final int seededIndex = session == null
        ? 0
        : _initialItemIndexForSession(session).clamp(
            0,
            session.practiceItemIds.isEmpty
                ? 0
                : session.practiceItemIds.length - 1,
          );
    _currentItemIndex = seededIndex;
    if (session != null && session.practiceItemIds.isNotEmpty) {
      _loadAssessmentForItem(
        session.id,
        session.practiceItemIds[_currentItemIndex],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final PracticeSessionLogV1? session = widget.controller.sessionById(
      widget.sessionId,
    );
    if (session == null) {
      return const Scaffold(body: Center(child: Text('Session not found.')));
    }
    if (session.practiceItemIds.isEmpty) {
      return const Scaffold(body: Center(child: Text('Session not found.')));
    }

    final int safeIndex = _currentItemIndex.clamp(
      0,
      session.practiceItemIds.length - 1,
    );
    final String currentItemId = session.practiceItemIds[safeIndex];
    final PracticeItemV1 currentItem = widget.controller.itemById(
      currentItemId,
    );
    final PracticeSessionItemRuntimeV1 currentRuntime =
        widget.controller.sessionItemRuntimeFor(session, currentItemId) ??
        PracticeSessionItemRuntimeV1(
          practiceItemId: currentItemId,
          startingBpm: session.startingBpm,
          endingBpm: session.bpm,
        );
    final bool bpmAdjusted =
        currentRuntime.startingBpm != currentRuntime.endingBpm;
    final _SessionRecommendation? recommendation = _recommendationFor(
      needsTempoDecision: bpmAdjusted,
    );
    final bool canSaveBpm =
        !_savedBpmItemIds.contains(currentItemId) &&
        bpmAdjusted &&
        widget.controller.launchBpmForItem(currentItemId) !=
            currentRuntime.endingBpm;

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
                  if (session.practiceItemIds.length > 1) ...<Widget>[
                    _SummaryStepper(
                      currentIndex: safeIndex,
                      itemCount: session.practiceItemIds.length,
                      onPrevious: safeIndex == 0
                          ? null
                          : () => _changeItem(session, safeIndex - 1),
                      onNext: safeIndex == session.practiceItemIds.length - 1
                          ? null
                          : () => _changeItem(session, safeIndex + 1),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (session.practiceMode == PracticeModeV1.flow)
                    PatternVoiceDisplay(
                      tokens: widget.controller.noteTokensFor(currentItemId),
                      markings: widget.controller.noteMarkingsFor(
                        currentItemId,
                      ),
                      voices: widget.controller.noteVoicesFor(currentItemId),
                      grouping: widget.controller.displayGroupingFor(
                        currentItemId,
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
                      tokens: widget.controller.noteTokensFor(currentItemId),
                      markings: widget.controller.noteMarkingsFor(
                        currentItemId,
                      ),
                      grouping: widget.controller.displayGroupingFor(
                        currentItemId,
                      ),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.8,
                          ),
                    ),
                  const SizedBox(height: 12),
                  _SummaryMetric(
                    label: 'Duration',
                    value: formatDuration(session.duration),
                  ),
                  _SummaryMetric(
                    label: 'BPM',
                    value: '${currentRuntime.endingBpm}',
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
                    'Mark how this pattern felt, then decide what the next rep needs.',
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
                      _saveAssessment(session.id, currentItemId);
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
                      _saveAssessment(session.id, currentItemId);
                    },
                  ),
                  if (recommendation != null) ...<Widget>[
                    const SizedBox(height: 16),
                    _RecommendationPanel(recommendation: recommendation),
                  ],
                  if (canSaveBpm) ...<Widget>[
                    const SizedBox(height: 16),
                    DrumPanel(
                      tone: DrumPanelTone.blue,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.speed_rounded, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Save BPM',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'This rep ended at ${currentRuntime.endingBpm} BPM.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Checkbox(
                            value: _savedBpmItemIds.contains(currentItemId),
                            onChanged: (bool? value) {
                              if (value != true) return;
                              widget.controller
                                  .rememberLaunchPreferencesForItem(
                                    itemId: currentItemId,
                                    bpm: currentRuntime.endingBpm,
                                    timerPreset: widget.controller
                                        .launchTimerPresetForItem(
                                          currentItemId,
                                        ),
                                  );
                              setState(() {
                                _savedBpmItemIds.add(currentItemId);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            DrumActionRow(
              children: <Widget>[
                if (!widget.controller.isInRoutine(currentItem.id))
                  FilledButton(
                    onPressed: () {
                      widget.controller.toggleRoutineItem(currentItem.id);
                      setState(() {});
                    },
                    child: const Text('Add to Working On'),
                  ),
                OutlinedButton(
                  onPressed: () {
                    final int nextBpm =
                        recommendation?.nextBpm(currentRuntime.endingBpm) ??
                        currentRuntime.endingBpm;
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => PracticeSessionScreen(
                          controller: widget.controller,
                          setup: widget.controller.buildSessionForItem(
                            currentItem.id,
                            practiceMode: session.practiceMode,
                            bpm: nextBpm,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Text(recommendation?.practiceLabel ?? 'Play It Again'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int _initialItemIndexForSession(PracticeSessionLogV1 session) {
    final String? assessmentItemId = session.assessmentItemId;
    if (assessmentItemId == null) return 0;
    final int index = session.practiceItemIds.indexOf(assessmentItemId);
    return index < 0 ? 0 : index;
  }

  void _changeItem(PracticeSessionLogV1 session, int nextIndex) {
    final int clampedIndex = nextIndex.clamp(
      0,
      session.practiceItemIds.length - 1,
    );
    final String nextItemId = session.practiceItemIds[clampedIndex];
    setState(() {
      _currentItemIndex = clampedIndex;
      _loadAssessmentForItem(session.id, nextItemId);
    });
  }

  void _loadAssessmentForItem(String sessionId, String itemId) {
    final SessionAssessmentResultV1? result = widget.controller
        .assessmentForSessionItem(sessionId, itemId);
    _control = result?.selfReportControl;
    _tension = result?.selfReportTension;
  }

  void _saveAssessment(String sessionId, String itemId) {
    widget.controller.updateSessionAssessment(
      sessionId: sessionId,
      itemId: itemId,
      selfReportControl: _control,
      selfReportTension: _tension,
      selfReportTempoReadiness: null,
    );
  }

  _SessionRecommendation? _recommendationFor({
    required bool needsTempoDecision,
  }) {
    final bool incomplete = _control == null || _tension == null;
    if (incomplete) {
      return null;
    }

    final bool slowDown =
        _control == SelfReportControlV1.low ||
        _tension == SelfReportTensionV1.high;
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
        !needsTempoDecision;
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

class _SummaryStepper extends StatelessWidget {
  final int currentIndex;
  final int itemCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _SummaryStepper({
    required this.currentIndex,
    required this.itemCount,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Center(
            child: Text(
              '${currentIndex + 1} / $itemCount',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}
