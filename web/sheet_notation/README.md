# Drumcabulary Sheet Notation POC

This folder is a sheet-music-only proof of concept for rendering Drumcabulary notation with VexFlow.

It intentionally excludes:

- tempo
- BPM
- metronome data
- playback
- audio samples
- practice tracking
- app UI state

The renderer accepts render-ready JSON and returns SVG markup.

```js
import { renderDrumNotationSvg } from './renderer.js';

const svg = renderDrumNotationSvg({
  timeSignature: '4/4',
  measures: [
    {
      notes: [
        { value: '16n', voices: ['snare'], sticking: 'R' },
        { value: '16n', voices: ['snare'], sticking: 'L' },
        { value: '16n', voices: ['kick'], sticking: 'K' },
      ],
    },
  ],
});
```

Run the browser demo from the repo root:

```sh
npm run demo:sheet-notation
```

Then open:

```text
http://127.0.0.1:8087/demo.html
```

Do not open `demo.html` directly with `file://`; the demo uses browser ES modules and should be served over HTTP.

For browser/WebView usage, load VexFlow globally and call:

```js
window.renderDrumNotationSvg(documentJson);
```

## Files

- `types.d.ts`: JSON contract types.
- `document.js`: parsing and validation.
- `duration.js`: Drumcabulary duration to VexFlow duration conversion.
- `voice_mapping.js`: one drum voice mapping table.
- `renderer.js`: VexFlow SVG renderer.
- `demo.js`: demo phrase data and render helper.
- `demo.html`: browser demo using VexFlow from a CDN.
- `server.mjs`: tiny local static server for the demo.

## Flam And Ghost Notes

Flams are isolated behind `attachFlam`. If the loaded VexFlow build does not expose `GraceNote` and `GraceNoteGroup`, the note is marked with an internal `__drumcabularyFlam` flag rather than failing.

Ghost note rendering is isolated behind `attachGhost`. It currently marks the note with `__drumcabularyGhost`; final visual parentheses should be completed against the exact VexFlow version selected for production.
