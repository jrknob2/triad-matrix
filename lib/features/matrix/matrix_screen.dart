import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_display_text.dart';
import '../practice/widgets/pattern_voice_display.dart';
import 'widgets/triad_matrix_grid.dart';

class MatrixScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final ValueChanged<List<String>> onBuildComboFromItems;

  const MatrixScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
    required this.onPracticeItemInMode,
    required this.onBuildComboFromItems,
  });

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  LearningLaneV1? _laneFocus;
  TriadMatrixFilterPaletteV1? _palette;
  final Set<TriadMatrixFilterV1> _filters = <TriadMatrixFilterV1>{};
  final Set<String> _selectedComboIds = <String>{};
  final Set<String> _selectedRows = <String>{};
  final Set<String> _selectedColumns = <String>{};
  final List<String> _selectedItemIds = <String>[];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool showBuildHeader = _showBuildHeader;

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
              children: LearningLaneV1.values
                  .map(
                    (LearningLaneV1 lane) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(lane.label),
                        selected: _laneFocus == lane,
                        onSelected: (_) => _toggleLaneFocus(lane),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          if (_laneFocus != null) ...<Widget>[
            const SizedBox(height: 10),
            _LaneFocusCard(
              lane: _laneFocus!,
              description: _laneDescription(_laneFocus!),
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 10),
          if (showBuildHeader) ...<Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                height: 38,
                child: Row(
                  children: <Widget>[
                    if (_laneFocus != null) ...<Widget>[
                      Chip(
                        label: Text(_laneFocus!.label),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                    ],
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _buildActionPills()),
            ),
          ] else ...<Widget>[
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
          ],
          const SizedBox(height: 12),
          TriadMatrixGrid(
            controller: widget.controller,
            filters: _effectiveFilters,
            selectedComboIds: _selectedComboIds,
            selectedItemIds: _selectedItemIds,
            selectedRows: _selectedRows,
            selectedColumns: _selectedColumns,
            onToggleRow: _toggleRow,
            onToggleColumn: _toggleColumn,
            onTapItem: _toggleItemSelection,
            onRemoveItem: _removeSelectedItem,
          ),
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
                label: _comboFilterLabel(comboId),
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
        .map(
          (filter) => Padding(
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
          ),
        )
        .toList(growable: false);
  }

  List<Widget> _buildActionPills() {
    final bool flowFirst = _laneFocus == LearningLaneV1.flow;
    final List<Widget> pills = <Widget>[
      if (flowFirst)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: const Text('Flow'),
            onPressed: _practiceSelectionInFlow,
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          label: const Text('Single Surface'),
          onPressed: _practiceSelection,
        ),
      ),
      if (!flowFirst)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: const Text('Flow'),
            onPressed: _practiceSelectionInFlow,
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          label: Text(
            _selectionIsInRoutine
                ? 'Remove from Working On'
                : 'Add to Working On',
          ),
          onPressed: _toggleRoutineSelection,
        ),
      ),
      if (_selectedItemIds.length > 1)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: const Text('Save Phrase'),
            onPressed: _saveSelection,
          ),
        ),
    ];

    if (_selectedItemIds.length == 1) {
      pills.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: const Text('View Details'),
            onPressed: () => widget.onOpenItem(_selectedItemIds.first),
          ),
        ),
      );
    }

    pills.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          label: const Text('Clear'),
          onPressed: () {
            setState(() => _selectedItemIds.clear());
          },
        ),
      ),
    );

    return pills;
  }

  Widget _comboFilterLabel(String comboId) {
    final bool showVoices = _laneFocus == LearningLaneV1.flow;
    if (!showVoices) {
      return Text(widget.controller.matrixLabelForCombination(comboId));
    }

    return PatternVoiceDisplay(
      tokens: widget.controller.noteTokensFor(comboId),
      markings: widget.controller.noteMarkingsFor(comboId),
      voices: widget.controller.noteVoicesFor(comboId),
      patternStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: const Color(0xFF101010),
      ),
      voiceStyle: Theme.of(context).textTheme.labelSmall,
      cellWidth: 30,
    );
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
      _laneFocus = null;
      _palette = _palette == palette ? null : palette;
      _filters.clear();
      _selectedComboIds.clear();
    });
  }

  bool get _hasBlockingFilters {
    return _selectedComboIds.isNotEmpty ||
        _selectedRows.isNotEmpty ||
        _selectedColumns.isNotEmpty ||
        _manualFiltersAreActive;
  }

  bool get _manualFiltersAreActive {
    final Set<TriadMatrixFilterV1> laneFilters = _lanePresetFilters();
    return _filters.difference(laneFilters).isNotEmpty;
  }

  bool get _showBuildHeader =>
      _selectedItemIds.isNotEmpty && !_hasBlockingFilters;

  Set<TriadMatrixFilterV1> get _effectiveFilters {
    return <TriadMatrixFilterV1>{..._filters, ..._lanePresetFilters()};
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
    final String? itemId = _selectionActionItemId(createIfMissing: true);
    if (itemId == null) return;
    widget.onPracticeItem(itemId);
  }

  void _practiceSelectionInFlow() {
    final String? itemId = _selectionActionItemId(createIfMissing: true);
    if (itemId == null) return;
    widget.onPracticeItemInMode(itemId, PracticeModeV1.flow);
  }

  void _toggleRoutineSelection() {
    final String? itemId = _selectionActionItemId(createIfMissing: true);
    if (itemId == null) return;
    widget.controller.toggleRoutineItem(itemId);
    setState(() {});
  }

  void _saveSelection() {
    if (_selectedItemIds.length < 2) return;
    widget.controller.createCombination(itemIds: _selectedItemIds);
    setState(() {});
  }

  String? _selectionActionItemId({bool createIfMissing = false}) {
    if (_selectedItemIds.isEmpty) return null;
    if (_selectedItemIds.length == 1) return _selectedItemIds.first;
    final PracticeCombinationV1? existing = widget.controller
        .combinationForItemIdsOrNull(_selectedItemIds);
    if (existing != null) return existing.id;
    if (!createIfMissing) return null;
    return widget.controller.createCombination(itemIds: _selectedItemIds).id;
  }

  void _toggleLaneFocus(LearningLaneV1 lane) {
    setState(() {
      final bool sameLane = _laneFocus == lane;
      _laneFocus = sameLane ? null : lane;
      _selectedRows.clear();
      _selectedColumns.clear();
      _selectedComboIds.clear();

      if (sameLane) {
        _palette = null;
        _filters.clear();
        return;
      }

      switch (lane) {
        case LearningLaneV1.control:
          _palette = TriadMatrixFilterPaletteV1.technique;
          _filters
            ..clear()
            ..add(TriadMatrixFilterV1.handsOnly);
        case LearningLaneV1.balance:
          _palette = TriadMatrixFilterPaletteV1.technique;
          _filters
            ..clear()
            ..add(TriadMatrixFilterV1.rightLead)
            ..add(TriadMatrixFilterV1.leftLead);
        case LearningLaneV1.dynamics:
          _palette = TriadMatrixFilterPaletteV1.coaching;
          _filters
            ..clear()
            ..add(TriadMatrixFilterV1.competency);
        case LearningLaneV1.integration:
          _palette = TriadMatrixFilterPaletteV1.technique;
          _filters
            ..clear()
            ..add(TriadMatrixFilterV1.hasKick);
        case LearningLaneV1.phrasing:
          _palette = TriadMatrixFilterPaletteV1.combos;
          _filters.clear();
        case LearningLaneV1.flow:
          _palette = TriadMatrixFilterPaletteV1.combos;
          _filters.clear();
      }
    });
  }

  Set<TriadMatrixFilterV1> _lanePresetFilters() {
    return switch (_laneFocus) {
      LearningLaneV1.control => const <TriadMatrixFilterV1>{
        TriadMatrixFilterV1.handsOnly,
      },
      LearningLaneV1.balance => const <TriadMatrixFilterV1>{
        TriadMatrixFilterV1.rightLead,
        TriadMatrixFilterV1.leftLead,
      },
      LearningLaneV1.dynamics => const <TriadMatrixFilterV1>{
        TriadMatrixFilterV1.competency,
      },
      LearningLaneV1.integration => const <TriadMatrixFilterV1>{
        TriadMatrixFilterV1.hasKick,
      },
      LearningLaneV1.phrasing => const <TriadMatrixFilterV1>{},
      LearningLaneV1.flow => const <TriadMatrixFilterV1>{},
      null => const <TriadMatrixFilterV1>{},
    };
  }

  String _laneDescription(LearningLaneV1 lane) {
    return switch (lane) {
      LearningLaneV1.control =>
        'Hands-only cells stay in view here. Use this lane to clean up pulse, rebound, and even sound before adding more variables.',
      LearningLaneV1.balance =>
        'Right and left lead are both visible here. Compare the two sides directly and use the weaker side first while your hands are fresh.',
      LearningLaneV1.dynamics =>
        'This lane is about touch. Pick stable cells, then work accent height and ghost-note control without changing the phrase.',
      LearningLaneV1.integration =>
        'Kick-based cells come forward here. Add the foot without letting the hands smear the phrase.',
      LearningLaneV1.phrasing =>
        'Use this lane to build and review longer phrases. The goal is transition quality and phrase shape, not just single-cell repetition.',
      LearningLaneV1.flow =>
        'Flow starts with a stable phrase, then moves it across voices. Choose a phrase and take it into Flow when you are ready to assign surfaces.',
    };
  }
}

class _LaneFocusCard extends StatelessWidget {
  final LearningLaneV1 lane;
  final String description;

  const _LaneFocusCard({required this.lane, required this.description});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F0E6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              lane.label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
