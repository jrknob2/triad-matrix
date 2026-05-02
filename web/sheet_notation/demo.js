import { renderDrumNotationSvg } from './renderer.js';

export const DEFAULT_DEMO_PATTERN =
  '^R^L^R(L)(L)K^R^L^R(L)(L)FTHH^CF';

export function demoDocument() {
  const wrappedMeasure = [
    { value: '16n', voices: ['snare'], sticking: 'R', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'L', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'R', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'L', ghost: true },
    { value: '16n', voices: ['snare'], sticking: 'L', ghost: true },
    { value: '16n', voices: ['kick'], sticking: 'K' },
    { value: '16n', voices: ['tom1'], sticking: 'R', accent: true },
    { value: '16n', voices: ['tom1'], sticking: 'L', accent: true },
    { value: '16n', voices: ['tom2'], sticking: 'R', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'L', ghost: true },
    { value: '16n', voices: ['snare'], sticking: 'L', ghost: true },
    { value: '16n', voices: ['floorTom'], sticking: 'FT' },
    { value: '16n', voices: ['hihat'], sticking: 'HH' },
    { value: '16n', voices: ['crash'], sticking: 'C', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'F', flam: true },
  ];
  return {
    measures: [
      { notes: wrappedMeasure },
      { notes: wrappedMeasure },
    ],
  };
}

export function renderDemoDrumNotationSvg(options = {}) {
  return renderDrumNotationSvg(demoDocument(), options);
}

export function documentFromPattern(pattern) {
  return {
    measures: [{ notes: notesFromPattern(pattern) }],
  };
}

export function patternFromNotes(notes) {
  return notes.map(patternTokenForNote).join('');
}

export function notesFromPattern(pattern) {
  const notes = [];
  let accent = false;
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
      notes.push(noteFromToken(symbol, { accent, ghost: true }));
      accent = false;
      index = close;
      continue;
    }
    const multi = multiCharacterTokenAt(pattern, index);
    if (multi != null) {
      notes.push(noteFromToken(multi, { accent }));
      accent = false;
      index += multi.length - 1;
      continue;
    }
    notes.push(noteFromToken(char, { accent }));
    accent = false;
  }
  return notes;
}

function multiCharacterTokenAt(pattern, index) {
  const nextTwo = pattern.slice(index, index + 2).toUpperCase();
  if (nextTwo === 'FT' || nextTwo === 'HH') return nextTwo;
  return null;
}

function noteFromToken(symbol, options = {}) {
  const token = symbol.toUpperCase();
  const common = {
    value: '16n',
    sticking: token,
    accent: options.accent === true,
    ghost: options.ghost === true,
  };
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
      return { value: '16n', rest: true, sticking: '-' };
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
