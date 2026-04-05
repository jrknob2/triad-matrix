// lib/core/pattern/pattern_engine.dart
//
// Triad Trainer — Pattern Engine (v1)
//
// Purpose:
// - Single source of truth for pattern generation primitives + request contract.
// - Supports deterministic generation via seed.
// - Supports locking the FIRST triad cell via PatternRequest.startCellId
//   (this is what enables true matrix traversal via Prev/Next).
//
// Notes:
// - This is intentionally small + explicit for v1.
// - “Smarter” behaviors (search, multi-phrase composition rules, pedagogy tracks)
//   can layer on top by driving PatternRequest.

import 'dart:math';

import 'package:flutter/foundation.dart';

/* -------------------------------------------------------------------------- */
/* Core enums                                                                  */
/* -------------------------------------------------------------------------- */

enum Limb { r, l, k }

enum LimbScope {
  handsOnly,
  handsAndKick,
}

enum PhraseType {
  chain,
}

/* -------------------------------------------------------------------------- */
/* Accent rules                                                                */
/* -------------------------------------------------------------------------- */

@immutable
class AccentRule {
  final String kind;
  final int? n;

  const AccentRule._(this.kind, this.n);

  factory AccentRule.cellStart() => const AccentRule._('cellStart', null);

  factory AccentRule.everyNth(int n) {
    if (n <= 0) throw ArgumentError.value(n, 'n', 'must be > 0');
    return AccentRule._('everyNth', n);
  }

  List<int> computeAccentNoteIndices({
    required int totalNotes,
  }) {
    if (totalNotes <= 0) return const <int>[];

    switch (kind) {
      case 'cellStart':
        // Accent the first note of every triad cell (0,3,6,...).
        final List<int> out = <int>[];
        for (int i = 0; i < totalNotes; i += 3) {
          out.add(i);
        }
        return out;

      case 'everyNth':
        final int step = n ?? 0;
        if (step <= 0) return const <int>[];
        final List<int> out = <int>[];
        for (int i = 0; i < totalNotes; i += step) {
          out.add(i);
        }
        return out;

      default:
        return const <int>[];
    }
  }
}

/* -------------------------------------------------------------------------- */
/* Generator constraints + presets                                             */
/* -------------------------------------------------------------------------- */

@immutable
class GeneratorConstraints {
  final LimbScope scope;

  /// If true, we force at least one kick note somewhere in the phrase.
  final bool requireKick;

  const GeneratorConstraints({
    required this.scope,
    required this.requireKick,
  });

  GeneratorConstraints copyWith({
    LimbScope? scope,
    bool? requireKick,
  }) {
    return GeneratorConstraints(
      scope: scope ?? this.scope,
      requireKick: requireKick ?? this.requireKick,
    );
  }

  static const GeneratorConstraints v1Default = GeneratorConstraints(
    scope: LimbScope.handsOnly,
    requireKick: false,
  );
}

@immutable
class GenrePreset {
  final String id;
  final String name;
  final GeneratorConstraints constraints;

  const GenrePreset({
    required this.id,
    required this.name,
    required this.constraints,
  });

  GenrePreset copyWith({
    String? id,
    String? name,
    GeneratorConstraints? constraints,
  }) {
    return GenrePreset(
      id: id ?? this.id,
      name: name ?? this.name,
      constraints: constraints ?? this.constraints,
    );
  }

  /// v1: small built-in set (enough to keep API stable).
  static Map<String, GenrePreset> builtIns() {
    const GenrePreset v1 = GenrePreset(
      id: 'v1',
      name: 'V1',
      constraints: GeneratorConstraints.v1Default,
    );
    return <String, GenrePreset>{v1.id: v1};
  }
}

/* -------------------------------------------------------------------------- */
/* Pattern model                                                               */
/* -------------------------------------------------------------------------- */

@immutable
class TriadCell {
  final String id; // e.g., "RLR"
  final List<Limb> limbs; // length 3

  const TriadCell({
    required this.id,
    required this.limbs,
  });
}

@immutable
class Pattern {
  final List<TriadCell> phrase;
  final int repeats;
  final bool infiniteRepeat;

  /// Note indices (0..phrase.length*3-1) that are accented.
  final List<int> accentNoteIndices;

  const Pattern({
    required this.phrase,
    required this.repeats,
    required this.infiniteRepeat,
    required this.accentNoteIndices,
  });
}

@immutable
class PatternResult {
  final Pattern pattern;

  const PatternResult({required this.pattern});
}

/* -------------------------------------------------------------------------- */
/* Request                                                                     */
/* -------------------------------------------------------------------------- */

@immutable
class PatternRequest {
  final GenrePreset genre;

  /// Kept for contract stability, but v1 doesn’t implement “exhaustive pool”.
  final bool coverageMode;

  final int seed;

  final PhraseType phraseType;

  /// Finite repeats (ignored if infiniteRepeat == true).
  final int repeats;

  /// Only meaningful for PhraseType.chain.
  final int chainCells;

  final AccentRule accentRule;

  final bool infiniteRepeat;

  /// NEW (v1.1): lock the FIRST triad cell by its id (e.g., "RLR").
  /// This enables true triad-matrix traversal via Prev/Next.
  final String? startCellId;

  const PatternRequest({
    required this.genre,
    required this.coverageMode,
    required this.seed,
    required this.phraseType,
    required this.repeats,
    required this.chainCells,
    required this.accentRule,
    required this.infiniteRepeat,
    this.startCellId,
  });
}

/* -------------------------------------------------------------------------- */
/* Engine                                                                      */
/* -------------------------------------------------------------------------- */

class PatternEngine {
  PatternResult generateNext(PatternRequest req) {
    final Random rng = Random(req.seed);

    final GeneratorConstraints c = req.genre.constraints;

    final List<String> pool = _eligibleTriadIds(scope: c.scope);

    final int cells = max(1, req.chainCells);

    // Build phrase cells.
    final List<TriadCell> phrase = <TriadCell>[];

    // If startCellId provided, use it as the first cell.
    if (req.startCellId != null) {
      final String id = req.startCellId!.trim().toUpperCase();
      phrase.add(_cellFromId(id, scope: c.scope));
    }

    while (phrase.length < cells) {
      final String id = pool[rng.nextInt(pool.length)];
      phrase.add(_cellFromId(id, scope: c.scope));
    }

    // Enforce “requireKick” at phrase level (at least one K note somewhere).
    if (c.requireKick && !_phraseHasKick(phrase)) {
      // Replace the LAST cell with a kick-containing one.
      final List<String> kickPool =
          pool.where((id) => id.contains('K')).toList(growable: false);
      if (kickPool.isNotEmpty) {
        final String id = kickPool[rng.nextInt(kickPool.length)];
        phrase[phrase.length - 1] = _cellFromId(id, scope: c.scope);
      }
    }

    final int totalNotes = phrase.length * 3;

    final List<int> accents = req.accentRule.computeAccentNoteIndices(
      totalNotes: totalNotes,
    );

    final Pattern p = Pattern(
      phrase: phrase,
      repeats: req.repeats <= 0 ? 1 : req.repeats,
      infiniteRepeat: req.infiniteRepeat,
      accentNoteIndices: accents,
    );

    return PatternResult(pattern: p);
  }

  /* ---------------------------- Helpers ---------------------------------- */

  bool _phraseHasKick(List<TriadCell> phrase) {
    for (final TriadCell c in phrase) {
      for (final Limb l in c.limbs) {
        if (l == Limb.k) return true;
      }
    }
    return false;
  }

  List<String> _eligibleTriadIds({required LimbScope scope}) {
    const List<String> hands = <String>['R', 'L'];
    const List<String> all = <String>['R', 'L', 'K'];

    final List<String> alphabet = scope == LimbScope.handsOnly ? hands : all;

    final List<String> out = <String>[];
    for (final String a in alphabet) {
      for (final String b in alphabet) {
        for (final String c in alphabet) {
          out.add('$a$b$c');
        }
      }
    }
    // Stable ordering helps search + deterministic traversal later.
    out.sort();
    return out;
  }

  TriadCell _cellFromId(String id, {required LimbScope scope}) {
    final String trimmed = id.trim().toUpperCase();

    if (trimmed.length != 3) {
      throw ArgumentError.value(
        id,
        'startCellId',
        'must be exactly 3 chars like "RLR" or "KRK"',
      );
    }

    final List<Limb> limbs = <Limb>[
      _limbFromChar(trimmed[0]),
      _limbFromChar(trimmed[1]),
      _limbFromChar(trimmed[2]),
    ];

    if (scope == LimbScope.handsOnly && limbs.any((l) => l == Limb.k)) {
      throw ArgumentError.value(
        id,
        'startCellId',
        'cannot include K when scope is handsOnly',
      );
    }

    return TriadCell(id: trimmed, limbs: limbs);
  }

  Limb _limbFromChar(String ch) {
    return switch (ch) {
      'R' => Limb.r,
      'L' => Limb.l,
      'K' => Limb.k,
      _ => throw ArgumentError.value(
          ch,
          'triadId',
          'must contain only R/L/K',
        ),
    };
  }
}
