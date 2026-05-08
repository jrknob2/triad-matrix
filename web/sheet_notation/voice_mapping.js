export const DRUM_VOICE_IDS = Object.freeze([
  'hihat',
  'ride',
  'crash',
  'snare',
  'tom1',
  'tom2',
  'floorTom',
  'kick',
]);

export const DRUM_VOICE_MAP = Object.freeze({
  crash: Object.freeze({
    key: 'a/5',
    notehead: 'x',
    stemDirection: 1,
  }),
  ride: Object.freeze({
    key: 'g/5',
    notehead: 'x',
    stemDirection: 1,
  }),
  hihat: Object.freeze({
    key: 'f/5',
    notehead: 'x',
    stemDirection: 1,
  }),
  tom1: Object.freeze({
    key: 'e/5',
    notehead: 'normal',
    stemDirection: 1,
  }),
  snare: Object.freeze({
    key: 'c/5',
    notehead: 'normal',
    stemDirection: -1,
  }),
  tom2: Object.freeze({
    key: 'a/4',
    notehead: 'normal',
    stemDirection: 1,
  }),
  floorTom: Object.freeze({
    key: 'g/4',
    notehead: 'normal',
    stemDirection: -1,
  }),
  kick: Object.freeze({
    key: 'f/4',
    notehead: 'normal',
    stemDirection: -1,
  }),
});

export function voiceMappingFor(voiceId) {
  const mapping = DRUM_VOICE_MAP[voiceId];
  if (mapping == null) {
    throw new Error(`Unknown drum voice: ${String(voiceId)}`);
  }
  return mapping;
}
