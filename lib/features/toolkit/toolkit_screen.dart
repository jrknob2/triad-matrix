import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';

enum _ToolkitSection { routine, combos, custom }

class ToolkitScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final VoidCallback onBuildCombo;
  final VoidCallback onCreateCustomPattern;

  const ToolkitScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onBuildCombo,
    required this.onCreateCustomPattern,
  });

  @override
  State<ToolkitScreen> createState() => _ToolkitScreenState();
}

class _ToolkitScreenState extends State<ToolkitScreen> {
  _ToolkitSection _section = _ToolkitSection.routine;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: <Widget>[
                  SegmentedButton<_ToolkitSection>(
                    segments: const <ButtonSegment<_ToolkitSection>>[
                      ButtonSegment(
                        value: _ToolkitSection.routine,
                        label: Text('Routine'),
                      ),
                      ButtonSegment(
                        value: _ToolkitSection.combos,
                        label: Text('Combos'),
                      ),
                      ButtonSegment(
                        value: _ToolkitSection.custom,
                        label: Text('Custom'),
                      ),
                    ],
                    selected: <_ToolkitSection>{_section},
                    onSelectionChanged: (Set<_ToolkitSection> selection) {
                      setState(() => _section = selection.first);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: widget.onBuildCombo,
                          child: const Text('Build Combo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: widget.onCreateCustomPattern,
                          child: const Text('New Custom'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    return switch (_section) {
      _ToolkitSection.routine => _ToolkitList(
        title: widget.controller.routine.name,
        items: widget.controller.routineItems,
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
        trailingFor: (item) => IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => widget.controller.toggleRoutineItem(item.id),
        ),
      ),
      _ToolkitSection.combos => _ToolkitList(
        title: 'Saved Combos',
        items: widget.controller.itemsByFamily(MaterialFamilyV1.combo),
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
      ),
      _ToolkitSection.custom => _ToolkitList(
        title: 'Custom Patterns',
        items: widget.controller.itemsByFamily(MaterialFamilyV1.custom),
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
      ),
    };
  }
}

class _ToolkitList extends StatelessWidget {
  final String title;
  final List<PracticeItemV1> items;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final Widget Function(PracticeItemV1 item)? trailingFor;

  const _ToolkitList({
    required this.title,
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: <Widget>[
                    _ToolkitStatChip(
                      label: items.length == 1
                          ? '1 item'
                          : '${items.length} items',
                    ),
                    _ToolkitStatChip(
                      label: '${formatDuration(totalLoggedTime)} logged',
                    ),
                    const _ToolkitStatChip(label: 'Tap to open'),
                    const _ToolkitStatChip(label: 'Hold to practice'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nothing here yet. Add material from the matrix or custom editor.',
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
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${controller.competencyFor(item.id).label} · '
                      '${formatDuration(controller.totalTime(itemId: item.id))}',
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
    );
  }
}

class _ToolkitStatChip extends StatelessWidget {
  final String label;

  const _ToolkitStatChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF3EBDD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
