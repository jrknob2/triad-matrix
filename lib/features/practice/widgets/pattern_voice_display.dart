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
  final PatternGroupingV1 grouping;
  final bool showRepeatIndicator;
  final bool scrollable;

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
    this.grouping = PatternGroupingV1.none,
    this.showRepeatIndicator = false,
    this.scrollable = true,
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
    final List<String> separators = List<String>.generate(
      tokens.length,
      (int index) => grouping.separatorAfter(index, tokens.length),
      growable: false,
    );
    final double separatorWidth = (cellWidth * 0.45).clamp(14.0, 28.0);

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: _rowCells(
                tokens,
                separators,
                separatorWidth,
                (int index) => _patternText(
                  tokens[index],
                  markings[index],
                  resolvedPatternStyle,
                ),
                resolvedPatternStyle,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: _rowCells(
                tokens,
                separators,
                separatorWidth,
                (int index) => Text(
                  voices[index].shortLabel,
                  textAlign: TextAlign.center,
                  style: resolvedVoiceStyle.copyWith(
                    color: const Color(0xFF5B5345),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                resolvedVoiceStyle,
                showSeparatorText: false,
              ),
            ),
          ],
        ),
        if (showRepeatIndicator)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(
              Icons.repeat_rounded,
              size: (resolvedPatternStyle.fontSize ?? 20) * 1.05,
              color: resolvedPatternStyle.color,
            ),
          ),
      ],
    );

    if (!scrollable) return content;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: content,
    );
  }

  List<Widget> _rowCells(
    List<String> tokens,
    List<String> separators,
    double separatorWidth,
    Widget Function(int index) noteCellFor,
    TextStyle separatorStyle, {
    bool showSeparatorText = true,
  }) {
    return <Widget>[
      for (int index = 0; index < tokens.length; index++) ...<Widget>[
        _PatternVoiceCell(width: cellWidth, child: noteCellFor(index)),
        if (separators[index].isNotEmpty)
          _PatternVoiceCell(
            width: separatorWidth,
            child: Text(
              showSeparatorText ? separators[index] : '',
              textAlign: TextAlign.center,
              style: separatorStyle,
            ),
          ),
      ],
    ];
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
