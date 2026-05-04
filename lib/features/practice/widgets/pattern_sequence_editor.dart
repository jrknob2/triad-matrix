import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';
import 'pattern_readout.dart';
import '../../app/drumcabulary_theme.dart';
import '../../app/app_formatters.dart';

class PatternSequenceEditor extends StatelessWidget {
  final AppController controller;
  final List<String> itemIds;
  final ValueChanged<int>? onRemoveAt;
  final EdgeInsetsGeometry chipPadding;
  final bool? showVoiceRows;
  final List<MatrixPhraseReadoutDataV1>? readouts;

  const PatternSequenceEditor({
    super.key,
    required this.controller,
    required this.itemIds,
    this.onRemoveAt,
    this.chipPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.showVoiceRows,
    this.readouts,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(itemIds.length, (int index) {
        final String itemId = itemIds[index];
        final MatrixPhraseReadoutDataV1? readout =
            readouts != null && index < readouts!.length
            ? readouts![index]
            : null;
        return InputChip(
          padding: chipPadding,
          label: readout == null
              ? PatternReadout(
                  controller: controller,
                  itemId: itemId,
                  patternStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                  voiceStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DrumcabularyTheme.mutedInk,
                  ),
                  scrollable: false,
                  wrap: false,
                  fitToBounds: false,
                  cellWidth: 22,
                  showVoiceRow: showVoiceRows,
                )
              : PatternTextReadout(
                  patternText: markedPatternTextForNotes(
                    readout.tokens,
                    readout.markings,
                    grouping: PatternGroupingV1.none,
                  ),
                  patternStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                  metadataStyle: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: DrumcabularyTheme.mutedInk,
                      ),
                  scrollable: false,
                  wrap: false,
                ),
          onDeleted: onRemoveAt == null ? null : () => onRemoveAt!(index),
        );
      }),
    );
  }
}
