import 'package:flutter/material.dart';

import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';
import 'widgets/triad_matrix_grid.dart';

class MatrixScreen extends StatefulWidget {
  final AppController controller;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const MatrixScreen({
    super.key,
    required this.controller,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  State<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends State<MatrixScreen> {
  final Set<TriadMatrixViewModeV1> _modes = <TriadMatrixViewModeV1>{
    TriadMatrixViewModeV1.competency,
  };
  final Set<String> _selectedRows = <String>{};
  final Set<String> _selectedColumns = <String>{};

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFFF5EEE1),
            Color(0xFFF8F6F1),
          ],
        ),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    children: TriadMatrixViewModeV1.values
                        .map(
                          (mode) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(mode.label),
                              selected: _modes.contains(mode),
                              onSelected: (bool selected) {
                                setState(() {
                                  if (selected) {
                                    _modes.add(mode);
                                  } else {
                                    _modes.remove(mode);
                                  }
                                });
                              },
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: SingleChildScrollView(
                child: TriadMatrixGrid(
                  controller: widget.controller,
                  modes: _modes,
                  selectedRows: _selectedRows,
                  selectedColumns: _selectedColumns,
                  onToggleRow: _toggleRow,
                  onToggleColumn: _toggleColumn,
                  onOpenItem: widget.onOpenItem,
                  onPracticeItem: widget.onPracticeItem,
                ),
              ),
            ),
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
}
