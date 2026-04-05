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
  ComboIntentTagV1 _intentTag = ComboIntentTagV1.coreSkills;

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
          DropdownButtonFormField<ComboIntentTagV1>(
            initialValue: _intentTag,
            decoration: const InputDecoration(
              labelText: 'Intent Tag',
              border: OutlineInputBorder(),
            ),
            items: ComboIntentTagV1.values
                .map(
                  (tag) => DropdownMenuItem<ComboIntentTagV1>(
                    value: tag,
                    child: Text(_labelForIntentTag(tag)),
                  ),
                )
                .toList(growable: false),
            onChanged: (ComboIntentTagV1? value) {
              if (value == null) return;
              setState(() => _intentTag = value);
            },
          ),
          const SizedBox(height: 16),
          TriadMatrixGrid(
            controller: widget.controller,
            filters: const <TriadMatrixFilterV1>{},
            selectedComboIds: const <String>{},
            selectedItemIds: _selectedItemIds,
            selectedRows: _selectedRows,
            selectedColumns: _selectedColumns,
            onToggleRow: _toggleRow,
            onToggleColumn: _toggleColumn,
            onTapItem: _toggleItemSelection,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Selected Sequence',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (!hasSelection)
                    const Text('Tap triads on the matrix to build a combo.')
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _selectedItemIds.length,
                      onReorder: _onReorder,
                      itemBuilder: (BuildContext context, int index) {
                        final String itemId = _selectedItemIds[index];
                        final PracticeItemV1 item = widget.controller.itemById(
                          itemId,
                        );
                        return ListTile(
                          key: ValueKey<String>('selected_$itemId$index'),
                          leading: CircleAvatar(
                            radius: 14,
                            child: Text('${index + 1}'),
                          ),
                          title: Text(item.name),
                          trailing: IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() => _selectedItemIds.removeAt(index));
                            },
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
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
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
      } else {
        _selectedItemIds.add(itemId);
      }
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

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final String item = _selectedItemIds.removeAt(oldIndex);
      _selectedItemIds.insert(newIndex, item);
    });
  }

  void _saveCombo() {
    if (_selectedItemIds.length < 2) return;
    widget.controller.createCombination(
      itemIds: _selectedItemIds,
      intentTag: _intentTag,
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
        .createCombination(itemIds: _selectedItemIds, intentTag: _intentTag)
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

  String _labelForIntentTag(ComboIntentTagV1 tag) {
    return switch (tag) {
      ComboIntentTagV1.coreSkills => 'Core Skills',
      ComboIntentTagV1.flow => 'Flow',
      ComboIntentTagV1.both => 'Both',
    };
  }
}
