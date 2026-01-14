// lib/core/practice_mode_defaults.dart
//
// Triad Trainer — Mode & Defaults (v1)
//
// Pure configuration layer for "how it should feel".
// No UI, no controller, no side effects.
//
// This file owns:
// - PracticeModeV1 (Training / Flow)
// - Default generator knobs per mode
// - Default instrument context (Pad as startup default)

import '../pattern/pattern_engine.dart';

/* -------------------------------------------------------------------------- */
/* Enums                                                                      */
/* -------------------------------------------------------------------------- */

enum PracticeModeV1 {
  training,
  flow,
}

enum InstrumentContextV1 {
  padOnly,
  padPlusKick,
  kit,
}

/* -------------------------------------------------------------------------- */
/* Defaults Model                                                              */
/* -------------------------------------------------------------------------- */

class ModeDefaultsV1 {
  final PhraseType phraseType;
  final int repeats;
  final int chainCells;
  final AccentRule accentRule;
  final bool infiniteRepeat;

  const ModeDefaultsV1({
    required this.phraseType,
    required this.repeats,
    required this.chainCells,
    required this.accentRule,
    required this.infiniteRepeat,
  });
}

/* -------------------------------------------------------------------------- */
/* Public API                                                                  */
/* -------------------------------------------------------------------------- */

class PracticeDefaultsV1 {
  /// Startup defaults (v1 intent)
  static const PracticeModeV1 defaultMode = PracticeModeV1.training;

  /// Startup instrument context (per your direction)
  static const InstrumentContextV1 defaultInstrument =
      InstrumentContextV1.padOnly;

  /// Instrument context → limb scope.
  /// (Scope can still be overridden later in Kit if you decide, but v1 keeps it simple.)
  static LimbScope scopeForInstrument(InstrumentContextV1 ctx) {
    switch (ctx) {
      case InstrumentContextV1.padOnly:
        return LimbScope.handsOnly;
      case InstrumentContextV1.padPlusKick:
        return LimbScope.handsAndKick;
      case InstrumentContextV1.kit:
        return LimbScope.handsAndKick;
    }
  }

  /// Locked v1 defaults per mode.
  static ModeDefaultsV1 forMode(PracticeModeV1 mode) {
    switch (mode) {
      case PracticeModeV1.training:
        return const ModeDefaultsV1(
          // shorter, more repeatable
          phraseType: PhraseType.chain,
          chainCells: 2,
          repeats: 6,
          // accents should make phrasing obvious, not busy
          accentRule: AccentRule.cellStart(),
          infiniteRepeat: true,
        );

      case PracticeModeV1.flow:
        return const ModeDefaultsV1(
          // longer, more musical continuity
          phraseType: PhraseType.chain,
          chainCells: 4,
          repeats: 2,
          // phrase-ish accents; keep it sparse
          accentRule: AccentRule.everyNth(3),
          infiniteRepeat: false,
        );
    }
  }
}
