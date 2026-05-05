import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../app/app_formatters.dart';
import '../../app/drumcabulary_theme.dart';
import '../../../state/app_controller.dart';
import 'pattern_text_styles.dart';

class PatternReadout extends StatelessWidget {
  final AppController controller;
  final String itemId;
  final TextStyle? patternStyle;
  final TextStyle? voiceStyle;
  final PatternGroupingV1? grouping;
  final bool showRepeatIndicator;
  final bool scrollable;
  final bool wrap;
  final double cellWidth;
  final bool showDynamics;
  final bool? showVoiceRow;
  final bool showPatternRow;
  final bool fitToBounds;

  const PatternReadout({
    super.key,
    required this.controller,
    required this.itemId,
    this.patternStyle,
    this.voiceStyle,
    this.grouping,
    this.showRepeatIndicator = false,
    this.scrollable = true,
    this.wrap = false,
    this.cellWidth = 46,
    this.showDynamics = true,
    this.showVoiceRow,
    this.showPatternRow = true,
    this.fitToBounds = true,
  });

  @override
  Widget build(BuildContext context) {
    final PracticeItemV1 item = controller.itemById(itemId);
    return PatternTextReadout(
      patternText: controller.markedPatternTextFor(
        itemId,
        grouping: PatternGroupingV1.none,
      ),
      metadataText: notationInfoForPracticeItem(item),
      patternStyle: patternStyle,
      scrollable: scrollable,
      wrap: wrap,
    );
  }
}

class PatternTextReadout extends StatelessWidget {
  final String patternText;
  final String? metadataText;
  final TextStyle? patternStyle;
  final TextStyle? metadataStyle;
  final bool scrollable;
  final bool wrap;

  const PatternTextReadout({
    super.key,
    required this.patternText,
    this.metadataText,
    this.patternStyle,
    this.metadataStyle,
    this.scrollable = false,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle resolvedPatternStyle = patternStyle == null
        ? PatternTextStyles.compact(context)
        : PatternTextStyles.applyNotationFace(patternStyle!);
    final TextStyle resolvedMetadataStyle =
        metadataStyle ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
          color: DrumcabularyTheme.mutedInk,
          fontWeight: FontWeight.w700,
        ) ??
        const TextStyle(
          color: DrumcabularyTheme.mutedInk,
          fontWeight: FontWeight.w700,
        );
    final Text pattern = Text(
      patternText.isEmpty ? '-' : patternText,
      maxLines: wrap ? null : 1,
      overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
      softWrap: wrap,
      style: resolvedPatternStyle,
    );
    final Widget patternWidget = scrollable && !wrap
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: pattern,
          )
        : pattern;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        patternWidget,
        if (metadataText != null &&
            metadataText!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 3),
          Text(
            metadataText!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: resolvedMetadataStyle,
          ),
        ],
      ],
    );
  }
}
