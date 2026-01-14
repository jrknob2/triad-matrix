// lib/core/pattern_engine.dart
//
// Triad Trainer — PatternEngine (v1)
// -----------------------------------------------------------------------------
// Goals:
// - Single source of truth for triad generation + genre constraints.
// - Coverage mode: no repeats until all eligible triads are exhausted.
// - Genre presets = bundles of defaults + constraints (no new engine logic).
// - Pure Dart (UI, audio, and storage sit above this).
//
// Notes:
// - Notation rendering is intentionally "simple text" for v1.
// - Accents are represented as note indices within the expanded pattern.
// - Orchestration is represented as a preset id string (resolved elsewhere).
//
// Drop-in ready. No Flutter imports.
// -----------------------------------------------------------------------------

import 'dart:math' show Random;

/* --------------------------------- Limbs --------------------------------- */

enum Limb { r, l, k }

extension LimbText on Limb {
  String get glyph => switch (this) {
        Limb.r => 'R',
        Limb.l => 'L',
        Limb.k => 'K',
      };
}

/* ------------------------------ Subdivisions ------------------------------ */

enum Subdivision {
  eighths,
  triplets,
  sixteenths,
}

extension SubdivisionText on Subdivision {
  String get label => switch (this) {
        Subdivision.eighths => '8th',
        Subdivision.triplets => 'Triplet',
        Subdivision.sixteenths => '16th',
      };
}

/* ------------------------------- Phrase Type ------------------------------ */

enum PhraseType {
  singleCell, // (A → B) × N
  twoCell, // (A → B → A → B) × N
  chain, // N cells in a row
}

class PhraseTypeDefaults {
  static int defaultCellCount(PhraseType t) => switch (t) {
        PhraseType.singleCell => 2,
        PhraseType.twoCell => 4,
        PhraseType.chain => 8,
      };
}

/* ------------------------------- Triad Cell ------------------------------- */

class TriadCell {
  final Limb a;
  final Limb b;
  final Limb c;

  const TriadCell(this.a, this.b, this.c);

  List<Limb> get limbs => <Limb>[a, b, c];

  /// Canonical id used for coverage + persistence (e.g., "LRR").
  String get id => '${a.glyph}${b.glyph}${c.glyph}';

  @override
  String toString() => id;

  @override
  bool operator ==(Object other) =>
      other is TriadCell && other.a == a && other.b == b && other.c == c;

  @override
  int get hashCode => Object.hash(a, b, c);

  static TriadCell parse(String s) {
    if (s.length != 3) {
      throw ArgumentError.value(s, 's', 'TriadCell.parse expects length 3');
    }
    Limb limbAt(int i) => switch (s[i]) {
          'R' => Limb.r,
          'L' => Limb.l,
          'K' => Limb.k,
          _ => throw ArgumentError.value(
              s, 's', 'Invalid limb glyph at $i: "${s[i]}"'),
        };
    return TriadCell(limbAt(0), limbAt(1), limbAt(2));
  }
}

/* --------------------------- Constraints & Filters ------------------------- */

enum LimbScope {
  handsOnly,
  handsAndKick,
}

class GeneratorConstraints {
  final LimbScope scope;

  /// If false, excludes any triad containing doubles (RR, LL, KK).
  final bool includeDoubles;

  /// If true, requires at least one K in the triad (only meaningful in hands+k).
  final bool requireKick;

  /// If false, excludes "KKK" and any triad where the last two are KK etc.
  final bool allowKickDoubles;

  const GeneratorConstraints({
    required this.scope,
    required this.includeDoubles,
    required this.requireKick,
    required this.allowKickDoubles,
  });

  GeneratorConstraints copyWith({
    LimbScope? scope,
    bool? includeDoubles,
    bool? requireKick,
    bool? allowKickDoubles,
  }) {
    return GeneratorConstraints(
      scope: scope ?? this.scope,
      includeDoubles: includeDoubles ?? this.includeDoubles,
      requireKick: requireKick ?? this.requireKick,
      allowKickDoubles: allowKickDoubles ?? this.allowKickDoubles,
    );
  }
}

/* --------------------------------- Accents -------------------------------- */

enum AccentStrategy {
  off,
  cellStart,
  everyNth,
}

class AccentRule {
  final AccentStrategy strategy;

  /// Used only for everyNth (e.g., 3).
  final int nth;

  const AccentRule._(this.strategy, this.nth);

  const AccentRule.off() : this._(AccentStrategy.off, 0);

  const AccentRule.cellStart() : this._(AccentStrategy.cellStart, 0);

  const AccentRule.everyNth(int n) : this._(AccentStrategy.everyNth, n);

  List<int> computeAccentNoteIndices({
    required int cellsCount,
    required int notesPerCell, // triads = 3
    required int repeats,
  }) {
    final int phraseNotes = cellsCount * notesPerCell;
    final int totalNotes = phraseNotes * repeats;

    switch (strategy) {
      case AccentStrategy.off:
        return const <int>[];
      case AccentStrategy.cellStart:
        final List<int> out = <int>[];
        for (int r = 0; r < repeats; r++) {
          final int repeatBase = r * phraseNotes;
          for (int cell = 0; cell < cellsCount; cell++) {
            out.add(repeatBase + (cell * notesPerCell));
          }
        }
        return out;
      case AccentStrategy.everyNth:
        if (nth <= 1) return const <int>[];
        final List<int> out = <int>[];
        for (int i = 0; i < totalNotes; i++) {
          if ((i + 1) % nth == 0) out.add(i);
        }
        return out;
    }
  }
}

/* ------------------------------ Genre Presets ------------------------------ */

class GenrePreset {
  final String id;
  final String name;

  final Subdivision defaultSubdivision;
  final PhraseType defaultPhraseType;
  final int defaultRepeats;
  final int defaultChainCells;
  final AccentRule defaultAccentRule;
  final String defaultOrchestrationPresetId;

  final GeneratorConstraints constraints;

  const GenrePreset({
    required this.id,
    required this.name,
    required this.defaultSubdivision,
    required this.defaultPhraseType,
    required this.defaultRepeats,
    required this.defaultChainCells,
    required this.defaultAccentRule,
    required this.defaultOrchestrationPresetId,
    required this.constraints,
  });

  GenrePreset copyWith({
    String? id,
    String? name,
    Subdivision? defaultSubdivision,
    PhraseType? defaultPhraseType,
    int? defaultRepeats,
    int? defaultChainCells,
    AccentRule? defaultAccentRule,
    String? defaultOrchestrationPresetId,
    GeneratorConstraints? constraints,
  }) {
    return GenrePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultSubdivision: defaultSubdivision ?? this.defaultSubdivision,
      defaultPhraseType: defaultPhraseType ?? this.defaultPhraseType,
      defaultRepeats: defaultRepeats ?? this.defaultRepeats,
      defaultChainCells: defaultChainCells ?? this.defaultChainCells,
      defaultAccentRule: defaultAccentRule ?? this.defaultAccentRule,
      defaultOrchestrationPresetId:
          defaultOrchestrationPresetId ?? this.defaultOrchestrationPresetId,
      constraints: constraints ?? this.constraints,
    );
  }

  static Map<String, GenrePreset> builtIns() {
    return <String, GenrePreset>{
      'rock': GenrePreset(
        id: 'rock',
        name: 'Rock',
        defaultSubdivision: Subdivision.eighths,
        defaultPhraseType: PhraseType.singleCell,
        defaultRepeats: 4,
        defaultChainCells: 8,
        defaultAccentRule: const AccentRule.cellStart(),
        defaultOrchestrationPresetId: 'rock_basic',
        constraints: const GeneratorConstraints(
          scope: LimbScope.handsAndKick,
          includeDoubles: true,
          requireKick: false,
          allowKickDoubles: false,
        ),
      ),
      'funk_linear': GenrePreset(
        id: 'funk_linear',
        name: 'Funk (Linear)',
        defaultSubdivision: Subdivision.sixteenths,
        defaultPhraseType: PhraseType.chain,
        defaultRepeats: 2,
        defaultChainCells: 8,
        defaultAccentRule: const AccentRule.everyNth(3),
        defaultOrchestrationPresetId: 'funk_linear',
        constraints: const GeneratorConstraints(
          scope: LimbScope.handsAndKick,
          includeDoubles: false,
          requireKick: true,
          allowKickDoubles: false,
        ),
      ),
      'jazz_triplet': GenrePreset(
        id: 'jazz_triplet',
        name: 'Jazz (Triplet)',
        defaultSubdivision: Subdivision.triplets,
        defaultPhraseType: PhraseType.chain,
        defaultRepeats: 2,
        defaultChainCells: 6,
        defaultAccentRule: const AccentRule.cellStart(),
        defaultOrchestrationPresetId: 'jazz_ride_comp',
        constraints: const GeneratorConstraints(
          scope: LimbScope.handsAndKick,
          includeDoubles: true,
          requireKick: false,
          allowKickDoubles: false,
        ),
      ),
      'fusion': GenrePreset(
        id: 'fusion',
        name: 'Fusion',
        defaultSubdivision: Subdivision.sixteenths,
        defaultPhraseType: PhraseType.chain,
        defaultRepeats: 2,
        defaultChainCells: 12,
        defaultAccentRule: const AccentRule.everyNth(4),
        defaultOrchestrationPresetId: 'fusion_melodic_toms',
        constraints: const GeneratorConstraints(
          scope: LimbScope.handsAndKick,
          includeDoubles: true,
          requireKick: false,
          allowKickDoubles: true,
        ),
      ),
      'hands_foundation': GenrePreset(
        id: 'hands_foundation',
        name: 'Hands (Foundation)',
        defaultSubdivision: Subdivision.eighths,
        defaultPhraseType: PhraseType.singleCell,
        defaultRepeats: 4,
        defaultChainCells: 8,
        defaultAccentRule: const AccentRule.off(),
        defaultOrchestrationPresetId: 'hands_basic',
        constraints: const GeneratorConstraints(
          scope: LimbScope.handsOnly,
          includeDoubles: true,
          requireKick: false,
          allowKickDoubles: false,
        ),
      ),
    };
  }
}

/* ------------------------------ Pattern Models ----------------------------- */

class PatternRequest {
  final GenrePreset genre;

  final Subdivision? subdivision;
  final PhraseType? phraseType;
  final int? repeats;
  final int? chainCells;
  final AccentRule? accentRule;
  final String? orchestrationPresetId;

  final bool coverageMode;

  /// If set, the engine uses this seed to make generation deterministic.
  final int? seed;

  /// UI flag: show ∞ instead of ×N in the rendered output.
  /// Engine still uses repeats for expansion unless the UI chooses otherwise.
  final bool infiniteRepeat;

  const PatternRequest({
    required this.genre,
    this.subdivision,
    this.phraseType,
    this.repeats,
    this.chainCells,
    this.accentRule,
    this.orchestrationPresetId,
    required this.coverageMode,
    this.seed,
    this.infiniteRepeat = false,
  });

  Subdivision get resolvedSubdivision => subdivision ?? genre.defaultSubdivision;

  PhraseType get resolvedPhraseType => phraseType ?? genre.defaultPhraseType;

  int get resolvedRepeats => repeats ?? genre.defaultRepeats;

  int get resolvedChainCells => chainCells ?? genre.defaultChainCells;

  AccentRule get resolvedAccentRule => accentRule ?? genre.defaultAccentRule;

  String get resolvedOrchestrationPresetId =>
      orchestrationPresetId ?? genre.defaultOrchestrationPresetId;
}

class Pattern {
  final String id;
  final GenrePreset genre;
  final Subdivision subdivision;
  final PhraseType phraseType;
  final int repeats;

  /// If true, UI can display "∞" instead of "× N".
  /// MUST be non-nullable; default false to avoid runtime type errors.
  final bool infiniteRepeat;

  final List<TriadCell> phrase;

  final List<int> accentNoteIndices;

  final String orchestrationPresetId;

  const Pattern({
    required this.id,
    required this.genre,
    required this.subdivision,
    required this.phraseType,
    required this.repeats,
    required this.infiniteRepeat,
    required this.phrase,
    required this.accentNoteIndices,
    required this.orchestrationPresetId,
  });

  List<Limb> expandedLimbs() {
    final List<Limb> out = <Limb>[];
    for (int r = 0; r < repeats; r++) {
      for (final TriadCell cell in phrase) {
        out.addAll(cell.limbs);
      }
    }
    return out;
  }

  String displayText() {
    final String arrow = ' \u2192 ';
    final String phraseText = phrase.map((c) => c.id).join(arrow);
    final String rep = infiniteRepeat ? '\u221E' : '\u00D7 $repeats';
    return '$phraseText $rep';
  }
}

/* ------------------------------- Coverage State ---------------------------- */

class CoverageState {
  final Set<String> remaining;
  final String signature;

  const CoverageState({
    required this.remaining,
    required this.signature,
  });

  CoverageState copyWith({
    Set<String>? remaining,
    String? signature,
  }) {
    return CoverageState(
      remaining: remaining ?? this.remaining,
      signature: signature ?? this.signature,
    );
  }

  static CoverageState empty() => const CoverageState(
        remaining: <String>{},
        signature: '',
      );
}

/* ------------------------------ Engine Result ------------------------------ */

class PatternResult {
  final Pattern pattern;
  final CoverageState coverageState;

  const PatternResult({
    required this.pattern,
    required this.coverageState,
  });
}

/* ------------------------------- Pattern Engine ---------------------------- */

class PatternEngine {
  CoverageState _coverage;

  PatternEngine({CoverageState? initialCoverage})
      : _coverage = initialCoverage ?? CoverageState.empty();

  CoverageState get coverageState => _coverage;

  PatternResult generateNext(PatternRequest req) {
    final Random rng = (req.seed == null) ? Random() : Random(req.seed);

    final GenrePreset genre = req.genre;
    final GeneratorConstraints constraints = genre.constraints;

    final String signature = _signatureFor(constraints);

    if (_coverage.signature != signature || _coverage.remaining.isEmpty) {
      final Set<String> eligible =
          Set<String>.from(_buildEligibleTriads(constraints).map((c) => c.id));
      _coverage = CoverageState(remaining: eligible, signature: signature);
    }

    final PhraseType phraseType = req.resolvedPhraseType;
    final int repeats = _clampInt(req.resolvedRepeats, 1, 64);
    final int chainCells = _clampInt(req.resolvedChainCells, 2, 64);

    final int targetPhraseCells = switch (phraseType) {
      PhraseType.singleCell => 2,
      PhraseType.twoCell => 4,
      PhraseType.chain => chainCells,
    };

    final List<TriadCell> phrase = _generatePhrase(
      rng: rng,
      constraints: constraints,
      coverageMode: req.coverageMode,
      targetCells: targetPhraseCells,
      phraseType: phraseType,
    );

    final AccentRule accents = req.resolvedAccentRule;
    final List<int> accentNoteIndices = accents.computeAccentNoteIndices(
      cellsCount: phrase.length,
      notesPerCell: 3,
      repeats: repeats,
    );

    final String id = _derivePatternId(
      genreId: genre.id,
      phraseType: phraseType,
      subdivision: req.resolvedSubdivision,
      repeats: repeats,
      phrase: phrase,
      accentRule: accents,
      orch: req.resolvedOrchestrationPresetId,
      infinite: req.infiniteRepeat,
    );

    final Pattern pattern = Pattern(
      id: id,
      genre: genre,
      subdivision: req.resolvedSubdivision,
      phraseType: phraseType,
      repeats: repeats,
      infiniteRepeat: req.infiniteRepeat,
      phrase: phrase,
      accentNoteIndices: accentNoteIndices,
      orchestrationPresetId: req.resolvedOrchestrationPresetId,
    );

    return PatternResult(pattern: pattern, coverageState: _coverage);
  }

  /* ---------------------------- Phrase Generation ------------------------- */

  List<TriadCell> _generatePhrase({
    required Random rng,
    required GeneratorConstraints constraints,
    required bool coverageMode,
    required int targetCells,
    required PhraseType phraseType,
  }) {
    final List<TriadCell> eligibleCells = _buildEligibleTriads(constraints);

    if (eligibleCells.isEmpty) {
      return const <TriadCell>[
        TriadCell(Limb.r, Limb.l, Limb.r),
        TriadCell(Limb.l, Limb.r, Limb.l),
      ];
    }

    TriadCell pickOne(Set<String> bannedIds) {
      if (coverageMode) {
        final List<String> candidates = _coverage.remaining
            .where((id) => !bannedIds.contains(id))
            .toList(growable: false);

        if (candidates.isEmpty) {
          final Set<String> refill =
              Set<String>.from(eligibleCells.map((c) => c.id));
          _coverage = _coverage.copyWith(remaining: refill);

          final List<String> candidates2 = _coverage.remaining
              .where((id) => !bannedIds.contains(id))
              .toList(growable: false);

          final String chosenId = candidates2.isNotEmpty
              ? candidates2[rng.nextInt(candidates2.length)]
              : eligibleCells[rng.nextInt(eligibleCells.length)].id;

          _coverage.remaining.remove(chosenId);
          return TriadCell.parse(chosenId);
        }

        final String chosenId = candidates[rng.nextInt(candidates.length)];
        _coverage.remaining.remove(chosenId);
        return TriadCell.parse(chosenId);
      }

      final List<TriadCell> filtered =
          eligibleCells.where((c) => !bannedIds.contains(c.id)).toList();
      final List<TriadCell> pool = filtered.isNotEmpty ? filtered : eligibleCells;
      return pool[rng.nextInt(pool.length)];
    }

    switch (phraseType) {
      case PhraseType.singleCell: {
        final Set<String> banned = <String>{};
        final TriadCell a = pickOne(banned);
        banned.add(a.id);
        final TriadCell b = pickOne(banned);
        return <TriadCell>[a, b];
      }

      case PhraseType.twoCell: {
        final Set<String> banned = <String>{};
        final TriadCell a = pickOne(banned);
        banned.add(a.id);
        final TriadCell b = pickOne(banned);
        return <TriadCell>[a, b, a, b];
      }

      case PhraseType.chain: {
        final List<TriadCell> out = <TriadCell>[];
        final Set<String> banned = <String>{};
        for (int i = 0; i < targetCells; i++) {
          final TriadCell next = pickOne(banned);
          out.add(next);
          banned.add(next.id);
        }
        return out;
      }
    }
  }

  /* ------------------------------ Eligibility ----------------------------- */

  List<TriadCell> _buildEligibleTriads(GeneratorConstraints c) {
    final List<Limb> limbs = switch (c.scope) {
      LimbScope.handsOnly => const <Limb>[Limb.r, Limb.l],
      LimbScope.handsAndKick => const <Limb>[Limb.r, Limb.l, Limb.k],
    };

    final List<TriadCell> out = <TriadCell>[];

    for (final Limb a in limbs) {
      for (final Limb b in limbs) {
        for (final Limb d in limbs) {
          final TriadCell cell = TriadCell(a, b, d);

          if (!c.includeDoubles && _hasAnyDouble(cell)) continue;
          if (c.requireKick && !cell.limbs.contains(Limb.k)) continue;
          if (!c.allowKickDoubles && _hasKickDouble(cell)) continue;

          out.add(cell);
        }
      }
    }

    return out;
  }

  bool _hasAnyDouble(TriadCell c) {
    final List<Limb> l = c.limbs;
    return (l[0] == l[1]) || (l[1] == l[2]) || (l[0] == l[2]);
  }

  bool _hasKickDouble(TriadCell c) {
    final List<Limb> l = c.limbs;
    final bool kk01 = l[0] == Limb.k && l[1] == Limb.k;
    final bool kk12 = l[1] == Limb.k && l[2] == Limb.k;
    final bool kkk = l[0] == Limb.k && l[1] == Limb.k && l[2] == Limb.k;
    return kk01 || kk12 || kkk;
  }

  String _signatureFor(GeneratorConstraints c) {
    return [
      'scope=${c.scope.name}',
      'doubles=${c.includeDoubles ? 1 : 0}',
      'reqK=${c.requireKick ? 1 : 0}',
      'kk=${c.allowKickDoubles ? 1 : 0}',
    ].join(';');
  }

  /* --------------------------------- Utils -------------------------------- */

  int _clampInt(int v, int min, int max) {
    if (v < min) return min;
    if (v > max) return max;
    return v;
  }

  String _derivePatternId({
    required String genreId,
    required PhraseType phraseType,
    required Subdivision subdivision,
    required int repeats,
    required List<TriadCell> phrase,
    required AccentRule accentRule,
    required String orch,
    required bool infinite,
  }) {
    final String phraseText = phrase.map((c) => c.id).join('-');
    final String a = switch (accentRule.strategy) {
      AccentStrategy.off => 'acc=off',
      AccentStrategy.cellStart => 'acc=cell',
      AccentStrategy.everyNth => 'acc=n${accentRule.nth}',
    };
    return [
      genreId,
      'pt=${phraseType.name}',
      'sub=${subdivision.name}',
      infinite ? 'x=inf' : 'x=$repeats',
      a,
      'orch=$orch',
      phraseText,
    ].join('|');
  }
}
