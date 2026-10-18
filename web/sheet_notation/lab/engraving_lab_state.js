import { renderDrumNotationSvgWithMetadata } from '../renderer.js';
export const labDefaults = Object.freeze({ availableWidth: 900, showSticking: true,
  stemMode: 'single', preserveMeasures: false });
export function createLabSession(render = renderDrumNotationSvgWithMetadata) {
  let renderCount = 0;
  return {
    render(testCase, controls = {}) {
      if (testCase.expected.status === 'unsupported') {
        return {status:'unsupported', reason:testCase.expected.reason, renderCount};
      }
      const options = {...labDefaults, ...testCase.input.options, ...controls};
      if (!Number.isFinite(options.availableWidth) || options.availableWidth < 280 || options.availableWidth > 2000) {
        throw new Error('Width must be between 280 and 2000 SVG units.');
      }
      renderCount += 1;
      const output = render(testCase.input.document, options);
      return {status:'supported', ...output, renderCount, options};
    },
  };
}
