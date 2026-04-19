import 'dart:math' as math;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        if (showPatternRow)
          Row(
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
              tokenGeometry: tokenGeometry,
              separatorWidth: separatorWidth,
              cellHeight: voiceCellHeight,
              noteCellFor: (int index) => _voiceText(
                label: voices[index].shortLabel,
                geometry: tokenGeometry[index],
                baseStyle: voiceStyle,
              ),
              separatorStyle: voiceStyle,
              showSeparatorText: false,
            ),
          ),
        ],
      ],
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
    final double noteSlotWidth = characterSlotWidthForStyle(style, cellWidth);
    return _slotWidthsForMarking(
      marking,
      noteSlotWidth,
    ).fold<double>(0, (double sum, double width) => sum + width);
  }

  _NotationTokenGeometry _tokenGeometryFor({
    required PatternNoteMarkingV1 marking,
    required TextStyle patternStyle,
    required double cellWidth,
  }) {
    final double noteSlotWidth = characterSlotWidthForStyle(
      patternStyle,
      cellWidth,
    );
    final List<double> slotWidths = _slotWidthsForMarking(
      marking,
      noteSlotWidth,
    );
    return _NotationTokenGeometry(
      marking: marking,
      slotWidths: slotWidths,
      noteSlotIndex: marking == PatternNoteMarkingV1.normal ? 0 : 1,
    );
  }

  static List<double> _slotWidthsForMarking(
    PatternNoteMarkingV1 marking,
    double noteSlotWidth,
  ) {
    final double accentSlotWidth = noteSlotWidth * 0.64;
    final double ghostParenSlotWidth = noteSlotWidth * 0.72;
    return switch (marking) {
      PatternNoteMarkingV1.normal => <double>[noteSlotWidth],
      PatternNoteMarkingV1.accent => <double>[accentSlotWidth, noteSlotWidth],
      PatternNoteMarkingV1.ghost => <double>[
        ghostParenSlotWidth,
        noteSlotWidth,
        ghostParenSlotWidth,
      ],
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
    _NotationTokenGeometry geometry,
    TextStyle baseStyle,
  ) {
    final double fontSize = baseStyle.fontSize ?? 18;
    final List<_NotationGlyphSlot> glyphs = switch (geometry.marking) {
      PatternNoteMarkingV1.normal => <_NotationGlyphSlot>[
        _NotationGlyphSlot(slotIndex: 0, text: token, style: baseStyle),
      ],
      PatternNoteMarkingV1.accent => <_NotationGlyphSlot>[
        _NotationGlyphSlot(
          slotIndex: 0,
          text: '^',
          style: baseStyle.copyWith(height: 1.0),
        ),
        _NotationGlyphSlot(slotIndex: 1, text: token, style: baseStyle),
      ],
      PatternNoteMarkingV1.ghost => <_NotationGlyphSlot>[
        _NotationGlyphSlot(
          slotIndex: 0,
          text: '(',
          style: _ghostParenStyle(baseStyle),
        ),
        _NotationGlyphSlot(slotIndex: 1, text: token, style: baseStyle),
        _NotationGlyphSlot(
          slotIndex: 2,
          text: ')',
          style: _ghostParenStyle(baseStyle),
        ),
      ],
    };
    return SizedBox(
      width: geometry.width,
      height: fontSize * 1.35,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (final _NotationGlyphSlot glyph in glyphs)
            Positioned(
              left: geometry.slotLeft(glyph.slotIndex),
              top: 0,
              bottom: 0,
              width: geometry.slotWidthAt(glyph.slotIndex),
              child: Center(
                child: Text(
                  glyph.text,
                  textAlign: TextAlign.center,
                  softWrap: false,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: glyph.style,
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
            color: const Color(0xFF5B5345),
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
  final List<double> slotWidths;
  final int noteSlotIndex;

  const _NotationTokenGeometry({
    required this.marking,
    required this.slotWidths,
    required this.noteSlotIndex,
  });

  int get slotCount => slotWidths.length;

  double get width =>
      slotWidths.fold<double>(0, (double sum, double value) => sum + value);

  double slotLeft(int slotIndex) {
    double left = 0;
    for (int index = 0; index < slotIndex; index += 1) {
      left += slotWidths[index];
    }
    return left;
  }

  double slotWidthAt(int slotIndex) => slotWidths[slotIndex];

  double get noteCenterX =>
      slotLeft(noteSlotIndex) + (slotWidthAt(noteSlotIndex) / 2);
}

class _NotationGlyphSlot {
  final int slotIndex;
  final String text;
  final TextStyle style;

  const _NotationGlyphSlot({
    required this.slotIndex,
    required this.text,
    required this.style,
  });
}
