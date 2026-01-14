// lib/features/practice/widgets/pattern_insight.dart
//
// Triad Trainer — Pattern Insight (v1)
//
// Purpose:
// - A short, drummer-friendly explanation of *why this pattern is valuable*.
// - Avoid theory-speak. Avoid “audition/transport” language.
// - Keep it calm: 1 headline + 1–2 bullets max.
//
// Notes:
// - This file depends on the existing pattern types from core/pattern_engine.dart.
// - If your Pattern model changes later, update the small adapter section at bottom.
//
// Usage (conceptual):
//   PatternInsightCard(
//     pattern: controller.pattern,
//     handedness: controller.handedness, // optional
//   )

import 'package:flutter/material.dart';
import '../../../core/pattern/pattern_engine.dart';

/* ------------------------------- Public API -------------------------------- */

enum HandednessV1 { right, left }

class PatternInsightCard extends StatelessWidget {
  final Pattern? pattern;

  /// Used only for “develops weak hand” style copy.
  /// If null, insights avoid weak/strong-hand claims.
  final HandednessV1? handedness;

  /// Max bullet lines to show (v1 default: 2).
  final int maxBullets;

  const PatternInsightCard({
    super.key,
    required this.pattern,
    this.handedness,
    this.maxBullets = 2,
  });

  @override
  Widget build(BuildContext context) {
    final Pattern? p = pattern;
    if (p == null) return const SizedBox.shrink();

    final PatternInsight insight = PatternInsightEngine.build(
      pattern: p,
      handedness: handedness,
      maxBullets: maxBullets,
    );

    if (insight.headline.trim().isEmpty && insight.bullets.isEmpty) {
      return const SizedBox.shrink();
    }

    final TextStyle? hStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );

    final TextStyle? bStyle = Theme.of(context).textTheme.bodySmall;

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (insight.headline.isNotEmpty) ...<Widget>[
              Text(insight.headline, style: hStyle),
              const SizedBox(height: 8),
            ],
            for (final String b in insight.bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('•  '),
                    Expanded(child: Text(b, style: bStyle)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------ Insight Model ------------------------------ */

class PatternInsight {
  final String headline;
  final List<String> bullets;

  const PatternInsight({
    required this.headline,
    required this.bullets,
  });
}

/* ----------------------------- Engine (v1) --------------------------------- */

class PatternInsightEngine {
  static PatternInsight build({
    required Pattern pattern,
    HandednessV1? handedness,
    int maxBullets = 2,
  }) {
    final _PatternStats s = _PatternStats.fromPattern(pattern);

    // Headline: keep it short and human.
    final String headline = _headlineFor(s);

    // Bullets: choose strongest 1–2 “why” lines.
    final List<String> bullets = <String>[];

    // 1) Lead / weak-hand focus (only if handedness provided)
    final String? lead = _leadBullet(s, handedness);
    if (lead != null) bullets.add(lead);

    // 2) Doubles control
    final String? doubles = _doublesBullet(s);
    if (doubles != null) bullets.add(doubles);

    // 3) Kick coordination (if kick present)
    final String? kick = _kickBullet(s);
    if (kick != null) bullets.add(kick);

    // 4) Flow / continuity (fallback)
    if (bullets.isEmpty) {
      bullets.add(_generalBullet(s));
    }

    // Enforce max
    final List<String> trimmed =
        bullets.take(maxBullets.clamp(0, 6)).toList(growable: false);

    return PatternInsight(headline: headline, bullets: trimmed);
  }

  static String _headlineFor(_PatternStats s) {
    if (s.kickNotes > 0 && s.handNotes > 0) return 'Hands + kick coordination';
    if (s.hasDoubles) return 'Control the doubles';
    if (s.startsWithL && !s.startsWithR) return 'Lead with the left';
    if (s.startsWithR && !s.startsWithL) return 'Lead with the right';
    return 'Build triad vocabulary';
  }

  static String? _leadBullet(_PatternStats s, HandednessV1? handedness) {
    if (handedness == null) return null;

    final Limb? lead = s.primaryLeadHand;
    if (lead == null) return null;

    final Limb weak = handedness == HandednessV1.right ? Limb.l : Limb.r;
    final Limb strong = handedness == HandednessV1.right ? Limb.r : Limb.l;

    if (lead == weak) {
      return 'Develops your weak hand by making it lead the phrase.';
    }
    if (lead == strong && s.leadHandBiasStrong) {
      return 'Reinforces strong-hand lead with clean, repeatable phrasing.';
    }
    return null;
  }

  static String? _doublesBullet(_PatternStats s) {
    if (!s.hasDoubles) return null;

    if (s.maxDoubleRun >= 3) {
      return 'Builds endurance and control on longer double runs.';
    }
    return 'Tightens rebound control on quick doubles without losing time.';
  }

  static String? _kickBullet(_PatternStats s) {
    if (s.kickNotes == 0) return null;

    // Keep it drummer-speak, not “coordination matrix”.
    if (s.kickDoubles > 0) {
      return 'Challenges foot consistency with kick doubles inside the cells.';
    }
    return 'Locks in foot placement so the hands can stay relaxed.';
  }

  static String _generalBullet(_PatternStats s) {
    if (s.cellsCount <= 2) return 'Short phrase—perfect for looping until it feels automatic.';
    return 'Longer phrase—practice keeping it smooth without resetting.';
  }
}

/* ------------------------------ Stats ------------------------------------- */

class _PatternStats {
  final int cellsCount;
  final int notesCount;

  final int handNotes;
  final int kickNotes;

  final bool hasDoubles;
  final int maxDoubleRun;

  final int kickDoubles;

  final bool startsWithL;
  final bool startsWithR;

  /// If set, indicates the lead hand over the phrase (R or L) based on start
  /// bias + dominance.
  final Limb? primaryLeadHand;

  /// True when lead bias is clearly strong-hand, used for copy gating.
  final bool leadHandBiasStrong;

  const _PatternStats({
    required this.cellsCount,
    required this.notesCount,
    required this.handNotes,
    required this.kickNotes,
    required this.hasDoubles,
    required this.maxDoubleRun,
    required this.kickDoubles,
    required this.startsWithL,
    required this.startsWithR,
    required this.primaryLeadHand,
    required this.leadHandBiasStrong,
  });

  static _PatternStats fromPattern(Pattern p) {
    final List<TriadCell> phrase = p.phrase;
    final int cells = phrase.length;
    final int notes = cells * 3;

    int handNotes = 0;
    int kickNotes = 0;

    bool hasDoubles = false;
    int maxDoubleRun = 1;

    int kickDoubles = 0;

    bool startsWithL = false;
    bool startsWithR = false;

    // Count lead notes over phrase (first note of each cell is often “feel”)
    int leadR = 0;
    int leadL = 0;

    // Track consecutive runs of same limb across the flattened note stream.
    Limb? prev;
    int run = 0;

    for (int ci = 0; ci < phrase.length; ci++) {
      final TriadCell c = phrase[ci];
      final List<Limb> limbs = c.limbs;

      // lead
      if (limbs.isNotEmpty) {
        if (limbs[0] == Limb.r) leadR++;
        if (limbs[0] == Limb.l) leadL++;
      }

      for (int ni = 0; ni < limbs.length; ni++) {
        final Limb limb = limbs[ni];

        if (limb == Limb.k) {
          kickNotes++;
        } else {
          handNotes++;
        }

        if (prev == null) {
          prev = limb;
          run = 1;
        } else if (prev == limb) {
          run++;
          hasDoubles = true;
          if (run > maxDoubleRun) maxDoubleRun = run;

          if (limb == Limb.k) kickDoubles++;
        } else {
          prev = limb;
          run = 1;
        }
      }
    }

    // startsWith
    if (phrase.isNotEmpty) {
      final Limb first = phrase.first.limbs.first;
      startsWithL = first == Limb.l;
      startsWithR = first == Limb.r;
    }

    // Primary lead hand heuristic:
    // - prefer the most common first-note-of-cell hand
    Limb? primary;
    bool leadBiasStrong = false;
    if (leadR > leadL) {
      primary = Limb.r;
      leadBiasStrong = (leadR - leadL) >= 2;
    } else if (leadL > leadR) {
      primary = Limb.l;
      leadBiasStrong = (leadL - leadR) >= 2;
    }

    return _PatternStats(
      cellsCount: cells,
      notesCount: notes,
      handNotes: handNotes,
      kickNotes: kickNotes,
      hasDoubles: hasDoubles,
      maxDoubleRun: maxDoubleRun,
      kickDoubles: kickDoubles,
      startsWithL: startsWithL,
      startsWithR: startsWithR,
      primaryLeadHand: primary,
      leadHandBiasStrong: leadBiasStrong,
    );
  }
}
