import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';
import 'pattern_readout.dart';
import '../../app/drumcabulary_theme.dart';

class PracticeItemSummaryBlock extends StatelessWidget {
  static const double _patternMetadataGap = 4;

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
    final String metadataText = metadataLines
        .where((String line) => line.trim().isNotEmpty)
        .join(' • ');

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
            color: DrumcabularyTheme.mutedInk,
            fontWeight: FontWeight.w700,
          ),
          scrollable: false,
          wrap: true,
          cellWidth: 32,
        ),
        if (metadataText.isNotEmpty) ...<Widget>[
          const SizedBox(height: _patternMetadataGap),
          Text(
            metadataText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: DrumcabularyTheme.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}
