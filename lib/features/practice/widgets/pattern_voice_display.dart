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
  final double ghostOpacity;
  final PatternGroupingV1 grouping;
  final bool showRepeatIndicator;
  final bool scrollable;
  final bool showPatternRow;
  final bool showDynamics;
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
    this.ghostOpacity = 0.62,
    this.grouping = PatternGroupingV1.none,
    this.showRepeatIndicator = false,
    this.scrollable = true,
    this.showPatternRow = true,
    this.showDynamics = true,
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
    final double resolvedCellWidth = _resolvedCellWidth(resolvedPatternStyle);
    final double separatorWidth = (resolvedCellWidth * 0.38).clamp(10.0, 24.0);

    final Widget content = wrap
        ? LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : double.infinity;
              final List<_PatternVoiceChunk> chunks = _chunksForWidth(
                maxWidth: maxWidth,
                separators: separators,
                resolvedCellWidth: resolvedCellWidth,
                separatorWidth: separatorWidth,
              );
              return Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < chunks.length; i++) ...<Widget>[
                      _chunkWidget(
                        chunk: chunks[i],
                        separators: separators,
                        resolvedCellWidth: resolvedCellWidth,
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
                ),
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
                resolvedCellWidth: resolvedCellWidth,
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
    required double resolvedCellWidth,
    required double separatorWidth,
    required TextStyle patternStyle,
    required TextStyle voiceStyle,
  }) {
    final double patternCellHeight = (patternStyle.fontSize ?? 18) * 1.35;
    final double voiceCellHeight = (voiceStyle.fontSize ?? 12) * 1.25;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (showPatternRow)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: _rowCellsForRange(
              chunk: chunk,
              separators: separators,
              resolvedCellWidth: resolvedCellWidth,
              separatorWidth: separatorWidth,
              cellHeight: patternCellHeight,
              noteCellFor: (int index) => _patternText(
                tokens[index],
                showDynamics ? markings[index] : PatternNoteMarkingV1.normal,
                patternStyle,
                resolvedCellWidth,
              ),
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
              resolvedCellWidth: resolvedCellWidth,
              separatorWidth: separatorWidth,
              cellHeight: voiceCellHeight,
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
    required double resolvedCellWidth,
    required double separatorWidth,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return <_PatternVoiceChunk>[
        _PatternVoiceChunk(start: 0, end: tokens.length),
      ];
    }

    final List<_PatternVoiceSegment> segments = _segmentsForSeparators(
      resolvedCellWidth: resolvedCellWidth,
      separators: separators,
      separatorWidth: separatorWidth,
    );
    final List<_PatternVoiceChunk> chunks = <_PatternVoiceChunk>[];
    int segmentIndex = 0;
    while (segmentIndex < segments.length) {
      double width = 0;
      int endSegmentIndex = segmentIndex;
      while (endSegmentIndex < segments.length) {
        final double nextWidth = segments[endSegmentIndex].width;
        if (endSegmentIndex > segmentIndex && width + nextWidth > maxWidth) {
          break;
        }
        width += nextWidth;
        endSegmentIndex++;
      }
      if (endSegmentIndex == segmentIndex) {
        endSegmentIndex++;
      }
      chunks.add(
        _PatternVoiceChunk(
          start: segments[segmentIndex].start,
          end: segments[endSegmentIndex - 1].end,
        ),
      );
      segmentIndex = endSegmentIndex;
    }
    return chunks;
  }

  List<_PatternVoiceSegment> _segmentsForSeparators({
    required double resolvedCellWidth,
    required List<String> separators,
    required double separatorWidth,
  }) {
    final List<_PatternVoiceSegment> segments = <_PatternVoiceSegment>[];
    int start = 0;
    double width = 0;
    for (int index = 0; index < tokens.length; index += 1) {
      width +=
          resolvedCellWidth + (separators[index].isNotEmpty ? separatorWidth : 0);
      final bool closesSegment =
          separators[index].isNotEmpty || index == tokens.length - 1;
      if (closesSegment) {
        segments.add(
          _PatternVoiceSegment(start: start, end: index + 1, width: width),
        );
        start = index + 1;
        width = 0;
      }
    }
    if (segments.isEmpty && tokens.isNotEmpty) {
      segments.add(
        _PatternVoiceSegment(
          start: 0,
          end: tokens.length,
          width: tokens.length * resolvedCellWidth,
        ),
      );
    }
    return segments;
  }

  List<Widget> _rowCellsForRange({
    required _PatternVoiceChunk chunk,
    required List<String> separators,
    required double resolvedCellWidth,
    required double separatorWidth,
    required double cellHeight,
    required Widget Function(int index) noteCellFor,
    required TextStyle separatorStyle,
    bool showSeparatorText = true,
  }) {
    return <Widget>[
      for (int index = chunk.start; index < chunk.end; index++) ...<Widget>[
        _PatternVoiceCell(
          width: resolvedCellWidth,
          height: cellHeight,
          child: noteCellFor(index),
        ),
        if (separators[index].isNotEmpty)
          _PatternVoiceCell(
            width: separatorWidth,
            height: cellHeight,
            child: Transform.translate(
              offset: Offset(0, showSeparatorText ? -(cellHeight * 0.18) : 0),
              child: Text(
                showSeparatorText ? separators[index] : '',
                textAlign: TextAlign.center,
                style: separatorStyle,
              ),
            ),
          ),
      ],
    ];
  }

  Widget _patternText(
    String token,
    PatternNoteMarkingV1 marking,
    TextStyle baseStyle,
    double resolvedCellWidth,
  ) {
    final double fontSize = baseStyle.fontSize ?? 18;
    final double accentShift = marking == PatternNoteMarkingV1.accent
        ? fontSize * 0.10
        : 0;
    final double ghostInset = (resolvedCellWidth - (fontSize * 0.92))
        .clamp(fontSize * 0.06, fontSize * 0.16);
    final double ghostOffsetY = -(fontSize * 0.04);
    return SizedBox(
      width: resolvedCellWidth,
      height: fontSize * 1.35,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: <Widget>[
          Transform.translate(
            offset: Offset(accentShift, 0),
            child: Text(
              token,
              textAlign: TextAlign.center,
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: baseStyle,
            ),
          ),
          if (marking == PatternNoteMarkingV1.accent)
            Positioned(
              left: -fontSize * 0.35,
              top: 0,
              bottom: 0,
              width: fontSize * 0.7,
              child: Center(
                child: Text(
                  '^',
                  textAlign: TextAlign.center,
                  softWrap: false,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: baseStyle.copyWith(height: 1.0),
                ),
              ),
            ),
          if (marking == PatternNoteMarkingV1.ghost) ...<Widget>[
            Positioned(
              left: ghostInset,
              top: 0,
              bottom: 0,
              width: fontSize * 0.34,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, ghostOffsetY),
                  child: Text(
                    '(',
                    textAlign: TextAlign.center,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: _ghostParenStyle(baseStyle),
                  ),
                ),
              ),
            ),
            Positioned(
              right: ghostInset,
              top: 0,
              bottom: 0,
              width: fontSize * 0.34,
              child: Center(
                child: Transform.translate(
                  offset: Offset(0, ghostOffsetY),
                  child: Text(
                    ')',
                    textAlign: TextAlign.center,
                    softWrap: false,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    style: _ghostParenStyle(baseStyle),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  TextStyle _ghostParenStyle(TextStyle baseStyle) {
    final Color baseColor = baseStyle.color ?? const Color(0xFF101010);
    return baseStyle.copyWith(
      color: baseColor.withValues(alpha: ghostOpacity),
      height: 1.0,
    );
  }

  double _resolvedCellWidth(TextStyle style) {
    final double fontSize = style.fontSize ?? 18;
    final double minWidth = fontSize * 1.04;
    final double tightenedWidth = cellWidth * 0.84;
    return tightenedWidth < minWidth ? minWidth : tightenedWidth;
  }
}

class _PatternVoiceCell extends StatelessWidget {
  final double width;
  final double height;
  final Widget child;

  const _PatternVoiceCell({
    required this.width,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Center(child: child),
    );
  }
}

class _PatternVoiceChunk {
  final int start;
  final int end;

  const _PatternVoiceChunk({required this.start, required this.end});
}

class _PatternVoiceSegment {
  final int start;
  final int end;
  final double width;

  const _PatternVoiceSegment({
    required this.start,
    required this.end,
    required this.width,
  });
}
