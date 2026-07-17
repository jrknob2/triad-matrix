enum StickingCue {
  left('L'),
  right('R'),
  // The app keeps ghost sticking semantically distinct, but the current ESP32
  // protocol only accepts L/R/B/FL/FR sticking tokens. Ghost cues therefore
  // serialize to their supported hand token until firmware exposes dim tokens.
  ghostLeft('L'),
  ghostRight('R'),
  both('B'),
  flamLeft('FL'),
  flamRight('FR');

  final String protocolValue;

  const StickingCue(this.protocolValue);
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
  if (normalized == '(L)') return StickingCue.ghostLeft;
  if (normalized == '(R)') return StickingCue.ghostRight;
  if (normalized == '(R)L' || normalized == 'FL') {
    return StickingCue.flamLeft;
  }
  if (normalized == '(L)R' || normalized == 'FR') {
    return StickingCue.flamRight;
  }
  if (flam && normalized == 'L') return StickingCue.flamLeft;
  if (flam && normalized == 'R') return StickingCue.flamRight;
  if (normalized == 'B' || normalized == 'LR' || normalized == 'RL') {
    return StickingCue.both;
  }
  if (normalized == 'L') {
    return ghost ? StickingCue.ghostLeft : StickingCue.left;
  }
  if (normalized == 'R') {
    return ghost ? StickingCue.ghostRight : StickingCue.right;
  }
  return null;
}
