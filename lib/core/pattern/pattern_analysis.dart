// lib/core/pattern_analysis.dart
//
// Triad Trainer — Pattern Analysis (v1)
//
// Pure analysis utilities for generated patterns.
// No UI, no state, no side effects.
//
// This layer answers questions like:
// - What hand leads?
// - Is one limb dominant?
// - How dense are doubles?
// - How much kick involvement exists?
//
// Used by:
// - pattern_insight
// - future mastery / coverage
// - mode tuning & validation

import 'pattern_engine.dart';

/* -------------------------------------------------------------------------- */
/* Analysis Result                                                            */
/* -------------------------------------------------------------------------- */

class PatternAnalysis {
  final int totalNotes;

  final int rightCount;
  final int leftCount;
  final int kickCount;

  final int doubleCount;
  final int handDoubleCount;
  final int kickDoubleCount;

  final Limb? leadLimb;

  final bool isRightHandDominant;
  final bool isLeftHandDominant;

  const PatternAnalysis({
    required this.totalNotes,
    required this.rightCount,
    required this.leftCount,
    required this.kickCount,
    required this.doubleCount,
    required this.handDoubleCount,
    required this.kickDoubleCount,
    required this.leadLimb,
    required this.isRightHandDominant,
    required this.isLeftHandDominant,
  });

  bool get hasKick => kickCount > 0;
  bool get hasDoubles => doubleCount > 0;
  bool get isBalancedHands =>
      (rightCount - leftCount).abs() <= 1;
}

/* -------------------------------------------------------------------------- */
/* Analyzer                                                                   */
/* -------------------------------------------------------------------------- */

class PatternAnalyzer {
  static PatternAnalysis analyze(Pattern pattern) {
    int r = 0;
    int l = 0;
    int k = 0;

    int doubles = 0;
    int handDoubles = 0;
    int kickDoubles = 0;

    Limb? firstNote;

    final List<TriadCell> phrase = pattern.phrase;

    for (final TriadCell cell in phrase) {
      final List<Limb> limbs = cell.limbs;

      for (int i = 0; i < limbs.length; i++) {
        final Limb limb = limbs[i];

        firstNote ??= limb;

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

        // Check for doubles (adjacent only)
        if (i > 0 && limbs[i - 1] == limb) {
          doubles++;
          if (limb == Limb.k) {
            kickDoubles++;
          } else {
            handDoubles++;
          }
        }
      }
    }

    final bool rightDom = r > l + 1;
    final bool leftDom = l > r + 1;

    return PatternAnalysis(
      totalNotes: phrase.length * 3,
      rightCount: r,
      leftCount: l,
      kickCount: k,
      doubleCount: doubles,
      handDoubleCount: handDoubles,
      kickDoubleCount: kickDoubles,
      leadLimb: firstNote,
      isRightHandDominant: rightDom,
      isLeftHandDominant: leftDom,
    );
  }
}
