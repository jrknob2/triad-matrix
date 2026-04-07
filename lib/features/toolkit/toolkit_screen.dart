import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';

enum _FocusSection { workingOn, phraseWork, myPatterns }

class FocusScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const FocusScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  _FocusSection _section = _FocusSection.workingOn;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        return ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _FocusSummary(
                    controller: widget.controller,
                    onOpenItem: widget.onOpenItem,
                    onPracticeItem: widget.onPracticeItem,
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _FocusSection.values
                          .map(
                            (_FocusSection section) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(_labelForSection(section)),
                                selected: _section == section,
                                onSelected: (_) {
                                  setState(() => _section = section);
                                },
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
                ],
              ),
            ),
            _buildBody(),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    return switch (_section) {
      _FocusSection.workingOn => _FocusList(
        title: 'Working On',
        summary:
            'These are the assignments that should get repeated attention. This is coached work, not storage.',
        items: widget.controller.activeWorkItems,
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
        trailingFor: (item) => IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => widget.controller.toggleRoutineItem(item.id),
        ),
      ),
      _FocusSection.phraseWork => _FocusList(
        title: 'Phrase Work',
        summary:
            'Saved multi-triad phrases live here. Use them to build transitions, phrase length, and later flow on the kit.',
        items: widget.controller.phraseWorkItems,
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
      ),
      _FocusSection.myPatterns => _FocusList(
        title: 'My Patterns',
        summary:
            'Your own phrases live here. They are easy to revisit whenever you want, but they do not affect coaching, coverage, or toolbox readiness.',
        items: widget.controller.customBucketItems,
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
      ),
    };
  }

  String _labelForSection(_FocusSection section) {
    return switch (section) {
      _FocusSection.workingOn => 'Working On',
      _FocusSection.phraseWork => 'Phrase Work',
      _FocusSection.myPatterns => 'My Patterns',
    };
  }
}

class _FocusSummary extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const _FocusSummary({
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  Widget build(BuildContext context) {
    final List<PracticeItemV1> toolboxReady = controller.toolboxReadyItems
        .take(3)
        .toList();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Working On',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '${controller.activeWorkItems.length} active items • ${controller.phraseWorkItems.length} saved phrases • ${controller.customBucketItems.length} customs',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5B5345)),
            ),
            const SizedBox(height: 14),
            if (toolboxReady.isEmpty)
              Text(
                controller.isFirstLight
                    ? 'You are starting fresh. Pick a few solid cells, stay with them, and let the toolbox grow from real repetition.'
                    : 'Nothing is close to your toolbox yet. Stay with consistency and revisit the same few phrases.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else ...<Widget>[
              Text(
                'Close To Toolbox',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: toolboxReady
                      .map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: _ToolboxReadyChip(
                            item: item,
                            controller: controller,
                            onOpenItem: onOpenItem,
                            onPracticeItem: onPracticeItem,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ToolboxReadyChip extends StatelessWidget {
  final PracticeItemV1 item;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const _ToolboxReadyChip({
    required this.item,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onOpenItem(item.id),
      onLongPress: () => onPracticeItem(item.id),
      child: Ink(
        width: 170,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F5EC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFB5882D), width: 1.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            PatternDisplayText(
              tokens: controller.noteTokensFor(item.id),
              markings: controller.noteMarkingsFor(item.id),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${controller.competencyFor(item.id).label} • ${formatDuration(controller.totalTime(itemId: item.id))}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xFF5B5345)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusList extends StatelessWidget {
  final String title;
  final String summary;
  final List<PracticeItemV1> items;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final Widget Function(PracticeItemV1 item)? trailingFor;

  const _FocusList({
    required this.title,
    required this.summary,
    required this.items,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    this.trailingFor,
  });

  @override
  Widget build(BuildContext context) {
    final Duration totalLoggedTime = items.fold<Duration>(
      Duration.zero,
      (Duration sum, PracticeItemV1 item) =>
          sum + controller.totalTime(itemId: item.id),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(summary, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(
            '${items.length == 1 ? '1 item' : '${items.length} items'} • ${formatDuration(totalLoggedTime)} logged',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5B5345)),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  controller.isFirstLight
                      ? 'Nothing is in this section yet. Build a phrase from the matrix or start practicing and let this area fill in from real work.'
                      : 'Nothing here yet. Add material from the matrix or save a custom phrase for later.',
                ),
              ),
            )
          else
            ...items.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      PatternDisplayText(
                        tokens: controller.noteTokensFor(item.id),
                        markings: controller.noteMarkingsFor(item.id),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${controller.competencyFor(item.id).label} • ${formatDuration(controller.totalTime(itemId: item.id))}',
                      ),
                    ],
                  ),
                  trailing: trailingFor?.call(item),
                  onTap: () => onOpenItem(item.id),
                  onLongPress: () => onPracticeItem(item.id),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
