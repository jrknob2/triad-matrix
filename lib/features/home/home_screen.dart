import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

class HomeScreen extends StatelessWidget {
  final AppController controller;
  final VoidCallback onStartPractice;
  final VoidCallback onGeneratePractice;
  final VoidCallback onContinueRoutine;
  final ValueChanged<String> onOpenItem;

  const HomeScreen({
    super.key,
    required this.controller,
    required this.onStartPractice,
    required this.onGeneratePractice,
    required this.onContinueRoutine,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final recentSessions = controller.recentSessions.take(4).toList();
        final routineItems = controller.routineItems.take(3).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _QuickStartCard(
              onStartPractice: onStartPractice,
              onGeneratePractice: onGeneratePractice,
              onContinueRoutine: onContinueRoutine,
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Currently Working On',
              child: routineItems.isEmpty
                  ? const Text('Build your first routine to keep active work visible.')
                  : Column(
                      children: routineItems
                          .map(
                            (item) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.name),
                              subtitle: Text(
                                '${item.family.label} · ${controller.competencyFor(item.id).label}',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => onOpenItem(item.id),
                            ),
                          )
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Recent Sessions',
              child: recentSessions.isEmpty
                  ? const Text('Start your first session to build history.')
                  : Column(
                      children: recentSessions
                          .map((session) {
                            final item = controller.itemById(session.practiceItemIds.first);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(item.name),
                              subtitle: Text(
                                '${formatShortDate(session.endedAt)} · '
                                '${session.context.label} · ${session.intent.label}',
                              ),
                              trailing: Text(formatDuration(session.duration)),
                              onTap: () => onOpenItem(item.id),
                            );
                          })
                          .toList(growable: false),
                    ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'This Week',
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  _StatChip(
                    label: 'Total',
                    value: formatDuration(controller.totalTime()),
                  ),
                  _StatChip(
                    label: 'Single Surface',
                    value: formatDuration(
                      controller.totalTime(context: PracticeContextV1.singleSurface),
                    ),
                  ),
                  _StatChip(
                    label: 'Kit',
                    value: formatDuration(
                      controller.totalTime(context: PracticeContextV1.kit),
                    ),
                  ),
                  _StatChip(
                    label: 'Triads',
                    value: formatDuration(
                      controller.totalTime(family: MaterialFamilyV1.triad),
                    ),
                  ),
                  _StatChip(
                    label: '5s',
                    value: formatDuration(
                      controller.totalTime(family: MaterialFamilyV1.fiveNote),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickStartCard extends StatelessWidget {
  final VoidCallback onStartPractice;
  final VoidCallback onGeneratePractice;
  final VoidCallback onContinueRoutine;

  const _QuickStartCard({
    required this.onStartPractice,
    required this.onGeneratePractice,
    required this.onContinueRoutine,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Quick Start', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onStartPractice,
              child: const Text('Start Practice'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onGeneratePractice,
              child: const Text('Generate For Me'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onContinueRoutine,
              child: const Text('Continue Routine'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
