export const DRUM_NOTE_VALUES = Object.freeze([
  '1n',
  '2n',
  '4n',
  '8n',
  '16n',
  '32n',
]);

const DURATION_BY_VALUE = Object.freeze({
  '1n': 'w',
  '2n': 'h',
  '4n': 'q',
  '8n': '8',
  '16n': '16',
  '32n': '32',
});

export function toVexFlowDuration(value, { rest = false } = {}) {
  const duration = DURATION_BY_VALUE[value];
  if (duration == null) {
    throw new Error(`Unsupported drum note value: ${String(value)}`);
  }
  return rest ? `${duration}r` : duration;
}

export function isBeamableValue(value) {
  return value === '8n' || value === '16n' || value === '32n';
}
