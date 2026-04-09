import 'package:flutter/material.dart';

import '../../../state/app_controller.dart';
import 'pattern_display_text.dart';

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
          label: PatternDisplayText(
            tokens: controller.noteTokensFor(itemId),
            markings: controller.noteMarkingsFor(itemId),
            grouping: controller.displayGroupingFor(itemId),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
          onDeleted: onRemoveAt == null ? null : () => onRemoveAt!(index),
        );
      }),
    );
  }
}
