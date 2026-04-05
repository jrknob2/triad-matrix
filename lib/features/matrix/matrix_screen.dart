import 'package:flutter/material.dart';

import '../../core/pattern/triad_matrix.dart';
import '../../core/practice/practice_domain_v1.dart';
import '../../features/app/app_formatters.dart';
import '../../state/app_controller.dart';

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
  TriadMatrixViewModeV1 _mode = TriadMatrixViewModeV1.competency;

  @override
  Widget build(BuildContext context) {
    final List<TriadMatrixCell> cells = triadMatrixAll();
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Triad Matrix',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Switch modes to see competency, lead hand, accents, surface use, or weak-hand pressure across the full matrix.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<TriadMatrixViewModeV1>(
                    segments: TriadMatrixViewModeV1.values
                        .map(
                          (mode) => ButtonSegment<TriadMatrixViewModeV1>(
                            value: mode,
                            label: Text(mode.label),
                          ),
                        )
                        .toList(growable: false),
                    selected: <TriadMatrixViewModeV1>{_mode},
                    onSelectionChanged: (Set<TriadMatrixViewModeV1> selection) {
                      setState(() => _mode = selection.first);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                _ModeLegend(mode: _mode, controller: widget.controller),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                children: <Widget>[
                  _MatrixHeader(),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 9,
                      itemBuilder: (BuildContext context, int rowIndex) {
                        final List<TriadMatrixCell> rowCells =
                            cells.skip(rowIndex * 3).take(3).toList(growable: false);
                        final String rowLabel = rowCells.first.id.substring(1);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: 48,
                                child: Text(
                                  rowLabel,
                                  textAlign: TextAlign.right,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              for (final TriadMatrixCell cell in rowCells) ...<Widget>[
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: _MatrixCellCard(
                                      controller: widget.controller,
                                      cell: cell,
                                      mode: _mode,
                                      onOpenItem: widget.onOpenItem,
                                      onPracticeItem: widget.onPracticeItem,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatrixHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(width: 58),
        for (final String label in const <String>['R', 'L', 'K']) ...<Widget>[
          Expanded(
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ModeLegend extends StatelessWidget {
  final TriadMatrixViewModeV1 mode;
  final AppController controller;

  const _ModeLegend({
    required this.mode,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final String text = switch (mode) {
      TriadMatrixViewModeV1.competency =>
        'Warm cells are more developed. Cool cells need work.',
      TriadMatrixViewModeV1.lead =>
        'Blue leads right, rust leads left, gold leads kick.',
      TriadMatrixViewModeV1.accents =>
        'Badge shows the guided accent shape. Brighter cells invite accent work.',
      TriadMatrixViewModeV1.surface =>
        'Hands-only cells stay clean. Kick cells signal kit-oriented material.',
      TriadMatrixViewModeV1.weakHand =>
        '${controller.weakHandLabel}-leading cells are emphasized for focused practice.',
    };

    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _MatrixCellCard extends StatelessWidget {
  final AppController controller;
  final TriadMatrixCell cell;
  final TriadMatrixViewModeV1 mode;
  final ValueChanged<String> onOpenItem;
  final ValueChanged<String> onPracticeItem;

  const _MatrixCellCard({
    required this.controller,
    required this.cell,
    required this.mode,
    required this.onOpenItem,
    required this.onPracticeItem,
  });

  @override
  Widget build(BuildContext context) {
    final item = controller.triadItemForCell(cell.id)!;
    final Color fill = _fillForMode(item.id);
    final Color foreground = fill.computeLuminance() > 0.55
        ? const Color(0xFF22303A)
        : Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onOpenItem(item.id),
      onLongPress: () => onPracticeItem(item.id),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: fill,
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                cell.id,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _secondaryLabel(item.id),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: foreground.withValues(alpha: 0.88),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                controller.accentPatternLabelFor(item.id),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: foreground.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _secondaryLabel(String itemId) {
    return switch (mode) {
      TriadMatrixViewModeV1.competency =>
        controller.competencyFor(itemId).label,
      TriadMatrixViewModeV1.lead => controller.leadsWithRight(itemId)
          ? 'Lead R'
          : controller.leadsWithLeft(itemId)
              ? 'Lead L'
              : 'Lead K',
      TriadMatrixViewModeV1.accents => 'Accent map',
      TriadMatrixViewModeV1.surface =>
        controller.handsOnly(itemId) ? 'Hands only' : 'Uses kick',
      TriadMatrixViewModeV1.weakHand => controller.leadsWithWeakHand(itemId)
          ? '${controller.weakHandLabel} lead'
          : 'Neutral',
    };
  }

  Color _fillForMode(String itemId) {
    return switch (mode) {
      TriadMatrixViewModeV1.competency =>
        switch (controller.competencyFor(itemId)) {
          CompetencyLevelV1.notStarted => const Color(0xFFCFD8DC),
          CompetencyLevelV1.learning => const Color(0xFF86BBD8),
          CompetencyLevelV1.comfortable => const Color(0xFF6AB187),
          CompetencyLevelV1.reliable => const Color(0xFFE0A458),
          CompetencyLevelV1.musical => const Color(0xFFD96C75),
        },
      TriadMatrixViewModeV1.lead => controller.leadsWithRight(itemId)
          ? const Color(0xFF4F86C6)
          : controller.leadsWithLeft(itemId)
              ? const Color(0xFFC76D5A)
              : const Color(0xFFD2A93A),
      TriadMatrixViewModeV1.accents => controller.itemById(itemId).hasAccents
          ? const Color(0xFF5FA89B)
          : const Color(0xFFB9C0C7),
      TriadMatrixViewModeV1.surface => controller.handsOnly(itemId)
          ? const Color(0xFF4F7C5A)
          : const Color(0xFF7F5A83),
      TriadMatrixViewModeV1.weakHand => controller.leadsWithWeakHand(itemId)
          ? const Color(0xFFE07A5F)
          : const Color(0xFF98A8B8),
    };
  }
}
