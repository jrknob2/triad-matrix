import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/practice/practice_domain_v1.dart';
import '../../app/app_formatters.dart';

class PatternVoiceDisplay extends StatelessWidget {
  final List<PatternTokenV1> tokens;
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
  final bool fitToBounds;
  final int? activeIndex;
  final Color? activePatternColor;
  final Color? activeVoiceColor;

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
    this.fitToBounds = true,
    this.activeIndex,
    this.activePatternColor,
    this.activeVoiceColor,
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
    final List<_NotationTokenGeometry> tokenGeometry =
        List<_NotationTokenGeometry>.generate(tokens.length, (int index) {
          final PatternNoteMarkingV1 effectiveMarking = showDynamics
              ? markings[index]
              : PatternNoteMarkingV1.normal;
          return _tokenGeometryFor(
            marking: effectiveMarking,
            patternStyle: resolvedPatternStyle,
            cellWidth: cellWidth,
          );
        });
    final double separatorWidth = separatorWidthForStyle(
      resolvedPatternStyle,
      cellWidth,
    );

    final Widget content = wrap
        ? LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double maxWidth = constraints.maxWidth.isFinite
                  ? constraints.maxWidth
                  : double.infinity;
              final List<_PatternVoiceChunk> chunks = _chunksForWidth(
                maxWidth: maxWidth,
                separators: separators,
                tokenGeometry: tokenGeometry,
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
                        tokenGeometry: tokenGeometry,
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
                tokenGeometry: tokenGeometry,
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
    required List<_NotationTokenGeometry> tokenGeometry,
    required double separatorWidth,
    required TextStyle patternStyle,
    required TextStyle voiceStyle,
  }) {
    final double patternCellHeight = (patternStyle.fontSize ?? 18) * 1.35;
    final double voiceCellHeight = (voiceStyle.fontSize ?? 12) * 1.25;
    final Widget patternRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: _rowCellsForRange(
        chunk: chunk,
        separators: separators,
        tokenGeometry: tokenGeometry,
        separatorWidth: separatorWidth,
        cellHeight: patternCellHeight,
        noteCellFor: (int index) => _patternText(
          tokens[index],
          tokenGeometry[index],
          patternStyle,
          isActive: activeIndex == index,
        ),
        separatorStyle: patternStyle,
      ),
    );
    final Widget voiceRow = Row(
      mainAxisSize: MainAxisSize.min,
      children: _rowCellsForRange(
        chunk: chunk,
        separators: separators,
        tokenGeometry: tokenGeometry,
        separatorWidth: separatorWidth,
        cellHeight: voiceCellHeight,
        noteCellFor: (int index) => _voiceText(
          label: tokens[index].isRest ? '' : voices[index].shortLabel,
          geometry: tokenGeometry[index],
          baseStyle: voiceStyle,
          isActive: activeIndex == index,
        ),
        separatorStyle: voiceStyle,
        showSeparatorText: false,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (showPatternRow) _fitRowToBounds(patternRow),
        if (showVoiceRow) ...<Widget>[
          if (showPatternRow) const SizedBox(height: 6),
          _fitRowToBounds(voiceRow),
        ],
      ],
    );
  }

  Widget _fitRowToBounds(Widget row) {
    if (scrollable || wrap || !fitToBounds) return row;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.maxWidth.isFinite) return row;
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: row,
          ),
        );
      },
    );
  }

  static double resolvedCellWidthForStyle(TextStyle style, double cellWidth) {
    final double fontSize = style.fontSize ?? 18;
    final double minWidth = fontSize * 1.04;
    final double tightenedWidth = cellWidth * 0.84;
    return tightenedWidth < minWidth ? minWidth : tightenedWidth;
  }

  static double characterSlotWidthForStyle(TextStyle style, double cellWidth) {
    final double resolvedCellWidth = resolvedCellWidthForStyle(
      style,
      cellWidth,
    );
    final double fontSize = style.fontSize ?? 18;
    return math.max(fontSize * 0.72, resolvedCellWidth * 0.56);
  }

  static double separatorWidthForStyle(TextStyle style, double cellWidth) {
    return characterSlotWidthForStyle(style, cellWidth);
  }

  static double tokenWidthForMarking(
    PatternNoteMarkingV1 marking,
    TextStyle style,
    double cellWidth,
  ) {
    final _NotationMetrics metrics = _metricsForStyle(style, cellWidth);
    return _tokenGeometryForMarking(marking, metrics).width;
  }

  _NotationTokenGeometry _tokenGeometryFor({
    required PatternNoteMarkingV1 marking,
    required TextStyle patternStyle,
    required double cellWidth,
  }) {
    final _NotationMetrics metrics = _metricsForStyle(patternStyle, cellWidth);
    return _tokenGeometryForMarking(marking, metrics);
  }

  static _NotationMetrics _metricsForStyle(TextStyle style, double cellWidth) {
    final double noteWidth = characterSlotWidthForStyle(style, cellWidth);
    return _NotationMetrics(
      noteWidth: noteWidth,
      accentWidth: noteWidth * 0.78,
      parenWidth: noteWidth * 0.44,
      accentGap: noteWidth * 0.28,
      parenGap: noteWidth * 0.10,
    );
  }

  static _NotationTokenGeometry _tokenGeometryForMarking(
    PatternNoteMarkingV1 marking,
    _NotationMetrics metrics,
  ) {
    return switch (marking) {
      PatternNoteMarkingV1.normal => _NotationTokenGeometry(
        marking: marking,
        boxes: <_NotationBox>[
          _NotationBox(
            kind: _NotationBoxKind.note,
            left: 0,
            width: metrics.noteWidth,
          ),
        ],
      ),
      PatternNoteMarkingV1.accent => _NotationTokenGeometry(
        marking: marking,
        boxes: <_NotationBox>[
          _NotationBox(
            kind: _NotationBoxKind.accent,
            left: 0,
            width: metrics.accentWidth,
          ),
          _NotationBox(
            kind: _NotationBoxKind.note,
            left: metrics.accentWidth + metrics.accentGap,
            width: metrics.noteWidth,
          ),
        ],
      ),
      PatternNoteMarkingV1.ghost => _NotationTokenGeometry(
        marking: marking,
        boxes: <_NotationBox>[
          _NotationBox(
            kind: _NotationBoxKind.leftParen,
            left: 0,
            width: metrics.parenWidth,
          ),
          _NotationBox(
            kind: _NotationBoxKind.note,
            left: metrics.parenWidth + metrics.parenGap,
            width: metrics.noteWidth,
          ),
          _NotationBox(
            kind: _NotationBoxKind.rightParen,
            left:
                metrics.parenWidth +
                metrics.parenGap +
                metrics.noteWidth +
                metrics.parenGap,
            width: metrics.parenWidth,
          ),
        ],
      ),
    };
  }

  List<_PatternVoiceChunk> _chunksForWidth({
    required double maxWidth,
    required List<String> separators,
    required List<_NotationTokenGeometry> tokenGeometry,
    required double separatorWidth,
  }) {
    if (!maxWidth.isFinite || maxWidth <= 0) {
      return <_PatternVoiceChunk>[
        _PatternVoiceChunk(start: 0, end: tokens.length),
      ];
    }

    final List<_PatternVoiceSegment> segments = _segmentsForSeparators(
      tokenGeometry: tokenGeometry,
      separators: separators,
      separatorWidth: separatorWidth,
    );
    final List<_PatternVoiceChunk> chunks = <_PatternVoiceChunk>[];
    int segmentIndex = 0;
    while (segmentIndex < segments.length) {
      final _PatternVoiceSegment firstSegment = segments[segmentIndex];
      if (firstSegment.width > maxWidth) {
        chunks.addAll(
          _tokenChunksForWidth(
            start: firstSegment.start,
            end: firstSegment.end,
            maxWidth: maxWidth,
            separators: separators,
            tokenGeometry: tokenGeometry,
            separatorWidth: separatorWidth,
          ),
        );
        segmentIndex += 1;
        continue;
      }

      double width = 0;
      int endSegmentIndex = segmentIndex;
      while (endSegmentIndex < segments.length) {
        final _PatternVoiceSegment nextSegment = segments[endSegmentIndex];
        if (nextSegment.width > maxWidth) {
          break;
        }
        final double nextWidth = nextSegment.width;
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

  List<_PatternVoiceChunk> _tokenChunksForWidth({
    required int start,
    required int end,
    required double maxWidth,
    required List<String> separators,
    required List<_NotationTokenGeometry> tokenGeometry,
    required double separatorWidth,
  }) {
    final List<_PatternVoiceChunk> chunks = <_PatternVoiceChunk>[];
    int chunkStart = start;
    double width = 0;

    for (int index = start; index < end; index += 1) {
      final double tokenWidth =
          tokenGeometry[index].width +
          (separators[index].isNotEmpty ? separatorWidth : 0);
      if (index > chunkStart && width + tokenWidth > maxWidth) {
        chunks.add(_PatternVoiceChunk(start: chunkStart, end: index));
        chunkStart = index;
        width = 0;
      }
      width += tokenWidth;
    }

    if (chunkStart < end) {
      chunks.add(_PatternVoiceChunk(start: chunkStart, end: end));
    }

    return chunks;
  }

  List<_PatternVoiceSegment> _segmentsForSeparators({
    required List<_NotationTokenGeometry> tokenGeometry,
    required List<String> separators,
    required double separatorWidth,
  }) {
    final List<_PatternVoiceSegment> segments = <_PatternVoiceSegment>[];
    int start = 0;
    double width = 0;
    for (int index = 0; index < tokens.length; index += 1) {
      width +=
          tokenGeometry[index].width +
          (separators[index].isNotEmpty ? separatorWidth : 0);
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
          width: tokenGeometry.fold<double>(
            0,
            (double sum, _NotationTokenGeometry geometry) =>
                sum + geometry.width,
          ),
        ),
      );
    }
    return segments;
  }

  List<Widget> _rowCellsForRange({
    required _PatternVoiceChunk chunk,
    required List<String> separators,
    required List<_NotationTokenGeometry> tokenGeometry,
    required double separatorWidth,
    required double cellHeight,
    required Widget Function(int index) noteCellFor,
    required TextStyle separatorStyle,
    bool showSeparatorText = true,
  }) {
    return <Widget>[
      for (int index = chunk.start; index < chunk.end; index++) ...<Widget>[
        _PatternVoiceCell(
          width: tokenGeometry[index].width,
          height: cellHeight,
          child: noteCellFor(index),
        ),
        if (separators[index].isNotEmpty)
          _PatternVoiceCell(
            width: separatorWidth,
            height: cellHeight,
            child: Align(
              alignment: Alignment.center,
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
    PatternTokenV1 token,
    _NotationTokenGeometry geometry,
    TextStyle baseStyle, {
    required bool isActive,
  }) {
    final double fontSize = baseStyle.fontSize ?? 18;
    final TextStyle activeBaseStyle = isActive
        ? baseStyle.copyWith(
            color: activePatternColor ?? const Color(0xFFF6B067),
          )
        : baseStyle;
    return SizedBox(
      width: geometry.width,
      height: fontSize * 1.35,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (final _NotationBox box in geometry.boxes)
            Positioned(
              left: box.left,
              top: 0,
              bottom: 0,
              width: box.width,
              child: Center(
                child: Text(
                  switch (box.kind) {
                    _NotationBoxKind.note => token.notationSymbol,
                    _NotationBoxKind.accent => '^',
                    _NotationBoxKind.leftParen => '(',
                    _NotationBoxKind.rightParen => ')',
                  },
                  textAlign: TextAlign.center,
                  softWrap: false,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: switch (box.kind) {
                    _NotationBoxKind.note => activeBaseStyle,
                    _NotationBoxKind.accent => activeBaseStyle.copyWith(
                      height: 1.0,
                    ),
                    _NotationBoxKind.leftParen || _NotationBoxKind.rightParen =>
                      _ghostParenStyle(activeBaseStyle),
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _voiceText({
    required String label,
    required _NotationTokenGeometry geometry,
    required TextStyle baseStyle,
    required bool isActive,
  }) {
    final double noteCenter = geometry.noteCenterX;
    final double horizontalAnchor = geometry.width == 0
        ? 0
        : ((noteCenter / geometry.width) * 2) - 1;
    return SizedBox(
      width: geometry.width,
      child: Align(
        alignment: Alignment(horizontalAnchor, 0),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: baseStyle.copyWith(
            color: isActive
                ? (activeVoiceColor ?? const Color(0xFFF6B067))
                : const Color(0xFF5B5345),
            fontWeight: FontWeight.w800,
          ),
        ),
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

class _NotationTokenGeometry {
  final PatternNoteMarkingV1 marking;
  final List<_NotationBox> boxes;

  const _NotationTokenGeometry({required this.marking, required this.boxes});

  double get width => boxes.isEmpty ? 0 : boxes.last.left + boxes.last.width;

  _NotationBox get noteBox =>
      boxes.firstWhere((_NotationBox box) => box.kind == _NotationBoxKind.note);

  double get noteCenterX => noteBox.left + (noteBox.width / 2);
}

class _NotationMetrics {
  final double noteWidth;
  final double accentWidth;
  final double parenWidth;
  final double accentGap;
  final double parenGap;

  const _NotationMetrics({
    required this.noteWidth,
    required this.accentWidth,
    required this.parenWidth,
    required this.accentGap,
    required this.parenGap,
  });
}

enum _NotationBoxKind { note, accent, leftParen, rightParen }

class _NotationBox {
  final _NotationBoxKind kind;
  final double left;
  final double width;

  const _NotationBox({
    required this.kind,
    required this.left,
    required this.width,
  });
}
