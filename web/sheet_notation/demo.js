import { renderDrumNotationSvg } from './renderer.js';

export const DEFAULT_DEMO_PATTERN =
  '^R^L^R(L)(L)K^R^L^R(L)(L)FTHH^CF';

export function demoDocument() {
  const wrappedMeasure = [
    { voices: ['snare'], sticking: 'R', accent: true },
    { voices: ['snare'], sticking: 'L', accent: true },
    { voices: ['snare'], sticking: 'R', accent: true },
    { voices: ['snare'], sticking: 'L', ghost: true },
    { voices: ['snare'], sticking: 'L', ghost: true },
    { voices: ['kick'], sticking: 'K' },
    { voices: ['tom1'], sticking: 'R', accent: true },
    { voices: ['tom1'], sticking: 'L', accent: true },
    { voices: ['tom2'], sticking: 'R', accent: true },
    { voices: ['snare'], sticking: 'L', ghost: true },
    { voices: ['snare'], sticking: 'L', ghost: true },
    { voices: ['floorTom'], sticking: 'FT' },
    { voices: ['hihat'], sticking: 'HH' },
    { voices: ['crash'], sticking: 'C', accent: true },
    { voices: ['snare'], sticking: 'F', flam: true },
  ];
  return {
    subdivision: '8n',
    measures: [
      { notes: wrappedMeasure },
      { notes: wrappedMeasure },
    ],
  };
}

export function renderDemoDrumNotationSvg(options = {}) {
  return renderDrumNotationSvg(demoDocument(), options);
}

export function documentFromPattern(pattern, options = {}) {
  return {
    subdivision: options.subdivision ?? '8n',
    measures: [{ notes: notesFromPattern(pattern) }],
  };
}

export function patternFromNotes(notes) {
  return notes.map(patternTokenForNote).join('');
}

export function notesFromPattern(pattern, options = {}) {
  const notes = [];
  let accent = false;
  const defaultValue = options.value;
  for (let index = 0; index < pattern.length; index += 1) {
    const char = pattern[index];
    if (/\s/.test(char)) continue;
    if (char === '^') {
      accent = true;
      continue;
    }
    if (char === '(') {
      const close = pattern.indexOf(')', index + 1);
      if (close < 0) throw new Error('Unclosed ghost note group.');
      const symbol = pattern.slice(index + 1, close).trim();
      if (symbol.length === 0) throw new Error('Empty ghost note group.');
      notes.push(noteFromToken(symbol, { accent, ghost: true, value: defaultValue }));
      accent = false;
      index = close;
      continue;
    }
    if (char === '[') {
      const close = pattern.indexOf(']', index + 1);
      if (close < 0) throw new Error('Unclosed duration override group.');
      const body = pattern.slice(index + 1, close);
      const separator = body.indexOf(':');
      if (separator < 0) {
        throw new Error('Duration override must use [duration: pattern].');
      }
      const value = durationValueFromLabel(body.slice(0, separator).trim());
      notes.push(...notesFromPattern(body.slice(separator + 1), { value }));
      accent = false;
      index = close;
      continue;
    }
    const multi = multiCharacterTokenAt(pattern, index);
    if (multi != null) {
      notes.push(noteFromToken(multi, { accent, value: defaultValue }));
      accent = false;
      index += multi.length - 1;
      continue;
    }
    notes.push(noteFromToken(char, { accent, value: defaultValue }));
    accent = false;
  }
  return notes;
}

function durationValueFromLabel(label) {
  const normalized = label.endsWith('n') ? label : `${label}n`;
  if (!['1n', '2n', '4n', '8n', '16n', '32n'].includes(normalized)) {
    throw new Error(`Unsupported duration override: ${label}`);
  }
  return normalized;
}

function multiCharacterTokenAt(pattern, index) {
  const nextTwo = pattern.slice(index, index + 2).toUpperCase();
  if (nextTwo === 'FT' || nextTwo === 'HH') return nextTwo;
  return null;
}

function noteFromToken(symbol, options = {}) {
  const token = symbol.toUpperCase();
  const common = {
    sticking: token,
    accent: options.accent === true,
    ghost: options.ghost === true,
  };
  if (options.value != null) common.value = options.value;
  switch (token) {
    case 'R':
    case 'L':
      return { ...common, voices: ['snare'] };
    case 'K':
      return { ...common, voices: ['kick'] };
    case 'F':
      return { ...common, voices: ['snare'], flam: true };
    case 'B':
      return { ...common, voices: ['hihat', 'snare'] };
    case 'X':
    case 'C':
      return { ...common, sticking: token === 'X' ? 'X' : 'C', voices: ['crash'] };
    case 'HH':
      return { ...common, voices: ['hihat'] };
    case 'FT':
      return { ...common, voices: ['floorTom'] };
    case '_':
    case '-':
      return { value: options.value, rest: true, sticking: '-' };
    default:
      throw new Error(`Unsupported pattern token: ${symbol}`);
  }
}

function patternTokenForNote(note) {
  const base = basePatternTokenForNote(note);
  const marked = note.ghost ? `(${base})` : base;
  return note.accent ? `^${marked}` : marked;
}

function basePatternTokenForNote(note) {
  if (note.rest) return '-';
  if (note.flam) return 'F';
  const voices = note.voices ?? [];
  if (voices.includes('kick')) return 'K';
  if (voices.includes('floorTom')) return 'FT';
  if (voices.includes('hihat') && voices.includes('snare')) return 'B';
  if (voices.includes('hihat')) return 'HH';
  if (voices.includes('crash')) return note.sticking === 'X' ? 'X' : 'C';
  return note.sticking ?? 'R';
}
