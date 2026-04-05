// lib/features/practice/widgets/triad_picker.dart
//
// Triad Trainer — Triad Picker (v1)
//
// Purpose:
// - Show the full triad matrix at once (no traversal required).
// - Allow selecting 1..N triad cells in an explicit order.
// - UI-only: no controller/state here. Selection order is owned by caller.

import 'package:flutter/material.dart';

class TriadPicker extends StatelessWidget {
  final List<String> selectedCellIds;
  final ValueChanged<String> onToggleCellId;
  final VoidCallback? onClear;
  final VoidCallback? onDone;
  final String? subtitle;

  const TriadPicker({
    super.key,
    required this.selectedCellIds,
    required this.onToggleCellId,
    this.onClear,
    this.onDone,
    this.subtitle,
  });

  static const List<String> _cols = <String>['R', 'L', 'K'];

  static const List<String> _rows = <String>[
    'RR',
    'LL',
    'RL',
    'LR',
    'KK',
    'RK',
    'LK',
    'KR',
    'KL',
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle headerStyle = theme.textTheme.labelLarge!.copyWith(
      fontWeight: FontWeight.w800,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints rootC) {
        final double maxH = rootC.maxHeight.isFinite ? rootC.maxHeight : 800;
        final bool compact = maxH < 560;

        final double headerGap = compact ? 8 : 10;

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            _HeaderBar(
              title: 'Pick triads',
              subtitle: subtitle ?? 'Tap to select. Tap again to remove.',
              onClear: onClear,
              onDone: onDone,
              compact: compact,
            ),
            SizedBox(height: headerGap),

            // Matrix: MUST fit remaining space (no scroll, no overflow)
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints c) {
                  final ThemeData theme = Theme.of(context);
                  final ColorScheme cs = theme.colorScheme;

                  final TextStyle rowStyle = theme.textTheme.labelLarge!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: cs.onSurfaceVariant,
                  );

                  final double maxW = c.maxWidth;
                  final double maxGridH = c.maxHeight;

                  // Layout constants
                  const double rowLabelW = 52;
                  final double colHeaderH = compact ? 20 : 22;
                  final double colHeaderGap = compact ? 4 : 6;

                  // Tile spacing
                  final double gapX = compact ? 6 : 8;
                  final double gapY = compact ? 6 : 8;

                  // Cell width from available width.
                  final double usableW = (maxW - rowLabelW).clamp(0.0, maxW);
                  final double cellW = ((usableW - (2 * gapX)) / 3).clamp(
                    compact ? 56.0 : 64.0,
                    compact ? 110.0 : 140.0,
                  );

                  // Cell height computed from available height so grid ALWAYS fits.
                  final int rows = _rows.length;
                  final double fixedH = colHeaderH + colHeaderGap;
                  final double remainingH = (maxGridH - fixedH).clamp(0.0, maxGridH);

                  final double cellH =
                      ((remainingH - ((rows - 1) * gapY)) / rows).clamp(
                    compact ? 30.0 : 36.0,
                    compact ? 54.0 : 62.0,
                  );

                  // Cap height by width so buttons don't get weirdly tall.
                  final double maxHFromW = (cellW * 0.82).clamp(30.0, 60.0);
                  final double finalCellH = cellH > maxHFromW ? maxHFromW : cellH;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(
                        height: colHeaderH,
                        child: Row(
                          children: <Widget>[
                            const SizedBox(width: rowLabelW),
                            for (int i = 0; i < _cols.length; i++) ...<Widget>[
                              SizedBox(
                                width: cellW,
                                child: Center(
                                  child: Text(_cols[i], style: headerStyle),
                                ),
                              ),
                              if (i != _cols.length - 1) SizedBox(width: gapX),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(height: colHeaderGap),

                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            for (int r = 0; r < _rows.length; r++) ...<Widget>[
                              Row(
                                children: <Widget>[
                                  SizedBox(
                                    width: rowLabelW,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Text(_rows[r], style: rowStyle),
                                      ),
                                    ),
                                  ),
                                  for (int cIdx = 0; cIdx < _cols.length; cIdx++) ...<Widget>[
                                    _CellButton(
                                      width: cellW,
                                      height: finalCellH,
                                      cellId: '${_cols[cIdx]}${_rows[r]}',
                                      selected: selectedCellIds.contains('${_cols[cIdx]}${_rows[r]}'),
                                      onTap: () => onToggleCellId('${_cols[cIdx]}${_rows[r]}'),
                                      compact: compact,
                                    ),
                                    if (cIdx != _cols.length - 1) SizedBox(width: gapX),
                                  ],
                                ],
                              ),
                              if (r != _rows.length - 1) SizedBox(height: gapY),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onClear;
  final VoidCallback? onDone;
  final bool compact;

  const _HeaderBar({
    required this.title,
    required this.subtitle,
    this.onClear,
    this.onDone,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (onClear != null) ...<Widget>[
          TextButton(
            onPressed: onClear,
            child: const Text('Clear'),
          ),
          const SizedBox(width: 6),
        ],
        if (onDone != null)
          FilledButton(
            onPressed: onDone,
            child: const Text('Done'),
          ),
      ],
    );
  }
}

class _CellButton extends StatelessWidget {
  final double width;
  final double height;
  final String cellId;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  const _CellButton({
    required this.width,
    required this.height,
    required this.cellId,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final Color bg = selected
        ? cs.primaryContainer.withValues(alpha: 0.80)
        : cs.surfaceContainerHighest.withValues(alpha: 0.25);

    final Color border = selected ? cs.primary : cs.outlineVariant;

    final TextStyle textStyle = theme.textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w900,
      letterSpacing: 1.0,
      color: selected ? cs.onPrimaryContainer : cs.onSurface,
      fontSize: compact ? 16 : 18,
    );

    return SizedBox(
      width: width,
      height: height,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: bg,
            border: Border.all(color: border, width: selected ? 1.6 : 1.0),
          ),
          child: Center(child: Text(cellId, style: textStyle)),
        ),
      ),
    );
  }
}
