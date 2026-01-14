// lib/core/pattern_benefits.dart
//
// Triad Trainer — Pattern Benefits (v1)
//
// Purpose:
// - Produce a short, drummer-first “why this is valuable” line for a given pattern.
// - Pure functions only (no Flutter, no state).
//
// This file intentionally does NOT depend on PatternAnalysis' API shape,
// because that module has been in flux. We compute the tiny stats we need
// directly from the Pattern + TriadCells, so this stays stable.

import 'pattern_engine.dart';

class PatternBenefits {
  const PatternBenefits._();

  /// Returns a single sentence (or short phrase) explaining the value of practicing this pattern.
  ///
  /// Notes:
  /// - If [nonDominantHandLabel] is provided (e.g. "left" / "right"), we may call out
  ///   the non-dominant hand when the phrase is clearly imbalanced.
  static String forPattern({
    required Pattern pattern,
    String? nonDominantHandLabel,
  }) {
    final _Stats s = _Stats.fromPattern(pattern);

    final List<_Candidate?> raw = <_Candidate?>[
      _weakHandCandidate(s, nonDominantHandLabel: nonDominantHandLabel),
      _alternationCandidate(s),
      _doublesCandidate(s),
      _kickIntegrationCandidate(s),
      _symmetryCandidate(s),
      _controlCandidate(s),
    ];

    final List<_Candidate> cands =
        raw.whereType<_Candidate>().toList(growable: false);

    if (cands.isEmpty) return 'Purpose: clean triad motion and control.';

    cands.sort((a, b) => b.score.compareTo(a.score));
    return cands.first.text;
  }

  static _Candidate? _weakHandCandidate(
    _Stats s, {
    required String? nonDominantHandLabel,
  }) {
    if (nonDominantHandLabel == null || nonDominantHandLabel.trim().isEmpty) {
      return null;
    }

    final int totalHands = s.countR + s.countL;
    if (totalHands < 6) return null;

    final int maxHand = s.countR > s.countL ? s.countR : s.countL;
    final int minHand = s.countR > s.countL ? s.countL : s.countR;

    // If imbalance is meaningful, make it a "strength/endurance" focus.
    if (maxHand >= minHand + 3) {
      return _Candidate(
        score: 80,
        text:
            'Purpose: build endurance and control in your $nonDominantHandLabel hand.',
      );
    }

    return null;
  }

  static _Candidate? _alternationCandidate(_Stats s) {
    // Lots of hand switching and short same-hand runs -> flow/timing.
    if (s.handSwitchCount >= 4 && s.longestSameHandRun <= 2) {
      return const _Candidate(
        score: 70,
        text: 'Purpose: tighten hand-to-hand alternation and timing.',
      );
    }
    return null;
  }

  static _Candidate? _doublesCandidate(_Stats s) {
    if (s.hasAnyDouble) {
      return const _Candidate(
        score: 65,
        text: 'Purpose: clean up doubles without losing spacing.',
      );
    }
    return null;
  }

  static _Candidate? _kickIntegrationCandidate(_Stats s) {
    if (s.hasKick) {
      return const _Candidate(
        score: 60,
        text: 'Purpose: lock kick placement into the hand motion.',
      );
    }
    return null;
  }

  static _Candidate? _symmetryCandidate(_Stats s) {
    if (s.countR == s.countL && s.countR >= 3) {
      return const _Candidate(
        score: 55,
        text: 'Purpose: balance both hands and keep strokes even.',
      );
    }
    return null;
  }

  static _Candidate _controlCandidate(_Stats s) {
    // Safe fallback, but still specific-ish.
    return const _Candidate(
      score: 10,
      text: 'Purpose: clean triad motion and control.',
    );
  }
}

/* ------------------------------ Internal stats ----------------------------- */

class _Stats {
  final int countR;
  final int countL;
  final int countK;

  final bool hasAnyDouble;
  final bool hasKick;

  final int handSwitchCount;
  final int longestSameHandRun;

  const _Stats({
    required this.countR,
    required this.countL,
    required this.countK,
    required this.hasAnyDouble,
    required this.hasKick,
    required this.handSwitchCount,
    required this.longestSameHandRun,
  });

  static _Stats fromPattern(Pattern p) {
    int r = 0;
    int l = 0;
    int k = 0;

    bool anyDouble = false;

    // Track hand switching across the full phrase (ignoring arrows/spaces; this is limb order).
    int switches = 0;
    int longestRun = 1;

    Limb? prevHand; // only R/L
    int curRun = 0;

    for (final TriadCell cell in p.phrase) {
      // Detect doubles within a cell.
      if (cell.limbs[0] == cell.limbs[1] ||
          cell.limbs[1] == cell.limbs[2] ||
          cell.limbs[0] == cell.limbs[2]) {
        anyDouble = true;
      }

      for (final Limb limb in cell.limbs) {
        switch (limb) {
          case Limb.r:
            r++;
            break;
          case Limb.l:
            l++;
            break;
          case Limb.k:
            k++;
            break;
        }

        // Hand switching stats (R/L only).
        if (limb == Limb.r || limb == Limb.l) {
          if (prevHand == null) {
            prevHand = limb;
            curRun = 1;
            if (longestRun < curRun) longestRun = curRun;
          } else {
            if (limb != prevHand) {
              switches++;
              prevHand = limb;
              curRun = 1;
              if (longestRun < curRun) longestRun = curRun;
            } else {
              curRun++;
              if (longestRun < curRun) longestRun = curRun;
            }
          }
        }
      }
    }

    return _Stats(
      countR: r,
      countL: l,
      countK: k,
      hasAnyDouble: anyDouble,
      hasKick: k > 0,
      handSwitchCount: switches,
      longestSameHandRun: longestRun,
    );
  }
}

class _Candidate {
  final int score;
  final String text;

  const _Candidate({
    required this.score,
    required this.text,
  });
}
