import 'package:flutter/material.dart';

import '../../../core/pattern/triad_matrix.dart';
import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';

class TriadMatrixGrid extends StatelessWidget {
  final AppController controller;
  final Set<TriadMatrixViewModeV1> modes;
  final Set<String> selectedRows;
  final Set<String> selectedColumns;
  final ValueChanged<String> onToggleRow;
  final ValueChanged<String> onToggleColumn;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const TriadMatrixGrid({
    super.key,
    required this.controller,
    required this.modes,
    required this.selectedRows,
    required this.selectedColumns,
    required this.onToggleRow,
    required this.onToggleColumn,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  Widget build(BuildContext context) {
    final List<TriadMatrixCell> cells = triadMatrixAll();

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFFF7F2E7),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Table(
          columnWidths: const <int, TableColumnWidth>{
            0: FixedColumnWidth(38),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: <TableRow>[
            TableRow(
              children: <Widget>[
                const SizedBox.shrink(),
                _MatrixAxisLabel(
                  label: 'R',
                  selected: selectedColumns.contains('R'),
                  onTap: () => onToggleColumn('R'),
                ),
                _MatrixAxisLabel(
                  label: 'L',
                  selected: selectedColumns.contains('L'),
                  onTap: () => onToggleColumn('L'),
                ),
                _MatrixAxisLabel(
                  label: 'K',
                  selected: selectedColumns.contains('K'),
                  onTap: () => onToggleColumn('K'),
                ),
              ],
            ),
            for (int rowIndex = 0; rowIndex < 9; rowIndex++)
              TableRow(
                children: <Widget>[
                  _MatrixAxisLabel(
                    label: cells[rowIndex * 3].id.substring(1),
                    selected: selectedRows.contains(cells[rowIndex * 3].id.substring(1)),
                    onTap: () => onToggleRow(cells[rowIndex * 3].id.substring(1)),
                  ),
                  for (final TriadMatrixCell cell
                      in cells.skip(rowIndex * 3).take(3))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: _TriadCellButton(
                        controller: controller,
                        cell: cell,
                        modes: modes,
                        rowSelected: selectedRows.contains(cell.id.substring(1)),
                        columnSelected: selectedColumns.contains(cell.id.substring(0, 1)),
                        rowFilterActive: selectedRows.isNotEmpty,
                        columnFilterActive: selectedColumns.isNotEmpty,
                        onOpenItem: onOpenItem,
                        onPracticeItem: onPracticeItem,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MatrixAxisLabel extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MatrixAxisLabel({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 2,
        bottom: 2,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? const Color(0xFFE4DED1) : Colors.transparent,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF101010),
                ),
          ),
        ),
      ),
    );
  }
}

class _TriadCellButton extends StatelessWidget {
  final AppController controller;
  final TriadMatrixCell cell;
  final Set<TriadMatrixViewModeV1> modes;
  final bool rowSelected;
  final bool columnSelected;
  final bool rowFilterActive;
  final bool columnFilterActive;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const _TriadCellButton({
    required this.controller,
    required this.cell,
    required this.modes,
    required this.rowSelected,
    required this.columnSelected,
    required this.rowFilterActive,
    required this.columnFilterActive,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  Widget build(BuildContext context) {
    final String itemId = controller.triadItemForCell(cell.id)!.id;
    final _CellDecorationStyle style = _styleFor(itemId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onOpenItem(itemId),
        onLongPress: () => onPracticeItem(itemId),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: style.backgroundColor,
            border: Border.all(
              color: style.borderColor,
              width: style.borderWidth,
            ),
          ),
          child: Center(
            child: Text(
              cell.id,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: style.textColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
                  ),
            ),
          ),
        ),
      ),
    );
  }

  _CellDecorationStyle _styleFor(String itemId) {
    Color backgroundColor = const Color(0xFFF6F1E7);
    Color borderColor = const Color(0x22000000);
    double borderWidth = 1;
    Color textColor = Colors.black;

    final bool handsOnly = controller.handsOnly(itemId);
    final bool weakHandLead = controller.leadsWithWeakHand(itemId);
    final bool hasAccents = controller.itemById(itemId).hasAccents;

    final bool filteredOutByHandsOnly =
        modes.contains(TriadMatrixViewModeV1.handsOnly) && !handsOnly;
    final bool filteredOutByWeakHand =
        modes.contains(TriadMatrixViewModeV1.weakHand) && !weakHandLead;
    final bool filteredOutByRow = rowFilterActive && !rowSelected;
    final bool filteredOutByColumn = columnFilterActive && !columnSelected;

    if (filteredOutByHandsOnly ||
        filteredOutByWeakHand ||
        filteredOutByRow ||
        filteredOutByColumn) {
      return const _CellDecorationStyle(
        backgroundColor: Color(0xFFE0DDD8),
        borderColor: Color(0x22000000),
        borderWidth: 1,
        textColor: Color(0x99000000),
      );
    }

    if (modes.contains(TriadMatrixViewModeV1.competency)) {
      backgroundColor = switch (controller.competencyFor(itemId)) {
        CompetencyLevelV1.notStarted => const Color(0xFFF1ECE3),
        CompetencyLevelV1.learning => const Color(0xFFD9E9F7),
        CompetencyLevelV1.comfortable => const Color(0xFFDDEDDD),
        CompetencyLevelV1.reliable => const Color(0xFFF4E4C8),
        CompetencyLevelV1.musical => const Color(0xFFF4D8DC),
      };
    }

    if (modes.contains(TriadMatrixViewModeV1.lead)) {
      borderColor = controller.leadsWithRight(itemId)
          ? const Color(0xFF4F86C6)
          : controller.leadsWithLeft(itemId)
              ? const Color(0xFFC76D5A)
              : const Color(0xFFD2A93A);
      borderWidth = borderWidth < 2 ? 2 : borderWidth;
    }

    if (modes.contains(TriadMatrixViewModeV1.handsOnly) && handsOnly) {
      borderColor = Colors.black;
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (modes.contains(TriadMatrixViewModeV1.weakHand) && weakHandLead) {
      borderColor = const Color(0xFF9A4A33);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (hasAccents && !modes.contains(TriadMatrixViewModeV1.lead)) {
      borderColor = borderWidth > 1 ? borderColor : const Color(0x33000000);
    }

    return _CellDecorationStyle(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      textColor: textColor,
    );
  }
}

class _CellDecorationStyle {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final Color textColor;

  const _CellDecorationStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.textColor,
  });
}
