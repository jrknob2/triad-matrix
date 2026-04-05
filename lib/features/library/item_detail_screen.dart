import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

class ItemDetailScreen extends StatelessWidget {
  final AppController controller;
  final String itemId;
  final ValueChanged<String> onPracticeItem;
  final ValueChanged<String> onBuildComboFromItem;

  const ItemDetailScreen({
    super.key,
    required this.controller,
    required this.itemId,
    required this.onPracticeItem,
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
        final singleSurfaceTime = controller.totalTime(
          itemId: item.id,
          context: PracticeContextV1.singleSurface,
        );
        final kitTime = controller.totalTime(
          itemId: item.id,
          context: PracticeContextV1.kit,
        );

        return Scaffold(
          appBar: AppBar(title: Text(item.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(item.sticking, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          Chip(label: Text(item.family.label)),
                          ...item.tags.map((tag) => Chip(label: Text(tag))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  title: const Text('Competency'),
                  subtitle: Text(competency.label),
                  trailing: DropdownButton<CompetencyLevelV1>(
                    value: competency,
                    onChanged: (CompetencyLevelV1? next) {
                      if (next != null) controller.updateCompetency(item.id, next);
                    },
                    items: CompetencyLevelV1.values
                        .map(
                          (level) => DropdownMenuItem<CompetencyLevelV1>(
                            value: level,
                            child: Text(level.label),
                          ),
                        )
                        .toList(growable: false),
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
                      title: const Text('Single Surface'),
                      trailing: Text(formatDuration(singleSurfaceTime)),
                    ),
                    ListTile(
                      title: const Text('Kit'),
                      trailing: Text(formatDuration(kitTime)),
                    ),
                    ListTile(
                      title: const Text('Last Session'),
                      trailing: Text(controller.recentSummaryForItem(item.id)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => onPracticeItem(item.id),
                child: const Text('Practice Now'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => onBuildComboFromItem(item.id),
                child: const Text('Build Combo From This'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => controller.toggleRoutineItem(item.id),
                child: Text(
                  controller.isInRoutine(item.id)
                      ? 'Remove from Routine'
                      : 'Add to Routine',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
