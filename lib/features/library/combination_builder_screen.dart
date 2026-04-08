import 'package:flutter/material.dart';

import '../../core/pattern/triad_matrix.dart';
import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../app/drumcabulary_ui.dart';
import '../matrix/widgets/triad_matrix_grid.dart';
import '../practice/practice_session_screen.dart';

class CombinationBuilderScreen extends StatefulWidget {
  final AppController controller;
  final List<String> initialItemIds;

  const CombinationBuilderScreen({
    super.key,
    required this.controller,
    this.initialItemIds = const <String>[],
  });

  @override
  State<CombinationBuilderScreen> createState() =>
      _CombinationBuilderScreenState();
}

class _CombinationBuilderScreenState extends State<CombinationBuilderScreen> {
  final List<String> _selectedItemIds = <String>[];

  @override
  void initState() {
    super.initState();
    _selectedItemIds.addAll(
      widget.initialItemIds.where(
        (itemId) => widget.controller.itemById(itemId).isTriad,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = _selectedItemIds.isNotEmpty;
    final bool canSaveCombo = _selectedItemIds.length > 1;
    final String? routineItemId = _routineStatusItemId();
    final bool inRoutine =
        routineItemId != null &&
        widget.controller.isDirectRoutineEntry(routineItemId);

    return Scaffold(
      appBar: AppBar(title: const Text('Build Combo')),
      body: DrumScreen(
        warm: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            DrumPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const DrumEyebrow(text: 'Combo'),
                  const SizedBox(height: 8),
                  Text(
                    hasSelection
                        ? widget.controller.comboDisplayName(_selectedItemIds)
                        : 'Tap triads, rows, or columns on the matrix to build a combo.',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if (hasSelection) ...<Widget>[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List<Widget>.generate(_selectedItemIds.length, (
                        index,
                      ) {
                        final String itemId = _selectedItemIds[index];
                        final PracticeItemV1 item = widget.controller.itemById(
                          itemId,
                        );
                        return InputChip(
                          label: Text('${index + 1}. ${item.name}'),
                          onDeleted: () {
                            setState(() => _selectedItemIds.removeAt(index));
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        OutlinedButton(
                          onPressed: _selectedItemIds.isEmpty
                              ? null
                              : () {
                                  setState(() => _selectedItemIds.removeLast());
                                },
                          child: const Text('Undo'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _selectedItemIds.isEmpty
                              ? null
                              : () {
                                  setState(() => _selectedItemIds.clear());
                                },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            TriadMatrixGrid(
              controller: widget.controller,
              filters: const MatrixFiltersV1(
                lane: null,
                palette: null,
                filters: <TriadMatrixFilterV1>{},
                selectedComboIds: <String>{},
                selectedRows: <String>{},
                selectedColumns: <String>{},
              ),
              selection: MatrixSelectionStateV1(
                orderedItemIds: _selectedItemIds,
              ),
              onToggleRow: _appendRow,
              onToggleColumn: _appendColumn,
              onTapItem: _toggleItemSelection,
              onRemoveItem: _removeLastOccurrence,
            ),
            const SizedBox(height: 16),
            DrumActionRow(
              children: <Widget>[
                OutlinedButton(
                  onPressed: hasSelection ? _practiceNow : null,
                  child: const Text('Practice Now'),
                ),
                FilledButton.tonal(
                  onPressed: hasSelection ? _toggleRoutine : null,
                  child: Text(
                    inRoutine ? 'Remove From Working On' : 'Add To Working On',
                  ),
                ),
                FilledButton(
                  onPressed: canSaveCombo ? _saveCombo : null,
                  child: const Text('Save Combo'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      _selectedItemIds.add(itemId);
    });
  }

  void _removeLastOccurrence(String itemId) {
    final int index = _selectedItemIds.lastIndexOf(itemId);
    if (index < 0) return;
    setState(() {
      _selectedItemIds.removeAt(index);
    });
  }

  void _appendRow(String rowLabel) {
    final List<String> itemIds = triadMatrixAll()
        .where((TriadMatrixCell cell) => cell.id.substring(1) == rowLabel)
        .map(
          (TriadMatrixCell cell) =>
              widget.controller.triadItemForCell(cell.id)!.id,
        )
        .toList(growable: false);
    setState(() => _selectedItemIds.addAll(itemIds));
  }

  void _appendColumn(String columnLabel) {
    final List<String> itemIds = triadMatrixAll()
        .where((TriadMatrixCell cell) => cell.id.startsWith(columnLabel))
        .map(
          (TriadMatrixCell cell) =>
              widget.controller.triadItemForCell(cell.id)!.id,
        )
        .toList(growable: false);
    setState(() => _selectedItemIds.addAll(itemIds));
  }

  void _saveCombo() {
    if (_selectedItemIds.length < 2) return;
    widget.controller.createCombination(itemIds: _selectedItemIds);
    Navigator.of(context).pop();
  }

  void _practiceNow() {
    final String? itemId = _selectionActionItemId();
    if (itemId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSessionScreen(
          controller: widget.controller,
          setup: widget.controller.buildSessionForItem(itemId),
        ),
      ),
    );
  }

  void _toggleRoutine() {
    final String? itemId = _routineActionItemId();
    if (itemId == null) return;
    widget.controller.toggleRoutineItem(itemId);
    setState(() {});
  }

  String? _selectionActionItemId() {
    if (_selectedItemIds.isEmpty) return null;
    if (_selectedItemIds.length == 1) return _selectedItemIds.first;
    return widget.controller.createCombination(itemIds: _selectedItemIds).id;
  }

  String? _routineActionItemId() => _selectionActionItemId();

  String? _routineStatusItemId() {
    if (_selectedItemIds.isEmpty) return null;
    if (_selectedItemIds.length == 1) return _selectedItemIds.first;
    return widget.controller
            .combinationForItemIdsOrNull(_selectedItemIds)
            ?.id ??
        'combo_${_selectedItemIds.join('_')}';
  }
}
