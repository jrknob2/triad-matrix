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
  final bool showPatternRow;
  final bool showVoiceRow;
  final bool wrap;

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
    this.showPatternRow = true,
    this.showVoiceRow = true,
    this.wrap = false,
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

    final Widget content = wrap
        ? LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : double.infinity;
              final List<_PatternVoiceChunk> chunks = _chunksForWidth(
                maxWidth: maxWidth,
                separators: separators,
                separatorWidth: separatorWidth,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (int i = 0; i < chunks.length; i++) ...<Widget>[
                    _chunkWidget(
                      chunk: chunks[i],
                      separators: separators,
                      separatorWidth: separatorWidth,
                      patternStyle: resolvedPatternStyle,
                      voiceStyle: resolvedVoiceStyle,
                    ),
                    if (i < chunks.length - 1) const SizedBox(height: 10),
                  ],
                  if (showRepeatIndicator)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.repeat_rounded,
                          size: (resolvedPatternStyle.fontSize ?? 20) * 1.05,
                          color: resolvedPatternStyle.color,
                        ),
                      ),
                    ),
                ],
              );
            },
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _chunkWidget(
                chunk: _PatternVoiceChunk(start: 0, end: tokens.length),
                separators: separators,
                separatorWidth: separatorWidth,
                patternStyle: resolvedPatternStyle,
                voiceStyle: resolvedVoiceStyle,
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

  Widget _chunkWidget({
    required _PatternVoiceChunk chunk,
    required List<String> separators,
    required double separatorWidth,
    required TextStyle patternStyle,
    required TextStyle voiceStyle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showPatternRow)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _rowCellsForRange(
              chunk: chunk,
              separators: separators,
              separatorWidth: separatorWidth,
              noteCellFor: (int index) =>
                  _patternText(tokens[index], markings[index], patternStyle),
              separatorStyle: patternStyle,
            ),
          ),
        if (showVoiceRow) ...<Widget>[
          if (showPatternRow) const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _rowCellsForRange(
              chunk: chunk,
              separators: separators,
              separatorWidth: separatorWidth,
              noteCellFor: (int index) => Text(
                voices[index].shortLabel,
                textAlign: TextAlign.center,
                style: voiceStyle.copyWith(
                  color: const Color(0xFF5B5345),
                  fontWeight: FontWeight.w800,
                ),
              ),
              separatorStyle: voiceStyle,
              showSeparatorText: false,
            ),
          ),
        ],
      ],
    );
  }

  List<_PatternVoiceChunk> _chunksForWidth({
    required double maxWidth,
    required List<String> separators,
    required double separatorWidth,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return <_PatternVoiceChunk>[
        _PatternVoiceChunk(start: 0, end: tokens.length),
      ];
    }

    final List<_PatternVoiceChunk> chunks = <_PatternVoiceChunk>[];
    int start = 0;
    while (start < tokens.length) {
      double width = 0;
      int end = start;
      while (end < tokens.length) {
        final double nextWidth =
            cellWidth + (separators[end].isNotEmpty ? separatorWidth : 0);
        if (end > start && width + nextWidth > maxWidth) {
          break;
        }
        width += nextWidth;
        end++;
      }
      if (end == start) end++;
      chunks.add(_PatternVoiceChunk(start: start, end: end));
      start = end;
    }
    return chunks;
  }

  List<Widget> _rowCellsForRange({
    required _PatternVoiceChunk chunk,
    required List<String> separators,
    required double separatorWidth,
    required Widget Function(int index) noteCellFor,
    required TextStyle separatorStyle,
    bool showSeparatorText = true,
  }) {
    return <Widget>[
      for (int index = chunk.start; index < chunk.end; index++) ...<Widget>[
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

class _PatternVoiceChunk {
  final int start;
  final int end;

  const _PatternVoiceChunk({required this.start, required this.end});
}
