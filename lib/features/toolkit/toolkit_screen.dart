import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_theme.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_readout.dart';
import '../practice/widgets/practice_item_summary_block.dart';

class FocusScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final VoidCallback onCreateNewItem;
  final VoidCallback onOpenMatrix;

  const FocusScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItemInMode,
    required this.onCreateNewItem,
    required this.onOpenMatrix,
  });

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
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
        final List<PracticeItemV1> allItems = widget.controller.items
            .where((PracticeItemV1 item) => item.saved && !item.isWarmup)
            .toList(growable: false);
        final bool hasSearch = _searchQuery.trim().isNotEmpty;
        final List<PracticeItemV1> visibleItems =
            allItems
                .where(
                  (PracticeItemV1 item) =>
                      !hasSearch || _matchesSearch(item, _searchQuery),
                )
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
                        hintText: 'Search all patterns',
                        prefixIcon: Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton(
                    onPressed: widget.onCreateNewItem,
                    child: const Text('New Pattern'),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (!hasSearch && allItems.isEmpty)
                _FocusEmptyState(onOpenMatrix: widget.onOpenMatrix)
              else if (visibleItems.isEmpty)
                _FocusSearchEmptyState(hasSearch: hasSearch)
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
                                onRemoveItem: () => _confirmRemoveItem(item),
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

  int _compareVisibleItems(PracticeItemV1 a, PracticeItemV1 b) {
    final bool aInRoutine = widget.controller.isDirectRoutineEntry(a.id);
    final bool bInRoutine = widget.controller.isDirectRoutineEntry(b.id);
    if (aInRoutine != bInRoutine) return aInRoutine ? -1 : 1;
    if (aInRoutine && bInRoutine) {
      return widget.controller.compareItemsByNeed(a, b);
    }
    return a.name.compareTo(b.name);
  }

  Future<void> _confirmRemoveItem(PracticeItemV1 item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: DrumcabularyTheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
            side: const BorderSide(color: DrumcabularyTheme.line),
          ),
          title: const Text('Remove From Working On?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'This only removes the item from Working On. It does not delete the practice item.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              PatternReadout(
                controller: widget.controller,
                itemId: item.id,
                voiceStyle: Theme.of(context).textTheme.bodySmall,
                scrollable: false,
                wrap: true,
                cellWidth: 24,
              ),
            ],
          ),
          actions: <Widget>[
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      widget.controller.toggleRoutineItem(item.id);
    }
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
          const DrumSectionTitle(text: 'No Saved Patterns'),
          const SizedBox(height: 8),
          Text(
            'Create a pattern or add one from Matrix. Saved patterns will appear here.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: DrumcabularyTheme.mutedInk,
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

  const _FocusSearchEmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return DrumPanel(
      child: Text(
        hasSearch ? 'No patterns match that search.' : 'No saved patterns yet.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: DrumcabularyTheme.mutedInk),
      ),
    );
  }
}

class _FocusItemCard extends StatelessWidget {
  static const EdgeInsetsGeometry _cardPadding = EdgeInsets.fromLTRB(
    12,
    6,
    12,
    10,
  );
  static const BoxConstraints _actionButtonConstraints =
      BoxConstraints.tightFor(width: 36, height: 34);

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
      padding: _cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: 'Practice',
                visualDensity: VisualDensity.compact,
                constraints: _actionButtonConstraints,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: () => onPracticeItemInMode(
                  item.id,
                  controller.displayPracticeModeForItem(item.id),
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                visualDensity: VisualDensity.compact,
                constraints: _actionButtonConstraints,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => onOpenItem(item.id),
              ),
              IconButton(
                tooltip: 'Remove from Working On',
                visualDensity: VisualDensity.compact,
                constraints: _actionButtonConstraints,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: onRemoveItem,
              ),
            ],
          ),
          PracticeItemSummaryBlock(
            controller: controller,
            item: item,
            metadataLines: <String>[
              '${item.family.label} - ${controller.matrixProgressStateFor(item.id).label}',
              '${formatDuration(controller.totalTime(itemId: item.id))} logged',
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  static const EdgeInsetsGeometry _cardPadding = EdgeInsets.fromLTRB(
    12,
    6,
    12,
    10,
  );
  static const BoxConstraints _actionButtonConstraints =
      BoxConstraints.tightFor(width: 36, height: 34);

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
      padding: _cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              IconButton(
                tooltip: 'Open Item',
                visualDensity: VisualDensity.compact,
                constraints: _actionButtonConstraints,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => onOpenItem(item.id),
              ),
              IconButton(
                tooltip: 'Add to Working On',
                visualDensity: VisualDensity.compact,
                constraints: _actionButtonConstraints,
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.add_circle_outline_rounded),
                onPressed: onAddItem,
              ),
            ],
          ),
          PracticeItemSummaryBlock(
            controller: controller,
            item: item,
            metadataLines: <String>[item.family.label],
          ),
        ],
      ),
    );
  }
}
