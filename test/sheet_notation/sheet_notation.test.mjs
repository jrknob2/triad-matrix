import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { parseDrumNotationDocument } from '../../web/sheet_notation/document.js';
import { toVexFlowDuration } from '../../web/sheet_notation/duration.js';
import { demoDocument, renderDemoDrumNotationSvg } from '../../web/sheet_notation/demo.js';
import { createVexFlowNote, renderDrumNotationSvg } from '../../web/sheet_notation/renderer.js';
import { voiceMappingFor } from '../../web/sheet_notation/voice_mapping.js';
import { createFakeVexFlow } from './fake_vexflow.mjs';

const VALID_DOCUMENT = {
  timeSignature: '4/4',
  measures: [
    {
      notes: [
        { value: '16n', voices: ['snare'], sticking: 'R' },
        { value: '16n', voices: ['snare'], sticking: 'L', accent: true },
        { value: '16n', voices: ['kick'], sticking: 'K' },
        { value: '16n', rest: true, sticking: '-' },
      ],
    },
  ],
};

describe('sheet notation document parsing', () => {
  test('valid document parsing', () => {
    const parsed = parseDrumNotationDocument(VALID_DOCUMENT);

    assert.equal(parsed.timeSignature, '4/4');
    assert.equal(parsed.measures.length, 1);
    assert.equal(parsed.measures[0].notes.length, 4);
    assert.deepEqual(parsed.measures[0].notes[0].voices, ['snare']);
  });

  test('error handling for unknown voice', () => {
    assert.throws(
      () =>
        parseDrumNotationDocument({
          timeSignature: '4/4',
          measures: [{ notes: [{ value: '16n', voices: ['cowbell'] }] }],
        }),
      /unknown: cowbell/,
    );
  });

  test('error handling for unsupported note value', () => {
    assert.throws(
      () =>
        parseDrumNotationDocument({
          timeSignature: '4/4',
          measures: [{ notes: [{ value: '64n', voices: ['snare'] }] }],
        }),
      /unsupported: 64n/,
    );
  });
});

describe('duration conversion', () => {
  test('duration conversion', () => {
    assert.equal(toVexFlowDuration('1n'), 'w');
    assert.equal(toVexFlowDuration('2n'), 'h');
    assert.equal(toVexFlowDuration('4n'), 'q');
    assert.equal(toVexFlowDuration('8n'), '8');
    assert.equal(toVexFlowDuration('16n'), '16');
    assert.equal(toVexFlowDuration('32n'), '32');
  });

  test('rest rendering conversion', () => {
    assert.equal(toVexFlowDuration('4n', { rest: true }), 'qr');
    assert.equal(toVexFlowDuration('16n', { rest: true }), '16r');
  });

  test('unsupported duration throws', () => {
    assert.throws(() => toVexFlowDuration('64n'), /Unsupported drum note value/);
  });
});

describe('voice mapping and VexFlow conversion', () => {
  test('voice mapping lookup', () => {
    assert.equal(voiceMappingFor('crash').notehead, 'x');
    assert.equal(voiceMappingFor('hihat').notehead, 'x');
    assert.equal(voiceMappingFor('ride').notehead, 'x');
    assert.equal(voiceMappingFor('snare').key, 'c/5');
    assert.equal(voiceMappingFor('tom1').key, 'd/5');
    assert.equal(voiceMappingFor('tom2').key, 'a/4');
    assert.equal(voiceMappingFor('floorTom').key, 'g/4');
    assert.equal(voiceMappingFor('kick').key, 'f/4');
    assert.equal(voiceMappingFor('kick').stemDirection, -1);
  });

  test('multi-voice note conversion', () => {
    const VF = createFakeVexFlow();
    const note = createVexFlowNote(VF, {
      value: '16n',
      voices: ['snare', 'kick'],
      sticking: 'RK',
    });

    assert.deepEqual(note.options.keys, ['c/5', 'f/4']);
    assert.equal(note.options.duration, '16');
    assert.equal(note.options.stem_direction, 1);
  });

  test('mapped stem mode can use the voice mapping directions', () => {
    const VF = createFakeVexFlow();
    const note = createVexFlowNote(
      VF,
      {
        value: '16n',
        voices: ['snare', 'kick'],
        sticking: 'RK',
      },
      { stemMode: 'mapped' },
    );

    assert.equal(note.options.stem_direction, -1);
  });

  test('cymbal voices render with x noteheads', () => {
    const VF = createFakeVexFlow();
    const hihat = createVexFlowNote(VF, {
      value: '16n',
      voices: ['hihat'],
      sticking: 'HH',
    });
    const crash = createVexFlowNote(VF, {
      value: '16n',
      voices: ['crash'],
      sticking: 'C',
    });
    const ride = createVexFlowNote(VF, {
      value: '16n',
      voices: ['ride'],
      sticking: 'R',
    });

    assert.equal(hihat.options.type, 'x');
    assert.equal(crash.options.type, 'x');
    assert.equal(ride.options.type, 'x');
  });

  test('sticking label attachment', () => {
    const VF = createFakeVexFlow();
    const note = createVexFlowNote(VF, {
      value: '16n',
      voices: ['snare'],
      sticking: 'R',
    });

    assert.equal(note.modifiers.length, 1);
    assert.equal(VF.calls.annotations[0].text, 'R');
    assert.equal(VF.calls.annotations[0].verticalJustification, 'bottom');
  });

  test('accent appears with the sticking label', () => {
    const VF = createFakeVexFlow();
    const note = createVexFlowNote(VF, {
      value: '16n',
      voices: ['crash'],
      sticking: 'X',
      accent: true,
    });

    assert.equal(note.modifiers.length, 1);
    assert.equal(VF.calls.annotations[0].text, '^X');
    assert.equal(VF.calls.articulations.length, 0);
  });

  test('ghost notes parenthesize the notehead, not the sticking label', () => {
    const VF = createFakeVexFlow();
    const note = createVexFlowNote(VF, {
      value: '16n',
      voices: ['snare'],
      sticking: 'L',
      ghost: true,
    });

    assert.equal(VF.calls.annotations[0].text, 'L');
    assert.deepEqual(
      VF.calls.parentheses.map((parenthesis) => parenthesis.position),
      ['left', 'right'],
    );
    assert.equal(note.modifiers[1].modifier, VF.calls.parentheses[0]);
    assert.equal(note.modifiers[2].modifier, VF.calls.parentheses[1]);
    assert.equal(note.__drumcabularyGhost, true);
  });

  test('flam attachment supports VexFlow modifier fallback', () => {
    const VF = createFakeVexFlow();
    VF.GraceNoteGroup = class GraceNoteGroup {
      constructor(notes, slur) {
        this.notes = notes;
        this.slur = slur;
      }

      beamNotes() {
        this.beamed = true;
      }
    };

    const note = createVexFlowNote(VF, {
      value: '16n',
      voices: ['snare'],
      sticking: 'F',
      flam: true,
    });

    assert.equal(note.graceNoteGroup.notes.length, 1);
    assert.equal(note.graceNoteGroup.beamed, true);
    assert.equal(note.modifiers.at(-1).modifier, note.graceNoteGroup);
  });
});

describe('svg rendering', () => {
  test('renders svg markup with fake VexFlow', () => {
    const VF = createFakeVexFlow();
    const svg = renderDrumNotationSvg(VALID_DOCUMENT, { vexFlow: VF });

    assert.match(svg, /^<svg /);
    assert.equal(VF.calls.staves[0].timeSignature, '4/4');
    assert.equal(VF.calls.notes.length, 4);
  });

  test('demo document matches the requested phrase and voices', () => {
    const document = demoDocument();
    const notes = document.measures[0].notes;

    assert.equal(document.measures.length, 2);
    assert.deepEqual(
      notes.map((note) => notationLabelFor(note)).join(''),
      '^R^L^R(L)(L)K^R^L^R(L)(L)FTHH^CF',
    );
    assert.deepEqual(
      notes.map((note) => note.voices.join('+')),
      [
        'snare',
        'snare',
        'snare',
        'snare',
        'snare',
        'kick',
        'tom1',
        'tom1',
        'tom2',
        'snare',
        'snare',
        'floorTom',
        'hihat',
        'crash',
        'snare',
      ],
    );
    assert.ok(notes.every((note) => note.value === '16n'));
    assert.equal(notes[14].flam, true);
  });

  test('demo renders sixteen-note phrase as svg', () => {
    const VF = createFakeVexFlow();
    const svg = renderDemoDrumNotationSvg({ vexFlow: VF });

    assert.match(svg, /^<svg /);
    assert.match(svg, /width="660"/);
    assert.match(svg, /height="248"/);
    assert.equal(VF.calls.notes.length, 30);
    assert.equal(VF.calls.annotations.length, 30);
    assert.equal(VF.calls.notes[14].graceNoteGroup.notes.length, 1);
    assert.equal(VF.calls.notes[29].graceNoteGroup.notes.length, 1);
    assert.equal(VF.calls.staves.length, 2);
    assert.equal(VF.calls.staves[0].width, 640);
    assert.equal(VF.calls.staves[0].x, 8);
    assert.equal(VF.calls.staves[0].y, 10);
    assert.equal(VF.calls.staves[1].x, 8);
    assert.equal(VF.calls.staves[1].y, 122);
    assert.equal(VF.calls.staves[0].clef, 'percussion');
    assert.equal(VF.calls.staves[0].timeSignature, '4/4');
    assert.equal(VF.calls.staves[1].clef, 'percussion');
    assert.equal(VF.calls.staves[1].timeSignature, undefined);
    assert.equal(VF.calls.staves[1].endBarType, 5);
    assert.equal(VF.calls.voices[0].formatterWidth, 538);
    assert.equal(VF.calls.voices[1].formatterWidth, 538);
  });

  test('availableWidth fits each wrapped system to a narrow container', () => {
    const VF = createFakeVexFlow();
    const svg = renderDemoDrumNotationSvg({ vexFlow: VF, availableWidth: 340 });

    assert.match(svg, /width="340"/);
    assert.equal(VF.calls.staves.length, 5);
    for (const stave of VF.calls.staves) {
      assert.equal(stave.x, 8);
      assert.equal(stave.width, 320);
    }
    assert.equal(VF.calls.beams.length, 5);
    assert.equal(VF.calls.beams[0].notes.length, 7);
    assert.equal(VF.calls.beams[1].notes.length, 7);
    assert.equal(VF.calls.beams[2].notes.length, 7);
    assert.equal(VF.calls.beams[3].notes.length, 7);
    assert.equal(VF.calls.beams[4].notes.length, 2);
    assert.equal(VF.calls.voices[0].formatterWidth, 266);
    assert.equal(VF.calls.voices[4].formatterWidth, 96);
  });

  test('default demo uses one compact rhythmic voice for sixteenth beaming', () => {
    const VF = createFakeVexFlow();
    renderDemoDrumNotationSvg({ vexFlow: VF });

    assert.equal(VF.calls.beams.length, 2);
    assert.equal(VF.calls.beams[0].notes.length, 15);
    assert.equal(VF.calls.beams[1].notes.length, 15);
    assert.equal(VF.calls.beams[0].render_options.flat_beams, true);
    assert.ok(
      VF.calls.events.indexOf('beam:create') <
        VF.calls.events.indexOf('voice:draw'),
    );
    assert.ok(
      VF.calls.events.indexOf('voice:draw') <
        VF.calls.events.indexOf('beam:draw'),
    );
    for (const note of VF.calls.beams[0].notes) {
      assert.equal(note.beam, VF.calls.beams[0]);
    }
    for (const note of VF.calls.notes) {
      assert.equal(note.options.stem_direction, 1);
    }
  });

  test('notesPerSystem can control responsive note chunks', () => {
    const VF = createFakeVexFlow();
    const svg = renderDemoDrumNotationSvg({ vexFlow: VF, notesPerSystem: 10 });

    assert.match(svg, /width="660"/);
    assert.match(svg, /height="360"/);
    assert.equal(VF.calls.staves.length, 3);
    assert.equal(VF.calls.beams[0].notes.length, 10);
    assert.equal(VF.calls.beams[1].notes.length, 10);
    assert.equal(VF.calls.beams[2].notes.length, 10);
  });

  test('mapped stem mode beams do not cross mixed stem directions', () => {
    const VF = createFakeVexFlow();
    renderDemoDrumNotationSvg({ vexFlow: VF, stemMode: 'mapped' });

    assert.ok(VF.calls.beams.length > 1);
    for (const beam of VF.calls.beams) {
      const directions = new Set(
        beam.notes.map((note) => note.options.stem_direction),
      );
      assert.equal(directions.size, 1);
    }
  });
});

function notationLabelFor(note) {
  if (note.ghost) return `(${note.sticking})`;
  if (note.accent) return `^${note.sticking}`;
  return note.sticking;
}
