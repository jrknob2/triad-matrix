import { renderDrumNotationSvg } from './renderer.js';

export function demoDocument() {
  const wrappedMeasure = [
    { value: '16n', voices: ['snare'], sticking: 'R', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'L', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'R', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'L', ghost: true },
    { value: '16n', voices: ['snare'], sticking: 'L', ghost: true },
    { value: '16n', voices: ['kick'], sticking: 'K' },
    { value: '16n', voices: ['tom1'], sticking: 'R', accent: true },
    { value: '16n', voices: ['tom1'], sticking: 'L', accent: true },
    { value: '16n', voices: ['tom2'], sticking: 'R', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'L', ghost: true },
    { value: '16n', voices: ['snare'], sticking: 'L', ghost: true },
    { value: '16n', voices: ['floorTom'], sticking: 'FT' },
    { value: '16n', voices: ['hihat'], sticking: 'HH' },
    { value: '16n', voices: ['crash'], sticking: 'C', accent: true },
    { value: '16n', voices: ['snare'], sticking: 'F', flam: true },
  ];
  return {
    timeSignature: '4/4',
    measures: [
      { notes: wrappedMeasure },
      { notes: wrappedMeasure },
    ],
  };
}

export function renderDemoDrumNotationSvg(options = {}) {
  return renderDrumNotationSvg(demoDocument(), options);
}
