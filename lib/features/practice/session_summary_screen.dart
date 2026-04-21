import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import 'widgets/pattern_readout.dart';

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
  final Set<String> _pendingSaveBpmItemIds = <String>{};
  final Set<String> _pendingKeepEarnedRepItemIds = <String>{};
  final Set<String> _submittedItemIds = <String>{};
  final Set<String> _skippedItemIds = <String>{};
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
      item: currentItem,
      itemId: currentItemId,
      runtime: currentRuntime,
    );
    final bool canSaveBpm = bpmAdjusted;
    final bool wantsToSaveBpm = _pendingSaveBpmItemIds.contains(currentItemId);
    final bool canKeepEarnedReps = currentRuntime.earnedReps > 0;
    final bool wantsToKeepEarnedReps = _pendingKeepEarnedRepItemIds.contains(
      currentItemId,
    );

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
                  PatternReadout(
                    controller: widget.controller,
                    itemId: currentItemId,
                    patternStyle: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.8,
                        ),
                    voiceStyle: Theme.of(context).textTheme.titleMedium,
                    scrollable: false,
                    wrap: true,
                    cellWidth: 28,
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
                                  'You changed the BPM from ${currentRuntime.startingBpm} to ${currentRuntime.endingBpm}. Save it at ${currentRuntime.endingBpm}?',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Checkbox(
                            value: wantsToSaveBpm,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _pendingSaveBpmItemIds.add(currentItemId);
                                } else {
                                  _pendingSaveBpmItemIds.remove(currentItemId);
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (canKeepEarnedReps) ...<Widget>[
                    const SizedBox(height: 16),
                    DrumPanel(
                      tone: DrumPanelTone.green,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(Icons.add_task_rounded, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Keep Earned Reps',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Keep ${currentRuntime.earnedReps} earned ${currentRuntime.earnedReps == 1 ? 'rep' : 'reps'} from this session?',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Checkbox(
                            value: wantsToKeepEarnedReps,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _pendingKeepEarnedRepItemIds.add(
                                    currentItemId,
                                  );
                                } else {
                                  _pendingKeepEarnedRepItemIds.remove(
                                    currentItemId,
                                  );
                                }
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
                OutlinedButton(
                  onPressed: () {
                    _skipCurrentItem(session.id, currentItemId);
                  },
                  child: const Text('Skip'),
                ),
                OutlinedButton(
                  onPressed: (_control == null || _tension == null)
                      ? null
                      : () {
                          _submitCurrentItem(session.id, currentItemId);
                        },
                  child: const Text('Submit'),
                ),
                OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      widget.controller.buildSessionForItem(
                        currentItem.id,
                        practiceMode: session.practiceMode,
                        bpm: currentRuntime.endingBpm,
                      ),
                    );
                  },
                  child: const Text('Play It Again'),
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
    _pendingSaveBpmItemIds.remove(itemId);
    final PracticeSessionLogV1? session = widget.controller.sessionById(
      sessionId,
    );
    final PracticeSessionItemRuntimeV1? runtime = session == null
        ? null
        : widget.controller.sessionItemRuntimeFor(session, itemId);
    if ((runtime?.claimedReps ?? 0) > 0) {
      _pendingKeepEarnedRepItemIds.add(itemId);
    } else {
      _pendingKeepEarnedRepItemIds.remove(itemId);
    }
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

  void _submitCurrentItem(String sessionId, String itemId) {
    final PracticeSessionLogV1? session = widget.controller.sessionById(
      widget.sessionId,
    );
    if (session != null && _pendingSaveBpmItemIds.contains(itemId)) {
      final PracticeSessionItemRuntimeV1? runtime = widget.controller
          .sessionItemRuntimeFor(session, itemId);
      if (runtime != null) {
        widget.controller.rememberLaunchPreferencesForItem(
          itemId: itemId,
          bpm: runtime.endingBpm,
          timerPreset: widget.controller.launchTimerPresetForItem(itemId),
        );
      }
    }
    widget.controller.updateSessionEarnedRepsClaim(
      sessionId: sessionId,
      itemId: itemId,
      keepEarnedReps: _pendingKeepEarnedRepItemIds.contains(itemId),
    );
    _saveAssessment(sessionId, itemId);
    setState(() {
      _submittedItemIds.add(itemId);
      _skippedItemIds.remove(itemId);
      _pendingSaveBpmItemIds.remove(itemId);
      _pendingKeepEarnedRepItemIds.remove(itemId);
    });
    _advanceOrClose(sessionId, itemId);
  }

  void _skipCurrentItem(String sessionId, String itemId) {
    widget.controller.updateSessionEarnedRepsClaim(
      sessionId: sessionId,
      itemId: itemId,
      keepEarnedReps: false,
    );
    widget.controller.updateSessionAssessment(
      sessionId: sessionId,
      itemId: itemId,
      selfReportControl: null,
      selfReportTension: null,
      selfReportTempoReadiness: null,
    );
    setState(() {
      _control = null;
      _tension = null;
      _submittedItemIds.remove(itemId);
      _skippedItemIds.add(itemId);
      _pendingSaveBpmItemIds.remove(itemId);
      _pendingKeepEarnedRepItemIds.remove(itemId);
    });
    _advanceOrClose(sessionId, itemId);
  }

  void _advanceOrClose(String sessionId, String currentItemId) {
    final PracticeSessionLogV1? session = widget.controller.sessionById(
      widget.sessionId,
    );
    if (session == null) return;
    final int nextIndex = _nextPendingItemIndex(session, currentItemId);
    if (nextIndex == -1) {
      Navigator.of(context).pop();
      return;
    }
    _changeItem(session, nextIndex);
  }

  int _nextPendingItemIndex(
    PracticeSessionLogV1 session,
    String currentItemId,
  ) {
    final Set<String> handledItemIds = <String>{
      ..._submittedItemIds,
      ..._skippedItemIds,
    };
    handledItemIds.add(currentItemId);
    final int currentIndex = session.practiceItemIds.indexOf(currentItemId);
    for (
      int index = currentIndex + 1;
      index < session.practiceItemIds.length;
      index += 1
    ) {
      if (!handledItemIds.contains(session.practiceItemIds[index])) {
        return index;
      }
    }
    for (int index = 0; index < currentIndex; index += 1) {
      if (!handledItemIds.contains(session.practiceItemIds[index])) {
        return index;
      }
    }
    return -1;
  }

  _SessionRecommendation? _recommendationFor({
    required PracticeItemV1 item,
    required String itemId,
    required PracticeSessionItemRuntimeV1 runtime,
  }) {
    final bool incomplete = _control == null || _tension == null;
    if (incomplete) {
      return null;
    }

    final _TempoSignal tempoSignal = _tempoSignalFor(
      item: item,
      itemId: itemId,
      attemptedBpm: runtime.endingBpm,
    );
    final bool noAssessmentHistory = widget.controller
        .assessmentHistoryForItem(itemId)
        .isEmpty;

    final bool slowDown =
        _control == SelfReportControlV1.low ||
        _tension == SelfReportTensionV1.high;
    if (slowDown) {
      if (_control == SelfReportControlV1.low &&
          _tension == SelfReportTensionV1.high) {
        return const _SessionRecommendation(
          title: 'This rep was strained and unstable',
          body:
              'Control dropped and tension rose. Bring the motion down and get the shape back under your hands before pushing it.',
        );
      }
      if (_control == SelfReportControlV1.low) {
        return const _SessionRecommendation(
          title: 'This rep lost control',
          body:
              'The sticking is not holding together yet. Keep the motion smaller and get the cycle clean again first.',
        );
      }
      return const _SessionRecommendation(
        title: 'This rep carried extra tension',
        body:
            'The pattern may be holding, but the motion is tightening up. Stay relaxed before you ask for more tempo.',
      );
    }

    if (_control == SelfReportControlV1.high &&
        _tension == SelfReportTensionV1.none) {
      if (tempoSignal == _TempoSignal.high) {
        return _SessionRecommendation(
          title: 'That rep felt strong',
          body: _strongTempoBodyFor(
            item: item,
            itemId: itemId,
            noAssessmentHistory: noAssessmentHistory,
          ),
        );
      }
      return const _SessionRecommendation(
        title: 'That rep felt strong',
        body:
            'You played it cleanly and stayed relaxed. A few more reps like that will put it in the toolbox.',
      );
    }

    if (tempoSignal == _TempoSignal.high && noAssessmentHistory) {
      return const _SessionRecommendation(
        title: 'You are setting your level',
        body:
            'This is a strong tempo for this pattern. Back it off slightly and settle it in, then build from there.',
      );
    }

    if (tempoSignal == _TempoSignal.high) {
      return const _SessionRecommendation(
        title: 'This rep is close',
        body:
            'The tempo is there. Stay here a little longer and let the motion settle before you push it again.',
      );
    }

    return const _SessionRecommendation(
      title: 'Stay here a little longer',
      body:
          'Reduce the BPM slightly and focus on evenness. Speed will come naturally as you do this work.',
    );
  }

  _TempoSignal _tempoSignalFor({
    required PracticeItemV1 item,
    required String itemId,
    required int attemptedBpm,
  }) {
    final List<String> tokens = widget.controller.noteTokensFor(itemId);
    final bool hasKick = widget.controller.hasKick(itemId);
    final bool hasFlowVoices = widget.controller.hasNonSnareVoice(itemId);
    final bool singleHandTriad =
        tokens.length == 3 &&
        !hasKick &&
        (tokens.every((String token) => token == 'R') ||
            tokens.every((String token) => token == 'L'));
    final bool simpleHandTriad = tokens.length == 3 && !hasKick;

    if (singleHandTriad) {
      if (attemptedBpm >= 180) return _TempoSignal.high;
      if (attemptedBpm >= 150) return _TempoSignal.medium;
      return _TempoSignal.low;
    }

    if (simpleHandTriad) {
      if (attemptedBpm >= 140) return _TempoSignal.high;
      if (attemptedBpm >= 110) return _TempoSignal.medium;
      return _TempoSignal.low;
    }

    if (tokens.length > 3 || hasFlowVoices) {
      if (attemptedBpm >= 100) return _TempoSignal.high;
      if (attemptedBpm >= 80) return _TempoSignal.medium;
      return _TempoSignal.low;
    }

    if (hasKick) {
      if (attemptedBpm >= 120) return _TempoSignal.high;
      if (attemptedBpm >= 95) return _TempoSignal.medium;
      return _TempoSignal.low;
    }

    if (attemptedBpm >= 130) return _TempoSignal.high;
    if (attemptedBpm >= 100) return _TempoSignal.medium;
    return _TempoSignal.low;
  }

  String _strongTempoBodyFor({
    required PracticeItemV1 item,
    required String itemId,
    required bool noAssessmentHistory,
  }) {
    final List<String> tokens = widget.controller.noteTokensFor(itemId);
    final bool simpleHandTriad =
        tokens.length == 3 &&
        tokens.every((String token) => token == 'R' || token == 'L');
    final bool singleHandTriad =
        simpleHandTriad &&
        (tokens.every((String token) => token == 'R') ||
            tokens.every((String token) => token == 'L'));

    if (singleHandTriad) {
      return noAssessmentHistory
          ? 'You played a simple hand triad cleanly at a strong tempo. That gives the app a much better read on where your playing already is.'
          : 'You played a simple hand triad cleanly at a strong tempo. A little more work and it will be firmly in the toolbox.';
    }
    if (simpleHandTriad) {
      return noAssessmentHistory
          ? 'You played a simple hand triad cleanly at a strong tempo. That gives the app a much better read on where your playing already is.'
          : 'You played a simple hand triad cleanly at a strong tempo. A little more work and it will be firmly in the toolbox.';
    }
    return noAssessmentHistory
        ? 'You played this cleanly and stayed relaxed at a strong tempo. That gives the app a much better read on where your playing already is.'
        : 'You played this cleanly and stayed relaxed at a strong tempo. A few more reps like that will put it in the toolbox.';
  }
}

class _SessionRecommendation {
  final String title;
  final String body;

  const _SessionRecommendation({required this.title, required this.body});
}

enum _TempoSignal { low, medium, high }

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
