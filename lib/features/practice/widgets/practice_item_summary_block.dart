import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';
import 'pattern_display_text.dart';
import 'pattern_voice_display.dart';

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
        PatternDisplayText(
          tokens: controller.noteTokensFor(item.id),
          markings: controller.noteMarkingsFor(item.id),
          grouping: controller.displayGroupingFor(item.id),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        if (controller.hasNonSnareVoice(item.id)) ...<Widget>[
          const SizedBox(height: 6),
          PatternVoiceDisplay(
            tokens: controller.noteTokensFor(item.id),
            markings: controller.noteMarkingsFor(item.id),
            voices: controller.noteVoicesFor(item.id),
            patternStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
            voiceStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF6A5E4C),
              fontWeight: FontWeight.w700,
            ),
            grouping: controller.displayGroupingFor(item.id),
          ),
        ],
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
