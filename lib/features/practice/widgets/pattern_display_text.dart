import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';

class PatternDisplayText extends StatelessWidget {
  final List<String> tokens;
  final List<PatternNoteMarkingV1> markings;
  final TextStyle? style;
  final TextAlign textAlign;
  final double ghostScale;
  final double ghostOpacity;
  final PatternGroupingV1 grouping;
  final bool showRepeatIndicator;
  final int? maxLines;

  const PatternDisplayText({
    super.key,
    required this.tokens,
    required this.markings,
    this.style,
    this.textAlign = TextAlign.center,
    this.ghostScale = 0.84,
    this.ghostOpacity = 0.72,
    this.grouping = PatternGroupingV1.spaced,
    this.showRepeatIndicator = false,
    this.maxLines,
  }) : assert(tokens.length == markings.length);

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle = style ?? DefaultTextStyle.of(context).style;
    final List<String> separators = List<String>.generate(
      tokens.length,
      (int index) => grouping.separatorAfter(index, tokens.length),
      growable: false,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: switch (textAlign) {
        TextAlign.center => CrossAxisAlignment.center,
        TextAlign.end || TextAlign.right => CrossAxisAlignment.end,
        _ => CrossAxisAlignment.start,
      },
      children: <Widget>[
        Align(
          alignment: Alignment.center,
          child: RichText(
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: TextOverflow.visible,
            text: TextSpan(
              style: baseStyle,
              children: <InlineSpan>[
                for (
                  int index = 0;
                  index < tokens.length;
                  index++
                ) ...<InlineSpan>[
                  ..._spansForToken(tokens[index], markings[index], baseStyle),
                  if (separators[index].isNotEmpty)
                    TextSpan(text: separators[index], style: baseStyle),
                ],
              ],
            ),
          ),
        ),
        if (showRepeatIndicator)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Icon(
                Icons.repeat_rounded,
                size: (baseStyle.fontSize ?? 20) * 1.05,
                color: baseStyle.color,
              ),
            ),
          ),
      ],
    );
  }

  List<InlineSpan> _spansForToken(
    String token,
    PatternNoteMarkingV1 marking,
    TextStyle baseStyle,
  ) {
    return switch (marking) {
      PatternNoteMarkingV1.normal => <InlineSpan>[
        TextSpan(text: token, style: baseStyle),
      ],
      PatternNoteMarkingV1.accent => <InlineSpan>[
        TextSpan(text: '^', style: baseStyle),
        TextSpan(text: token, style: baseStyle),
      ],
      PatternNoteMarkingV1.ghost => <InlineSpan>[
        TextSpan(text: '(', style: baseStyle),
        TextSpan(text: token, style: _ghostStyleForToken(token, baseStyle)),
        TextSpan(text: ')', style: baseStyle),
      ],
    };
  }

  TextStyle _ghostStyleForToken(String token, TextStyle baseStyle) {
    final Color baseColor = baseStyle.color ?? const Color(0xFF101010);
    final FontWeight? ghostWeight =
        (baseStyle.fontWeight == null ||
            baseStyle.fontWeight!.value < FontWeight.w700.value)
        ? baseStyle.fontWeight
        : FontWeight.w700;

    if (token != 'R' && token != 'L') {
      return baseStyle.copyWith(
        color: baseColor.withValues(alpha: ghostOpacity),
        fontWeight: ghostWeight,
      );
    }
    final double? fontSize = baseStyle.fontSize;
    return baseStyle.copyWith(
      fontSize: fontSize == null ? null : fontSize * ghostScale,
      color: baseColor.withValues(alpha: ghostOpacity),
      fontWeight: ghostWeight,
    );
  }
}
