import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import '../practice/widgets/pattern_voice_display.dart';

enum _FocusSection { workingOn, phraseWork, myPatterns }

class FocusScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final ValueChanged<PracticeModeV1> onPracticeWorkingOn;
  final VoidCallback onPracticeWarmup;

  const FocusScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onPracticeItemInMode,
    required this.onPracticeWorkingOn,
    required this.onPracticeWarmup,
  });

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  _FocusSection _section = _FocusSection.workingOn;
  PracticeModeV1 _viewMode = PracticeModeV1.singleSurface;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        return DrumScreen(
          child: ListView(
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
                      onPracticeWorkingOn: widget.onPracticeWorkingOn,
                      onPracticeWarmup: widget.onPracticeWarmup,
                      practiceMode: _viewMode,
                    ),
                    const SizedBox(height: 14),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _FocusSection.values
                            .map(
                              (_FocusSection section) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: DrumSelectablePill(
                                  label: _chipText(
                                    _labelForSection(section),
                                    _section == section,
                                  ),
                                  selected: _section == section,
                                  onPressed: () {
                                    setState(() => _section = section);
                                  },
                                ),
                              ),
                            )
                            .toList(growable: false),
                      ),
                    ),
                    if (_section == _FocusSection.workingOn) ...<Widget>[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: PracticeModeV1.values
                              .map(
                                (PracticeModeV1 mode) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: DrumSelectablePill(
                                    label: _chipText(
                                      mode.label,
                                      _viewMode == mode,
                                    ),
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
                    ],
                  ],
                ),
              ),
              _buildBody(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    return switch (_section) {
      _FocusSection.workingOn => _FocusList(
        title: 'Working On',
        summary: 'These are the assignments getting repeated attention.',
        items: widget.controller.activeWorkItems,
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
        onPracticeItemInMode: widget.onPracticeItemInMode,
        practiceMode: _viewMode,
        trailingFor: (item) => _WorkingOnActions(
          item: item,
          practiceMode: _viewMode,
          onPracticeItemInMode: widget.onPracticeItemInMode,
          onOpenItem: widget.onOpenItem,
          onRemoveItem: () => widget.controller.toggleRoutineItem(item.id),
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
        onPracticeItemInMode: widget.onPracticeItemInMode,
        practiceMode: PracticeModeV1.singleSurface,
      ),
      _FocusSection.myPatterns => _FocusList(
        title: 'My Patterns',
        summary:
            'Your own phrases live here. They are easy to revisit whenever you want, but they do not affect coaching, coverage, or toolbox readiness.',
        items: widget.controller.customBucketItems,
        controller: widget.controller,
        onOpenItem: widget.onOpenItem,
        onPracticeItem: widget.onPracticeItem,
        onPracticeItemInMode: widget.onPracticeItemInMode,
        practiceMode: PracticeModeV1.singleSurface,
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

  Widget _chipText(String label, bool selected) {
    return Text(
      label,
      style: TextStyle(
        color: selected ? Colors.white : null,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _FocusSummary extends StatelessWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final ValueChanged<PracticeModeV1> onPracticeWorkingOn;
  final VoidCallback onPracticeWarmup;
  final PracticeModeV1 practiceMode;

  const _FocusSummary({
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onPracticeWorkingOn,
    required this.onPracticeWarmup,
    required this.practiceMode,
  });

  @override
  Widget build(BuildContext context) {
    final List<PracticeItemV1> toolboxReady = controller.toolboxReadyItems
        .take(3)
        .toList();
    final bool canPracticeWorkingOn = controller.activeWorkItems.any(
      (PracticeItemV1 item) =>
          practiceMode == PracticeModeV1.singleSurface ||
          controller.hasNonSnareVoice(item.id),
    );

    return DrumPanel(
      tone: DrumPanelTone.warm,
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const DrumSectionTitle(text: 'Working On'),
            const SizedBox(height: 6),
            Text(
              '${controller.activeWorkItems.length} active items • ${controller.phraseWorkItems.length} saved phrases • ${controller.customBucketItems.length} My Patterns',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5B5345)),
            ),
            const SizedBox(height: 14),
            DrumActionRow(
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: canPracticeWorkingOn
                      ? () => onPracticeWorkingOn(practiceMode)
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Practice Working On'),
                ),
                OutlinedButton.icon(
                  onPressed: onPracticeWarmup,
                  icon: const Icon(Icons.local_fire_department_outlined),
                  label: const Text('Warm Up'),
                ),
              ],
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
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final PracticeModeV1 practiceMode;
  final Widget Function(PracticeItemV1 item)? trailingFor;

  const _FocusList({
    required this.title,
    required this.summary,
    required this.items,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onPracticeItemInMode,
    required this.practiceMode,
    this.trailingFor,
  });

  @override
  Widget build(BuildContext context) {
    final List<PracticeItemV1> visibleItems =
        practiceMode == PracticeModeV1.flow
        ? items
              .where(
                (PracticeItemV1 item) => controller.hasNonSnareVoice(item.id),
              )
              .toList(growable: false)
        : items;
    final Duration totalLoggedTime = visibleItems.fold<Duration>(
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
            '${visibleItems.length == 1 ? '1 item' : '${visibleItems.length} items'} • ${formatDuration(totalLoggedTime)} logged',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: const Color(0xFF5B5345)),
          ),
          const SizedBox(height: 12),
          if (visibleItems.isEmpty)
            DrumPanel(
              child: Text(
                practiceMode == PracticeModeV1.flow
                    ? 'Nothing here has a Flow voice assignment yet. Open a practice item, switch to Flow, and assign at least one non-snare voice.'
                    : controller.isFirstLight
                    ? 'Nothing is in this section yet. Build a phrase from the Matrix or start practicing and let this area fill in from real work.'
                    : 'Nothing here yet. Add material from the Matrix or save a custom phrase for later.',
              ),
            )
          else
            ...visibleItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DrumPanel(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onOpenItem(item.id),
                    onLongPress: () =>
                        onPracticeItemInMode(item.id, practiceMode),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              if (practiceMode == PracticeModeV1.flow)
                                PatternVoiceDisplay(
                                  tokens: controller.noteTokensFor(item.id),
                                  markings: controller.noteMarkingsFor(item.id),
                                  voices: controller.noteVoicesFor(item.id),
                                  patternStyle: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.5,
                                      ),
                                  voiceStyle: Theme.of(
                                    context,
                                  ).textTheme.labelMedium,
                                  cellWidth: 34,
                                )
                              else
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
                        ),
                        if (trailingFor != null) ...<Widget>[
                          const SizedBox(width: 8),
                          trailingFor!(item),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkingOnActions extends StatelessWidget {
  final PracticeItemV1 item;
  final PracticeModeV1 practiceMode;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final ValueChanged<String> onOpenItem;
  final VoidCallback onRemoveItem;

  const _WorkingOnActions({
    required this.item,
    required this.practiceMode,
    required this.onPracticeItemInMode,
    required this.onOpenItem,
    required this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 2,
      children: <Widget>[
        IconButton(
          tooltip: 'Practice',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.play_arrow_rounded),
          onPressed: () => onPracticeItemInMode(item.id, practiceMode),
        ),
        IconButton(
          tooltip: 'Edit',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => onOpenItem(item.id),
        ),
        IconButton(
          tooltip: 'Remove from Working On',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: onRemoveItem,
        ),
      ],
    );
  }
}
