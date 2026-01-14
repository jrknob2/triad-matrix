// lib/features/practice/widgets/pattern_card.dart
//
// Triad Trainer — Pattern Card (v1)
//
// Extracted from the original PracticeScreen so we stop growing a mega-file.
//
// Responsibilities (v1):
// - Display the “why this pattern is valuable” line (insight/benefit).
// - Optionally show a calm kit diagram above the pattern.
// - Render the pattern in a mono, fixed-grid style.
// - Show the v1 footer copy with the correct separator: `○` (NOT the letter O).
//
// Non-responsibilities:
// - No controller/state logic.
// - No audio/click.
// - No generator tuning UI.
//
// Imports assume these exist (you already referenced them):
// - lib/core/pattern/pattern_engine.dart (Pattern, TriadCell, Limb)
// - lib/core/practice/practice_models.dart (PatternFocus)
// - lib/core/instrument/instrument_context_v1.dart (InstrumentContextV1, KitPresetV1, DrumSurfaceV1)
// - lib/features/practice/widgets/kit_diagram.dart (KitDiagram + surface specs)

import 'package:flutter/material.dart';
import 'package:traid_trainer/core/instrument/instrument_context_v1.dart';
import 'package:traid_trainer/core/practice/practice_models.dart';

import '../../../core/pattern/pattern_engine.dart';
import 'kit_diagram.dart';

class PatternCard extends StatelessWidget {
  /// The generated pattern (phrase cells + accents + repeat metadata).
  final Pattern? pattern;

  /// Optional “why this matters” copy for v1.
  final PatternFocus? focus;

  /// Instrument context controls whether we show kit visuals/labels.
  final InstrumentContextV1 instrument;

  /// Kit preset is only meaningful for instrument == kit, but kept here
  /// so the widget can be reused without branching outside.
  final KitPresetV1 kit;

  /// Labels to render on the kit diagram (S, 1, 2, F, H, R, K).
  final Map<DrumSurfaceV1, String> voiceLabels;

  /// Whether to show the diagram above the pattern.
  final bool showKitDiagram;

  /// Whether to render the “voice row” beneath the limbs.
  /// In v1, you may prefer diagram-only and keep the pattern clean.
  final bool showVoiceRow;

  const PatternCard({
    super.key,
    required this.pattern,
    required this.focus,
    required this.instrument,
    required this.kit,
    required this.voiceLabels,
    this.showKitDiagram = true,
    this.showVoiceRow = false,
  });

  static const String _arrow = ' \u2192 '; // →

  @override
  Widget build(BuildContext context) {
    final Pattern? p = pattern;

    if (p == null) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(18), child: Text('…')),
      );
    }

    final ThemeData theme = Theme.of(context);
    final Color onSurface = theme.colorScheme.onSurface;

    final TextStyle phraseStyle = TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: const <String>['SF Mono', 'Courier New', 'monospace'],
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.12,
      letterSpacing: 0,
      color: onSurface,
    );

    final TextStyle metaStyle = phraseStyle.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w500,
    );

    final String benefit = _resolveBenefitText(focus);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double maxWidth = c.maxWidth - 36;
        final _MonoMetrics m = _MonoMetrics.fromStyle(phraseStyle);
        final int maxCols = (maxWidth / m.cellW).floor().clamp(18, 140);

        final List<_RenderedPatternLine> lines = _renderLines(
          phrase: p.phrase,
          repeats: p.repeats,
          infinite: p.infiniteRepeat,
          accents: p.accentNoteIndices,
          maxCols: maxCols,
          instrument: instrument,
          kit: kit,
          voiceLabels: voiceLabels,
          showVoiceRow: showVoiceRow,
        );

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (showKitDiagram) ...<Widget>[
                  KitDiagram(
                    title: _kitCaption(instrument, kit),
                    surfaces: _buildKitSurfaces(
                      instrument: instrument,
                      kit: kit,
                      voiceLabels: voiceLabels,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _BenefitPill(text: benefit),
                const SizedBox(height: 14),
                for (int i = 0; i < lines.length; i++) ...<Widget>[
                  Center(
                    child: _MonoGridBlock(
                      phrase: lines[i].phraseChars,
                      voices: lines[i].voiceChars,
                      carets: lines[i].caretChars,
                      phraseStyle: phraseStyle,
                      metaStyle: metaStyle,
                    ),
                  ),
                  if (i != lines.length - 1) const SizedBox(height: 14),
                ],
                const SizedBox(height: 12),
                Text(
                  // IMPORTANT: `○` is a separator glyph, not the letter "O".
                  'Accents are marked with `^` ○ Unaccented notes are ghost notes',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _resolveBenefitText(PatternFocus? f) {
    // No fallbacks-by-guessing. If focus is absent, use the known default copy.
    if (f == null) return PatternFocus.defaultFocus.detail;

    final String detail = f.detail.trim();
    if (detail.isNotEmpty) return detail;

    final String title = f.title.trim();
    if (title.isNotEmpty) return title;

    return PatternFocus.defaultFocus.detail;
  }

  String _kitCaption(InstrumentContextV1 instrument, KitPresetV1 kit) {
    return switch (instrument) {
      InstrumentContextV1.pad => 'Pad (hands only)',
      InstrumentContextV1.padKick => 'Pad + kick',
      InstrumentContextV1.kit =>
        'Kit (${kit.pieces}-piece, ${kit.leftHanded ? 'left' : 'right'}-handed)',
    };
  }

  List<KitSurfaceSpec> _buildKitSurfaces({
    required InstrumentContextV1 instrument,
    required KitPresetV1 kit,
    required Map<DrumSurfaceV1, String> voiceLabels,
  }) {
    KitSurfaceKind? kindFor(DrumSurfaceV1 s) {
      return switch (s) {
        DrumSurfaceV1.snare => KitSurfaceKind.snare,
        DrumSurfaceV1.tom1 => KitSurfaceKind.tom1,
        DrumSurfaceV1.tom2 => KitSurfaceKind.tom2,
        DrumSurfaceV1.floorTom => KitSurfaceKind.floorTom,
        DrumSurfaceV1.hiHat => KitSurfaceKind.hiHat,
        DrumSurfaceV1.ride => KitSurfaceKind.ride,
        DrumSurfaceV1.kick => KitSurfaceKind.kick,
      };
    }

    String requireLabel(DrumSurfaceV1 s) {
      final String? raw = voiceLabels[s];
      final String label = (raw ?? '').trim();
      assert(
        label.isNotEmpty,
        'voiceLabels must include a non-empty label for $s when rendering KitDiagram.',
      );
      return label;
    }

    // For pad contexts, the surface set is deterministic.
    if (instrument == InstrumentContextV1.pad) {
      return <KitSurfaceSpec>[
        KitSurfaceSpec(
          id: 'S',
          label: requireLabel(DrumSurfaceV1.snare),
          kind: KitSurfaceKind.snare,
        ),
      ];
    }

    if (instrument == InstrumentContextV1.padKick) {
      return <KitSurfaceSpec>[
        KitSurfaceSpec(
          id: 'S',
          label: requireLabel(DrumSurfaceV1.snare),
          kind: KitSurfaceKind.snare,
        ),
        KitSurfaceSpec(
          id: 'K',
          label: requireLabel(DrumSurfaceV1.kick),
          kind: KitSurfaceKind.kick,
        ),
      ];
    }

    // Kit mode: surfaces come from the preset. Order matters for a stable UI.
    final List<DrumSurfaceV1> order = <DrumSurfaceV1>[
      DrumSurfaceV1.hiHat,
      DrumSurfaceV1.ride,
      DrumSurfaceV1.tom1,
      DrumSurfaceV1.tom2,
      DrumSurfaceV1.snare,
      DrumSurfaceV1.floorTom,
      DrumSurfaceV1.kick,
    ];

    final Set<DrumSurfaceV1> enabled = kit.surfaces().toSet();
    final List<KitSurfaceSpec> out = <KitSurfaceSpec>[];

    for (final DrumSurfaceV1 s in order) {
      if (!enabled.contains(s)) continue;
      final KitSurfaceKind k = kindFor(s)!;
      final String label = requireLabel(s);
      out.add(
        KitSurfaceSpec(
          id: s.name,
          label: label,
          kind: k,
        ),
      );
    }

    return out;
  }

  List<_RenderedPatternLine> _renderLines({
    required List<TriadCell> phrase,
    required int repeats,
    required bool infinite,
    required List<int> accents,
    required int maxCols,
    required InstrumentContextV1 instrument,
    required KitPresetV1 kit,
    required Map<DrumSurfaceV1, String> voiceLabels,
    required bool showVoiceRow,
  }) {
    final List<List<TriadCell>> chunks = _chunkCellsByCols(
      phrase: phrase,
      maxCols: maxCols,
    );

    final int totalNotes = phrase.length * 3;
    final List<_RenderedPatternLine> out = <_RenderedPatternLine>[];

    int globalCellStart = 0;

    for (int i = 0; i < chunks.length; i++) {
      final List<TriadCell> lineCells = chunks[i];
      final bool isLast = i == chunks.length - 1;

      String lineText = lineCells.map((c) => c.id).join(_arrow);
      if (isLast) {
        lineText = infinite ? '$lineText \u221E' : '$lineText \u00D7 $repeats';
      }

      final List<String> phraseChars = _toChars(lineText);
      final List<String> caretChars = List<String>.filled(
        phraseChars.length,
        ' ',
      );
      final List<String> voiceChars = List<String>.filled(
        phraseChars.length,
        ' ',
      );

      final int lineCellCount = lineCells.length;
      final int globalNoteStart = globalCellStart * 3;
      final int globalNoteEndExclusive = globalNoteStart + (lineCellCount * 3);

      final List<int> localAccentNotes = <int>[];
      for (final int a in accents) {
        final int inPhrase = totalNotes == 0 ? 0 : (a % totalNotes);
        if (inPhrase >= globalNoteStart && inPhrase < globalNoteEndExclusive) {
          localAccentNotes.add(inPhrase - globalNoteStart);
        }
      }

      final List<int> glyphCols = _glyphCols(phraseChars);

      // Place carets. (Docs allow accents on any limb, including kick.)
      for (final int n in localAccentNotes) {
        if (n < 0 || n >= glyphCols.length) continue;
        final int col = glyphCols[n];
        if (col >= 0 && col < caretChars.length) caretChars[col] = '^';
      }

      if (showVoiceRow) {
        // v1: very minimal voice row—label the FIRST and LAST note only,
        // to avoid clutter, and only when we’re in kit context.
        if (instrument == InstrumentContextV1.kit &&
            glyphCols.isNotEmpty &&
            lineCells.isNotEmpty) {
          final int notesInLine = lineCells.length * 3;

          String labelFor(int noteIndexInLine) {
            final Limb limb =
                lineCells[noteIndexInLine ~/ 3].limbs[noteIndexInLine % 3];
            final DrumSurfaceV1 surf = _surfaceForLimb(limb);
            final String? raw = voiceLabels[surf];
            final String lab = (raw ?? '').trim();
            if (lab.isEmpty) return '';
            return lab.length <= 2 ? lab : lab[0];
          }

          void placeAt(int noteIndexInLine, String label) {
            if (label.isEmpty) return;
            if (noteIndexInLine < 0 || noteIndexInLine >= glyphCols.length) {
              return;
            }
            final int col = glyphCols[noteIndexInLine];
            if (col >= 0 && col < voiceChars.length) voiceChars[col] = label;
          }

          int first = 0;
          while (first < notesInLine && labelFor(first).isEmpty) {
            first++;
          }

          int last = notesInLine - 1;
          while (last >= 0 && labelFor(last).isEmpty) {
            last--;
          }

          if (first < notesInLine) placeAt(first, labelFor(first));
          if (last >= 0) placeAt(last, labelFor(last));
        }
      }

      out.add(
        _RenderedPatternLine(
          phraseChars: phraseChars,
          voiceChars: voiceChars,
          caretChars: caretChars,
        ),
      );

      globalCellStart += lineCells.length;
    }

    return out;
  }

  DrumSurfaceV1 _surfaceForLimb(Limb limb) {
    // v1: keep it dead simple—limbs map to “primary” surfaces.
    // Actual orchestration/movement rules belong in generator/assignment logic.
    return switch (limb) {
      Limb.r => DrumSurfaceV1.snare,
      Limb.l => DrumSurfaceV1.snare,
      Limb.k => DrumSurfaceV1.kick,
    };
  }

  List<List<TriadCell>> _chunkCellsByCols({
    required List<TriadCell> phrase,
    required int maxCols,
  }) {
    const String arrow = _arrow;

    int estimateCols(List<TriadCell> cells) {
      if (cells.isEmpty) return 0;
      final int ids = cells.fold<int>(0, (n, c) => n + c.id.length);
      final int arrows = (cells.length - 1) * arrow.length;
      return ids + arrows + 4; // room for trailing "× N" or "∞"
    }

    final List<List<TriadCell>> lines = <List<TriadCell>>[];
    List<TriadCell> cur = <TriadCell>[];

    for (final TriadCell cell in phrase) {
      if (cur.isEmpty) {
        cur.add(cell);
        continue;
      }
      final List<TriadCell> next = <TriadCell>[...cur, cell];
      if (estimateCols(next) <= maxCols) {
        cur.add(cell);
      } else {
        lines.add(cur);
        cur = <TriadCell>[cell];
      }
    }

    if (cur.isNotEmpty) lines.add(cur);
    if (lines.isEmpty) lines.add(<TriadCell>[]);

    return lines;
  }

  List<String> _toChars(String s) => <String>[
        for (int i = 0; i < s.length; i++) s[i],
      ];

  List<int> _glyphCols(List<String> chars) {
    final List<int> cols = <int>[];
    for (int i = 0; i < chars.length; i++) {
      final String ch = chars[i];
      if (ch == 'R' || ch == 'L' || ch == 'K') cols.add(i);
    }
    return cols;
  }
}

/* -------------------------------------------------------------------------- */
/* Benefit pill                                                                */
/* -------------------------------------------------------------------------- */

class _BenefitPill extends StatelessWidget {
  final String text;

  const _BenefitPill({required this.text});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium,
        textAlign: TextAlign.left,
      ),
    );
  }
}

/* -------------------------------------------------------------------------- */
/* Fixed-grid painter widgets (self-contained)                                 */
/* -------------------------------------------------------------------------- */

class _RenderedPatternLine {
  final List<String> phraseChars;
  final List<String> voiceChars;
  final List<String> caretChars;

  const _RenderedPatternLine({
    required this.phraseChars,
    required this.voiceChars,
    required this.caretChars,
  });
}

class _MonoMetrics {
  final double cellW;
  final double cellH;

  const _MonoMetrics(this.cellW, this.cellH);

  static _MonoMetrics fromStyle(TextStyle style) {
    final TextPainter tp = TextPainter(
      text: TextSpan(text: 'M', style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final double w = tp.width <= 0 ? 14 : tp.width;
    final double h = tp.height <= 0 ? (style.fontSize ?? 26) * 1.1 : tp.height;
    return _MonoMetrics(w, h);
  }
}

class _MonoGridBlock extends StatelessWidget {
  final List<String> phrase;
  final List<String> voices;
  final List<String> carets;

  final TextStyle phraseStyle;
  final TextStyle metaStyle;

  const _MonoGridBlock({
    required this.phrase,
    required this.voices,
    required this.carets,
    required this.phraseStyle,
    required this.metaStyle,
  });

  @override
  Widget build(BuildContext context) {
    final int cols = phrase.length;
    final _MonoMetrics m = _MonoMetrics.fromStyle(phraseStyle);

    // 3 rows: phrase, voices, carets
    final double w = cols * m.cellW;
    final double h = 3 * m.cellH;

    return CustomPaint(
      size: Size(w, h),
      painter: _MonoGridPainter(
        phrase: phrase,
        voices: voices,
        carets: carets,
        phraseStyle: phraseStyle,
        metaStyle: metaStyle,
        metrics: m,
      ),
    );
  }
}

class _MonoGridPainter extends CustomPainter {
  final List<String> phrase;
  final List<String> voices;
  final List<String> carets;

  final TextStyle phraseStyle;
  final TextStyle metaStyle;
  final _MonoMetrics metrics;

  _MonoGridPainter({
    required this.phrase,
    required this.voices,
    required this.carets,
    required this.phraseStyle,
    required this.metaStyle,
    required this.metrics,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintRow(canvas, phrase, 0, phraseStyle);
    _paintRow(canvas, voices, 1, metaStyle);
    _paintRow(
      canvas,
      carets,
      2,
      metaStyle.copyWith(fontWeight: FontWeight.w800),
    );
  }

  void _paintRow(
    Canvas canvas,
    List<String> row,
    int rowIndex,
    TextStyle baseStyle,
  ) {
    final double y = rowIndex * metrics.cellH;

    for (int col = 0; col < row.length; col++) {
      final String ch = row[col];
      if (ch == ' ') continue;

      final TextPainter tp = TextPainter(
        text: TextSpan(text: ch, style: baseStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final double x = col * metrics.cellW;
      canvas.save();
      canvas.translate(x, y + (metrics.cellH - tp.height) / 2);
      tp.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _MonoGridPainter oldDelegate) {
    return oldDelegate.phrase != phrase ||
        oldDelegate.voices != voices ||
        oldDelegate.carets != carets ||
        oldDelegate.phraseStyle != phraseStyle ||
        oldDelegate.metaStyle != metaStyle;
  }
}
