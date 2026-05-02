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
    measures: [{ notes: notesFromPattern(pattern, { lenient: options.lenient }) }],
  };
}

export function patternFromNotes(notes, options = {}) {
  return notes.map((note) => patternTokenForNote(note, options)).join('');
}

export function notesFromPattern(pattern, options = {}) {
  const notes = [];
  let accent = false;
  const defaultValue = options.value;
  const defaultVoices = options.voices;
  for (let index = 0; index < pattern.length; index += 1) {
    const char = pattern[index];
    if (/\s/.test(char)) continue;
    if (char === '^') {
      accent = true;
      continue;
    }
    if (char === '(') {
      const close = pattern.indexOf(')', index + 1);
      if (close < 0) {
        if (options.lenient) break;
        throw new Error('Unclosed ghost note group.');
      }
      const symbol = pattern.slice(index + 1, close).trim();
      if (symbol.length === 0) {
        if (options.lenient) {
          accent = false;
          index = close;
          continue;
        }
        throw new Error('Empty ghost note group.');
      }
      notes.push(noteFromToken(symbol, {
        accent,
        ghost: true,
        value: defaultValue,
        voices: defaultVoices,
      }));
      accent = false;
      index = close;
      continue;
    }
    if (char === '[') {
      const close = pattern.indexOf(']', index + 1);
      if (close < 0) {
        if (options.lenient) break;
        throw new Error('Unclosed duration override group.');
      }
      const body = pattern.slice(index + 1, close);
      const separator = body.indexOf(':');
      if (separator < 0) {
        if (options.lenient) {
          accent = false;
          index = close;
          continue;
        }
        throw new Error('Duration override must use [duration: pattern].');
      }
      let override;
      try {
        override = overrideFromLabel(body.slice(0, separator).trim());
      } catch (error) {
        if (options.lenient) {
          accent = false;
          index = close;
          continue;
        }
        throw error;
      }
      notes.push(...notesFromPattern(body.slice(separator + 1), {
        lenient: options.lenient,
        value: override.value ?? defaultValue,
        voices: override.voices ?? defaultVoices,
      }));
      accent = false;
      index = close;
      continue;
    }
    const multi = multiCharacterTokenAt(pattern, index);
    if (multi != null) {
      notes.push(noteFromToken(multi, {
        accent,
        value: defaultValue,
        voices: defaultVoices,
      }));
      accent = false;
      index += multi.length - 1;
      continue;
    }
    try {
      notes.push(noteFromToken(char, {
        accent,
        value: defaultValue,
        voices: defaultVoices,
      }));
    } catch (error) {
      if (!options.lenient) throw error;
    }
    accent = false;
  }
  return notes;
}

function overrideFromLabel(label) {
  const parts = label
    .split(/[,\s]+/)
    .map((part) => part.trim())
    .filter((part) => part.length > 0);
  if (parts.length === 0) {
    throw new Error('Override label cannot be empty.');
  }

  const override = {};
  for (const part of parts) {
    const value = durationValueFromLabel(part);
    if (value != null) {
      override.value = value;
      continue;
    }
    const voices = voicesFromLabel(part);
    if (voices != null) {
      override.voices = voices;
      continue;
    }
    throw new Error(`Unsupported override: ${part}`);
  }
  return override;
}

function durationValueFromLabel(label) {
  const normalized = label.endsWith('n') ? label : `${label}n`;
  return ['1n', '2n', '4n', '8n', '16n', '32n'].includes(normalized)
    ? normalized
    : null;
}

function voicesFromLabel(label) {
  switch (label.toUpperCase()) {
    case 'S':
    case 'SN':
    case 'SNARE':
      return ['snare'];
    case 'T1':
    case 'TOM1':
      return ['tom1'];
    case 'T2':
    case 'TOM2':
      return ['tom2'];
    case 'FT':
    case 'FLOORTOM':
    case 'FLOOR_TOM':
      return ['floorTom'];
    case 'K':
    case 'KICK':
      return ['kick'];
    case 'HH':
    case 'HIHAT':
    case 'HIGHHAT':
      return ['hihat'];
    case 'C':
    case 'X':
    case 'CRASH':
      return ['crash'];
    case 'RD':
    case 'RIDE':
      return ['ride'];
    default:
      return null;
  }
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
  const withVoices = (voices) => options.voices ?? voices;
  switch (token) {
    case 'R':
    case 'L':
      return { ...common, voices: withVoices(['snare']) };
    case 'K':
      return { ...common, voices: withVoices(['kick']) };
    case 'F':
      return { ...common, voices: withVoices(['snare']), flam: true };
    case 'B':
      return { ...common, voices: withVoices(['hihat', 'snare']) };
    case 'X':
    case 'C':
      return {
        ...common,
        sticking: token === 'X' ? 'X' : 'C',
        voices: withVoices(['crash']),
      };
    case 'HH':
      return { ...common, voices: withVoices(['hihat']) };
    case 'FT':
      return { ...common, voices: withVoices(['floorTom']) };
    case '_':
    case '-':
      return { value: options.value, rest: true, sticking: '-' };
    default:
      throw new Error(`Unsupported pattern token: ${symbol}`);
  }
}

function patternTokenForNote(note, options = {}) {
  const base = basePatternTokenForNote(note);
  const marked = note.ghost ? `(${base})` : base;
  const token = note.accent ? `^${marked}` : marked;
  const overrides = [];
  const voiceOverride = voiceOverrideLabelForNote(note);
  if (voiceOverride != null) overrides.push(voiceOverride);
  if (
    options.subdivision != null &&
    note.value != null &&
    note.value !== options.subdivision
  ) {
    overrides.push(note.value.replace('n', ''));
  }
  if (overrides.length > 0) return `[${overrides.join(' ')}:${token}]`;
  return token;
}

function basePatternTokenForNote(note) {
  if (note.rest) return '-';
  if (note.flam) return 'F';
  if (isLimbSticking(note.sticking)) return note.sticking;
  const voices = note.voices ?? [];
  if (voices.includes('kick')) return 'K';
  if (voices.includes('floorTom')) return 'FT';
  if (voices.includes('hihat') && voices.includes('snare')) return 'B';
  if (voices.includes('hihat')) return 'HH';
  if (voices.includes('crash')) return note.sticking === 'X' ? 'X' : 'C';
  return note.sticking ?? 'R';
}

function voiceOverrideLabelForNote(note) {
  if (!isLimbSticking(note.sticking)) return null;
  const voices = note.voices ?? [];
  if (voices.length !== 1 || voices[0] === 'snare') return null;
  switch (voices[0]) {
    case 'tom1':
      return 'T1';
    case 'tom2':
      return 'T2';
    case 'floorTom':
      return 'FT';
    case 'kick':
      return 'K';
    case 'hihat':
      return 'HH';
    case 'crash':
      return 'C';
    case 'ride':
      return 'RD';
    default:
      return null;
  }
}

function isLimbSticking(sticking) {
  return sticking === 'R' || sticking === 'L';
}
