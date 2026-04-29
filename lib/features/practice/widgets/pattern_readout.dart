import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../../state/app_controller.dart';
import 'pattern_voice_display.dart';

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
    return PatternVoiceDisplay(
      tokens: controller.patternTokensFor(itemId),
      markings: controller.noteMarkingsFor(itemId),
      voices: controller.noteVoicesFor(itemId),
      patternStyle: patternStyle,
      voiceStyle: voiceStyle,
      cellWidth: cellWidth,
      grouping: grouping ?? controller.displayGroupingFor(itemId),
      showRepeatIndicator: showRepeatIndicator,
      scrollable: scrollable,
      showPatternRow: showPatternRow,
      showDynamics: showDynamics,
      showVoiceRow: showVoiceRow ?? controller.hasNonSnareVoice(itemId),
      wrap: wrap,
      fitToBounds: fitToBounds,
    );
  }
}
