import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import '../practice/widgets/pattern_voice_display.dart';

enum _FocusViewFilter { all, flow }

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
  _FocusViewFilter _viewFilter = _FocusViewFilter.all;
  late final TextEditingController _searchController;
  String _searchQuery = '';
  int _visibleItemCount = 5;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, _) {
        final List<PracticeItemV1> allItems = widget.controller.activeWorkItems;
        final bool hasSearch = _searchQuery.trim().isNotEmpty;
        final List<PracticeItemV1> searchSource = widget.controller.items
            .where((PracticeItemV1 item) => !item.isWarmup)
            .toList(growable: false);
        final List<PracticeItemV1> visibleItems =
            (hasSearch
                    ? searchSource.where(
                        (PracticeItemV1 item) =>
                            _matchesSearch(item, _searchQuery),
                      )
                    : allItems)
                .where(_matchesViewFilter)
                .toList(growable: false)
              ..sort(_compareVisibleItems);

        return DrumScreen(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (String value) => setState(() {
                        _searchQuery = value;
                        _visibleItemCount = 5;
                      }),
                      decoration: const InputDecoration(
                        hintText: 'Search all practice items',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: widget.onOpenMatrix,
                    child: const Text('New'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _FocusViewFilter.values
                      .map(
                        (_FocusViewFilter filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: DrumSelectablePill(
                            label: Text(
                              _labelForViewFilter(filter),
                              style: TextStyle(
                                color: _viewFilter == filter
                                    ? Colors.white
                                    : null,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            selected: _viewFilter == filter,
                            onPressed: () => setState(() {
                              _viewFilter = filter;
                              _visibleItemCount = 5;
                            }),
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
              const SizedBox(height: 14),
              if (!hasSearch && allItems.isEmpty)
                _FocusEmptyState(onOpenMatrix: widget.onOpenMatrix)
              else if (visibleItems.isEmpty)
                _FocusSearchEmptyState(
                  hasSearch: hasSearch,
                  filterLabel: _labelForViewFilter(_viewFilter),
                )
              else
                ...visibleItems
                    .take(_visibleItemCount)
                    .map(
                      (PracticeItemV1 item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: widget.controller.isDirectRoutineEntry(item.id)
                            ? _FocusItemCard(
                                controller: widget.controller,
                                item: item,
                                onOpenItem: widget.onOpenItem,
                                onPracticeItemInMode:
                                    widget.onPracticeItemInMode,
                                onRemoveItem: () => widget.controller
                                    .toggleRoutineItem(item.id),
                              )
                            : _SearchResultCard(
                                controller: widget.controller,
                                item: item,
                                onOpenItem: widget.onOpenItem,
                                onAddItem: () => widget.controller
                                    .toggleRoutineItem(item.id),
                              ),
                      ),
                    ),
              if (visibleItems.length > _visibleItemCount)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      _visibleItemCount += 5;
                    }),
                    child: const Text('Show More'),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _matchesSearch(PracticeItemV1 item, String query) {
    final String normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    final String haystack = <String>[
      item.name,
      item.sticking,
      item.family.label,
      ...item.tags,
    ].join(' ').toLowerCase();
    return haystack.contains(normalized);
  }

  bool _matchesViewFilter(PracticeItemV1 item) {
    return switch (_viewFilter) {
      _FocusViewFilter.all => true,
      _FocusViewFilter.flow => widget.controller.hasNonSnareVoice(item.id),
    };
  }

  int _compareVisibleItems(PracticeItemV1 a, PracticeItemV1 b) {
    final bool aInRoutine = widget.controller.isDirectRoutineEntry(a.id);
    final bool bInRoutine = widget.controller.isDirectRoutineEntry(b.id);
    if (aInRoutine != bInRoutine) return aInRoutine ? -1 : 1;
    if (aInRoutine && bInRoutine) {
      return widget.controller.compareItemsByNeed(a, b);
    }
    return a.name.compareTo(b.name);
  }

  String _labelForViewFilter(_FocusViewFilter filter) {
    return switch (filter) {
      _FocusViewFilter.all => 'All',
      _FocusViewFilter.flow => 'Flow',
    };
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

class _FocusSearchEmptyState extends StatelessWidget {
  final bool hasSearch;
  final String filterLabel;

  const _FocusSearchEmptyState({
    required this.hasSearch,
    required this.filterLabel,
  });

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Text(
        hasSearch
            ? 'No practice items match that search in $filterLabel.'
            : 'Nothing in Working On matches $filterLabel right now.',
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
  final ValueChanged<String> onOpenItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final VoidCallback onRemoveItem;

  const _FocusItemCard({
    required this.controller,
    required this.item,
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
                PatternDisplayText(
                  tokens: controller.noteTokensFor(item.id),
                  markings: controller.noteMarkingsFor(item.id),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  grouping: controller.displayGroupingFor(item.id),
                ),
                if (controller.hasNonSnareVoice(item.id)) ...<Widget>[
                  const SizedBox(height: 6),
                  PatternVoiceDisplay(
                    tokens: controller.noteTokensFor(item.id),
                    markings: controller.noteMarkingsFor(item.id),
                    voices: controller.noteVoicesFor(item.id),
                    patternStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                    voiceStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6A5E4C),
                      fontWeight: FontWeight.w700,
                    ),
                    grouping: controller.displayGroupingFor(item.id),
                  ),
                ],
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
                tooltip: 'Practice on One Surface',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () =>
                    onPracticeItemInMode(item.id, PracticeModeV1.singleSurface),
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

class _SearchResultCard extends StatelessWidget {
  final AppController controller;
  final PracticeItemV1 item;
  final ValueChanged<String> onOpenItem;
  final VoidCallback onAddItem;

  const _SearchResultCard({
    required this.controller,
    required this.item,
    required this.onOpenItem,
    required this.onAddItem,
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
                PatternDisplayText(
                  tokens: controller.noteTokensFor(item.id),
                  markings: controller.noteMarkingsFor(item.id),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                  grouping: controller.displayGroupingFor(item.id),
                ),
                if (controller.hasNonSnareVoice(item.id)) ...<Widget>[
                  const SizedBox(height: 6),
                  PatternVoiceDisplay(
                    tokens: controller.noteTokensFor(item.id),
                    markings: controller.noteMarkingsFor(item.id),
                    voices: controller.noteVoicesFor(item.id),
                    patternStyle: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                    voiceStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6A5E4C),
                      fontWeight: FontWeight.w700,
                    ),
                    grouping: controller.displayGroupingFor(item.id),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  item.family.label,
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
                tooltip: 'Open Item',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => onOpenItem(item.id),
              ),
              IconButton(
                tooltip: 'Add to Working On',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: onAddItem,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
