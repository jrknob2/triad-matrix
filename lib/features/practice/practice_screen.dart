// lib/features/practice/practice_screen.dart
//
// Triad Trainer — Practice Screen (v1 scaffold + generator bottom sheet)

import 'package:flutter/material.dart';

import '../../core/pattern_engine.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

/* ----------------------------- Orchestration ------------------------------ */

enum DrumVoice {
  snare,
  tom1,
  tom2,
  floorTom,
  hiHat,
  ride,
  kick,
}

extension DrumVoiceText on DrumVoice {
  String get short => switch (this) {
        DrumVoice.snare => 'S',
        DrumVoice.tom1 => 'T1',
        DrumVoice.tom2 => 'T2',
        DrumVoice.floorTom => 'FT',
        DrumVoice.hiHat => 'HH',
        DrumVoice.ride => 'R',
        DrumVoice.kick => 'K',
      };
}

class OrchestrationPreset {
  final String id;
  final String name;
  final Map<Limb, DrumVoice> limbToVoice;
  final Map<int, DrumVoice> perNoteOverride;

  const OrchestrationPreset({
    required this.id,
    required this.name,
    required this.limbToVoice,
    this.perNoteOverride = const <int, DrumVoice>{},
  });

  DrumVoice voiceFor(Limb limb, int noteIndexInCell) {
    return perNoteOverride[noteIndexInCell] ?? limbToVoice[limb]!;
  }

  static Map<String, OrchestrationPreset> builtIns() {
    return <String, OrchestrationPreset>{
      'hands_basic': OrchestrationPreset(
        id: 'hands_basic',
        name: 'Hands Basic',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.hiHat,
          Limb.k: DrumVoice.kick,
        },
      ),
      'rock_basic': OrchestrationPreset(
        id: 'rock_basic',
        name: 'Rock Basic',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.hiHat,
          Limb.k: DrumVoice.kick,
        },
      ),
      'funk_linear': OrchestrationPreset(
        id: 'funk_linear',
        name: 'Funk Linear',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.hiHat,
          Limb.k: DrumVoice.kick,
        },
      ),
      'jazz_ride_comp': OrchestrationPreset(
        id: 'jazz_ride_comp',
        name: 'Jazz Ride/Comp',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.ride,
          Limb.l: DrumVoice.snare,
          Limb.k: DrumVoice.kick,
        },
      ),
      'fusion_melodic_toms': OrchestrationPreset(
        id: 'fusion_melodic_toms',
        name: 'Fusion Melodic Toms',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.tom1,
          Limb.l: DrumVoice.snare,
          Limb.k: DrumVoice.kick,
        },
        perNoteOverride: const <int, DrumVoice>{
          1: DrumVoice.tom2,
        },
      ),
    };
  }
}

/* --------------------------- Generator Override Model ---------------------- */

class GeneratorOverrides {
  PhraseType? phraseType;
  int? repeats;
  int? chainCells;
  AccentRule? accentRule;
  String? orchestrationPresetId;

  GeneratorOverrides();

  GeneratorOverrides clone() {
    final GeneratorOverrides o = GeneratorOverrides();
    o.phraseType = phraseType;
    o.repeats = repeats;
    o.chainCells = chainCells;
    o.accentRule = accentRule;
    o.orchestrationPresetId = orchestrationPresetId;
    return o;
  }

  void clear() {
    phraseType = null;
    repeats = null;
    chainCells = null;
    accentRule = null;
    orchestrationPresetId = null;
  }
}

/* ------------------------------ Formatting Model -------------------------- */

class _RenderedPatternLine {
  final String phraseText;
  final List<String> phraseChars;
  final List<String> caretChars;
  final List<String> voiceChars;

  const _RenderedPatternLine({
    required this.phraseText,
    required this.phraseChars,
    required this.caretChars,
    required this.voiceChars,
  });
}

/* ------------------------------ Screen State ------------------------------ */

class _PracticeScreenState extends State<PracticeScreen> {
  final Map<String, GenrePreset> _genres = GenrePreset.builtIns();
  final Map<String, OrchestrationPreset> _orchPresets =
      OrchestrationPreset.builtIns();

  late final PatternEngine _engine;

  late GenrePreset _genre;
  bool _coverageMode = true;

  int _bpm = 92;

  final GeneratorOverrides _overrides = GeneratorOverrides();

  PatternResult? _last;
  int? _lastSeed;

  @override
  void initState() {
    super.initState();
    _engine = PatternEngine();
    _genre = _genres.values.first;
    _generateNext();
  }

  PatternRequest _buildRequest({int? seedOverride}) {
    return PatternRequest(
      genre: _genre,
      coverageMode: _coverageMode,
      seed: seedOverride,
      phraseType: _overrides.phraseType,
      repeats: _overrides.repeats,
      chainCells: _overrides.chainCells,
      accentRule: _overrides.accentRule,
      orchestrationPresetId: _overrides.orchestrationPresetId,
    );
  }

  void _generateNext({int? seed}) {
    final int computedSeed = seed ?? DateTime.now().microsecondsSinceEpoch;
    final PatternRequest req = _buildRequest(seedOverride: computedSeed);

    setState(() {
      _lastSeed = computedSeed;
      _last = _engine.generateNext(req);
    });
  }

  void _restartSame() {
    final int? seed = _lastSeed;
    if (seed == null) {
      _generateNext();
      return;
    }
    final PatternRequest req = _buildRequest(seedOverride: seed);
    setState(() {
      _last = _engine.generateNext(req);
    });
  }

  void _setGenre(String id) {
    final GenrePreset? next = _genres[id];
    if (next == null) return;
    setState(() => _genre = next);
    _generateNext();
  }

  void _toggleCoverage(bool v) {
    setState(() => _coverageMode = v);
    _generateNext();
  }

  void _bpmStep(int delta) {
    setState(() => _bpm = (_bpm + delta).clamp(30, 260));
  }

  Future<void> _openGeneratorSheet() async {
    final GeneratorOverrides draft = _overrides.clone();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext ctx) {
        return _GeneratorSheet(
          genre: _genre,
          orchPresets: _orchPresets,
          draft: draft,
          onApply: () {
            Navigator.of(ctx).pop();
            setState(() {
              _overrides.phraseType = draft.phraseType;
              _overrides.repeats = draft.repeats;
              _overrides.chainCells = draft.chainCells;
              _overrides.accentRule = draft.accentRule;
              _overrides.orchestrationPresetId = draft.orchestrationPresetId;
            });
            _generateNext();
          },
          onReset: () => draft.clear(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PatternResult? last = _last;
    final Pattern? p = last?.pattern;

    final OrchestrationPreset? orch =
        p == null ? null : _orchPresets[p.orchestrationPresetId];

    final int remaining = last?.coverageState.remaining.length ?? 0;
    final int eligibleTotal = _estimateEligibleTotal(_genre.constraints);

    final String coverageLabel = _coverageMode
        ? 'Coverage: ${eligibleTotal - remaining}/$eligibleTotal'
        : 'Coverage: Off';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Triad Trainer'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Favorites coming soon')),
              );
            },
            icon: const Icon(Icons.star_border),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon')),
              );
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _TopControls(
              genres: _genres,
              selectedGenreId: _genre.id,
              onGenreChanged: _setGenre,
              coverageMode: _coverageMode,
              onCoverageChanged: _toggleCoverage,
              coverageLabel: coverageLabel,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _PatternCard(pattern: p, orch: orch),
                  ),
                ),
              ),
            ),
            _TransportBar(
              bpm: _bpm,
              onBpmMinus: () => _bpmStep(-1),
              onBpmPlus: () => _bpmStep(1),
              onNext: () => _generateNext(),
              onPlay: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Audio playback coming soon')),
                );
              },
              onRestart: _restartSame,
              onGenerator: _openGeneratorSheet,
            ),
          ],
        ),
      ),
    );
  }

  int _estimateEligibleTotal(GeneratorConstraints c) {
    final int limbCount = c.scope == LimbScope.handsOnly ? 2 : 3;
    int total = limbCount * limbCount * limbCount;

    if (c.requireKick && c.scope == LimbScope.handsAndKick) {
      total -= 2 * 2 * 2;
    }

    if (!c.includeDoubles) {
      final int n = limbCount;
      total = n * (n - 1) * (n - 2);
      if (total < 0) total = 0;

      if (c.requireKick && c.scope == LimbScope.handsAndKick) {
        total = 6;
      }
    }

    if (!c.allowKickDoubles && c.scope == LimbScope.handsAndKick) {
      int exact = 0;
      const List<Limb> limbs = <Limb>[Limb.r, Limb.l, Limb.k];
      for (final Limb a in limbs) {
        for (final Limb b in limbs) {
          for (final Limb d in limbs) {
            final TriadCell cell = TriadCell(a, b, d);

            final bool hasAnyDouble = (a == b) || (b == d) || (a == d);
            final bool hasKickDouble = (a == Limb.k && b == Limb.k) ||
                (b == Limb.k && d == Limb.k) ||
                (a == Limb.k && b == Limb.k && d == Limb.k);

            if (!c.includeDoubles && hasAnyDouble) continue;
            if (c.requireKick && !cell.limbs.contains(Limb.k)) continue;
            if (hasKickDouble) continue;

            exact++;
          }
        }
      }
      return exact;
    }

    return total;
  }
}

/* ------------------------------- Pattern Card ------------------------------ */

class _PatternCard extends StatelessWidget {
  final Pattern? pattern;
  final OrchestrationPreset? orch;

  const _PatternCard({
    required this.pattern,
    required this.orch,
  });

  static const String _arrow = ' \u2192 ';

  @override
  Widget build(BuildContext context) {
    final Pattern? p = pattern;
    if (p == null) {
      return const Card(
        child: Padding(padding: EdgeInsets.all(18), child: Text('…')),
      );
    }

    final TextStyle mono = const TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: <String>['SF Mono', 'Courier New', 'monospace'],
      fontSize: 26,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: 0,
    );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints c) {
        final double maxWidth = c.maxWidth - 36;
        final _MonoMetrics m = _MonoMetrics.fromStyle(mono);
        final int maxCols = (maxWidth / m.cellW).floor().clamp(18, 140);

        final List<_RenderedPatternLine> lines = _renderLines(
          phrase: p.phrase,
          repeats: p.repeats,
          accents: p.accentNoteIndices,
          orch: orch,
          maxCols: maxCols,
        );

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (int i = 0; i < lines.length; i++) ...<Widget>[
                  Center(
                    child: _MonoGridBlock(
                      phrase: lines[i].phraseChars,
                      carets: lines[i].caretChars,
                      voices: lines[i].voiceChars,
                      style: mono,
                    ),
                  ),
                  if (i != lines.length - 1) const SizedBox(height: 14),
                ],
                const SizedBox(height: 10),
                if (orch != null)
                  Text(
                    'Orchestration: ${orch!.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_RenderedPatternLine> _renderLines({
    required List<TriadCell> phrase,
    required int repeats,
    required List<int> accents,
    required OrchestrationPreset? orch,
    required int maxCols,
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
      lineText = isLast ? '($lineText) × $repeats' : '($lineText)';

      final List<String> phraseChars = _toChars(lineText);
      final List<String> caretChars =
          List<String>.filled(phraseChars.length, ' ');
      final List<String> voiceChars =
          List<String>.filled(phraseChars.length, ' ');

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

      for (final int n in localAccentNotes) {
        if (n >= 0 && n < glyphCols.length) {
          caretChars[glyphCols[n]] = '^';
        }
      }

      if (orch != null && glyphCols.isNotEmpty && lineCells.isNotEmpty) {
        final int notesInLine = lineCells.length * 3;

        bool isKickNote(int noteIndexInLine) {
          final int cellIndex = noteIndexInLine ~/ 3;
          final int noteInCell = noteIndexInLine % 3;
          return lineCells[cellIndex].limbs[noteInCell] == Limb.k;
        }

        String voiceLabel(int noteIndexInLine) {
          if (isKickNote(noteIndexInLine)) return '';
          final int cellIndex = noteIndexInLine ~/ 3;
          final int noteInCell = noteIndexInLine % 3;
          final Limb limb = lineCells[cellIndex].limbs[noteInCell];
          return orch.voiceFor(limb, noteInCell).short;
        }

        void placeLabelAtNote(int noteIndexInLine, String label) {
          if (label.isEmpty) return;
          if (noteIndexInLine < 0 || noteIndexInLine >= glyphCols.length) return;
          final int col = glyphCols[noteIndexInLine];
          for (int i = 0; i < label.length; i++) {
            final int idx = col + i;
            if (idx >= 0 && idx < voiceChars.length) {
              voiceChars[idx] = label[i];
            }
          }
        }

        int first = 0;
        while (first < notesInLine && voiceLabel(first).isEmpty) {
          first++;
        }

        int last = notesInLine - 1;
        while (last >= 0 && voiceLabel(last).isEmpty) {
          last--;
        }

        if (first < notesInLine) placeLabelAtNote(first, voiceLabel(first));
        if (last >= 0) placeLabelAtNote(last, voiceLabel(last));
      }

      out.add(
        _RenderedPatternLine(
          phraseText: lineText,
          phraseChars: phraseChars,
          caretChars: caretChars,
          voiceChars: voiceChars,
        ),
      );

      globalCellStart += lineCells.length;
    }

    return out;
  }

  List<List<TriadCell>> _chunkCellsByCols({
    required List<TriadCell> phrase,
    required int maxCols,
  }) {
    const String arrow = _arrow;

    int estimateCols(List<TriadCell> cells) {
      if (cells.isEmpty) return 2;
      final int ids = cells.fold<int>(0, (n, c) => n + c.id.length);
      final int arrows = (cells.length - 1) * arrow.length;
      return 2 + ids + arrows; // parentheses
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

  List<String> _toChars(String s) => <String>[for (int i = 0; i < s.length; i++) s[i]];

  List<int> _glyphCols(List<String> chars) {
    final List<int> cols = <int>[];
    for (int i = 0; i < chars.length; i++) {
      final String ch = chars[i];
      if (ch == 'R' || ch == 'L' || ch == 'K') cols.add(i);
    }
    return cols;
  }
}

/* -------------------------- Fixed-grid painter widgets --------------------- */

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
  final List<String> carets;
  final List<String> voices;
  final TextStyle style;

  const _MonoGridBlock({
    required this.phrase,
    required this.carets,
    required this.voices,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final int cols = phrase.length;
    final _MonoMetrics m = _MonoMetrics.fromStyle(style);

    final double w = cols * m.cellW;
    final double h = 3 * m.cellH;

    return CustomPaint(
      size: Size(w, h),
      painter: _MonoGridPainter(
        phrase: phrase,
        carets: carets,
        voices: voices,
        style: style,
        metrics: m,
      ),
    );
  }
}

class _MonoGridPainter extends CustomPainter {
  final List<String> phrase;
  final List<String> carets;
  final List<String> voices;
  final TextStyle style;
  final _MonoMetrics metrics;

  _MonoGridPainter({
    required this.phrase,
    required this.carets,
    required this.voices,
    required this.style,
    required this.metrics,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintRow(canvas, phrase, 0);
    _paintRow(canvas, carets, 1);
    _paintRow(canvas, voices, 2);
  }

  void _paintRow(Canvas canvas, List<String> row, int rowIndex) {
    final double y = rowIndex * metrics.cellH;

    for (int col = 0; col < row.length; col++) {
      final String ch = row[col];
      if (ch == ' ') continue;

      final TextPainter tp = TextPainter(
        text: TextSpan(text: ch, style: style),
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
        oldDelegate.carets != carets ||
        oldDelegate.voices != voices ||
        oldDelegate.style != style;
  }
}

/* ------------------------------- Transport Bar ----------------------------- */
/* ... keep your existing transport + generator + top controls implementations */
/* (unchanged below in your actual file)                                       */

// NOTE: Your project already has _TransportBar, _GeneratorSheet, _TopControls,
// etc. Keep those as they were. The important warnings/braces are fixed above.
