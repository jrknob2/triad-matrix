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
  systemGapY: 112,
  finalRepeat: true,
  repeatClefEverySystem: true,
  repeatTimeSignatureEverySystem: false,
  stemMode: 'single',
  flatBeams: true,
});

export function renderDrumNotationSvg(documentJson, options = {}) {
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
    if (
      index === 0 ||
      (layout.isSystemStart && renderOptions.repeatTimeSignatureEverySystem)
    ) {
      stave.addTimeSignature(document.timeSignature);
    }
    if (renderOptions.finalRepeat === true && index === systems.length - 1) {
      setEndRepeatBar(VF, stave);
    }
    stave.setContext(context).draw();

    const notes = system.notes.map((note) =>
      createVexFlowNote(VF, note, { stemMode: renderOptions.stemMode }),
    );
    const voice = new VF.Voice({
      num_beats: beatsFromTimeSignature(document.timeSignature),
      beat_value: beatValueFromTimeSignature(document.timeSignature),
    }).setStrict(false);
    voice.addTickables(notes);
    const formatterWidth = formatterWidthForSystem(system, renderOptions);
    new VF.Formatter()
      .joinVoices([voice])
      .format([voice], formatterWidth);
    const beams = createBeams(
      VF,
      notes,
      system.notes,
      renderOptions,
    );
    voice.draw(context, stave);
    drawBeams(context, beams);
  }

  return extractSvg(host);
}

export function createVexFlowNote(VF, note, options = {}) {
  const duration = toVexFlowDuration(note.value, { rest: note.rest });
  const mappings = note.rest ? [] : note.voices.map(voiceMappingFor);
  const keys = note.rest ? ['b/4'] : mappings.map((mapping) => mapping.key);
  const noteOptions = {
    keys,
    duration,
    stem_direction: stemDirectionForMappings(mappings, options.stemMode),
  };
  const noteheadType = noteheadTypeForMappings(mappings);
  if (noteheadType != null) {
    noteOptions.type = noteheadType;
  }
  const staveNote = new VF.StaveNote(noteOptions);

  applyNoteheads(VF, staveNote, mappings);
  attachSticking(VF, staveNote, stickingLabelFor(note));
  if (note.accent && (note.sticking == null || note.sticking === '')) {
    attachAccent(VF, staveNote, true);
  }
  attachGhost(VF, staveNote, note.ghost);
  attachFlam(VF, staveNote, note);
  return staveNote;
}

export function attachSticking(VF, staveNote, sticking) {
  if (sticking == null || sticking === '') return;
  const annotation = new VF.Annotation(sticking)
    .setFont('Arial', 12, '')
    .setVerticalJustification(VF.Annotation.VerticalJustify.BOTTOM);
  staveNote.addModifier(annotation, 0);
}

export function attachAccent(VF, staveNote, accent) {
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

function noteheadTypeForMappings(mappings) {
  if (mappings.length === 0) return null;
  return mappings.every((mapping) => mapping.notehead === 'x') ? 'x' : null;
}

function stemDirectionForMappings(mappings, stemMode = 'single') {
  if (stemMode === 'single') return 1;
  if (mappings.length === 0) return 1;
  const hasDownStem = mappings.some((mapping) => mapping.stemDirection < 0);
  return hasDownStem ? -1 : 1;
}

function stickingLabelFor(note) {
  const accentPrefix = note.accent ? '^' : '';
  if (note.sticking == null || note.sticking === '') return note.sticking;
  return `${accentPrefix}${note.sticking}`;
}

function createBeams(VF, vexNotes, sourceNotes, options = {}) {
  if (typeof VF.Beam !== 'function') return [];
  const beams = [];
  let beamGroup = [];
  for (let index = 0; index < vexNotes.length; index += 1) {
    const currentStemDirection = vexNotes[index].options?.stem_direction;
    const previousStemDirection =
      beamGroup.length === 0
        ? currentStemDirection
        : beamGroup[beamGroup.length - 1].options?.stem_direction;
    if (
      !sourceNotes[index].rest &&
      isBeamableValue(sourceNotes[index].value) &&
      currentStemDirection === previousStemDirection
    ) {
      beamGroup.push(vexNotes[index]);
      continue;
    }
    addBeamGroup(VF, beams, beamGroup, options);
    beamGroup =
      !sourceNotes[index].rest && isBeamableValue(sourceNotes[index].value)
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
    system.notes.length * options.noteSpacing + options.systemEndReserve;
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
  const notesPerSystem = normalizedNotesPerSystem(options);
  if (notesPerSystem != null) {
    const notes = document.measures.flatMap((measure) => measure.notes);
    return chunksForNotes(notes, notesPerSystem);
  }

  return document.measures.map((measure) => ({ notes: measure.notes }));
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

function chunksForNotes(notes, notesPerSystem) {
  const chunks = [];
  for (let index = 0; index < notes.length; index += notesPerSystem) {
    chunks.push({ notes: notes.slice(index, index + notesPerSystem) });
  }
  return chunks;
}

function systemLayoutForIndex(index, options) {
  return {
    x: options.staffX,
    y: options.staffY + index * options.systemGapY,
    isSystemStart: true,
  };
}

function beatsFromTimeSignature(timeSignature) {
  return Number(timeSignature.split('/')[0]);
}

function beatValueFromTimeSignature(timeSignature) {
  return Number(timeSignature.split('/')[1]);
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
}
