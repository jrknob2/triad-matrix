import 'package:flutter/material.dart';

import '../../../core/pattern/triad_matrix.dart';
import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';

class TriadMatrixGrid extends StatelessWidget {
  final AppController controller;
  final Set<TriadMatrixFilterV1> filters;
  final Set<String> selectedComboIds;
  final List<String> selectedItemIds;
  final Set<String> selectedRows;
  final Set<String> selectedColumns;
  final ValueChanged<String> onToggleRow;
  final ValueChanged<String> onToggleColumn;
  final ValueChanged<String> onTapItem;

  const TriadMatrixGrid({
    super.key,
    required this.controller,
    required this.filters,
    required this.selectedComboIds,
    this.selectedItemIds = const <String>[],
    required this.selectedRows,
    required this.selectedColumns,
    required this.onToggleRow,
    required this.onToggleColumn,
    required this.onTapItem,
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
          columnWidths: const <int, TableColumnWidth>{0: FixedColumnWidth(38)},
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
                    selected: selectedRows.contains(
                      cells[rowIndex * 3].id.substring(1),
                    ),
                    onTap: () =>
                        onToggleRow(cells[rowIndex * 3].id.substring(1)),
                  ),
                  for (final TriadMatrixCell cell
                      in cells.skip(rowIndex * 3).take(3))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: _TriadCellButton(
                        controller: controller,
                        cell: cell,
                        filters: filters,
                        selectedComboIds: selectedComboIds,
                        rowSelected: selectedRows.contains(
                          cell.id.substring(1),
                        ),
                        columnSelected: selectedColumns.contains(
                          cell.id.substring(0, 1),
                        ),
                        rowFilterActive: selectedRows.isNotEmpty,
                        columnFilterActive: selectedColumns.isNotEmpty,
                        selectionIndex: selectedItemIds.indexOf(
                          controller.triadItemForCell(cell.id)!.id,
                        ),
                        onTapItem: onTapItem,
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
      padding: const EdgeInsets.only(top: 2, bottom: 2),
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
  final Set<TriadMatrixFilterV1> filters;
  final Set<String> selectedComboIds;
  final bool rowSelected;
  final bool columnSelected;
  final bool rowFilterActive;
  final bool columnFilterActive;
  final int selectionIndex;
  final ValueChanged<String> onTapItem;

  const _TriadCellButton({
    required this.controller,
    required this.cell,
    required this.filters,
    required this.selectedComboIds,
    required this.rowSelected,
    required this.columnSelected,
    required this.rowFilterActive,
    required this.columnFilterActive,
    required this.selectionIndex,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final String itemId = controller.triadItemForCell(cell.id)!.id;
    final _CellDecorationStyle style = _styleFor(itemId);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onTapItem(itemId),
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
          child: Stack(
            children: <Widget>[
              Center(
                child: Text(
                  cell.id,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: style.textColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
              if (selectionIndex >= 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF101010),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${selectionIndex + 1}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
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
    final bool rightLead = controller.startsWithRight(itemId);
    final bool leftLead = controller.startsWithLeft(itemId);
    final bool hasKick = controller.hasKick(itemId);
    final bool startsWithKick = controller.startsWithKick(itemId);
    final bool endsWithKick = controller.endsWithKick(itemId);
    final bool hasDoubles = controller.hasDoubles(itemId);
    final bool inRoutine = controller.isInRoutine(itemId);
    final bool needsAttention = controller.needsAttention(itemId);
    final bool underPracticed = controller.isUnderPracticed(itemId);
    final bool closeToToolkit = controller.isCloseToToolkit(itemId);
    final bool recent = controller.isRecent(itemId);
    final bool unseen = controller.isUnseen(itemId);
    final bool comboMatch =
        selectedComboIds.isEmpty ||
        selectedComboIds.any(
          (comboId) => controller.combinationContainsItem(
            comboId: comboId,
            itemId: itemId,
          ),
        );

    final bool filteredOutByHandsOnly =
        filters.contains(TriadMatrixFilterV1.handsOnly) && !handsOnly;
    final bool leadSideFilterActive =
        filters.contains(TriadMatrixFilterV1.rightLead) ||
        filters.contains(TriadMatrixFilterV1.leftLead);
    final bool matchesLeadSide =
        (filters.contains(TriadMatrixFilterV1.rightLead) && rightLead) ||
        (filters.contains(TriadMatrixFilterV1.leftLead) && leftLead);
    final bool filteredOutByLead = leadSideFilterActive && !matchesLeadSide;
    final bool filteredOutByHasKick =
        filters.contains(TriadMatrixFilterV1.hasKick) && !hasKick;
    final bool filteredOutByStartsWithKick =
        filters.contains(TriadMatrixFilterV1.startsWithKick) && !startsWithKick;
    final bool filteredOutByEndsWithKick =
        filters.contains(TriadMatrixFilterV1.endsWithKick) && !endsWithKick;
    final bool filteredOutByInRoutine =
        filters.contains(TriadMatrixFilterV1.inRoutine) && !inRoutine;
    final bool filteredOutByNeedsAttention =
        filters.contains(TriadMatrixFilterV1.needsAttention) && !needsAttention;
    final bool filteredOutByUnderPracticed =
        filters.contains(TriadMatrixFilterV1.underPracticed) && !underPracticed;
    final bool filteredOutByCloseToToolkit =
        filters.contains(TriadMatrixFilterV1.closeToToolkit) && !closeToToolkit;
    final bool filteredOutByRecent =
        filters.contains(TriadMatrixFilterV1.recent) && !recent;
    final bool filteredOutByUnseen =
        filters.contains(TriadMatrixFilterV1.unseen) && !unseen;
    final bool filteredOutByDoubles =
        filters.contains(TriadMatrixFilterV1.doubles) && !hasDoubles;
    final bool filteredOutByCombos = selectedComboIds.isNotEmpty && !comboMatch;
    final bool filteredOutByRow = rowFilterActive && !rowSelected;
    final bool filteredOutByColumn = columnFilterActive && !columnSelected;

    if (filteredOutByHandsOnly ||
        filteredOutByLead ||
        filteredOutByHasKick ||
        filteredOutByStartsWithKick ||
        filteredOutByEndsWithKick ||
        filteredOutByInRoutine ||
        filteredOutByNeedsAttention ||
        filteredOutByUnderPracticed ||
        filteredOutByCloseToToolkit ||
        filteredOutByRecent ||
        filteredOutByUnseen ||
        filteredOutByDoubles ||
        filteredOutByCombos ||
        filteredOutByRow ||
        filteredOutByColumn) {
      return const _CellDecorationStyle(
        backgroundColor: Color(0xFFE0DDD8),
        borderColor: Color(0x22000000),
        borderWidth: 1,
        textColor: Color(0x99000000),
      );
    }

    if (filters.contains(TriadMatrixFilterV1.competency)) {
      backgroundColor = switch (controller.competencyFor(itemId)) {
        CompetencyLevelV1.notStarted => const Color(0xFFF1ECE3),
        CompetencyLevelV1.learning => const Color(0xFFD9E9F7),
        CompetencyLevelV1.comfortable => const Color(0xFFDDEDDD),
        CompetencyLevelV1.reliable => const Color(0xFFF4E4C8),
        CompetencyLevelV1.musical => const Color(0xFFF4D8DC),
      };
    }

    if (rightLead && filters.contains(TriadMatrixFilterV1.rightLead)) {
      borderColor = const Color(0xFFC94949);
      borderWidth = borderWidth < 2 ? 2 : borderWidth;
    }

    if (leftLead && filters.contains(TriadMatrixFilterV1.leftLead)) {
      borderColor = const Color(0xFF2F6EC8);
      borderWidth = borderWidth < 2 ? 2 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.handsOnly) && handsOnly) {
      borderColor = Colors.black;
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.hasKick) && hasKick) {
      borderColor = const Color(0xFF8B6A1C);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.startsWithKick) &&
        startsWithKick) {
      borderColor = const Color(0xFF7E6222);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.endsWithKick) && endsWithKick) {
      borderColor = const Color(0xFF916F2F);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.doubles) && hasDoubles) {
      borderColor = const Color(0xFF3E4E74);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.inRoutine) && inRoutine) {
      borderColor = const Color(0xFF41644A);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.needsAttention) &&
        needsAttention) {
      borderColor = const Color(0xFF9C3D2C);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.underPracticed) &&
        underPracticed) {
      borderColor = const Color(0xFF5E7A8A);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.closeToToolkit) &&
        closeToToolkit) {
      borderColor = const Color(0xFFB37A22);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.recent) && recent) {
      borderColor = const Color(0xFF2F7C72);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (filters.contains(TriadMatrixFilterV1.unseen) && unseen) {
      borderColor = const Color(0xFF6B6B6B);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (selectedComboIds.isNotEmpty && comboMatch) {
      final String comboId = selectedComboIds.firstWhere(
        (candidate) => controller.combinationContainsItem(
          comboId: candidate,
          itemId: itemId,
        ),
      );
      borderColor = _comboColor(comboId);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    return _CellDecorationStyle(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      borderWidth: borderWidth,
      textColor: textColor,
    );
  }

  Color _comboColor(String comboId) {
    const List<Color> colors = <Color>[
      Color(0xFF2E5E4E),
      Color(0xFF7D5A50),
      Color(0xFF3D6C8C),
      Color(0xFF876C2B),
    ];
    return colors[comboId.hashCode.abs() % colors.length];
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
