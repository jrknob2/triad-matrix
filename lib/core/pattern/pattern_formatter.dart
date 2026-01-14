// lib/core/pattern_formatter.dart
//
// Triad Trainer — Pattern Formatting (v1)
//
// Converts a Pattern into fixed-width mono “rows” suitable for rendering.
// This is UI-agnostic: it outputs strings/char arrays, not widgets.
//
// Goals:
// - Keep UI simple: UI paints rows; this file decides what the rows are.
// - No “kick never accented” nonsense: kick can be accented.
// - No ghost/fade logic here. If you ever want ghost visuals later, UI can
//   choose to dim, but we always output full data.
//
// Rows (v1):
// - phrase:  "RLL → RRL → ... × N" (or "∞")
// - voices:  single-letter labels under each limb glyph column (optional)
// - carets:  '^' under accented limb glyph columns
//
// Notes:
// - We treat "→" as a 3-char arrow token " → " to preserve spacing.
// - Voices are only rendered for non-kick notes by default, but you can
//   override via the VoiceResolver.

import 'pattern_engine.dart';

/* -------------------------------------------------------------------------- */
/* Types                                                                      */
/* -------------------------------------------------------------------------- */

typedef VoiceResolver = String Function(Limb limb);

class RenderedPatternLine {
  final List<String> phraseChars;
  final List<String> voiceChars;
  final List<String> caretChars;

  const RenderedPatternLine({
    required this.phraseChars,
    required this.voiceChars,
    required this.caretChars,
  });
}

/* -------------------------------------------------------------------------- */
/* Formatter                                                                  */
/* -------------------------------------------------------------------------- */

class PatternFormatterV1 {
  static const String arrowToken = ' \u2192 '; // " → "
  static const String infinityGlyph = '\u221E'; // "∞"
  static const String timesGlyph = '\u00D7'; // "×"

  const PatternFormatterV1();

  List<RenderedPatternLine> render({
    required Pattern pattern,
    required int maxCols,
    VoiceResolver? voiceResolver,
    bool renderVoices = true,
    bool renderKickVoices = false,
  }) {
    final List<List<TriadCell>> chunks = _chunkCellsByCols(
      phrase: pattern.phrase,
      maxCols: maxCols,
    );

    final int totalNotes = pattern.phrase.length * 3;
    final List<RenderedPatternLine> out = <RenderedPatternLine>[];

    int globalCellStart = 0;

    for (int i = 0; i < chunks.length; i++) {
      final List<TriadCell> lineCells = chunks[i];
      final bool isLast = i == chunks.length - 1;

      String lineText = lineCells.map((c) => c.id).join(arrowToken);
      if (isLast) {
        lineText = pattern.infiniteRepeat
            ? '$lineText $infinityGlyph'
            : '$lineText $timesGlyph ${pattern.repeats}';
      }

      final List<String> phraseChars = _toChars(lineText);
      final List<String> caretChars =
          List<String>.filled(phraseChars.length, ' ');
      final List<String> voiceChars =
          List<String>.filled(phraseChars.length, ' ');

      // Accents are global-note indices into the whole phrase (wrapping allowed).
      final int lineCellCount = lineCells.length;
      final int globalNoteStart = globalCellStart * 3;
      final int globalNoteEndExclusive = globalNoteStart + (lineCellCount * 3);

      final List<int> localAccentNotes = <int>[];
      for (final int a in pattern.accentNoteIndices) {
        final int inPhrase = totalNotes == 0 ? 0 : (a % totalNotes);
        if (inPhrase >= globalNoteStart && inPhrase < globalNoteEndExclusive) {
          localAccentNotes.add(inPhrase - globalNoteStart);
        }
      }

      final List<int> glyphCols = _glyphCols(phraseChars);

      // Place carets under accented limb glyphs.
      for (final int n in localAccentNotes) {
        if (n < 0 || n >= glyphCols.length) continue;

        final int cellIndex = n ~/ 3;
        final int noteInCell = n % 3;
        final Limb limb = lineCells[cellIndex].limbs[noteInCell];

        final int col = glyphCols[n];
        if (col >= 0 && col < caretChars.length) caretChars[col] = '^';

        // Optionally render voices per-glyph
        if (renderVoices && voiceResolver != null) {
          if (limb == Limb.k && !renderKickVoices) continue;
          final String v = voiceResolver(limb);
          if (v.isEmpty) continue;
          if (col >= 0 && col < voiceChars.length) voiceChars[col] = v[0];
        }
      }

      // If we didn’t place any voices via accents but voices are enabled,
      // render voices for ALL glyph positions (clean + unambiguous).
      if (renderVoices && voiceResolver != null) {
        _renderAllVoices(
          lineCells: lineCells,
          glyphCols: glyphCols,
          voiceChars: voiceChars,
          voiceResolver: voiceResolver,
          renderKickVoices: renderKickVoices,
        );
      }

      out.add(
        RenderedPatternLine(
          phraseChars: phraseChars,
          voiceChars: voiceChars,
          caretChars: caretChars,
        ),
      );

      globalCellStart += lineCells.length;
    }

    return out;
  }

  /* ------------------------------------------------------------------------ */
  /* Internals                                                                */
  /* ------------------------------------------------------------------------ */

  void _renderAllVoices({
    required List<TriadCell> lineCells,
    required List<int> glyphCols,
    required List<String> voiceChars,
    required VoiceResolver voiceResolver,
    required bool renderKickVoices,
  }) {
    final int notesInLine = lineCells.length * 3;

    for (int note = 0; note < notesInLine; note++) {
      if (note < 0 || note >= glyphCols.length) continue;

      final int cellIndex = note ~/ 3;
      final int noteInCell = note % 3;
      final Limb limb = lineCells[cellIndex].limbs[noteInCell];

      if (limb == Limb.k && !renderKickVoices) continue;

      final String v = voiceResolver(limb);
      if (v.isEmpty) continue;

      final int col = glyphCols[note];
      if (col >= 0 && col < voiceChars.length) voiceChars[col] = v[0];
    }
  }

  List<List<TriadCell>> _chunkCellsByCols({
    required List<TriadCell> phrase,
    required int maxCols,
  }) {
    int estimateCols(List<TriadCell> cells) {
      if (cells.isEmpty) return 0;
      final int ids = cells.fold<int>(0, (n, c) => n + c.id.length);
      final int arrows = (cells.length - 1) * arrowToken.length;
      return ids + arrows + 6; // room for trailing "× N" or "∞"
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
