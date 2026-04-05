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
  TriadMatrixFilterPaletteV1? _palette;
  final Set<TriadMatrixFilterV1> _filters = <TriadMatrixFilterV1>{};
  final Set<String> _selectedComboIds = <String>{};
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
          colors: <Color>[Color(0xFFF5EEE1), Color(0xFFF8F6F1)],
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
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
              child: SingleChildScrollView(
                child: TriadMatrixGrid(
                  controller: widget.controller,
                  filters: _filters,
                  selectedComboIds: _selectedComboIds,
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
        TriadMatrixFilterV1.lead,
        TriadMatrixFilterV1.weakHand,
        TriadMatrixFilterV1.handsOnly,
        TriadMatrixFilterV1.hasKick,
        TriadMatrixFilterV1.mirror,
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
}
