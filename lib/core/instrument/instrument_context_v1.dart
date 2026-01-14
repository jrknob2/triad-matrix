// lib/core/instrument_context_v1.dart
//
// Instrument + practice context domain (v1)
//
// This file defines the core, UI-agnostic domain types that describe
// how a pattern is practiced and rendered (pad vs kit, surfaces, etc).
// These are intentionally simple value objects / enums.

import 'package:flutter/foundation.dart';

/* ---------------------------- Instrument Context --------------------------- */

/// Describes the active instrument context for a pattern.
/// This is NOT audio or UI — it is semantic intent.
enum InstrumentContextV1 {
  pad,
  padKick,
  kit,
}

/* ------------------------------- Drum Surfaces ----------------------------- */

/// Logical drum surfaces used for labeling and mapping.
/// These are symbolic, not tied to MIDI/audio yet.
enum DrumSurfaceV1 {
  snare,
  hiHat,
  ride,
  tom1,
  tom2,
  floorTom,
  kick,
}

/* ------------------------------- Kit Preset -------------------------------- */

/// Describes a physical kit configuration.
/// This is intentionally lightweight and immutable.
@immutable
class KitPresetV1 {
  final int pieces; // 2..7
  final bool leftHanded;
  final bool hasRide;

  const KitPresetV1({
    required this.pieces,
    required this.leftHanded,
    required this.hasRide,
  });

  static const KitPresetV1 defaultRightHanded = KitPresetV1(
    pieces: 4,
    leftHanded: false,
    hasRide: false,
  );

  KitPresetV1 copyWith({
    int? pieces,
    bool? leftHanded,
    bool? hasRide,
  }) {
    return KitPresetV1(
      pieces: pieces ?? this.pieces,
      leftHanded: leftHanded ?? this.leftHanded,
      hasRide: hasRide ?? this.hasRide,
    );
  }

  /// Returns the available logical drum surfaces for this kit.
  List<DrumSurfaceV1> surfaces() {
    final List<DrumSurfaceV1> out = <DrumSurfaceV1>[
      DrumSurfaceV1.snare,
      DrumSurfaceV1.kick,
    ];

    if (pieces >= 3) out.add(DrumSurfaceV1.tom1);
    if (pieces >= 4) out.add(DrumSurfaceV1.floorTom);
    if (pieces >= 5) out.add(DrumSurfaceV1.tom2);
    if (pieces >= 6) out.add(DrumSurfaceV1.hiHat);
    if (pieces >= 7 || hasRide) out.add(DrumSurfaceV1.ride);

    return out;
  }
}
