import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { parseDrumNotationDocument } from '../../web/sheet_notation/document.js';
import { toVexFlowDuration } from '../../web/sheet_notation/duration.js';
import { renderDemoDrumNotationSvg } from '../../web/sheet_notation/demo.js';
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
    assert.equal(voiceMappingFor('snare').key, 'c/5');
    assert.equal(voiceMappingFor('kick').stemDirection, -1);
  });

  test('multi-voice note conversion', () => {
    const VF = createFakeVexFlow();
    const note = createVexFlowNote(VF, {
      value: '16n',
      voices: ['snare', 'kick'],
      sticking: 'RK',
    });

    assert.deepEqual(note.options.keys, ['c/5', 'f/3']);
    assert.equal(note.options.duration, '16');
    assert.equal(note.options.stem_direction, -1);
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

  test('accent attachment', () => {
    const VF = createFakeVexFlow();
    const note = createVexFlowNote(VF, {
      value: '16n',
      voices: ['crash'],
      sticking: 'X',
      accent: true,
    });

    assert.equal(note.modifiers.length, 2);
    assert.equal(VF.calls.articulations[0].type, 'a>');
    assert.equal(VF.calls.articulations[0].position, 'above');
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

  test('demo renders sixteen-note phrase as svg', () => {
    const VF = createFakeVexFlow();
    const svg = renderDemoDrumNotationSvg({ vexFlow: VF });

    assert.match(svg, /^<svg /);
    assert.equal(VF.calls.notes.length, 16);
    assert.equal(VF.calls.annotations.length, 16);
  });

  test('beams do not cross mixed stem directions', () => {
    const VF = createFakeVexFlow();
    renderDemoDrumNotationSvg({ vexFlow: VF });

    assert.ok(VF.calls.beams.length > 1);
    for (const beam of VF.calls.beams) {
      const directions = new Set(
        beam.notes.map((note) => note.options.stem_direction),
      );
      assert.equal(directions.size, 1);
    }
  });
});
