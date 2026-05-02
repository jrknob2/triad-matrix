import { renderDrumNotationSvg } from './renderer.js';

export function demoDocument() {
  const sticking = ['R', 'L', 'K', 'R', 'L', 'K', 'R', 'L', 'K', 'R', 'L', 'K', 'L', 'R', 'K', 'L'];
  return {
    timeSignature: '4/4',
    measures: [
      {
        notes: sticking.map((label) => ({
          value: '16n',
          voices: [label === 'K' ? 'kick' : 'snare'],
          sticking: label,
        })),
      },
    ],
  };
}

export function renderDemoDrumNotationSvg(options = {}) {
  return renderDrumNotationSvg(demoDocument(), options);
}
