import 'package:flutter/material.dart';

import '../../../core/pattern/triad_matrix.dart';
import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';

class TriadMatrixGrid extends StatelessWidget {
  final AppController controller;
  final MatrixFiltersV1 filters;
  final MatrixSelectionStateV1 selection;
  final ValueChanged<String> onToggleRow;
  final ValueChanged<String> onToggleColumn;
  final ValueChanged<String> onTapItem;

  const TriadMatrixGrid({
    super.key,
    required this.controller,
    required this.filters,
    required this.selection,
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
                  selected: filters.selectedColumns.contains('R'),
                  onTap: () => onToggleColumn('R'),
                ),
                _MatrixAxisLabel(
                  label: 'L',
                  selected: filters.selectedColumns.contains('L'),
                  onTap: () => onToggleColumn('L'),
                ),
                _MatrixAxisLabel(
                  label: 'K',
                  selected: filters.selectedColumns.contains('K'),
                  onTap: () => onToggleColumn('K'),
                ),
              ],
            ),
            for (int rowIndex = 0; rowIndex < 9; rowIndex++)
              TableRow(
                children: <Widget>[
                  _MatrixAxisLabel(
                    label: cells[rowIndex * 3].id.substring(1),
                    selected: filters.selectedRows.contains(
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
                        selection: selection,
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
  final MatrixFiltersV1 filters;
  final MatrixSelectionStateV1 selection;
  final ValueChanged<String> onTapItem;

  const _TriadCellButton({
    required this.controller,
    required this.cell,
    required this.filters,
    required this.selection,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final String itemId = controller.triadItemForCell(cell.id)!.id;
    final MatrixCellVisualStateV1 visualState = controller
        .matrixCellVisualStateFor(
          itemId: itemId,
          filters: filters,
          selection: selection,
        );
    final _CellDecorationStyle style = _styleFor(itemId, visualState);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: visualState.inScope ? () => onTapItem(itemId) : null,
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

  _CellDecorationStyle _styleFor(
    String itemId,
    MatrixCellVisualStateV1 visualState,
  ) {
    final bool hasActiveProgressFilter = filters.filters.any(
      _progressFilterSet.contains,
    );
    Color backgroundColor = switch (visualState.progress) {
      MatrixProgressStateV1.notTrained => const Color(0xFFFFFFFF),
      MatrixProgressStateV1.active => const Color(0xFFD9E9F7),
      MatrixProgressStateV1.needsWork => const Color(0xFFF0B2AA),
      MatrixProgressStateV1.strong => const Color(0xFFDDEDDD),
    };
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
    final bool recent = controller.isRecent(itemId);
    if (visualState.muted) {
      if (hasActiveProgressFilter) {
        backgroundColor = const Color(0xFFF1ECE3);
        borderColor = const Color(0xFFE0D6C6);
        borderWidth = 1;
        textColor = const Color(0x886A5E4C);
      } else {
        backgroundColor =
            Color.lerp(backgroundColor, const Color(0xFFE6E1D7), 0.5) ??
            const Color(0xFFE6E1D7);
        borderColor = const Color(0x22000000);
        textColor = const Color(0x99000000);
      }
    }

    if (!visualState.muted &&
        rightLead &&
        filters.filters.contains(TriadMatrixFilterV1.rightLead)) {
      borderColor = const Color(0xFFC94949);
      borderWidth = borderWidth < 2 ? 2 : borderWidth;
    }

    if (!visualState.muted &&
        leftLead &&
        filters.filters.contains(TriadMatrixFilterV1.leftLead)) {
      borderColor = const Color(0xFF2F6EC8);
      borderWidth = borderWidth < 2 ? 2 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.handsOnly) &&
        handsOnly) {
      borderColor = Colors.black;
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.hasKick) &&
        hasKick) {
      borderColor = const Color(0xFF8B6A1C);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.startsWithKick) &&
        startsWithKick) {
      borderColor = const Color(0xFF7E6222);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.endsWithKick) &&
        endsWithKick) {
      borderColor = const Color(0xFF916F2F);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.doubles) &&
        hasDoubles) {
      borderColor = const Color(0xFF3E4E74);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.inRoutine) &&
        inRoutine) {
      borderColor = const Color(0xFF41644A);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.inPhrases) &&
        controller.isInAnyPhrase(itemId)) {
      borderColor = const Color(0xFF7A5D9E);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.recent) &&
        recent) {
      borderColor = const Color(0xFF2F7C72);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.notTrained) &&
        visualState.progress == MatrixProgressStateV1.notTrained) {
      borderColor = const Color(0xFF6B6B6B);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.activeStatus) &&
        visualState.progress == MatrixProgressStateV1.active) {
      borderColor = const Color(0xFF3A6F96);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (!visualState.muted &&
        filters.filters.contains(TriadMatrixFilterV1.needsWorkStatus) &&
        visualState.progress == MatrixProgressStateV1.needsWork) {
      borderColor = const Color(0xFF9C3D2C);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
    }

    if (visualState.selected) {
      borderColor = const Color(0xFF101010);
      borderWidth = borderWidth < 3 ? 3 : borderWidth;
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

const Set<TriadMatrixFilterV1> _progressFilterSet = <TriadMatrixFilterV1>{
  TriadMatrixFilterV1.notTrained,
  TriadMatrixFilterV1.activeStatus,
  TriadMatrixFilterV1.needsWorkStatus,
  TriadMatrixFilterV1.inRoutine,
  TriadMatrixFilterV1.inPhrases,
  TriadMatrixFilterV1.recent,
};
