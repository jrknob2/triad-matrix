import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import '../practice/widgets/pattern_marking_editor.dart';
import '../practice/widgets/pattern_voice_display.dart';
import '../practice/widgets/voice_assignment_editor.dart';

class ItemDetailScreen extends StatefulWidget {
  final AppController controller;
  final String itemId;
  final ValueChanged<String> onPracticeItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final ValueChanged<String> onBuildComboFromItem;

  const ItemDetailScreen({
    super.key,
    required this.controller,
    required this.itemId,
    required this.onPracticeItem,
    required this.onPracticeItemInMode,
    required this.onBuildComboFromItem,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  PracticeModeV1 _viewMode = PracticeModeV1.singleSurface;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final PracticeItemV1 item = widget.controller.itemById(widget.itemId);
        final CompetencyLevelV1 competency = widget.controller.competencyFor(
          item.id,
        );
        final Duration totalTime = widget.controller.totalTime(itemId: item.id);
        final int sessionCount = widget.controller.sessionCount(
          itemId: item.id,
        );
        final List<String> tokens = widget.controller.noteTokensFor(item.id);
        final List<PatternNoteMarkingV1> markings = widget.controller
            .noteMarkingsFor(item.id);
        final List<DrumVoiceV1> voices = widget.controller.noteVoicesFor(
          item.id,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Practice Item')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              DrumPanel(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: PracticeModeV1.values
                              .map(
                                (PracticeModeV1 mode) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: DrumSelectablePill(
                                    label: Text(mode.label),
                                    selected: _viewMode == mode,
                                    onPressed: () {
                                      setState(() => _viewMode = mode);
                                    },
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_viewMode == PracticeModeV1.flow)
                        PatternVoiceDisplay(
                          tokens: tokens,
                          markings: markings,
                          voices: voices,
                          patternStyle: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                          voiceStyle: Theme.of(context).textTheme.titleMedium,
                        )
                      else
                        PatternDisplayText(
                          tokens: tokens,
                          markings: markings,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'Accents & Ghosts',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      PatternMarkingEditor(
                        controller: widget.controller,
                        itemId: item.id,
                        showHelpText: false,
                      ),
                      if (_viewMode == PracticeModeV1.flow) ...<Widget>[
                        const SizedBox(height: 16),
                        Text(
                          'Flow Voices',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        VoiceAssignmentEditor(
                          controller: widget.controller,
                          itemId: item.id,
                          showHelpText: false,
                        ),
                        const SizedBox(height: 12),
                        _FlowReadinessNote(
                          ready: widget.controller.hasNonSnareVoice(item.id),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DrumPanel(
                child: Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'Competency',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          PopupMenuButton<CompetencyLevelV1>(
                            onSelected: (CompetencyLevelV1 next) {
                              widget.controller.updateCompetency(item.id, next);
                            },
                            itemBuilder: (BuildContext context) =>
                                CompetencyLevelV1.values
                                    .map(
                                      (CompetencyLevelV1 level) =>
                                          PopupMenuItem<CompetencyLevelV1>(
                                            value: level,
                                            child: Text(level.label),
                                          ),
                                    )
                                    .toList(growable: false),
                            child: DrumTag(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Text(
                                    competency.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.expand_more, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const SizedBox(height: 10),
                      Text(
                        widget.controller.competencyGuidanceFor(
                          item.id,
                          competency,
                        ),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF5B5345),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DrumPanel(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      title: const Text('Logged Time'),
                      trailing: Text(formatDuration(totalTime)),
                    ),
                    ListTile(
                      title: const Text('Sessions'),
                      trailing: Text('$sessionCount'),
                    ),
                    ListTile(
                      title: const Text('Last Worked'),
                      trailing: Text(
                        widget.controller.recentSummaryForItem(item.id),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () =>
                    widget.onPracticeItemInMode(item.id, _viewMode),
                child: Text(
                  _viewMode == PracticeModeV1.flow
                      ? 'Practice in Flow'
                      : 'Practice on One Surface',
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => widget.onBuildComboFromItem(item.id),
                child: const Text('Open in Matrix'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => widget.controller.toggleRoutineItem(item.id),
                child: Text(
                  widget.controller.isDirectRoutineEntry(item.id)
                      ? 'Remove from Working On'
                      : 'Add to Working On',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FlowReadinessNote extends StatelessWidget {
  final bool ready;

  const _FlowReadinessNote({required this.ready});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ready ? const Color(0xFFDDEDDD) : const Color(0xFFF1ECE3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          ready
              ? 'The voices are set. Keep the sticking the same and let the voices do the moving.'
              : 'Set at least one note off the snare before you treat this as flow.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
