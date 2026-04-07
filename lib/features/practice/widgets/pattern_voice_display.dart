import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../app/app_formatters.dart';

class PatternVoiceDisplay extends StatelessWidget {
  final List<String> tokens;
  final List<PatternNoteMarkingV1> markings;
  final List<DrumVoiceV1> voices;
  final TextStyle? patternStyle;
  final TextStyle? voiceStyle;
  final double cellWidth;
  final double ghostScale;
  final double ghostOpacity;

  const PatternVoiceDisplay({
    super.key,
    required this.tokens,
    required this.markings,
    required this.voices,
    this.patternStyle,
    this.voiceStyle,
    this.cellWidth = 46,
    this.ghostScale = 0.84,
    this.ghostOpacity = 0.72,
  }) : assert(tokens.length == markings.length),
       assert(tokens.length == voices.length);

  @override
  Widget build(BuildContext context) {
    final TextStyle resolvedPatternStyle =
        patternStyle ?? DefaultTextStyle.of(context).style;
    final TextStyle resolvedVoiceStyle =
        voiceStyle ??
        Theme.of(context).textTheme.labelLarge ??
        DefaultTextStyle.of(context).style;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: List<Widget>.generate(tokens.length, (int index) {
              return _PatternVoiceCell(
                width: cellWidth,
                child: _patternText(
                  tokens[index],
                  markings[index],
                  resolvedPatternStyle,
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            children: List<Widget>.generate(tokens.length, (int index) {
              return _PatternVoiceCell(
                width: cellWidth,
                child: Text(
                  voices[index].shortLabel,
                  textAlign: TextAlign.center,
                  style: resolvedVoiceStyle.copyWith(
                    color: const Color(0xFF5B5345),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _patternText(
    String token,
    PatternNoteMarkingV1 marking,
    TextStyle baseStyle,
  ) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: baseStyle,
        children: switch (marking) {
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
        },
      ),
    );
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

class _PatternVoiceCell extends StatelessWidget {
  final double width;
  final Widget child;

  const _PatternVoiceCell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Center(child: child),
    );
  }
}
