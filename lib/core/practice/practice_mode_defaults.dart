// lib/core/practice/practice_mode_defaults.dart
//
// Triad Trainer — Mode & Defaults (v1)
//
// Pure configuration layer for "how it should feel".
// No UI, no controller, no side effects.

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

  /// Startup instrument context
  static const InstrumentContextV1 defaultInstrument =
      InstrumentContextV1.padOnly;

  /// Instrument context → limb scope.
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
        return ModeDefaultsV1(
          phraseType: PhraseType.chain,
          chainCells: 2,
          repeats: 6,
          accentRule: AccentRule.cellStart(),
          infiniteRepeat: true,
        );

      case PracticeModeV1.flow:
        return ModeDefaultsV1(
          phraseType: PhraseType.chain,
          chainCells: 4,
          repeats: 2,
          accentRule: AccentRule.everyNth(3),
          infiniteRepeat: false,
        );
    }
  }
}
