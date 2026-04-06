import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';

enum _FocusSection { workingOn, combos, custom }

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
        return Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
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
            Expanded(child: _buildBody()),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    return switch (_section) {
      _FocusSection.workingOn => _FocusList(
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
      _FocusSection.combos => _FocusList(
        title: 'Saved Combos',
        items: widget.controller.itemsByFamily(MaterialFamilyV1.combo),
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
      ),
      _FocusSection.custom => _FocusList(
        title: 'Custom Bucket',
        items: widget.controller.itemsByFamily(MaterialFamilyV1.custom),
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
      ),
    };
  }

  String _labelForSection(_FocusSection section) {
    return switch (section) {
      _FocusSection.workingOn => 'Working On',
      _FocusSection.combos => 'Combos',
      _FocusSection.custom => 'Custom',
    };
  }
}

class _FocusList extends StatelessWidget {
  final String title;
  final List<PracticeItemV1> items;
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final Widget Function(PracticeItemV1 item)? trailingFor;

  const _FocusList({
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
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '$title · ${items.length == 1 ? '1 item' : '${items.length} items'} · ${formatDuration(totalLoggedTime)} logged',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5B5345)),
          ),
        ),
        if (items.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Nothing here yet. Add material from the matrix or save a custom phrase for later.',
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
