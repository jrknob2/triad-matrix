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
  timeSignatureReserve: 48,
  noteSpacing: 34,
  groupGap: 0,
  stemLength: null,
  systemGapY: 140,
  finalRepeat: true,
  preserveMeasures: false,
  grouping: null,
  repeatClefEverySystem: false,
  standardAccents: true,
  showSticking: true,
  stemMode: 'single',
  flatBeams: true,
  avoidSingleNoteFlags: true,
});

const STICKING_FONT_FAMILY = 'Arial';
const STICKING_FONT_SIZE = 12;
const STICKING_FONT_WEIGHT = '';
// Symbol spacing constants are semantic distances applied to anchors derived
// from VexFlow geometry. They are intentionally centralized so new symbols can
// reuse anchors without trial-and-error offsets in placement code.
const STICKING_LABEL_GAP_ABOVE_TOP_TEXT = 18;
const STICKING_LABEL_FALLBACK_GAP_ABOVE_STAVE = 28;
const OPEN_HIHAT_MARKER_RADIUS = 5.25;
const OPEN_HIHAT_MARKER_STROKE_WIDTH = 1.85;
const OPEN_HIHAT_MARKER_CLEARANCE = 4.25;
const FALLBACK_NOTEHEAD_SIZE = 10;
const SELECTION_EVENT_HORIZONTAL_PADDING = 13;
const SELECTION_EVENT_TOP_FROM_STAVE_TOP = 2;
const SELECTION_EVENT_HEIGHT = 95;

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
  try {
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
      if (index === 0 && typeof stave.addTimeSignature === 'function') {
        stave.addTimeSignature(document.timeSignature);
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
          stemLength: renderOptions.stemLength,
        }),
      );
      const voice = new VF.Voice({
        num_beats: numBeatsForSystem(system, document),
        beat_value: beatValueForSystem(system, document),
      }).setStrict(false);
      voice.addTickables(notes);
      const formatterWidth = formatterWidthForSystem(system, renderOptions, {
        document,
        systemIndex: index,
      });
      new VF.Formatter()
        .joinVoices([voice])
        .format([voice], formatterWidth);
      applyGroupSpacing(notes, system, renderOptions);
      const beams = createBeams(
        VF,
        notes,
        system,
        renderOptions,
      );
      const tuplets = createTuplets(VF, notes, system, document);
      voice.draw(context, stave);
      drawBeams(context, beams);
      drawTuplets(context, tuplets);
      if (renderOptions.showSticking !== false) {
        appendStickingLabels(host, VF, notes, system, layout);
      }
      appendOpenHiHatMarkers(host, VF, notes, system, layout);
    }

    return {
      svg: extractSvg(host),
      notes: systems.flatMap((system, systemIndex) => {
        const layout = systemLayoutForIndex(systemIndex, renderOptions);
        return system.entries.map((entry) => noteMetadataForEntry(entry, layout));
      }),
    };
  } finally {
    disposeDetachedHost(host);
  }
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
  applyStemLength(staveNote, note, options.stemLength);
  attachStickingMetadata(staveNote, stickingLabelFor(note));
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
    .setVerticalJustification(VF.Annotation.VerticalJustify.TOP);
  staveNote.addModifier(annotation, 0);
}

function attachStickingMetadata(staveNote, sticking) {
  staveNote.__drumcabularyStickingLabel = sticking == null
    ? ''
    : String(sticking).trim().toUpperCase();
}

function applyStemLength(staveNote, note, stemLength) {
  if (note.rest || typeof staveNote.setStemLength !== 'function') return;
  const length = Number(stemLength);
  if (!Number.isFinite(length) || length <= 0) return;
  staveNote.setStemLength(length);
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
  const beamBreaks = options.avoidSingleNoteFlags === true
    ? beamBreaksWithoutSingleNoteGroups(system)
    : system.beamBreaks;
  for (let index = 0; index < vexNotes.length; index += 1) {
    if (index > 0 && beamBreaks.has(index)) {
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

function beamBreaksWithoutSingleNoteGroups(system) {
  if (system.beamBreaks.size === 0) return system.beamBreaks;
  const breaks = [...system.beamBreaks].sort((left, right) => left - right);
  const boundaries = [0, ...breaks, system.entries.length];
  const result = new Set(system.beamBreaks);
  for (let index = 1; index < boundaries.length - 1; index += 1) {
    const start = boundaries[index];
    const end = boundaries[index + 1];
    const length = end - start;
    if (length === 1 && isBeamableEntry(system.entries[start])) {
      result.delete(start);
      if (end < system.entries.length) result.delete(end);
    }
  }
  return result;
}

function isBeamableEntry(entry) {
  return !entry.note.rest && isBeamableValue(entry.value);
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

function createTuplets(VF, vexNotes, system, document) {
  if (document.feel !== 'triplet' || typeof VF.Tuplet !== 'function') return [];
  const tuplets = [];
  for (let index = 0; index < vexNotes.length;) {
    const value = system.entries[index]?.value;
    const config = tupletConfigForValue(value);
    if (config == null) {
      index += 1;
      continue;
    }

    const entries = system.entries.slice(index, index + config.groupSize);
    if (entries.length < config.groupSize) break;
    if (!entries.every((entry) => entry.value === value)) {
      index += 1;
      continue;
    }

    tuplets.push(new VF.Tuplet(
      vexNotes.slice(index, index + config.groupSize),
      {
        num_notes: config.numNotes,
        notes_occupied: config.notesOccupied,
      },
    ));
    index += config.groupSize;
  }
  return tuplets;
}

function tupletConfigForValue(value) {
  if (value === '8n') {
    return { groupSize: 3, numNotes: 3, notesOccupied: 2 };
  }
  if (value === '16n') {
    return { groupSize: 6, numNotes: 6, notesOccupied: 4 };
  }
  return null;
}

function drawTuplets(context, tuplets) {
  tuplets.forEach((tuplet) => {
    if (typeof tuplet.setContext === 'function') {
      tuplet.setContext(context);
    }
    if (typeof tuplet.draw === 'function') {
      tuplet.draw();
    }
  });
}

function appendStickingLabels(host, VF, vexNotes, system, layout) {
  const labels = vexNotes
    .map((note, index) => ({
      text: note.__drumcabularyStickingLabel,
      x: eventCenterX(VF, note),
      entry: system.entries[index],
    }))
    .filter((label) =>
      label.text != null &&
      label.text !== '' &&
      Number.isFinite(label.x) &&
      label.entry?.note?.rest !== true,
    );
  if (labels.length === 0) return;

  const y = stickingLabelY(vexNotes, layout);
  appendSvgTextElements(
    host,
    labels.map((label) => ({
      text: label.text,
      x: label.x,
      y,
    })),
  );
}

function appendOpenHiHatMarkers(host, VF, vexNotes, system, layout) {
  const markers = vexNotes
    .flatMap((note, index) =>
      openHiHatMarkersForEntry(host, VF, note, system.entries[index], layout),
    )
    .filter((marker) =>
      Number.isFinite(marker.x) &&
      Number.isFinite(marker.y),
    );
  if (markers.length === 0) return;
  appendSvgCircleElements(host, markers);
}

function openHiHatMarkersForEntry(host, VF, note, entry, layout) {
  const voices = entry?.note?.voices;
  if (entry?.note?.rest === true || !Array.isArray(voices)) return [];
  return voices
    .map((voice, voiceIndex) => {
      if (voice !== 'openHiHat') return null;
      const anchors = noteAnchorsForVoice(host, VF, note, voiceIndex, layout);
      const center = pointAbove(
        anchors.notehead.top,
        OPEN_HIHAT_MARKER_RADIUS + OPEN_HIHAT_MARKER_CLEARANCE,
      );
      return {
        x: center.x,
        y: center.y,
        radius: OPEN_HIHAT_MARKER_RADIUS,
      };
    })
    .filter((marker) => marker != null);
}

function noteAnchorsForVoice(host, VF, note, voiceIndex, layout) {
  return {
    staff: staffAnchorsForLayout(layout),
    notehead: noteheadAnchorsForVoice(host, VF, note, voiceIndex, layout),
  };
}

function noteheadAnchorsForVoice(host, VF, note, voiceIndex, layout) {
  const visualBounds = noteheadVisualBounds(
    host,
    noteheadForVoice(note, voiceIndex),
  );
  const center = {
    x: visualBounds?.center?.x ?? noteheadCenterX(VF, note, voiceIndex),
    y: visualBounds?.center?.y ?? noteheadCenterY(note, voiceIndex, layout),
  };
  const size = visualBounds?.size ?? noteheadSize(note, voiceIndex);
  const halfWidth = size.width / 2;
  const halfHeight = size.height / 2;
  const bounds = {
    x: center.x - halfWidth,
    y: center.y - halfHeight,
    width: size.width,
    height: size.height,
  };
  return {
    center,
    top: { x: center.x, y: bounds.y },
    bottom: { x: center.x, y: bounds.y + bounds.height },
    left: { x: bounds.x, y: center.y },
    right: { x: bounds.x + bounds.width, y: center.y },
    bounds,
  };
}

function staffAnchorsForLayout(layout) {
  return {
    staveTop: layout.y,
    selectionTop: layout.y + SELECTION_EVENT_TOP_FROM_STAVE_TOP,
    selectionBottom:
      layout.y + SELECTION_EVENT_TOP_FROM_STAVE_TOP + SELECTION_EVENT_HEIGHT,
    stickingFallbackY: layout.y - STICKING_LABEL_FALLBACK_GAP_ABOVE_STAVE,
  };
}

function selectionBoundsForLayout(layout) {
  const staff = staffAnchorsForLayout(layout);
  return {
    y: staff.selectionTop,
    height: staff.selectionBottom - staff.selectionTop,
  };
}

function pointAbove(anchor, gap) {
  return {
    x: anchor.x,
    y: anchor.y - gap,
  };
}

function noteheadCenterY(note, voiceIndex, layout) {
  const ys = noteYPositions(note);
  if (ys.length > 0) {
    const voiceY = ys[voiceIndex];
    if (Number.isFinite(voiceY)) return voiceY;
    const topY = Math.min(...ys.filter((value) => Number.isFinite(value)));
    if (Number.isFinite(topY)) return topY;
  }
  const noteHead = noteheadForVoice(note, voiceIndex);
  if (Number.isFinite(noteHead?.y)) return noteHead.y;
  return staffAnchorsForLayout(layout).selectionTop;
}

function noteYPositions(note) {
  if (typeof note?.getYs !== 'function') return [];
  try {
    const ys = note.getYs();
    return Array.isArray(ys)
      ? ys.filter((value) => Number.isFinite(value))
      : [];
  } catch {
    return [];
  }
}

function noteheadCenterX(VF, note, voiceIndex) {
  const noteHead = noteheadForVoice(note, voiceIndex);
  const noteHeadX = noteHeadCenterX(noteHead);
  if (Number.isFinite(noteHeadX)) return noteHeadX;

  const bounds = noteheadHorizontalBounds(note);
  if (bounds != null) return bounds.x + bounds.width / 2;

  return eventCenterX(VF, note);
}

function noteheadSize(note, voiceIndex) {
  const noteHead = noteheadForVoice(note, voiceIndex);
  const width = noteheadWidth(noteHead) ?? noteheadHorizontalBounds(note)?.width;
  const normalizedWidth = Number.isFinite(width) && width > 0
    ? width
    : FALLBACK_NOTEHEAD_SIZE;
  return {
    width: normalizedWidth,
    height: normalizedWidth,
  };
}

function noteheadWidth(noteHead) {
  if (noteHead == null) return null;
  try {
    const width =
      typeof noteHead.getGlyphWidth === 'function'
        ? noteHead.getGlyphWidth()
        : noteHead.width;
    return Number.isFinite(width) && width > 0 ? width : null;
  } catch {
    return null;
  }
}

function noteheadHorizontalBounds(note) {
  const begin = noteheadBoundaryX(note, 'getNoteHeadBeginX');
  const end = noteheadBoundaryX(note, 'getNoteHeadEndX');
  if (Number.isFinite(begin) && Number.isFinite(end) && end > begin) {
    return {
      x: begin,
      width: end - begin,
    };
  }
  return null;
}

function noteheadForVoice(note, voiceIndex) {
  const noteHeads = note?._noteHeads;
  if (!Array.isArray(noteHeads)) return null;
  return noteHeads[voiceIndex] ?? null;
}

function noteheadVisualBounds(host, noteHead) {
  try {
    const element = noteheadSvgElement(host, noteHead);
    if (element == null || typeof element.getBBox !== 'function') return null;
    const box = element.getBBox();
    if (
      !Number.isFinite(box?.x) ||
      !Number.isFinite(box?.y) ||
      !Number.isFinite(box?.width) ||
      !Number.isFinite(box?.height) ||
      box.width <= 0 ||
      box.height <= 0
    ) {
      return null;
    }
    return {
      center: {
        x: box.x + box.width / 2,
        y: box.y + box.height / 2,
      },
      size: {
        width: box.width,
        height: box.height,
      },
    };
  } catch {
    return null;
  }
}

function noteheadSvgElement(host, noteHead) {
  if (noteHead == null) return null;
  if (typeof noteHead.getSVGElement === 'function') {
    try {
      const element = noteHead.getSVGElement();
      if (element != null) return element;
    } catch {
      // Fall through to searching the renderer host.
    }
  }
  if (typeof host?.querySelector !== 'function') return null;
  const id =
    typeof noteHead.getAttribute === 'function'
      ? noteHead.getAttribute('id')
      : null;
  if (id == null || id === '') return null;
  try {
    return host.querySelector(`#vf-${id}`);
  } catch {
    return null;
  }
}

function noteHeadCenterX(noteHead) {
  if (noteHead == null) return Number.NaN;
  try {
    const x =
      typeof noteHead.getAbsoluteX === 'function'
        ? noteHead.getAbsoluteX()
        : noteHead.x;
    const xShift =
      typeof noteHead.getXShift === 'function'
        ? noteHead.getXShift()
        : noteHead.x_shift ?? 0;
    const width = noteheadWidth(noteHead);
    if (Number.isFinite(x) && Number.isFinite(width)) {
      return x + (Number.isFinite(xShift) ? xShift : 0) + width / 2;
    }
  } catch {
    return Number.NaN;
  }
  return Number.NaN;
}

function noteheadBoundaryX(note, methodName) {
  if (typeof note?.[methodName] !== 'function') return Number.NaN;
  try {
    const value = note[methodName]();
    return Number.isFinite(value) ? value : Number.NaN;
  } catch {
    return Number.NaN;
  }
}

function eventCenterX(VF, note) {
  if (typeof note?.getCenterGlyphX === 'function') {
    const value = note.getCenterGlyphX();
    if (Number.isFinite(value)) return value;
  }
  if (typeof note?.getModifierStartXY === 'function') {
    const position = VF.ModifierPosition?.ABOVE ?? VF.Modifier?.Position?.ABOVE;
    if (position != null) {
      try {
        const point = note.getModifierStartXY(position, 0);
        if (Number.isFinite(point?.x)) return point.x;
      } catch {
        // Fall through to the absolute-x fallback.
      }
    }
  }
  if (typeof note?.getAbsoluteX === 'function') {
    try {
      const absoluteX = note.getAbsoluteX();
      const xShift =
        typeof note.getXShift === 'function' ? note.getXShift() : 0;
      const glyphWidth =
        typeof note.getGlyphWidth === 'function' ? note.getGlyphWidth() : 0;
      const x = absoluteX + xShift + glyphWidth / 2;
      if (Number.isFinite(x)) return x;
    } catch {
      return Number.NaN;
    }
  }
  return Number.NaN;
}

function stickingLabelY(vexNotes, layout) {
  const noteYs = vexNotes
    .map((note) => {
      if (typeof note.getYForTopText !== 'function') return Number.NaN;
      try {
        return note.getYForTopText(0);
      } catch {
        return Number.NaN;
      }
    })
    .filter((value) => Number.isFinite(value));
  if (noteYs.length > 0) {
    return Math.min(...noteYs) - STICKING_LABEL_GAP_ABOVE_TOP_TEXT;
  }
  return staffAnchorsForLayout(layout).stickingFallbackY;
}

function appendSvgTextElements(host, labels) {
  const svg = host.querySelector('svg');
  if (svg == null) return;

  if (typeof document !== 'undefined' && typeof svg.appendChild === 'function') {
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    group.setAttribute('class', 'drum-sticking-labels');
    group.setAttribute('font-family', STICKING_FONT_FAMILY);
    group.setAttribute('font-size', String(STICKING_FONT_SIZE));
    group.setAttribute('font-weight', STICKING_FONT_WEIGHT || 'normal');
    group.setAttribute('fill', 'currentColor');
    group.setAttribute('text-anchor', 'middle');
    labels.forEach((label) => {
      const text = document.createElementNS('http://www.w3.org/2000/svg', 'text');
      text.setAttribute('x', formatSvgNumber(label.x));
      text.setAttribute('y', formatSvgNumber(label.y));
      text.textContent = label.text;
      group.appendChild(text);
    });
    svg.appendChild(group);
    return;
  }

  if (typeof svg.outerHTML !== 'string') return;
  const text = `<g class="drum-sticking-labels" font-family="${escapeXmlAttribute(
    STICKING_FONT_FAMILY,
  )}" font-size="${STICKING_FONT_SIZE}" font-weight="${escapeXmlAttribute(
    STICKING_FONT_WEIGHT || 'normal',
  )}" fill="currentColor" text-anchor="middle">${labels
    .map((label) => (
      `<text x="${formatSvgNumber(label.x)}" y="${formatSvgNumber(label.y)}">${escapeXmlText(
        label.text,
      )}</text>`
    ))
    .join('')}</g>`;
  svg.outerHTML = svg.outerHTML.replace('</svg>', `${text}</svg>`);
}

function appendSvgCircleElements(host, markers) {
  const svg = host.querySelector('svg');
  if (svg == null) return;

  if (typeof document !== 'undefined' && typeof svg.appendChild === 'function') {
    const group = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    group.setAttribute('class', 'drum-open-hihat-markers');
    group.setAttribute('fill', 'none');
    group.setAttribute('stroke', 'currentColor');
    group.setAttribute('stroke-width', formatSvgNumber(OPEN_HIHAT_MARKER_STROKE_WIDTH));
    markers.forEach((marker) => {
      const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
      circle.setAttribute('cx', formatSvgNumber(marker.x));
      circle.setAttribute('cy', formatSvgNumber(marker.y));
      circle.setAttribute('r', formatSvgNumber(marker.radius));
      group.appendChild(circle);
    });
    svg.appendChild(group);
    return;
  }

  if (typeof svg.outerHTML !== 'string') return;
  const circles = `<g class="drum-open-hihat-markers" fill="none" stroke="currentColor" stroke-width="${formatSvgNumber(
    OPEN_HIHAT_MARKER_STROKE_WIDTH,
  )}">${markers
    .map((marker) => (
      `<circle cx="${formatSvgNumber(marker.x)}" cy="${formatSvgNumber(marker.y)}" r="${formatSvgNumber(
        marker.radius,
      )}"></circle>`
    ))
    .join('')}</g>`;
  svg.outerHTML = svg.outerHTML.replace('</svg>', `${circles}</svg>`);
}

function formatSvgNumber(value) {
  return Number(value).toFixed(2).replace(/\.?0+$/, '');
}

function escapeXmlText(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');
}

function escapeXmlAttribute(value) {
  return escapeXmlText(value)
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function formatterWidthForSystem(system, options, context = {}) {
  const groupGap = groupGapForSystem(system, options);
  const startReserve = startReserveForSystem(options, context);
  const maxWidth = options.formatterWidth ?? options.measureWidth;
  const availableFormatterWidth = Math.max(
    24,
    maxWidth - groupGap - startReserve,
  );
  const densityFormatterWidth = Math.max(
    24,
    intrinsicSystemWidth(system, options) - groupGap,
  );
  return Math.max(
    24,
    Math.min(availableFormatterWidth, densityFormatterWidth),
  );
}

function intrinsicSystemWidth(system, options) {
  return system.entries.length * options.noteSpacing + options.systemEndReserve;
}

function startReserveForSystem(options, context) {
  if (context.systemIndex !== 0) return 0;
  if (context.document?.timeSignature == null) return 0;
  const reserve = Number(options.timeSignatureReserve);
  return Number.isFinite(reserve) && reserve > 0 ? reserve : 0;
}

function applyGroupSpacing(vexNotes, system, options) {
  const gap = normalizedGroupGap(options);
  if (gap <= 0 || system.beamBreaks.size === 0) return;
  const breaks = [...system.beamBreaks]
    .filter((index) => index > 0 && index < vexNotes.length)
    .sort((left, right) => left - right);
  if (breaks.length === 0) return;

  let breakIndex = 0;
  let xShift = 0;
  for (let noteIndex = 0; noteIndex < vexNotes.length; noteIndex += 1) {
    while (breakIndex < breaks.length && breaks[breakIndex] === noteIndex) {
      xShift += gap;
      breakIndex += 1;
    }
    if (xShift <= 0 || typeof vexNotes[noteIndex].setXShift !== 'function') {
      continue;
    }
    const existing =
      typeof vexNotes[noteIndex].getXShift === 'function'
        ? vexNotes[noteIndex].getXShift()
        : 0;
    vexNotes[noteIndex].setXShift(existing + xShift);
  }
}

function groupGapForSystem(system, options) {
  return [...system.beamBreaks].filter(
    (index) => index > 0 && index < system.entries.length,
  ).length * normalizedGroupGap(options);
}

function normalizedGroupGap(options) {
  const gap = Number(options.groupGap);
  return Number.isFinite(gap) && gap > 0 ? gap : 0;
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
  if (options.preserveMeasures === true) {
    return document.measures.map((measure, measureIndex) => {
      const measureEntries = entries.filter(
        (entry) => entry.measureIndex === measureIndex,
      );
      return systemForEntries(measureEntries, grouping, { preserveMeasure: true });
    });
  }
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

function systemForEntries(entries, grouping, options = {}) {
  return {
    entries,
    beamBreaks: beamBreaksForEntries(entries, grouping),
    preserveMeasure: options.preserveMeasure === true,
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

function noteMetadataForEntry(entry, layout) {
  const sticking = entry.note.sticking == null
    ? entry.note.sticking
    : String(entry.note.sticking).toUpperCase();
  const staff = staffAnchorsForLayout(layout);
  const selectionBounds = selectionBoundsForLayout(layout);
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
    selection: {
      bounds: selectionBounds,
      horizontalPadding: SELECTION_EVENT_HORIZONTAL_PADDING,
      anchors: {
        staff,
      },
    },
  };
}

function systemLayoutForIndex(index, options) {
  return {
    x: options.staffX,
    y: options.staffY + index * options.systemGapY,
    isSystemStart: true,
  };
}

function numBeatsForSystem(system, document) {
  return timeSignatureNumerator(document.timeSignature);
}

function beatValueForSystem(system, document) {
  return timeSignatureDenominator(document.timeSignature);
}

function timeSignatureNumerator(timeSignature) {
  const value = Number(String(timeSignature).split('/')[0]);
  return Number.isFinite(value) && value > 0 ? value : 4;
}

function timeSignatureDenominator(timeSignature) {
  const value = Number(String(timeSignature).split('/')[1]);
  return Number.isFinite(value) && value > 0 ? value : 4;
}

function resolvedNoteForEntry(entry, document) {
  return {
    ...entry.note,
    value: entry.value ?? document.subdivision,
  };
}

function createDetachedHost() {
  if (typeof document !== 'undefined') {
    const host = document.createElement('div');
    host.style.position = 'absolute';
    host.style.left = '-10000px';
    host.style.top = '-10000px';
    host.style.width = '1px';
    host.style.height = '1px';
    host.style.overflow = 'visible';
    host.style.pointerEvents = 'none';
    host.style.visibility = 'hidden';
    host.dataset.drumcabularyDetachedNotationHost = 'true';
    document.body?.appendChild(host);
    return host;
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

function disposeDetachedHost(host) {
  if (
    host?.dataset?.drumcabularyDetachedNotationHost === 'true' &&
    typeof host.remove === 'function'
  ) {
    host.remove();
  }
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
