import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../features/app/drumcabulary_ui.dart';
import '../../state/app_controller.dart';
import '../practice/widgets/pattern_sequence_editor.dart';
import '../practice/widgets/pattern_voice_display.dart';
import 'widgets/triad_matrix_grid.dart';

class MatrixScreenRequest {
  final int version;
  final LearningLaneV1? lane;
  final TriadMatrixFilterPaletteV1? palette;
  final Set<TriadMatrixFilterV1> filters;

  const MatrixScreenRequest({
    required this.version,
    required this.lane,
    required this.palette,
    required this.filters,
  });
}

class MatrixScreen extends StatefulWidget {
  final AppController controller;
  final MatrixScreenRequest? request;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;
  final void Function(String, PracticeModeV1) onPracticeItemInMode;
  final ValueChanged<List<String>> onBuildComboFromItems;

  const MatrixScreen({
    super.key,
    required this.controller,
    required this.request,
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
  int? _appliedRequestVersion;

  @override
  void didUpdateWidget(covariant MatrixScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final MatrixScreenRequest? request = widget.request;
    if (request == null || request.version == _appliedRequestVersion) return;
    _appliedRequestVersion = request.version;
    _applyRequest(request);
  }

  @override
  Widget build(BuildContext context) {
    final bool showBuildHeader = _selectedItemIds.isNotEmpty;
    final MatrixFiltersV1 matrixFilters = MatrixFiltersV1(
      lane: _laneFocus,
      palette: _palette,
      filters: _effectiveFilters,
      selectedComboIds: _selectedComboIds,
      selectedRows: _selectedRows,
      selectedColumns: _selectedColumns,
    );
    final MatrixSelectionStateV1 matrixSelection = MatrixSelectionStateV1(
      orderedItemIds: _selectedItemIds,
    );

    return DrumScreen(
      warm: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: <Widget>[
          const DrumEyebrow(text: 'Lane'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: LearningLaneV1.values
                  .map(
                    (LearningLaneV1 lane) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DrumSelectablePill(
                        label: _chipText(lane.label, _laneFocus == lane),
                        selected: _laneFocus == lane,
                        onPressed: () => _toggleLaneFocus(lane),
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
          const DrumEyebrow(text: 'Filter'),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: TriadMatrixFilterPaletteV1.values
                  .map(
                    (palette) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: DrumSelectablePill(
                        label: _chipText(palette.label, _palette == palette),
                        selected: _palette == palette,
                        onPressed: () => _togglePalette(palette),
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
          if (_effectiveFilters.contains(
            TriadMatrixFilterV1.competency,
          )) ...<Widget>[
            const SizedBox(height: 10),
            const _ProgressLegendCard(),
          ],
          if (showBuildHeader) ...<Widget>[
            const SizedBox(height: 10),
            DrumPanel(
              tone: DrumPanelTone.warm,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const DrumEyebrow(text: 'Phrase'),
                  const SizedBox(height: 8),
                  PatternSequenceEditor(
                    controller: widget.controller,
                    itemIds: _selectedItemIds,
                    onRemoveAt: _removeSelectedAt,
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: _buildActionPills()),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TriadMatrixGrid(
            controller: widget.controller,
            filters: matrixFilters,
            selection: matrixSelection,
            onToggleRow: _toggleRow,
            onToggleColumn: _toggleColumn,
            onTapItem: _toggleItemSelection,
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
              child: DrumSelectablePill(
                label: _comboFilterLabel(
                  comboId,
                  selected: _selectedComboIds.contains(comboId),
                ),
                selected: _selectedComboIds.contains(comboId),
                onPressed: () {
                  setState(() {
                    if (_selectedComboIds.contains(comboId)) {
                      _selectedComboIds.remove(comboId);
                    } else {
                      _selectedComboIds.add(comboId);
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
            child: DrumSelectablePill(
              label: _chipText(filter.label, _filters.contains(filter)),
              selected: _filters.contains(filter),
              onPressed: () {
                setState(() {
                  if (_filters.contains(filter)) {
                    _filters.remove(filter);
                  } else {
                    _filters.add(filter);
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
          child: DrumActionPill(
            label: const Text('Flow'),
            onPressed: _practiceSelectionInFlow,
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DrumActionPill(
          label: const Text('Single Surface'),
          onPressed: _practiceSelection,
        ),
      ),
      if (!flowFirst)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DrumActionPill(
            label: const Text('Flow'),
            onPressed: _practiceSelectionInFlow,
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DrumActionPill(
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
          child: DrumActionPill(
            label: const Text('Save Phrase'),
            onPressed: _saveSelection,
          ),
        ),
    ];

    if (_selectedItemIds.length == 1) {
      pills.add(
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DrumActionPill(
            label: const Text('View Details'),
            onPressed: () => widget.onOpenItem(_selectedItemIds.first),
          ),
        ),
      );
    }

    pills.add(
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: DrumActionPill(
          label: const Text('Clear'),
          onPressed: () {
            setState(() => _selectedItemIds.clear());
          },
        ),
      ),
    );

    return pills;
  }

  Widget _comboFilterLabel(String comboId, {required bool selected}) {
    final bool showVoices = _laneFocus == LearningLaneV1.flow;
    if (!showVoices) {
      return _chipText(
        widget.controller.matrixLabelForCombination(comboId),
        selected,
      );
    }

    return PatternVoiceDisplay(
      tokens: widget.controller.noteTokensFor(comboId),
      markings: widget.controller.noteMarkingsFor(comboId),
      voices: widget.controller.noteVoicesFor(comboId),
      patternStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w900,
        color: selected ? Colors.white : const Color(0xFF101010),
      ),
      voiceStyle: Theme.of(
        context,
      ).textTheme.labelSmall?.copyWith(color: selected ? Colors.white : null),
      cellWidth: 30,
    );
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

  Set<TriadMatrixFilterV1> get _effectiveFilters {
    return <TriadMatrixFilterV1>{..._filters, ..._lanePresetFilters()};
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

  void _removeSelectedAt(int index) {
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

  void _applyRequest(MatrixScreenRequest request) {
    setState(() {
      _laneFocus = request.lane;
      _palette = request.palette;
      _filters
        ..clear()
        ..addAll(request.filters);
      _selectedComboIds.clear();
      _selectedRows.clear();
      _selectedColumns.clear();
      _selectedItemIds.clear();

      final LearningLaneV1? lane = _laneFocus;
      if (lane != null && _palette == null && _filters.isEmpty) {
        _palette = switch (lane) {
          LearningLaneV1.control => TriadMatrixFilterPaletteV1.technique,
          LearningLaneV1.balance => TriadMatrixFilterPaletteV1.technique,
          LearningLaneV1.dynamics => TriadMatrixFilterPaletteV1.coaching,
          LearningLaneV1.integration => TriadMatrixFilterPaletteV1.technique,
          LearningLaneV1.phrasing => TriadMatrixFilterPaletteV1.combos,
          LearningLaneV1.flow => TriadMatrixFilterPaletteV1.combos,
        };
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
    return DrumPanel(
      tone: DrumPanelTone.warm,
      padding: const EdgeInsets.all(14),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            DrumSectionTitle(text: lane.label),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ProgressLegendCard extends StatelessWidget {
  const _ProgressLegendCard();

  @override
  Widget build(BuildContext context) {
    const List<({String label, Color color})> items =
        <({String label, Color color})>[
          (label: 'Not trained', color: Color(0xFFE6E1D7)),
          (label: 'Active', color: Color(0xFFD9E9F7)),
          (label: 'Needs work', color: Color(0xFFF0B2AA)),
          (label: 'Strong', color: Color(0xFFDDEDDD)),
        ];

    return DrumPanel(
      tone: DrumPanelTone.warm,
      padding: const EdgeInsets.all(12),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: items
              .map(
                (item) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: item.color,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0x22000000)),
                      ),
                      child: const SizedBox(width: 16, height: 16),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}
