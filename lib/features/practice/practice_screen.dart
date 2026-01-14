// lib/features/practice/practice_screen.dart
//
// Triad Trainer — Practice Screen (v1 scaffold + generator bottom sheet)

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/pattern/pattern_engine.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

/* ----------------------------- Practice / Kit ----------------------------- */

enum PracticeMode { pad, kit }

enum Handedness { right, left }

enum Brass { none, hh, hhRide }

class KitPreset {
  final int pieces; // 2..7 (kit mode only)
  final Handedness handedness;
  final Brass brass;

  const KitPreset({
    required this.pieces,
    required this.handedness,
    required this.brass,
  });

  KitPreset copyWith({
    int? pieces,
    Handedness? handedness,
    Brass? brass,
  }) {
    return KitPreset(
      pieces: pieces ?? this.pieces,
      handedness: handedness ?? this.handedness,
      brass: brass ?? this.brass,
    );
  }

  static const KitPreset defaultKit = KitPreset(
    pieces: 4,
    handedness: Handedness.right,
    brass: Brass.hh,
  );
}

/* ----------------------------- Orchestration ------------------------------ */

/// Single-letter codes only (to avoid "HH" collisions).
/// We keep this separate from the limb glyphs (R/L/K) on purpose.
enum DrumVoice {
  pad, // (legacy) not used in UI for v1
  snare, // S
  tom1, // 1
  tom2, // 2
  floorTom, // F
  hiHat, // H
  ride, // R
  kick, // K (not shown in voice row)
}

extension DrumVoiceText on DrumVoice {
  String get short => switch (this) {
        DrumVoice.pad => 'S', // v1: never show "P" in pad mode
        DrumVoice.snare => 'S',
        DrumVoice.tom1 => '1',
        DrumVoice.tom2 => '2',
        DrumVoice.floorTom => 'F',
        DrumVoice.hiHat => 'H',
        DrumVoice.ride => 'R',
        DrumVoice.kick => 'K',
      };
}

class OrchestrationPreset {
  final String id;
  final String name;
  final Map<Limb, DrumVoice> limbToVoice;

  const OrchestrationPreset({
    required this.id,
    required this.name,
    required this.limbToVoice,
  });

  DrumVoice voiceFor(Limb limb) => limbToVoice[limb] ?? DrumVoice.snare;

  static Map<String, OrchestrationPreset> builtIns() {
    return <String, OrchestrationPreset>{
      'pad_basic': OrchestrationPreset(
        id: 'pad_basic',
        name: 'Pad',
        limbToVoice: const <Limb, DrumVoice>{
          // v1: in pad mode, show "S" (snare) not "P"
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.snare,
          Limb.k: DrumVoice.kick,
        },
      ),
      'kit_2pc': OrchestrationPreset(
        id: 'kit_2pc',
        name: '2-piece (S+K)',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.snare,
          Limb.k: DrumVoice.kick,
        },
      ),
      'kit_3pc': OrchestrationPreset(
        id: 'kit_3pc',
        name: '3-piece (S+K+1)',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.tom1,
          Limb.k: DrumVoice.kick,
        },
      ),
      'kit_4pc': OrchestrationPreset(
        id: 'kit_4pc',
        name: '4-piece (S+K+1+F)',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.tom1,
          Limb.k: DrumVoice.kick,
        },
      ),
      'kit_5pc': OrchestrationPreset(
        id: 'kit_5pc',
        name: '5-piece (S+K+1+2+F)',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.tom1,
          Limb.k: DrumVoice.kick,
        },
      ),
      'kit_6pc': OrchestrationPreset(
        id: 'kit_6pc',
        name: '6-piece',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.tom1,
          Limb.k: DrumVoice.kick,
        },
      ),
      'kit_7pc': OrchestrationPreset(
        id: 'kit_7pc',
        name: '7-piece',
        limbToVoice: const <Limb, DrumVoice>{
          Limb.r: DrumVoice.snare,
          Limb.l: DrumVoice.tom1,
          Limb.k: DrumVoice.kick,
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

  // v1: show infinity for beginner/skill loops
  bool infiniteRepeat = false;

  // Practice/kit config (UI-level)
  PracticeMode mode = PracticeMode.pad;
  KitPreset kit = KitPreset.defaultKit;

  // Scope is derived but user may override in kit mode.
  LimbScope scope = LimbScope.handsOnly;

  GeneratorOverrides();

  GeneratorOverrides clone() {
    final GeneratorOverrides o = GeneratorOverrides();
    o.phraseType = phraseType;
    o.repeats = repeats;
    o.chainCells = chainCells;
    o.accentRule = accentRule;
    o.infiniteRepeat = infiniteRepeat;
    o.mode = mode;
    o.kit = kit;
    o.scope = scope;
    return o;
  }

  void clearTuningOnly() {
    phraseType = null;
    repeats = null;
    chainCells = null;
    accentRule = null;
  }
}

/* ------------------------------ Formatting Model -------------------------- */

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

/* ------------------------------ Screen State ------------------------------ */

class _PracticeScreenState extends State<PracticeScreen> {
  final Map<String, GenrePreset> _genres = GenrePreset.builtIns();
  final Map<String, OrchestrationPreset> _orchPresets =
      OrchestrationPreset.builtIns();

  // ✅ hard fallback so we never crash if a preset key is missing
  static const OrchestrationPreset _fallbackOrch = OrchestrationPreset(
    id: '_fallback',
    name: 'Fallback',
    limbToVoice: <Limb, DrumVoice>{
      Limb.r: DrumVoice.snare,
      Limb.l: DrumVoice.snare,
      Limb.k: DrumVoice.kick,
    },
  );

  late final PatternEngine _engine;

  late GenrePreset _genre;
  bool _coverageMode = true;

  int _bpm = 92;

  final GeneratorOverrides _overrides = GeneratorOverrides();

  PatternResult? _last;
  int? _lastSeed;

  // v1 timer (optional, beginner-oriented)
  Duration? _targetDuration;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _engine = PatternEngine();
    _genre = _genres.values.first;

    // default v1: pad practice, hands-only
    _overrides.mode = PracticeMode.pad;
    _overrides.scope = LimbScope.handsOnly;

    _generateNext();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setTimerTarget(Duration? d) {
    setState(() {
      _targetDuration = d;
      _elapsed = Duration.zero;
      _timerRunning = false;
    });
    _timer?.cancel();
    _timer = null;
  }

  void _resetTimer() {
    setState(() => _elapsed = Duration.zero);
  }

  void _toggleTimerRunning() {
    if (_timerRunning) {
      setState(() => _timerRunning = false);
      return;
    }
    _startTimer();
  }

  void _startTimer() {
    if (_timerRunning) return;
    setState(() => _timerRunning = true);
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_timerRunning) return;
      setState(() {
        _elapsed += const Duration(seconds: 1);
        if (_targetDuration != null && _elapsed >= _targetDuration!) {
          _timerRunning = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Time! Nice work.')),
          );
        }
      });
    });
  }

  GeneratorConstraints _effectiveConstraints() {
    final GeneratorConstraints base = _genre.constraints;

    final LimbScope scope = switch (_overrides.mode) {
      PracticeMode.pad => LimbScope.handsOnly,
      PracticeMode.kit => _overrides.scope,
    };

    // If hands-only, requireKick must be false.
    final bool requireKick =
        (scope == LimbScope.handsAndKick) && base.requireKick;

    return base.copyWith(scope: scope, requireKick: requireKick);
  }

  String _orchIdForSelection() {
    if (_overrides.mode == PracticeMode.pad) return 'pad_basic';
    final int p = _overrides.kit.pieces.clamp(2, 7);
    return 'kit_${p}pc';
  }

  OrchestrationPreset _resolveOrchSafe() {
    final String wanted = _orchIdForSelection();
    return _orchPresets[wanted] ?? _orchPresets['pad_basic'] ?? _fallbackOrch;
  }

  void _generateNext({int? seed}) {
    final int computedSeed = seed ?? DateTime.now().microsecondsSinceEpoch;

    final GenrePreset tunedGenre =
        _genre.copyWith(constraints: _effectiveConstraints());

    final PatternRequest req = PatternRequest(
      genre: tunedGenre,
      coverageMode: _coverageMode,
      seed: computedSeed,
      phraseType: _overrides.phraseType,
      repeats: _overrides.repeats,
      chainCells: _overrides.chainCells,
      accentRule: _overrides.accentRule,
      infiniteRepeat: _overrides.infiniteRepeat,
    );

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
    _generateNext(seed: seed);
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
          draft: draft,
          onApply: () {
            Navigator.of(ctx).pop();
            setState(() {
              _overrides.phraseType = draft.phraseType;
              _overrides.repeats = draft.repeats;
              _overrides.chainCells = draft.chainCells;
              _overrides.accentRule = draft.accentRule;
              _overrides.infiniteRepeat = draft.infiniteRepeat;
              _overrides.mode = draft.mode;
              _overrides.kit = draft.kit;
              _overrides.scope = draft.scope;
            });
            _generateNext();
          },
          onResetTuningOnly: () => setState(draft.clearTuningOnly),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final PatternResult? last = _last;
    final Pattern? p = last?.pattern;

    final OrchestrationPreset orch = _resolveOrchSafe();

    final int remaining = last?.coverageState.remaining.length ?? 0;
    final int eligibleTotal = _estimateEligibleTotal(_effectiveConstraints());

    final String coverageLabel = _coverageMode
        ? 'Coverage: ${eligibleTotal - remaining}/$eligibleTotal'
        : 'Coverage: Off';

    final String timerLabel = _targetDuration == null
        ? _formatMmSs(_elapsed)
        : '${_formatMmSs(_elapsed)} / ${_formatMmSs(_targetDuration!)}';

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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: <Widget>[
                  IconButton(
                    icon: Icon(_timerRunning ? Icons.pause : Icons.play_arrow),
                    tooltip: _timerRunning ? 'Pause timer' : 'Start timer',
                    onPressed: _toggleTimerRunning,
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.timer, size: 18),
                  const SizedBox(width: 6),
                  Text(timerLabel),
                  IconButton(
                    icon: const Icon(Icons.restart_alt),
                    tooltip: 'Reset timer',
                    onPressed: _resetTimer,
                  ),
                  const Spacer(),
                  PopupMenuButton<Duration?>(
                    tooltip: 'Timer target',
                    onSelected: _setTimerTarget,
                    itemBuilder: (_) => const <PopupMenuEntry<Duration?>>[
                      PopupMenuItem(value: null, child: Text('No timer')),
                      PopupMenuItem(
                        value: Duration(minutes: 5),
                        child: Text('5 min'),
                      ),
                      PopupMenuItem(
                        value: Duration(minutes: 10),
                        child: Text('10 min'),
                      ),
                      PopupMenuItem(
                        value: Duration(minutes: 30),
                        child: Text('30 min'),
                      ),
                    ],
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text('Timer'),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _PatternCard(
                      pattern: p,
                      orch: orch,
                      ghostHands: false, // v1: no ghosting
                    ),
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
                // v1: starting playback starts the timer (if you prefer manual only, say so)
                _startTimer();
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

  String _formatMmSs(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    final String mm = m.toString().padLeft(2, '0');
    final String ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
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
  final OrchestrationPreset orch;
  final bool ghostHands;

  const _PatternCard({
    required this.pattern,
    required this.orch,
    required this.ghostHands,
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

    final Color onSurface = Theme.of(context).colorScheme.onSurface;

    final TextStyle phraseStyle = TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: const <String>['SF Mono', 'Courier New', 'monospace'],
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: 0,
      color: onSurface,
    );

    final TextStyle metaStyle = phraseStyle.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w500,
    );

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
          orch: orch,
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
                      voices: lines[i].voiceChars,
                      carets: lines[i].caretChars,
                      phraseStyle: phraseStyle,
                      metaStyle: metaStyle,
                      ghostHands: ghostHands,
                      lineLimbTriplets: _lineLimbsForChars(lines[i].phraseChars),
                      accentedCols: _accentedCols(lines[i].caretChars),
                    ),
                  ),
                  if (i != lines.length - 1) const SizedBox(height: 14),
                ],
                const SizedBox(height: 10),
                Text(
                  'Accents are marked with ^ (kick never accented).',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Limb?> _lineLimbsForChars(List<String> phraseChars) {
    final List<Limb?> out = List<Limb?>.filled(phraseChars.length, null);
    for (int i = 0; i < phraseChars.length; i++) {
      switch (phraseChars[i]) {
        case 'R':
          out[i] = Limb.r;
          break;
        case 'L':
          out[i] = Limb.l;
          break;
        case 'K':
          out[i] = Limb.k;
          break;
      }
    }
    return out;
  }

  Set<int> _accentedCols(List<String> caretChars) {
    final Set<int> cols = <int>{};
    for (int i = 0; i < caretChars.length; i++) {
      if (caretChars[i] == '^') cols.add(i);
    }
    return cols;
  }

  List<_RenderedPatternLine> _renderLines({
    required List<TriadCell> phrase,
    required int repeats,
    required bool infinite,
    required List<int> accents,
    required int maxCols,
    required OrchestrationPreset orch,
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

      // Place carets, skipping kick notes.
      for (final int n in localAccentNotes) {
        if (n < 0 || n >= glyphCols.length) continue;

        final int cellIndex = n ~/ 3;
        final int noteInCell = n % 3;
        final Limb limb = lineCells[cellIndex].limbs[noteInCell];
        if (limb == Limb.k) continue;

        caretChars[glyphCols[n]] = '^';
      }

      // Voice labels under first and last non-kick notes (single letter).
      if (glyphCols.isNotEmpty && lineCells.isNotEmpty) {
        final int notesInLine = lineCells.length * 3;

        bool isKickNote(int noteIndexInLine) {
          final int cellIndex = noteIndexInLine ~/ 3;
          final int noteInCell = noteIndexInLine % 3;
          return lineCells[cellIndex].limbs[noteInCell] == Limb.k;
        }

        String voiceLabel(int noteIndexInLine) {
          final int cellIndex = noteIndexInLine ~/ 3;
          final int noteInCell = noteIndexInLine % 3;
          final Limb limb = lineCells[cellIndex].limbs[noteInCell];
          final DrumVoice v = orch.voiceFor(limb);
          if (isKickNote(noteIndexInLine)) return '';
          return v.short;
        }

        void placeLabelAtNote(int noteIndexInLine, String label) {
          if (label.isEmpty) return;
          if (noteIndexInLine < 0 || noteIndexInLine >= glyphCols.length) return;
          final int col = glyphCols[noteIndexInLine];
          if (col >= 0 && col < voiceChars.length) voiceChars[col] = label;
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
          phraseChars: phraseChars,
          voiceChars: voiceChars,
          caretChars: caretChars,
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
  final List<String> voices;
  final List<String> carets;

  final TextStyle phraseStyle;
  final TextStyle metaStyle;

  final bool ghostHands;

  final List<Limb?> lineLimbTriplets;
  final Set<int> accentedCols;

  const _MonoGridBlock({
    required this.phrase,
    required this.voices,
    required this.carets,
    required this.phraseStyle,
    required this.metaStyle,
    required this.ghostHands,
    required this.lineLimbTriplets,
    required this.accentedCols,
  });

  @override
  Widget build(BuildContext context) {
    final int cols = phrase.length;
    final _MonoMetrics m = _MonoMetrics.fromStyle(phraseStyle);

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
        ghostHands: ghostHands,
        limbByCol: lineLimbTriplets,
        accentedCols: accentedCols,
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

  final bool ghostHands;
  final List<Limb?> limbByCol;
  final Set<int> accentedCols;

  _MonoGridPainter({
    required this.phrase,
    required this.voices,
    required this.carets,
    required this.phraseStyle,
    required this.metaStyle,
    required this.metrics,
    required this.ghostHands,
    required this.limbByCol,
    required this.accentedCols,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // triad / voice / accent
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

      // v1: no ghosting — everything opaque.
      final TextStyle style = baseStyle;

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
        oldDelegate.voices != voices ||
        oldDelegate.carets != carets ||
        oldDelegate.phraseStyle != phraseStyle ||
        oldDelegate.metaStyle != metaStyle ||
        oldDelegate.ghostHands != ghostHands ||
        oldDelegate.limbByCol != limbByCol ||
        oldDelegate.accentedCols.length != accentedCols.length;
  }
}

/* ------------------------------- Top Controls ------------------------------ */

class _TopControls extends StatelessWidget {
  final Map<String, GenrePreset> genres;
  final String selectedGenreId;
  final ValueChanged<String> onGenreChanged;

  final bool coverageMode;
  final ValueChanged<bool> onCoverageChanged;
  final String coverageLabel;

  const _TopControls({
    required this.genres,
    required this.selectedGenreId,
    required this.onGenreChanged,
    required this.coverageMode,
    required this.onCoverageChanged,
    required this.coverageLabel,
  });

  @override
  Widget build(BuildContext context) {
    final items = genres.values
        .map((g) => DropdownMenuItem<String>(value: g.id, child: Text(g.name)))
        .toList(growable: false);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints c) {
          // ✅ Fix the remaining top-row overflow by stacking on narrow widths.
          final bool compact = c.maxWidth < 520;

          final Widget genre = DropdownButtonFormField<String>(
            initialValue: selectedGenreId,
            items: items,
            onChanged: (v) {
              if (v != null) onGenreChanged(v);
            },
            decoration: const InputDecoration(
              labelText: 'Genre',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          );

          final Widget coverage = Column(
            crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: <Widget>[
              Row(
                mainAxisAlignment:
                    compact ? MainAxisAlignment.start : MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Coverage'),
                  const SizedBox(width: 6),
                  Switch.adaptive(
                    value: coverageMode,
                    onChanged: onCoverageChanged,
                  ),
                ],
              ),
              Text(
                coverageLabel,
                textAlign: compact ? TextAlign.start : TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );

          if (!compact) {
            return Row(
              children: <Widget>[
                Expanded(child: genre),
                const SizedBox(width: 12),
                coverage,
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              genre,
              const SizedBox(height: 10),
              coverage,
            ],
          );
        },
      ),
    );
  }
}

/* ------------------------------- Transport Bar ----------------------------- */

class _TransportBar extends StatelessWidget {
  final int bpm;

  final VoidCallback onRestart;
  final VoidCallback onPlay;
  final VoidCallback onNext;
  final VoidCallback onGenerator;

  final VoidCallback onBpmMinus;
  final VoidCallback onBpmPlus;

  const _TransportBar({
    required this.bpm,
    required this.onRestart,
    required this.onPlay,
    required this.onNext,
    required this.onGenerator,
    required this.onBpmMinus,
    required this.onBpmPlus,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                final bool compact = c.maxWidth < 460;

                if (!compact) {
                  return Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: onRestart,
                        icon: const Icon(Icons.replay),
                        tooltip: 'Restart',
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: onPlay,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: onBpmMinus,
                        icon: const Icon(Icons.remove),
                        tooltip: 'BPM -',
                      ),
                      Text(
                        '$bpm BPM',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      IconButton(
                        onPressed: onBpmPlus,
                        icon: const Icon(Icons.add),
                        tooltip: 'BPM +',
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: onGenerator,
                        icon: const Icon(Icons.tune),
                        label: const Text('Gen'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: onNext,
                        icon: const Icon(Icons.casino),
                        label: const Text('Next'),
                      ),
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: onRestart,
                          icon: const Icon(Icons.replay),
                          tooltip: 'Restart',
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onPlay,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: onGenerator,
                          child: const Icon(Icons.tune),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: onNext,
                          child: const Icon(Icons.casino),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          onPressed: onBpmMinus,
                          icon: const Icon(Icons.remove),
                          tooltip: 'BPM -',
                        ),
                        Text(
                          '$bpm BPM',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          onPressed: onBpmPlus,
                          icon: const Icon(Icons.add),
                          tooltip: 'BPM +',
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------------------- Generator Sheet --------------------------- */

class _GeneratorSheet extends StatefulWidget {
  final GenrePreset genre;
  final GeneratorOverrides draft;

  final VoidCallback onApply;
  final VoidCallback onResetTuningOnly;

  const _GeneratorSheet({
    required this.genre,
    required this.draft,
    required this.onApply,
    required this.onResetTuningOnly,
  });

  @override
  State<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<_GeneratorSheet> {
  PhraseType get _phraseType =>
      widget.draft.phraseType ?? widget.genre.defaultPhraseType;

  int get _repeats => widget.draft.repeats ?? widget.genre.defaultRepeats;

  int get _chainCells =>
      widget.draft.chainCells ?? widget.genre.defaultChainCells;

  AccentRule get _accentRule =>
      widget.draft.accentRule ?? widget.genre.defaultAccentRule;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text('Generator',
                      style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onResetTuningOnly,
                    child: const Text('Reset'),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: widget.onApply,
                    child: const Text('Apply'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<PracticeMode>(
                initialValue: widget.draft.mode,
                items: PracticeMode.values
                    .map(
                      (m) => DropdownMenuItem(
                        value: m,
                        child: Text(m == PracticeMode.pad ? 'Pad' : 'Kit'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (v) {
                  if (v == null) return;
                  setState(() {
                    widget.draft.mode = v;
                    widget.draft.scope = (v == PracticeMode.pad)
                        ? LimbScope.handsOnly
                        : LimbScope.handsAndKick;
                    widget.draft.infiniteRepeat = (v == PracticeMode.pad);
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Mode',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              if (widget.draft.mode == PracticeMode.kit) ...<Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: widget.draft.kit.pieces,
                        items: <int>[2, 3, 4, 5, 6, 7]
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n-piece'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => widget.draft.kit =
                              widget.draft.kit.copyWith(pieces: v));
                        },
                        decoration: const InputDecoration(
                          labelText: 'Kit Size',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<Handedness>(
                        initialValue: widget.draft.kit.handedness,
                        items: Handedness.values
                            .map(
                              (h) => DropdownMenuItem(
                                value: h,
                                child: Text(h == Handedness.right
                                    ? 'Right-handed'
                                    : 'Left-handed'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => widget.draft.kit =
                              widget.draft.kit.copyWith(handedness: v));
                        },
                        decoration: const InputDecoration(
                          labelText: 'Handedness',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<Brass>(
                  initialValue: widget.draft.kit.brass,
                  items: Brass.values
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(switch (b) {
                            Brass.none => 'No brass',
                            Brass.hh => 'Hi-hat',
                            Brass.hhRide => 'Hi-hat + Ride',
                          }),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() =>
                        widget.draft.kit = widget.draft.kit.copyWith(brass: v));
                  },
                  decoration: const InputDecoration(
                    labelText: 'Brass',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<LimbScope>(
                  initialValue: widget.draft.scope,
                  items: LimbScope.values
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s == LimbScope.handsOnly
                              ? 'Hands only'
                              : 'Hands + Kick'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => widget.draft.scope = v);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Scope',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              DropdownButtonFormField<PhraseType>(
                initialValue: _phraseType,
                items: PhraseType.values
                    .map((v) => DropdownMenuItem(value: v, child: Text(v.name)))
                    .toList(growable: false),
                onChanged: (v) => setState(() => widget.draft.phraseType = v),
                decoration: const InputDecoration(
                  labelText: 'Phrase Type',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<AccentRule>(
                initialValue: _accentRule,
                items: _accentRuleOptions()
                    .map(
                      (AccentRule v) => DropdownMenuItem<AccentRule>(
                        value: v,
                        child: Text(_accentRuleLabel(v)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (AccentRule? v) =>
                    setState(() => widget.draft.accentRule = v),
                decoration: const InputDecoration(
                  labelText: 'Accent Rule',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _NumberField(
                      label: 'Chain Cells',
                      value: _chainCells,
                      min: 1,
                      max: 32,
                      onChanged: (v) =>
                          setState(() => widget.draft.chainCells = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumberField(
                      label: 'Repeats',
                      value: _repeats,
                      min: 1,
                      max: 16,
                      onChanged: (v) =>
                          setState(() => widget.draft.repeats = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                value: widget.draft.infiniteRepeat,
                onChanged: (v) =>
                    setState(() => widget.draft.infiniteRepeat = v),
                title: const Text('Infinity loop (∞)'),
                subtitle: const Text('Show ∞ instead of ×N (skill building)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AccentRule> _accentRuleOptions() {
    return const <AccentRule>[
      AccentRule.off(),
      AccentRule.cellStart(),
      AccentRule.everyNth(3),
      AccentRule.everyNth(4),
    ];
  }

  String _accentRuleLabel(AccentRule r) {
    return switch (r.strategy) {
      AccentStrategy.off => 'Off',
      AccentStrategy.cellStart => 'Cell start',
      AccentStrategy.everyNth => 'Every ${r.nth}',
    };
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
            tooltip: '$label -',
          ),
          Expanded(
            child: Center(
              child: Text(
                '$value',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
            tooltip: '$label +',
          ),
        ],
      ),
    );
  }
}
