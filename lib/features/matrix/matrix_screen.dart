import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import 'widgets/triad_matrix_grid.dart';

class MatrixScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final ValueChanged<List<String>> onBuildComboFromItems;

  const MatrixScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onBuildComboFromItems,
  });

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  TriadMatrixFilterPaletteV1? _palette;
  final Set<TriadMatrixFilterV1> _filters = <TriadMatrixFilterV1>{};
  final Set<String> _selectedComboIds = <String>{};
  final Set<String> _selectedRows = <String>{};
  final Set<String> _selectedColumns = <String>{};
  final List<String> _selectedItemIds = <String>[];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFFF5EEE1), Color(0xFFF8F6F1)],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: <Widget>[
          Text(
            'Triad Matrix',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TriadMatrixFilterPaletteV1.values
                  .map(
                    (palette) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(palette.label),
                        selected: _palette == palette,
                        onSelected: (_) => _togglePalette(palette),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          if (_palette != null) ...<Widget>[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildPaletteFilters()),
            ),
          ],
          const SizedBox(height: 12),
          TriadMatrixGrid(
            controller: widget.controller,
            filters: _filters,
            selectedComboIds: _selectedComboIds,
            selectedItemIds: _selectedItemIds,
            selectedRows: _selectedRows,
            selectedColumns: _selectedColumns,
            onToggleRow: _toggleRow,
            onToggleColumn: _toggleColumn,
            onTapItem: _toggleItemSelection,
            onRemoveItem: _removeSelectedItem,
          ),
          if (_selectedItemIds.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            SafeArea(
              top: false,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (_selectedItemIds.length == 1)
                        PatternDisplayText(
                          tokens: widget.controller.noteTokensFor(
                            _selectedItemIds.first,
                          ),
                          markings: widget.controller.noteMarkingsFor(
                            _selectedItemIds.first,
                          ),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        )
                      else
                        Text(
                          _selectedLabel,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _practiceSelection,
                        child: const Text('Practice Now'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _buildComboFromSelection,
                        child: const Text('Build Combo'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _toggleRoutineSelection,
                        child: Text(
                          _selectionIsInRoutine
                              ? 'Remove from Routine'
                              : 'Add to Routine',
                        ),
                      ),
                      if (_selectedItemIds.length == 1) ...<Widget>[
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: () =>
                              widget.onOpenItem(_selectedItemIds.first),
                          child: const Text('View Details'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedItemIds.clear());
                        },
                        child: const Text('Clear Selection'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _toggleRow(String rowLabel) {
    setState(() {
      if (_selectedRows.contains(rowLabel)) {
        _selectedRows.remove(rowLabel);
      } else {
        _selectedRows.add(rowLabel);
      }
    });
  }

  void _toggleColumn(String columnLabel) {
    setState(() {
      if (_selectedColumns.contains(columnLabel)) {
        _selectedColumns.remove(columnLabel);
      } else {
        _selectedColumns.add(columnLabel);
      }
    });
  }

  List<Widget> _buildPaletteFilters() {
    if (_palette == TriadMatrixFilterPaletteV1.combos) {
      return widget.controller.triadCombinations
          .map((combo) {
            final String comboId = combo.id;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  widget.controller.matrixLabelForCombination(comboId),
                ),
                selected: _selectedComboIds.contains(comboId),
                onSelected: (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedComboIds.add(comboId);
                    } else {
                      _selectedComboIds.remove(comboId);
                    }
                  });
                },
              ),
            );
          })
          .toList(growable: false);
    }

    if (_palette == null) return const <Widget>[];

    return _paletteFilters(_palette!)
        .map((filter) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter.label),
              selected: _filters.contains(filter),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _filters.add(filter);
                  } else {
                    _filters.remove(filter);
                  }
                });
              },
            ),
          );
        })
        .toList(growable: false);
  }

  List<TriadMatrixFilterV1> _paletteFilters(
    TriadMatrixFilterPaletteV1 palette,
  ) {
    return switch (palette) {
      TriadMatrixFilterPaletteV1.coaching => const <TriadMatrixFilterV1>[
        TriadMatrixFilterV1.competency,
        TriadMatrixFilterV1.inRoutine,
        TriadMatrixFilterV1.needsAttention,
        TriadMatrixFilterV1.underPracticed,
        TriadMatrixFilterV1.closeToToolkit,
        TriadMatrixFilterV1.recent,
        TriadMatrixFilterV1.unseen,
      ],
      TriadMatrixFilterPaletteV1.technique => const <TriadMatrixFilterV1>[
        TriadMatrixFilterV1.rightLead,
        TriadMatrixFilterV1.leftLead,
        TriadMatrixFilterV1.handsOnly,
        TriadMatrixFilterV1.hasKick,
        TriadMatrixFilterV1.startsWithKick,
        TriadMatrixFilterV1.endsWithKick,
        TriadMatrixFilterV1.doubles,
      ],
      TriadMatrixFilterPaletteV1.combos => const <TriadMatrixFilterV1>[],
    };
  }

  void _togglePalette(TriadMatrixFilterPaletteV1 palette) {
    setState(() {
      _palette = _palette == palette ? null : palette;
      _filters.clear();
      _selectedComboIds.clear();
    });
  }

  String get _selectedLabel {
    if (_selectedItemIds.length == 1) {
      return widget.controller.markedPatternTextFor(_selectedItemIds.first);
    }
    return widget.controller.comboDisplayName(_selectedItemIds);
  }

  bool get _selectionIsInRoutine {
    final String? itemId = _selectionRoutineItemId;
    return itemId != null && widget.controller.isDirectRoutineEntry(itemId);
  }

  String? get _selectionRoutineItemId {
    if (_selectedItemIds.isEmpty) return null;
    if (_selectedItemIds.length == 1) return _selectedItemIds.first;
    return widget.controller.combinationForItemIdsOrNull(_selectedItemIds)?.id;
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      _selectedItemIds.add(itemId);
    });
  }

  void _removeSelectedItem(String itemId) {
    final int index = _selectedItemIds.lastIndexOf(itemId);
    if (index < 0) return;
    setState(() {
      _selectedItemIds.removeAt(index);
    });
  }

  void _practiceSelection() {
    final String? itemId = _selectionActionItemId();
    if (itemId == null) return;
    widget.onPracticeItem(itemId);
  }

  void _buildComboFromSelection() {
    if (_selectedItemIds.isEmpty) return;
    widget.onBuildComboFromItems(List<String>.from(_selectedItemIds));
  }

  void _toggleRoutineSelection() {
    final String? itemId = _selectionActionItemId(createIfMissing: true);
    if (itemId == null) return;
    widget.controller.toggleRoutineItem(itemId);
    setState(() {});
  }

  String? _selectionActionItemId({bool createIfMissing = false}) {
    if (_selectedItemIds.isEmpty) return null;
    if (_selectedItemIds.length == 1) return _selectedItemIds.first;
    final PracticeCombinationV1? existing = widget.controller
        .combinationForItemIdsOrNull(_selectedItemIds);
    if (existing != null) return existing.id;
    if (!createIfMissing) return null;
    return widget.controller
        .createCombination(
          itemIds: _selectedItemIds,
          intentTag: ComboIntentTagV1.both,
        )
        .id;
  }
}
