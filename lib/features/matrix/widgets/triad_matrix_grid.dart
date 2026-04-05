import 'package:flutter/material.dart';

import '../../../core/pattern/triad_matrix.dart';
import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';

class TriadMatrixGrid extends StatelessWidget {
  final AppController controller;
  final Set<TriadMatrixViewModeV1> modes;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const TriadMatrixGrid({
    super.key,
    required this.controller,
    required this.modes,
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
            const TableRow(
              children: <Widget>[
                SizedBox.shrink(),
                _MatrixAxisLabel(label: 'R'),
                _MatrixAxisLabel(label: 'L'),
                _MatrixAxisLabel(label: 'K'),
              ],
            ),
            for (int rowIndex = 0; rowIndex < 9; rowIndex++)
              TableRow(
                children: <Widget>[
                  _MatrixAxisLabel(
                    label: cells[rowIndex * 3].id.substring(1),
                    alignRight: true,
                  ),
                  for (final TriadMatrixCell cell
                      in cells.skip(rowIndex * 3).take(3))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                      child: _TriadCellButton(
                        controller: controller,
                        cell: cell,
                        modes: modes,
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
  final bool alignRight;

  const _MatrixAxisLabel({
    required this.label,
    this.alignRight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        right: alignRight ? 4 : 0,
        top: 2,
        bottom: 2,
      ),
      child: Align(
        alignment: alignRight ? Alignment.centerRight : Alignment.center,
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF101010),
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
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const _TriadCellButton({
    required this.controller,
    required this.cell,
    required this.modes,
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

    if (filteredOutByHandsOnly || filteredOutByWeakHand) {
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

    if (modes.contains(TriadMatrixViewModeV1.accents) && hasAccents) {
      backgroundColor = modes.contains(TriadMatrixViewModeV1.competency)
          ? backgroundColor
          : const Color(0xFFDDF0E6);
      borderColor = const Color(0xFF2F7D57);
      borderWidth = 2;
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
