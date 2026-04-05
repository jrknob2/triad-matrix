import 'package:flutter/material.dart';

import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

class RoutineScreen extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const RoutineScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final items = controller.routineItems;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(controller.routine.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('${items.length} active items'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: items.isEmpty
                          ? null
                          : () => onPracticeItem(items.first.id),
                      child: const Text('Start First Item'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Add items from the library to build your routine.'),
                ),
              )
            else
              ...items.map(
                (item) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(item.name),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${item.family.label} · '
                        '${controller.competencyFor(item.id).label}\n'
                        '${controller.recentSummaryForItem(item.id)}',
                      ),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      tooltip: 'Remove from Routine',
                      onPressed: () => controller.toggleRoutineItem(item.id),
                    ),
                    onTap: () => onOpenItem(item.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
