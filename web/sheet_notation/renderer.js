import { parseDrumNotationDocument } from './document.js';
import { isBeamableValue, toVexFlowDuration } from './duration.js';
import { voiceMappingFor } from './voice_mapping.js';

const DEFAULT_RENDER_OPTIONS = Object.freeze({
  measureWidth: 760,
  staffX: 20,
  staffY: 36,
  staffHeight: 190,
  paddingRight: 20,
  formatterPadding: 90,
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
      createVexFlowNote(VF, note),
    );
    const voice = new VF.Voice({
      num_beats: beatsFromTimeSignature(document.timeSignature),
      beat_value: beatValueFromTimeSignature(document.timeSignature),
    }).setStrict(false);
    voice.addTickables(notes);
    new VF.Formatter()
      .joinVoices([voice])
      .format([voice], renderOptions.measureWidth - renderOptions.formatterPadding);
    voice.draw(context, stave);
    drawBeams(VF, context, notes, document.measures[index].notes);
    x += renderOptions.measureWidth;
  }

  return extractSvg(host);
}

export function createVexFlowNote(VF, note) {
  const duration = toVexFlowDuration(note.value, { rest: note.rest });
  const mappings = note.rest ? [] : note.voices.map(voiceMappingFor);
  const keys = note.rest ? ['b/4'] : mappings.map((mapping) => mapping.key);
  const staveNote = new VF.StaveNote({
    keys,
    duration,
    stem_direction: stemDirectionForMappings(mappings),
  });

  applyNoteheads(VF, staveNote, mappings);
  attachSticking(VF, staveNote, note.sticking);
  attachAccent(VF, staveNote, note.accent);
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
  const articulation = new VF.Articulation('a>').setPosition(
    VF.Modifier.Position.ABOVE,
  );
  staveNote.addModifier(articulation, 0);
}

export function attachGhost(VF, staveNote, ghost) {
  if (!ghost) return;
  if (typeof VF.NoteSubGroup !== 'function') {
    staveNote.__drumcabularyGhost = true;
    return;
  }
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
  new VF.GraceNoteGroup([grace], true).beamNotes().attach(staveNote);
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

function stemDirectionForMappings(mappings) {
  if (mappings.length === 0) return 1;
  const hasDownStem = mappings.some((mapping) => mapping.stemDirection < 0);
  return hasDownStem ? -1 : 1;
}

function drawBeams(VF, context, vexNotes, sourceNotes) {
  if (typeof VF.Beam !== 'function') return;
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
    drawBeamGroup(VF, context, beamGroup);
    beamGroup =
      !sourceNotes[index].rest && isBeamableValue(sourceNotes[index].value)
        ? [vexNotes[index]]
        : [];
  }
  drawBeamGroup(VF, context, beamGroup);
}

function drawBeamGroup(VF, context, beamGroup) {
  if (beamGroup.length < 2) return;
  new VF.Beam(beamGroup).setContext(context).draw();
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
