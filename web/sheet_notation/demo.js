import { renderDrumNotationSvg } from './renderer.js';

export const DEFAULT_DEMO_PATTERN =
  '^R^L^R(L)(L) K ^R^L^R(L)(L) ^R^L^R(L)(L) [XK]';

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
    { voices: ['snare'], sticking: 'R', accent: true },
    { voices: ['snare'], sticking: 'L', accent: true },
    { voices: ['snare'], sticking: 'R', accent: true },
    { voices: ['snare'], sticking: 'L', ghost: true },
    { voices: ['snare'], sticking: 'L', ghost: true },
    { voices: ['crash', 'kick'], sticking: 'XK' },
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

export function groupingFromPattern(pattern, options = {}) {
  const groups = topLevelPatternGroups(pattern)
    .map((group) => notesFromPattern(group, { lenient: options.lenient }).length)
    .filter((count) => count > 0);
  return groups.length > 1 ? groupingLabelFor(groups) : null;
}

export function patternFromNotes(notes, options = {}) {
  const tokens = notes.map((note) => patternTokenForNote(note, options));
  return joinTokensWithGrouping(tokens, options.grouping);
}

export function patternWithGrouping(pattern, grouping, options = {}) {
  return patternFromNotes(
    notesFromPattern(pattern, { lenient: options.lenient }),
    { ...options, grouping },
  );
}

export function notesFromPattern(pattern, options = {}) {
  const notes = [];
  let accent = options.initialAccent === true;
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
      if (accent) {
        throw new Error('Ghost notes cannot be accented.');
      }
      const ghostNotes = notesFromPattern(symbol, {
        lenient: options.lenient,
        value: defaultValue,
        voices: defaultVoices,
      });
      if (ghostNotes.length !== 1) {
        if (options.lenient) {
          accent = false;
          index = close;
          continue;
        }
        throw new Error('Ghost note groups must contain exactly one note.');
      }
      if (ghostNotes[0].accent) {
        throw new Error('Ghost notes cannot be accented.');
      }
      notes.push({ ...ghostNotes[0], ghost: true });
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
        try {
          notes.push(simultaneousNoteFromBody(body, {
            accent,
            value: defaultValue,
          }));
        } catch (error) {
          if (!options.lenient) throw error;
        }
        accent = false;
        index = close;
        continue;
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
        initialAccent: accent,
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

function topLevelPatternGroups(pattern) {
  const groups = [];
  let current = '';
  let bracketDepth = 0;
  let parenDepth = 0;

  for (let index = 0; index < pattern.length; index += 1) {
    const char = pattern[index];
    if (char === '[' && parenDepth === 0) bracketDepth += 1;
    if (char === ']' && bracketDepth > 0 && parenDepth === 0) bracketDepth -= 1;
    if (char === '(' && bracketDepth === 0) parenDepth += 1;
    if (char === ')' && parenDepth > 0 && bracketDepth === 0) parenDepth -= 1;

    if (/\s/.test(char) && bracketDepth === 0 && parenDepth === 0) {
      if (current.trim().length > 0) groups.push(current);
      current = '';
      continue;
    }
    current += char;
  }

  if (current.trim().length > 0) groups.push(current);
  return groups;
}

function joinTokensWithGrouping(tokens, grouping) {
  const groups = groupingValuesFromLabel(grouping);
  if (groups.length === 0 || tokens.length === 0) return tokens.join('');

  const parts = [];
  let index = 0;
  let groupIndex = 0;
  while (index < tokens.length) {
    const size = groups[groupIndex % groups.length];
    parts.push(tokens.slice(index, index + size).join(''));
    index += size;
    groupIndex += 1;
  }
  return parts.join(' ');
}

function groupingValuesFromLabel(grouping) {
  if (Array.isArray(grouping)) {
    return grouping
      .map((value) => Number(value))
      .filter((value) => Number.isInteger(value) && value > 0);
  }
  if (typeof grouping !== 'string') return [];
  const trimmed = grouping.trim();
  if (trimmed.length === 0) return [];
  const parts = /^\d+$/.test(trimmed) ? [...trimmed] : trimmed.match(/\d+/g) ?? [];
  return parts
    .map((value) => Number(value))
    .filter((value) => Number.isInteger(value) && value > 0);
}

function groupingLabelFor(groups) {
  return groups.every((count) => count > 0 && count < 10)
    ? groups.join('')
    : groups.join(' ');
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
  return null;
}

function simultaneousNoteFromBody(body, options = {}) {
  const trimmed = body.trim();
  if (trimmed.length === 0) {
    throw new Error('Empty bracket. Use a simultaneous hit like [XK] or an override like [T1:L].');
  }
  const parts = notesFromPattern(trimmed, { lenient: false, value: options.value });
  if (parts.length < 2) {
    throw new Error('Simultaneous hits must contain at least two notes, such as [XK] or [RL].');
  }
  if (parts.some((note) => note.rest)) {
    throw new Error('Rests are not allowed inside simultaneous hits.');
  }
  const voices = [];
  let sticking = '';
  let accent = options.accent === true;
  let ghost = false;
  let flam = false;
  for (const note of parts) {
    for (const voice of note.voices ?? []) {
      if (!voices.includes(voice)) voices.push(voice);
    }
    sticking += basePatternTokenForNote(note);
    accent = accent || note.accent === true;
    ghost = ghost || note.ghost === true;
    flam = flam || note.flam === true;
  }
  return {
    value: options.value,
    voices,
    sticking,
    accent,
    ghost,
    flam,
  };
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
      throw new Error('Invalid token: B is no longer supported. Use [RL] for both hands/unison or assign explicit voices.');
    case 'X':
      return {
        ...common,
        sticking: 'X',
        voices: withVoices(['crash']),
      };
    case '_':
      return { value: options.value, rest: true, sticking: '_' };
    default:
      throw new Error(`Unsupported pattern token: ${symbol}`);
  }
}

function patternTokenForNote(note, options = {}) {
  if (isSimultaneousNote(note)) {
    const token = `[${note.accent ? '^' : ''}${note.sticking}]`;
    const overrides = [];
    if (
      options.subdivision != null &&
      note.value != null &&
      note.value !== options.subdivision
    ) {
      overrides.push(note.value.replace('n', ''));
    }
    return overrides.length > 0 ? `[${overrides.join(' ')}:${token}]` : token;
  }
  if (note.ghost && note.accent) {
    throw new Error('Ghost notes cannot be accented.');
  }
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
  if (note.rest) return '_';
  if (note.flam) return 'F';
  if (isLimbSticking(note.sticking)) return note.sticking;
  const voices = note.voices ?? [];
  if (voices.includes('kick')) return 'K';
  if (voices.includes('hihat') && voices.includes('snare')) return '[RL]';
  if (voices.includes('crash')) return 'X';
  return note.sticking ?? 'R';
}

function isSimultaneousNote(note) {
  return !note.rest && /^[RLKFX]{2,}$/.test(note.sticking ?? '');
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
      return 'X';
    case 'ride':
      return 'RD';
    default:
      return null;
  }
}

function isLimbSticking(sticking) {
  return sticking === 'R' || sticking === 'L';
}
