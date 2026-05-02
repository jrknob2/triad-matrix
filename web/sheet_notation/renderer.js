import { parseDrumNotationDocument } from './document.js';
import { isBeamableValue, toVexFlowDuration } from './duration.js';
import { voiceMappingFor } from './voice_mapping.js';

const DEFAULT_RENDER_OPTIONS = Object.freeze({
  measureWidth: 640,
  staffX: 20,
  staffY: 36,
  staffHeight: 190,
  paddingRight: 70,
  formatterWidth: 500,
  stemMode: 'single',
  flatBeams: true,
});

export function renderDrumNotationSvg(documentJson, options = {}) {
  const document = parseDrumNotationDocument(documentJson);
  const VF = options.vexFlow ?? resolveVexFlow();
  const renderOptions = { ...DEFAULT_RENDER_OPTIONS, ...options };
  const width =
    renderOptions.staffX +
    renderOptions.paddingRight +
    document.measures.length * renderOptions.measureWidth;
  const height = renderOptions.staffY + renderOptions.staffHeight;

  const host = createDetachedHost();
  const renderer = new VF.Renderer(host, VF.Renderer.Backends.SVG);
  renderer.resize(width, height);
  const context = renderer.getContext();

  let x = renderOptions.staffX;
  for (let index = 0; index < document.measures.length; index += 1) {
    const stave = new VF.Stave(
      x,
      renderOptions.staffY,
      renderOptions.measureWidth,
    );
    if (index === 0) {
      stave.addClef('percussion').addTimeSignature(document.timeSignature);
    }
    stave.setContext(context).draw();

    const notes = document.measures[index].notes.map((note) =>
      createVexFlowNote(VF, note, { stemMode: renderOptions.stemMode }),
    );
    const voice = new VF.Voice({
      num_beats: beatsFromTimeSignature(document.timeSignature),
      beat_value: beatValueFromTimeSignature(document.timeSignature),
    }).setStrict(false);
    voice.addTickables(notes);
    const formatterWidth =
      renderOptions.formatterWidth ??
      renderOptions.measureWidth - renderOptions.formatterPadding;
    new VF.Formatter()
      .joinVoices([voice])
      .format([voice], formatterWidth);
    const beams = createBeams(
      VF,
      notes,
      document.measures[index].notes,
      renderOptions,
    );
    voice.draw(context, stave);
    drawBeams(context, beams);
    x += renderOptions.measureWidth;
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
  window.renderDrumNotationSvg = (documentJson) => renderDrumNotationSvg(documentJson);
}
