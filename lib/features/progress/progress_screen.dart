import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

enum _ProgressSection {
  competency,
  time,
  coverage,
  contexts,
}

class ProgressScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const ProgressScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
  });

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  _ProgressSection _section = _ProgressSection.competency;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SegmentedButton<_ProgressSection>(
                segments: const <ButtonSegment<_ProgressSection>>[
                  ButtonSegment(
                    value: _ProgressSection.competency,
                    label: Text('Competency'),
                  ),
                  ButtonSegment(
                    value: _ProgressSection.time,
                    label: Text('Time'),
                  ),
                  ButtonSegment(
                    value: _ProgressSection.coverage,
                    label: Text('Coverage'),
                  ),
                  ButtonSegment(
                    value: _ProgressSection.contexts,
                    label: Text('Contexts'),
                  ),
                ],
                selected: <_ProgressSection>{_section},
                onSelectionChanged: (Set<_ProgressSection> next) {
                  setState(() => _section = next.first);
                },
              ),
            ),
            Expanded(child: _buildSection(context)),
          ],
        );
      },
    );
  }

  Widget _buildSection(BuildContext context) {
    return switch (_section) {
      _ProgressSection.competency => _CompetencyView(
          controller: widget.controller,
          onOpenItem: widget.onOpenItem,
        ),
      _ProgressSection.time => _TimeView(controller: widget.controller),
      _ProgressSection.coverage => _CoverageView(
          controller: widget.controller,
          onOpenItem: widget.onOpenItem,
        ),
      _ProgressSection.contexts => _ContextsView(controller: widget.controller),
    };
  }
}

class _CompetencyView extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const _CompetencyView({
    required this.controller,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    final items = controller.items.toList()
      ..sort((a, b) => controller
          .competencyFor(a.id)
          .index
          .compareTo(controller.competencyFor(b.id).index));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length + 1,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: const Text('Overall Player Level'),
              subtitle: Text(controller.profile.selfRank.label),
            ),
          );
        }

        final item = items[index - 1];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(item.name),
            subtitle: Text(
              '${item.family.label} · ${controller.competencyFor(item.id).label}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onOpenItem(item.id),
          ),
        );
      },
    );
  }
}

class _TimeView extends StatelessWidget {
  final AppController controller;

  const _TimeView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _TimeCard(
          title: 'Total Time',
          value: formatDuration(controller.totalTime()),
        ),
        _TimeCard(
          title: 'Triads',
          value: formatDuration(controller.totalTime(family: MaterialFamilyV1.triad)),
        ),
        _TimeCard(
          title: '5-Note Groupings',
          value: formatDuration(controller.totalTime(family: MaterialFamilyV1.fiveNote)),
        ),
        _TimeCard(
          title: 'Custom',
          value: formatDuration(controller.totalTime(family: MaterialFamilyV1.custom)),
        ),
        _TimeCard(
          title: 'Combos',
          value: formatDuration(controller.totalTime(family: MaterialFamilyV1.combo)),
        ),
      ],
    );
  }
}

class _CoverageView extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const _CoverageView({
    required this.controller,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    final triads = controller.itemsNeedingPractice(MaterialFamilyV1.triad).take(3).toList();
    final fives =
        controller.itemsNeedingPractice(MaterialFamilyV1.fiveNote).take(3).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _CoverageCard(
          title: 'Triads Needing Attention',
          items: triads,
          controller: controller,
          onOpenItem: onOpenItem,
        ),
        const SizedBox(height: 12),
        _CoverageCard(
          title: '5s Needing Attention',
          items: fives,
          controller: controller,
          onOpenItem: onOpenItem,
        ),
      ],
    );
  }
}

class _ContextsView extends StatelessWidget {
  final AppController controller;

  const _ContextsView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        _TimeCard(
          title: 'Single Surface',
          value: formatDuration(
            controller.totalTime(context: PracticeContextV1.singleSurface),
          ),
        ),
        _TimeCard(
          title: 'Kit',
          value: formatDuration(
            controller.totalTime(context: PracticeContextV1.kit),
          ),
        ),
        _TimeCard(
          title: 'Core Skills',
          value: formatDuration(
            controller.totalTime(intent: PracticeIntentV1.coreSkills),
          ),
        ),
        _TimeCard(
          title: 'Flow',
          value: formatDuration(
            controller.totalTime(intent: PracticeIntentV1.flow),
          ),
        ),
      ],
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String title;
  final String value;

  const _TimeCard({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(title),
        trailing: Text(value),
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  final String title;
  final List<PracticeItemV1> items;
  final AppController controller;
  final ValueChanged<String> onOpenItem;

  const _CoverageCard({
    required this.title,
    required this.items,
    required this.controller,
    required this.onOpenItem,
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
            if (items.isEmpty)
              const Text('Nothing to show yet.')
            else
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(item.name),
                  subtitle: Text(
                    '${controller.competencyFor(item.id).label} · '
                    '${formatDuration(controller.totalTime(itemId: item.id))}',
                  ),
                  onTap: () => onOpenItem(item.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
