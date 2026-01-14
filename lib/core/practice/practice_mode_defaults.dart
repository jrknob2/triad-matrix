// lib/core/practice/practice_mode_defaults.dart
//
// Triad Trainer — Mode & Defaults (v1)
//
// Pure configuration layer for "how it should feel".
// No UI, no controller, no side effects.
//
// This file owns:
// - Default generator knobs per mode
// - Default instrument context (Pad as startup default)
//
// IMPORTANT:
// - This file MUST NOT define PracticeModeV1 or InstrumentContextV1.
//   Those are canonical in:
//   - core/practice/practice_models.dart (PracticeModeV1)
//   - core/instrument/instrument_context_v1.dart (InstrumentContextV1)

import '../instrument/instrument_context_v1.dart';
import '../pattern/pattern_engine.dart';
import 'practice_models.dart';

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
  static const InstrumentContextV1 defaultInstrument = InstrumentContextV1.pad;

  /// Instrument context → limb scope.
  static LimbScope scopeForInstrument(InstrumentContextV1 ctx) {
    switch (ctx) {
      case InstrumentContextV1.pad:
        return LimbScope.handsOnly;
      case InstrumentContextV1.padKick:
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
