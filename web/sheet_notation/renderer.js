import { parseDrumNotationDocument } from './document.js';
import { isBeamableValue, toVexFlowDuration } from './duration.js';
import { voiceMappingFor } from './voice_mapping.js';

const DEFAULT_RENDER_OPTIONS = Object.freeze({
  baseMeasureWidth: 640,
  measureWidth: null,
  staffX: 8,
  staffY: 10,
  staffHeight: 126,
  paddingRight: 12,
  formatterWidth: null,
  formatterWidthScale: 0.92,
  availableWidth: null,
  notesPerSystem: null,
  minNoteWidth: 39,
  systemEndReserve: 28,
  noteSpacing: 34,
  systemGapY: 140,
  finalRepeat: true,
  grouping: null,
  repeatClefEverySystem: true,
  standardAccents: true,
  stemMode: 'single',
  flatBeams: true,
});

const STICKING_FONT_FAMILY = 'Arial';
const STICKING_FONT_SIZE = 12;
const STICKING_FONT_WEIGHT = '';

export function renderDrumNotationSvg(documentJson, options = {}) {
  return renderDrumNotationSvgWithMetadata(documentJson, options).svg;
}

export function renderDrumNotationSvgWithMetadata(documentJson, options = {}) {
  const document = parseDrumNotationDocument(documentJson);
  const VF = options.vexFlow ?? resolveVexFlow();
  const renderOptions = resolveRenderOptions({ ...DEFAULT_RENDER_OPTIONS, ...options });
  const systems = notationSystemsForDocument(document, renderOptions);
  const systemCount = systems.length;
  const width =
    renderOptions.staffX +
    renderOptions.paddingRight +
    renderOptions.measureWidth;
  const height =
    renderOptions.staffY +
    renderOptions.staffHeight +
    Math.max(0, systemCount - 1) * renderOptions.systemGapY;

  const host = createDetachedHost();
  const renderer = new VF.Renderer(host, VF.Renderer.Backends.SVG);
  renderer.resize(width, height);
  const context = renderer.getContext();

  for (let index = 0; index < systems.length; index += 1) {
    const system = systems[index];
    const layout = systemLayoutForIndex(index, renderOptions);
    const stave = new VF.Stave(
      layout.x,
      layout.y,
      renderOptions.measureWidth,
    );
    if (layout.isSystemStart && renderOptions.repeatClefEverySystem) {
      stave.addClef('percussion');
    }
    if (renderOptions.finalRepeat === true && index === systems.length - 1) {
      setEndRepeatBar(VF, stave);
    }
    stave.setContext(context).draw();

    const notes = system.entries.map((entry) =>
      createVexFlowNote(VF, resolvedNoteForEntry(entry, document), {
        stemMode: renderOptions.stemMode,
        metadata: entry,
        standardAccents: renderOptions.standardAccents,
      }),
    );
    const voice = new VF.Voice({
      num_beats: system.entries.length,
      beat_value: beatValueForSystem(system),
    }).setStrict(false);
    voice.addTickables(notes);
    const formatterWidth = formatterWidthForSystem(system, renderOptions);
    new VF.Formatter()
      .joinVoices([voice])
      .format([voice], formatterWidth);
    const beams = createBeams(
      VF,
      notes,
      system,
      renderOptions,
    );
    voice.draw(context, stave);
    drawBeams(context, beams);
  }

  return {
    svg: extractSvg(host),
    notes: systems.flatMap((system) => system.entries.map(noteMetadataForEntry)),
  };
}

export function createVexFlowNote(VF, note, options = {}) {
  const duration = toVexFlowDuration(note.value, { rest: note.rest });
  const mappings = note.rest ? [] : note.voices.map(voiceMappingFor);
  const keys = note.rest ? ['b/4'] : mappings.map(keyForMapping);
  const noteOptions = {
    keys,
    duration,
    stem_direction: stemDirectionForNote(note, mappings, options.stemMode),
  };
  const staveNote = new VF.StaveNote(noteOptions);

  applyNoteheads(VF, staveNote, mappings);
  attachSticking(VF, staveNote, stickingLabelFor(note));
  if (options.standardAccents !== false) {
    attachAccent(VF, staveNote, note.accent);
  } else if (note.accent && (note.sticking == null || note.sticking === '')) {
    attachAccentAnnotation(VF, staveNote, true);
  }
  attachGhost(VF, staveNote, note.ghost);
  attachFlam(VF, staveNote, note);
  attachNoteMetadata(staveNote, options.metadata);
  return staveNote;
}

export function attachSticking(VF, staveNote, sticking) {
  if (sticking == null || sticking === '') return;
  const annotation = new VF.Annotation(sticking)
    .setFont(STICKING_FONT_FAMILY, STICKING_FONT_SIZE, STICKING_FONT_WEIGHT)
    .setVerticalJustification(VF.Annotation.VerticalJustify.BOTTOM);
  staveNote.addModifier(annotation, 0);
}

export function attachAccent(VF, staveNote, accent) {
  if (!accent) return;
  attachAccentAnnotation(VF, staveNote, accent);
}

export function attachAccentAnnotation(VF, staveNote, accent) {
  if (!accent) return;
  const annotation = new VF.Annotation('>')
    .setFont('Arial', 14, 'bold')
    .setVerticalJustification(VF.Annotation.VerticalJustify.TOP);
  staveNote.addModifier(annotation, 0);
}

export function attachGhost(VF, staveNote, ghost) {
  if (!ghost) return;
  if (typeof VF.Parenthesis !== 'function') {
    staveNote.__drumcabularyGhost = true;
    return;
  }
  const modifierPosition = VF.ModifierPosition ?? VF.Modifier?.Position;
  if (modifierPosition?.LEFT == null || modifierPosition?.RIGHT == null) {
    staveNote.__drumcabularyGhost = true;
    return;
  }
  staveNote.addModifier(new VF.Parenthesis(modifierPosition.LEFT), 0);
  staveNote.addModifier(new VF.Parenthesis(modifierPosition.RIGHT), 0);
  staveNote.__drumcabularyGhost = true;
}

export function attachFlam(VF, staveNote, note) {
  if (!note.flam) return;
  if (typeof VF.GraceNote !== 'function' || typeof VF.GraceNoteGroup !== 'function') {
    staveNote.__drumcabularyFlam = true;
    return;
  }
  const voice = note.rest ? 'snare' : note.voices[0];
  const mapping = voiceMappingFor(voice);
  const grace = new VF.GraceNote({
    keys: [mapping.key],
    duration: '8',
    slash: true,
  });
  const graceNoteGroup = new VF.GraceNoteGroup([grace], true);
  if (typeof graceNoteGroup.beamNotes === 'function') {
    graceNoteGroup.beamNotes();
  }
  if (typeof graceNoteGroup.attach === 'function') {
    graceNoteGroup.attach(staveNote);
  } else if (typeof staveNote.addModifier === 'function') {
    staveNote.addModifier(graceNoteGroup, 0);
  } else {
    staveNote.__drumcabularyFlam = true;
    return;
  }
  staveNote.graceNoteGroup = graceNoteGroup;
}

function applyNoteheads(VF, staveNote, mappings) {
  mappings.forEach((mapping, index) => {
    if (mapping.notehead === 'x' && typeof staveNote.setKeyStyle === 'function') {
      staveNote.setKeyStyle(index, { fillStyle: 'black', strokeStyle: 'black' });
    }
    if (mapping.notehead === 'x' && typeof VF.GlyphNoteHead === 'function') {
      staveNote.__drumcabularyNoteheads ??= [];
      staveNote.__drumcabularyNoteheads[index] = 'x';
    }
  });
}

function keyForMapping(mapping) {
  return mapping.notehead === 'x' ? `${mapping.key}/x` : mapping.key;
}

function stemDirectionForNote(note, mappings, stemMode = 'single') {
  if (stemMode === 'single') return 1;
  if (stemMode === 'role') {
    return stemDirectionForMappings(mappings);
  }
  if (mappings.length === 0) return 1;
  return stemDirectionForMappings(mappings);
}

export function stemDirectionForMappings(mappings) {
  if (mappings.length === 0) return 1;
  return mappings[0].stemDirection < 0 ? -1 : 1;
}

function stickingLabelFor(note) {
  if (note.sticking == null || note.sticking === '') return note.sticking;
  const sticking = String(note.sticking).trim().toUpperCase();
  if (sticking === '') return '';
  if (!Array.isArray(note.voices) || note.voices.length <= 1) return sticking;
  if (sticking.length === 1) return sticking;
  if (sticking.includes('R')) return 'R';
  if (sticking.includes('L')) return 'L';
  if (sticking.includes('K')) return 'K';
  if (sticking.includes('F')) return 'F';
  return '';
}

function attachNoteMetadata(staveNote, metadata) {
  if (metadata == null) return;
  setElementAttribute(staveNote, 'data-drum-note-index', String(metadata.index));
  setElementAttribute(staveNote, 'data-drum-measure-index', String(metadata.measureIndex));
  setElementAttribute(
    staveNote,
    'data-drum-measure-note-index',
    String(metadata.measureNoteIndex),
  );
}

function setElementAttribute(element, name, value) {
  if (typeof element.setAttribute === 'function') {
    element.setAttribute(name, value);
  } else {
    element.attributes ??= {};
    element.attributes[name] = value;
  }
}

function createBeams(VF, vexNotes, system, options = {}) {
  if (typeof VF.Beam !== 'function') return [];
  const beams = [];
  let beamGroup = [];
  for (let index = 0; index < vexNotes.length; index += 1) {
    if (index > 0 && system.beamBreaks.has(index)) {
      addBeamGroup(VF, beams, beamGroup, options);
      beamGroup = [];
    }
    const currentStemDirection = vexNotes[index].options?.stem_direction;
    const previousStemDirection =
      beamGroup.length === 0
        ? currentStemDirection
        : beamGroup[beamGroup.length - 1].options?.stem_direction;
    if (
      !system.entries[index].note.rest &&
      isBeamableValue(system.entries[index].value) &&
      currentStemDirection === previousStemDirection
    ) {
      beamGroup.push(vexNotes[index]);
      continue;
    }
    addBeamGroup(VF, beams, beamGroup, options);
    beamGroup =
      !system.entries[index].note.rest &&
      isBeamableValue(system.entries[index].value)
        ? [vexNotes[index]]
        : [];
  }
  addBeamGroup(VF, beams, beamGroup, options);
  return beams;
}

function addBeamGroup(VF, beams, beamGroup, options) {
  if (beamGroup.length < 2) return;
  const beam = new VF.Beam(beamGroup);
  if (options.flatBeams === true && beam.render_options != null) {
    beam.render_options.flat_beams = true;
  }
  if (options.flatBeamOffset != null && beam.render_options != null) {
    beam.render_options.flat_beam_offset = options.flatBeamOffset;
  }
  beams.push(beam);
}

function drawBeams(context, beams) {
  beams.forEach((beam) => beam.setContext(context).draw());
}

function formatterWidthForSystem(system, options) {
  const widthForNotes =
    system.entries.length * options.noteSpacing + options.systemEndReserve;
  const maxWidth = options.formatterWidth ?? options.measureWidth;
  return Math.min(maxWidth, widthForNotes);
}

function setEndRepeatBar(VF, stave) {
  const repeatEnd =
    VF.BarlineType?.REPEAT_END ??
    VF.Barline?.type?.REPEAT_END ??
    VF.Barline?.type?.repeatEnd ??
    5;
  if (typeof stave.setEndBarType === 'function') {
    stave.setEndBarType(repeatEnd);
  }
}

function resolveRenderOptions(options) {
  const availableWidth = Number(options.availableWidth);
  const hasAvailableWidth = Number.isFinite(availableWidth) && availableWidth > 0;
  const usableWidth = hasAvailableWidth
    ? Math.max(180, availableWidth - options.staffX - options.paddingRight)
    : options.baseMeasureWidth;
  const measureWidth =
    options.measureWidth ??
    Math.floor(usableWidth);
  const formatterWidth =
    options.formatterWidth ??
    Math.floor(
      Math.max(120, measureWidth - options.systemEndReserve),
    );

  return {
    ...options,
    measureWidth,
    formatterWidth,
  };
}

function notationSystemsForDocument(document, options) {
  const entries = noteEntriesForDocument(document);
  const grouping = parseGrouping(options.grouping);
  const notesPerSystem = normalizedNotesPerSystem(options);
  if (notesPerSystem != null) {
    return systemsForEntries(entries, {
      grouping,
      notesPerSystem,
    });
  }

  return document.measures.map((measure, measureIndex) => {
    const measureEntries = entries.filter(
      (entry) => entry.measureIndex === measureIndex,
    );
    return systemForEntries(measureEntries, grouping);
  });
}

function normalizedNotesPerSystem(options) {
  if (options.notesPerSystem === 'auto') return autoNotesPerSystem(options);
  if (options.notesPerSystem == null && options.availableWidth != null) {
    return autoNotesPerSystem(options);
  }
  if (options.notesPerSystem == null) return null;

  const value = Number(options.notesPerSystem);
  if (!Number.isFinite(value) || value < 1) return null;
  return Math.floor(value);
}

function autoNotesPerSystem(options) {
  const minNoteWidth = Number(options.minNoteWidth);
  const formatterWidth = Number(options.formatterWidth);
  const safeMinNoteWidth =
    Number.isFinite(minNoteWidth) && minNoteWidth > 0 ? minNoteWidth : 22;
  const safeSystemWidth =
    Number.isFinite(formatterWidth) && formatterWidth > 0
      ? formatterWidth
      : Math.max(120, options.measureWidth - options.systemEndReserve);
  return Math.max(4, Math.floor(safeSystemWidth / safeMinNoteWidth));
}

function noteEntriesForDocument(document) {
  const entries = [];
  document.measures.forEach((measure, measureIndex) => {
    measure.notes.forEach((note, measureNoteIndex) => {
      entries.push({
        index: entries.length,
        measureIndex,
        measureNoteIndex,
        value: note.value ?? document.subdivision,
        note,
      });
    });
  });
  return entries;
}

function systemsForEntries(entries, options) {
  if (entries.length === 0) return [];
  if (options.grouping.length === 0) {
    const systems = [];
    for (let index = 0; index < entries.length; index += options.notesPerSystem) {
      systems.push(
        systemForEntries(entries.slice(index, index + options.notesPerSystem), []),
      );
    }
    return systems;
  }

  const groups = groupedEntries(entries, options.grouping);
  const systems = [];
  let current = [];
  for (const group of groups) {
    if (
      current.length > 0 &&
      current.length + group.length > options.notesPerSystem
    ) {
      systems.push(systemForEntries(current, options.grouping));
      current = [];
    }
    current.push(...group);
  }
  if (current.length > 0) systems.push(systemForEntries(current, options.grouping));
  return systems;
}

function groupedEntries(entries, grouping) {
  const groups = [];
  let index = 0;
  let groupingIndex = 0;
  while (index < entries.length) {
    const size = grouping[groupingIndex % grouping.length];
    groups.push(entries.slice(index, index + size));
    index += size;
    groupingIndex += 1;
  }
  return groups;
}

function systemForEntries(entries, grouping) {
  return {
    entries,
    beamBreaks: beamBreaksForEntries(entries, grouping),
  };
}

function beamBreaksForEntries(entries, grouping) {
  const breaks = new Set();
  if (grouping.length === 0) return breaks;
  let consumed = 0;
  let groupingIndex = 0;
  while (consumed < entries.length) {
    if (consumed > 0) breaks.add(consumed);
    consumed += grouping[groupingIndex % grouping.length];
    groupingIndex += 1;
  }
  return breaks;
}

function parseGrouping(grouping) {
  if (Array.isArray(grouping)) {
    return grouping
      .map((value) => Number(value))
      .filter((value) => Number.isInteger(value) && value > 0);
  }
  if (typeof grouping !== 'string') return [];
  const trimmed = grouping.trim();
  const parts = /^\d+$/.test(trimmed) ? [...trimmed] : trimmed.match(/\d+/g) ?? [];
  return parts
    .map((value) => Number(value))
    .filter((value) => Number.isInteger(value) && value > 0);
}

function noteMetadataForEntry(entry) {
  const sticking = entry.note.sticking == null
    ? entry.note.sticking
    : String(entry.note.sticking).toUpperCase();
  return {
    index: entry.index,
    measureIndex: entry.measureIndex,
    measureNoteIndex: entry.measureNoteIndex,
    value: entry.value,
    voices: entry.note.voices,
    rest: entry.note.rest,
    sticking,
    accent: entry.note.accent,
    flam: entry.note.flam,
    ghost: entry.note.ghost,
    tie: entry.note.tie,
  };
}

function systemLayoutForIndex(index, options) {
  return {
    x: options.staffX,
    y: options.staffY + index * options.systemGapY,
    isSystemStart: true,
  };
}

function beatValueForSystem(system) {
  const firstValue = system.entries[0]?.value;
  if (firstValue == null) return 4;
  const match = /^(\d+)n$/.exec(firstValue);
  return match == null ? 4 : Number(match[1]);
}

function resolvedNoteForEntry(entry, document) {
  return {
    ...entry.note,
    value: entry.value ?? document.subdivision,
  };
}

function createDetachedHost() {
  if (typeof document !== 'undefined') {
    return document.createElement('div');
  }
  return {
    children: [],
    appendChild(child) {
      this.children.push(child);
    },
    querySelector(selector) {
      if (selector !== 'svg') return null;
      return this.children.find((child) => child?.tagName === 'svg') ?? null;
    },
  };
}

function extractSvg(host) {
  const svg = host.querySelector('svg');
  if (svg == null) {
    throw new Error('VexFlow did not produce an SVG element.');
  }
  return svg.outerHTML ?? String(svg);
}

function resolveVexFlow() {
  const globalVexFlow = globalThis.VexFlow ?? globalThis.Vex?.Flow ?? globalThis.VF;
  if (globalVexFlow == null) {
    throw new Error('VexFlow is required. Pass { vexFlow } or load Vex.Flow globally.');
  }
  return globalVexFlow;
}

if (typeof window !== 'undefined') {
  window.renderDrumNotationSvg = (documentJson, options) =>
    renderDrumNotationSvg(documentJson, options);
  window.renderDrumNotationSvgWithMetadata = (documentJson, options) =>
    renderDrumNotationSvgWithMetadata(documentJson, options);
}
