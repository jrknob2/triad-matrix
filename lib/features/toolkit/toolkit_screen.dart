import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import '../practice/widgets/pattern_voice_display.dart';

class FocusScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final VoidCallback onOpenMatrix;

  const FocusScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItemInMode,
    required this.onOpenMatrix,
  });

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  PracticeModeV1 _viewMode = PracticeModeV1.singleSurface;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final List<PracticeItemV1> allItems = widget.controller.activeWorkItems;
        final List<PracticeItemV1> visibleItems =
            _viewMode == PracticeModeV1.flow
            ? allItems
                  .where(
                    (PracticeItemV1 item) =>
                        widget.controller.hasNonSnareVoice(item.id),
                  )
                  .toList(growable: false)
            : allItems;

        return DrumScreen(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              DrumPanel(
                tone: DrumPanelTone.warm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const DrumSectionTitle(text: 'Working On'),
                    const SizedBox(height: 8),
                    Text(
                      'Keep this list short. These are the patterns and phrases getting your attention right now.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5B5345),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    DrumActionRow(
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: widget.onOpenMatrix,
                          icon: const Icon(Icons.grid_view_rounded),
                          label: const Text('Add From Matrix'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: PracticeModeV1.values
                      .map(
                        (PracticeModeV1 mode) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: DrumSelectablePill(
                            label: Text(
                              mode.label,
                              style: TextStyle(
                                color: _viewMode == mode ? Colors.white : null,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            selected: _viewMode == mode,
                            onPressed: () => setState(() => _viewMode = mode),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 14),
              if (allItems.isEmpty)
                _FocusEmptyState(onOpenMatrix: widget.onOpenMatrix)
              else if (visibleItems.isEmpty)
                const _FocusFlowEmptyState()
              else
                ...visibleItems.map(
                  (PracticeItemV1 item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FocusItemCard(
                      controller: widget.controller,
                      item: item,
                      practiceMode: _viewMode,
                      onOpenItem: widget.onOpenItem,
                      onPracticeItemInMode: widget.onPracticeItemInMode,
                      onRemoveItem: () =>
                          widget.controller.toggleRoutineItem(item.id),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FocusEmptyState extends StatelessWidget {
  final VoidCallback onOpenMatrix;

  const _FocusEmptyState({required this.onOpenMatrix});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const DrumSectionTitle(text: 'Nothing In Working On'),
          const SizedBox(height: 8),
          Text(
            'Add a few items from Coach or Matrix. This screen is only for the material you are actively trying to develop now.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF5E584D),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onOpenMatrix,
            child: const Text('Open Matrix'),
          ),
        ],
      ),
    );
  }
}

class _FocusFlowEmptyState extends StatelessWidget {
  const _FocusFlowEmptyState();

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Text(
        'Nothing in Working On has a flow voice assignment yet. Open an item and assign at least one non-snare voice before practicing it in Flow.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF5E584D)),
      ),
    );
  }
}

class _FocusItemCard extends StatelessWidget {
  final AppController controller;
  final PracticeItemV1 item;
  final PracticeModeV1 practiceMode;
  final ValueChanged<String> onOpenItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final VoidCallback onRemoveItem;

  const _FocusItemCard({
    required this.controller,
    required this.item,
    required this.practiceMode,
    required this.onOpenItem,
    required this.onPracticeItemInMode,
    required this.onRemoveItem,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
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
                    patternStyle: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                    voiceStyle: Theme.of(context).textTheme.labelMedium,
                    grouping: controller.displayGroupingFor(item.id),
                    showRepeatIndicator: false,
                  )
                else
                  PatternDisplayText(
                    tokens: controller.noteTokensFor(item.id),
                    markings: controller.noteMarkingsFor(item.id),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                    grouping: controller.displayGroupingFor(item.id),
                  ),
                const SizedBox(height: 6),
                Text(
                  '${item.family.label} • ${controller.matrixProgressStateFor(item.id).label}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6A5E4C),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatDuration(controller.totalTime(itemId: item.id))} logged',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6A5E4C),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
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
          ),
        ],
      ),
    );
  }
}
