enum LedStrokeHand { left, right }

enum LedStrokeArticulation { normal, ghost, accent }

class LedStroke {
  final LedStrokeHand hand;
  final LedStrokeArticulation articulation;

  const LedStroke({
    required this.hand,
    this.articulation = LedStrokeArticulation.normal,
  });

  String get protocolValue {
    final String handLabel = hand == LedStrokeHand.left ? 'L' : 'R';
    return switch (articulation) {
      LedStrokeArticulation.normal => handLabel,
      LedStrokeArticulation.ghost => '($handLabel)',
      LedStrokeArticulation.accent => '^$handLabel',
    };
  }

  @override
  bool operator ==(Object other) {
    return other is LedStroke &&
        other.hand == hand &&
        other.articulation == articulation;
  }

  @override
  int get hashCode => Object.hash(hand, articulation);
}

class StickingCue {
  static const StickingCue left = StickingCue._(<LedStroke>[
    LedStroke(hand: LedStrokeHand.left),
  ]);
  static const StickingCue right = StickingCue._(<LedStroke>[
    LedStroke(hand: LedStrokeHand.right),
  ]);
  static const StickingCue ghostLeft = StickingCue._(<LedStroke>[
    LedStroke(
      hand: LedStrokeHand.left,
      articulation: LedStrokeArticulation.ghost,
    ),
  ]);
  static const StickingCue ghostRight = StickingCue._(<LedStroke>[
    LedStroke(
      hand: LedStrokeHand.right,
      articulation: LedStrokeArticulation.ghost,
    ),
  ]);
  static const StickingCue accentLeft = StickingCue._(<LedStroke>[
    LedStroke(
      hand: LedStrokeHand.left,
      articulation: LedStrokeArticulation.accent,
    ),
  ]);
  static const StickingCue accentRight = StickingCue._(<LedStroke>[
    LedStroke(
      hand: LedStrokeHand.right,
      articulation: LedStrokeArticulation.accent,
    ),
  ]);

  static const StickingCue leftRight = StickingCue._(<LedStroke>[
    LedStroke(hand: LedStrokeHand.left),
    LedStroke(hand: LedStrokeHand.right),
  ]);

  static const StickingCue ghostLeftRight = StickingCue._(<LedStroke>[
    LedStroke(
      hand: LedStrokeHand.left,
      articulation: LedStrokeArticulation.ghost,
    ),
    LedStroke(hand: LedStrokeHand.right),
  ]);

  static const StickingCue ghostRightLeft = StickingCue._(<LedStroke>[
    LedStroke(
      hand: LedStrokeHand.right,
      articulation: LedStrokeArticulation.ghost,
    ),
    LedStroke(hand: LedStrokeHand.left),
  ]);

  final List<LedStroke> strokes;

  const StickingCue._(this.strokes);

  factory StickingCue.fromStrokes(Iterable<LedStroke> strokes) {
    return StickingCue._(List<LedStroke>.unmodifiable(strokes));
  }

  String get protocolValue {
    return strokes.map((LedStroke stroke) => stroke.protocolValue).join();
  }

  StickingCue merge(StickingCue other) {
    if (this == other) return this;
    return StickingCue.fromStrokes(<LedStroke>[...strokes, ...other.strokes]);
  }

  @override
  bool operator ==(Object other) {
    if (other is! StickingCue || other.strokes.length != strokes.length) {
      return false;
    }
    for (int index = 0; index < strokes.length; index += 1) {
      if (other.strokes[index] != strokes[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(strokes);
}

StickingCue? stickingCueFromText(
  String value, {
  bool flam = false,
  bool ghost = false,
}) {
  final String normalized = value.trim().toUpperCase().replaceAll(
    RegExp(r'\s+'),
    '',
  );
  if (normalized.isEmpty) return null;
  if (flam && normalized == 'L') return StickingCue.ghostRightLeft;
  if (flam && normalized == 'R') return StickingCue.ghostLeftRight;
  if (normalized == 'L') {
    return ghost ? StickingCue.ghostLeft : StickingCue.left;
  }
  if (normalized == 'R') {
    return ghost ? StickingCue.ghostRight : StickingCue.right;
  }
  final StickingCue? parsed = _parseSemanticStrokeSequence(normalized);
  if (parsed != null) return parsed;
  return null;
}

StickingCue? _parseSemanticStrokeSequence(String value) {
  final List<LedStroke> strokes = <LedStroke>[];
  for (int index = 0; index < value.length;) {
    final String char = value[index];
    if (char == '^') {
      if (index + 1 >= value.length) return null;
      final LedStrokeHand? hand = _ledStrokeHandFromText(value[index + 1]);
      if (hand == null) return null;
      strokes.add(
        LedStroke(hand: hand, articulation: LedStrokeArticulation.accent),
      );
      index += 2;
      continue;
    }
    if (char == '(') {
      if (index + 2 >= value.length || value[index + 2] != ')') return null;
      final LedStrokeHand? hand = _ledStrokeHandFromText(value[index + 1]);
      if (hand == null) return null;
      strokes.add(
        LedStroke(hand: hand, articulation: LedStrokeArticulation.ghost),
      );
      index += 3;
      continue;
    }
    final LedStrokeHand? hand = _ledStrokeHandFromText(char);
    if (hand == null) return null;
    strokes.add(LedStroke(hand: hand));
    index += 1;
  }
  if (strokes.isEmpty) return null;
  return StickingCue.fromStrokes(strokes);
}

LedStrokeHand? _ledStrokeHandFromText(String value) {
  return switch (value.toUpperCase()) {
    'L' => LedStrokeHand.left,
    'R' => LedStrokeHand.right,
    _ => null,
  };
}
