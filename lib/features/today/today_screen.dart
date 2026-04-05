import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

class TodayScreen extends StatelessWidget {
  final AppController controller;
  final VoidCallback onOpenMatrix;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const TodayScreen({
    super.key,
    required this.controller,
    required this.onOpenMatrix,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final briefing = controller.buildTodayBriefing();

        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xFFF7E8C7),
                Color(0xFFF3F1EA),
              ],
            ),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              _TodayHero(
                headline: briefing.headline,
                summary: briefing.summary,
                onOpenMatrix: onOpenMatrix,
              ),
              const SizedBox(height: 16),
              ...briefing.cues.map(
                (cue) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CoachCueCard(
                    title: cue.title,
                    detail: cue.detail,
                    itemIds: cue.suggestedItemIds,
                    controller: controller,
                    onOpenItem: onOpenItem,
                    onPracticeItem: onPracticeItem,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _TodaySection(
                title: 'Context Split',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: <Widget>[
                    _ContextTile(
                      title: 'Single Surface',
                      value: formatDuration(
                        controller.totalTime(
                          context: PracticeContextV1.singleSurface,
                        ),
                      ),
                      note: 'Control, accents, weak-hand work',
                    ),
                    _ContextTile(
                      title: 'Kit Flow',
                      value: formatDuration(
                        controller.totalTime(
                          context: PracticeContextV1.kit,
                        ),
                      ),
                      note: 'Movement, landing, phrasing',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TodayHero extends StatelessWidget {
  final String headline;
  final String summary;
  final VoidCallback onOpenMatrix;

  const _TodayHero({
    required this.headline,
    required this.summary,
    required this.onOpenMatrix,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: <Color>[
            Color(0xFF133E62),
            Color(0xFF2C6A6A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Today',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: const Color(0xFFD8E8E4),
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              headline,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              summary,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFE8F2EF),
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onOpenMatrix,
              icon: const Icon(Icons.grid_view_rounded),
              label: const Text('Open Matrix'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFF4C95D),
                foregroundColor: const Color(0xFF24323A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachCueCard extends StatelessWidget {
  final String title;
  final String detail;
  final List<String> itemIds;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const _CoachCueCard({
    required this.title,
    required this.detail,
    required this.itemIds,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> chips = itemIds
        .map((itemId) {
          final item = controller.itemById(itemId);
          return ActionChip(
            label: Text(item.name),
            avatar: Text(controller.accentPatternLabelFor(itemId)),
            onPressed: () => onPracticeItem(itemId),
          );
        })
        .toList(growable: false);

    return Card(
      elevation: 1,
      clipBehavior: Clip.hardEdge,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(detail, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
            if (itemIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => onOpenItem(itemIds.first),
                child: const Text('Open First Recommendation'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  final String title;
  final Widget child;

  const _TodaySection({
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
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _ContextTile extends StatelessWidget {
  final String title;
  final String value;
  final String note;

  const _ContextTile({
    required this.title,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(note, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
