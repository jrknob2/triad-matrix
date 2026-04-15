import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';
import 'pattern_readout.dart';

class PracticeItemSummaryBlock extends StatelessWidget {
  final AppController controller;
  final PracticeItemV1 item;
  final List<String> metadataLines;

  const PracticeItemSummaryBlock({
    super.key,
    required this.controller,
    required this.item,
    this.metadataLines = const <String>[],
  });

  @override
  Widget build(BuildContext context) {
    final List<String> visibleMetadata = metadataLines
        .where((String line) => line.trim().isNotEmpty)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PatternReadout(
          controller: controller,
          itemId: item.id,
          patternStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
          voiceStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: const Color(0xFF6A5E4C),
            fontWeight: FontWeight.w700,
          ),
          scrollable: false,
          wrap: true,
          cellWidth: 32,
        ),
        for (
          int index = 0;
          index < visibleMetadata.length;
          index++
        ) ...<Widget>[
          SizedBox(height: index == 0 ? 6 : 2),
          Text(
            visibleMetadata[index],
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6A5E4C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
