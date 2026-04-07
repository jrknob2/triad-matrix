import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import '../practice/widgets/pattern_marking_editor.dart';

class ItemDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final item = controller.itemById(itemId);
        final competency = controller.competencyFor(item.id);
        final totalTime = controller.totalTime(itemId: item.id);
        final sessionCount = controller.sessionCount(itemId: item.id);
        final List<String> tokens = controller.noteTokensFor(item.id);
        final List<PatternNoteMarkingV1> markings = controller.noteMarkingsFor(
          item.id,
        );

        return Scaffold(
          appBar: AppBar(title: const Text('Practice Items')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
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
                      PatternMarkingEditor(
                        controller: controller,
                        itemId: item.id,
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
                          DropdownButton<CompetencyLevelV1>(
                            value: competency,
                            onChanged: (CompetencyLevelV1? next) {
                              if (next != null) {
                                controller.updateCompetency(item.id, next);
                              }
                            },
                            items: CompetencyLevelV1.values
                                .map(
                                  (level) =>
                                      DropdownMenuItem<CompetencyLevelV1>(
                                        value: level,
                                        child: Text(level.label),
                                      ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        competency.label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF6B5D42),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        controller.competencyGuidanceFor(item.id, competency),
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
              Card(
                child: Column(
                  children: <Widget>[
                    ListTile(
                      title: const Text('Total Time'),
                      trailing: Text(formatDuration(totalTime)),
                    ),
                    ListTile(
                      title: const Text('Sessions'),
                      trailing: Text('$sessionCount'),
                    ),
                    ListTile(
                      title: const Text('Last Session'),
                      trailing: Text(controller.recentSummaryForItem(item.id)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Expanded(
                    child: FilledButton(
                      onPressed: () => onPracticeItem(item.id),
                      child: const Text('Single Surface'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: () =>
                          onPracticeItemInMode(item.id, PracticeModeV1.flow),
                      child: const Text('Flow'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onBuildComboFromItem(item.id),
                child: const Text('Build Phrase From This'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => controller.toggleRoutineItem(item.id),
                child: Text(
                  controller.isDirectRoutineEntry(item.id)
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
