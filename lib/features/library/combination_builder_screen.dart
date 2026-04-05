import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../state/app_controller.dart';
import '../matrix/widgets/triad_matrix_grid.dart';
import '../practice/practice_setup_screen.dart';

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
  final Set<String> _selectedRows = <String>{};
  final Set<String> _selectedColumns = <String>{};

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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Combo', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    hasSelection
                        ? widget.controller.comboDisplayName(_selectedItemIds)
                        : 'Tap triads on the matrix to build a combo.',
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
          ),
          const SizedBox(height: 16),
          TriadMatrixGrid(
            controller: widget.controller,
            filters: const <TriadMatrixFilterV1>{},
            selectedComboIds: const <String>{},
            selectedItemIds: const <String>[],
            selectedRows: _selectedRows,
            selectedColumns: _selectedColumns,
            onToggleRow: _toggleRow,
            onToggleColumn: _toggleColumn,
            onTapItem: _toggleItemSelection,
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: hasSelection ? _practiceNow : null,
                  child: const Text('Practice Now'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: hasSelection ? _toggleRoutine : null,
                  child: Text(
                    inRoutine ? 'Remove From Routine' : 'Add To Routine',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: canSaveCombo ? _saveCombo : null,
            child: const Text('Save Combo'),
          ),
        ],
      ),
    );
  }

  void _toggleItemSelection(String itemId) {
    setState(() {
      _selectedItemIds.add(itemId);
    });
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

  void _saveCombo() {
    if (_selectedItemIds.length < 2) return;
    widget.controller.createCombination(
      itemIds: _selectedItemIds,
      intentTag: ComboIntentTagV1.both,
    );
    Navigator.of(context).pop();
  }

  void _practiceNow() {
    final String? itemId = _selectionActionItemId();
    if (itemId == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PracticeSetupScreen(
          controller: widget.controller,
          initialItemId: itemId,
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
    return widget.controller
        .createCombination(
          itemIds: _selectedItemIds,
          intentTag: ComboIntentTagV1.both,
        )
        .id;
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
