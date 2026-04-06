import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';

class PatternDisplayText extends StatelessWidget {
  final List<String> tokens;
  final List<PatternNoteMarkingV1> markings;
  final TextStyle? style;
  final TextAlign textAlign;
  final double ghostScale;

  const PatternDisplayText({
    super.key,
    required this.tokens,
    required this.markings,
    this.style,
    this.textAlign = TextAlign.start,
    this.ghostScale = 0.84,
  }) : assert(tokens.length == markings.length);

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle = style ?? DefaultTextStyle.of(context).style;

    return RichText(
      textAlign: textAlign,
      text: TextSpan(
        style: baseStyle,
        children: <InlineSpan>[
          for (int index = 0; index < tokens.length; index++) ...<InlineSpan>[
            ..._spansForToken(tokens[index], markings[index], baseStyle),
            if (index != tokens.length - 1)
              TextSpan(text: ' ', style: baseStyle),
          ],
        ],
      ),
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
    if (token != 'R' && token != 'L') return baseStyle;
    final double? fontSize = baseStyle.fontSize;
    return baseStyle.copyWith(
      fontSize: fontSize == null ? null : fontSize * ghostScale,
    );
  }
}
