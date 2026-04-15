import 'package:flutter/material.dart';

import '../../../state/app_controller.dart';
import 'pattern_readout.dart';

class PatternSequenceEditor extends StatelessWidget {
  final AppController controller;
  final List<String> itemIds;
  final ValueChanged<int>? onRemoveAt;
  final EdgeInsetsGeometry chipPadding;

  const PatternSequenceEditor({
    super.key,
    required this.controller,
    required this.itemIds,
    this.onRemoveAt,
    this.chipPadding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: List<Widget>.generate(itemIds.length, (int index) {
        final String itemId = itemIds[index];
        return InputChip(
          padding: chipPadding,
          label: PatternReadout(
            controller: controller,
            itemId: itemId,
            patternStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
            voiceStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6A5E4C),
            ),
            scrollable: false,
            wrap: false,
            cellWidth: 22,
          ),
          onDeleted: onRemoveAt == null ? null : () => onRemoveAt!(index),
        );
      }),
    );
  }
}
