enum StickingCue {
  left('L'),
  right('R'),
  both('B'),
  flamLeft('FL'),
  flamRight('FR');

  final String protocolValue;

  const StickingCue(this.protocolValue);
}

StickingCue? stickingCueFromText(String value, {bool flam = false}) {
  final String normalized = value.trim().toUpperCase().replaceAll(
    RegExp(r'\s+'),
    '',
  );
  if (normalized.isEmpty) return null;
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
  if (normalized == 'L') return StickingCue.left;
  if (normalized == 'R') return StickingCue.right;
  return null;
}
