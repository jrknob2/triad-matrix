import { DRUM_NOTE_VALUES } from './duration.js';
import { DRUM_VOICE_IDS } from './voice_mapping.js';

const NOTE_VALUE_SET = new Set(DRUM_NOTE_VALUES);
const VOICE_ID_SET = new Set(DRUM_VOICE_IDS);

export function parseDrumNotationDocument(input) {
  const raw = typeof input === 'string' ? JSON.parse(input) : input;
  assertObject(raw, 'document');
  assertString(raw.timeSignature, 'timeSignature');
  if (!Array.isArray(raw.measures) || raw.measures.length === 0) {
    throw new Error('DrumNotationDocument.measures must be a non-empty array.');
  }

  return {
    timeSignature: raw.timeSignature,
    measures: raw.measures.map(parseMeasure),
  };
}

function parseMeasure(rawMeasure, measureIndex) {
  assertObject(rawMeasure, `measures[${measureIndex}]`);
  if (!Array.isArray(rawMeasure.notes) || rawMeasure.notes.length === 0) {
    throw new Error(`measures[${measureIndex}].notes must be a non-empty array.`);
  }
  return {
    notes: rawMeasure.notes.map((rawNote, noteIndex) =>
      parseNote(rawNote, measureIndex, noteIndex),
    ),
  };
}

function parseNote(rawNote, measureIndex, noteIndex) {
  const path = `measures[${measureIndex}].notes[${noteIndex}]`;
  assertObject(rawNote, path);
  if (!NOTE_VALUE_SET.has(rawNote.value)) {
    throw new Error(`${path}.value is unsupported: ${String(rawNote.value)}`);
  }
  const rest = rawNote.rest === true;
  const voices = rest ? [] : parseVoices(rawNote.voices, path);

  return {
    value: rawNote.value,
    voices,
    rest,
    sticking: optionalString(rawNote.sticking, `${path}.sticking`),
    accent: rawNote.accent === true,
    flam: rawNote.flam === true,
    ghost: rawNote.ghost === true,
    tie: rawNote.tie === true,
  };
}

function parseVoices(rawVoices, path) {
  if (!Array.isArray(rawVoices) || rawVoices.length === 0) {
    throw new Error(`${path}.voices must be a non-empty array for notes.`);
  }
  return rawVoices.map((voice, index) => {
    if (!VOICE_ID_SET.has(voice)) {
      throw new Error(`${path}.voices[${index}] is unknown: ${String(voice)}`);
    }
    return voice;
  });
}

function optionalString(value, path) {
  if (value == null) return undefined;
  assertString(value, path);
  return value;
}

function assertObject(value, path) {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(`${path} must be an object.`);
  }
}

function assertString(value, path) {
  if (typeof value !== 'string' || value.trim() === '') {
    throw new Error(`${path} must be a non-empty string.`);
  }
}
