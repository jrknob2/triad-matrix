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

Accents are shown with the sticking label, for example `^R`, instead of as VexFlow articulations above the note. That keeps them readable when beams and stems are dense.

The default demo uses a shorter staff with compressed spacing:

```js
renderDrumNotationSvg(documentJson, {
  availableWidth: container.clientWidth,
  paddingRight: 12,
  notesPerSystem: 'auto',
  systemGapY: 112,
});
```

`availableWidth` makes the renderer fit the SVG to its container. `measureWidth` can still override staff length when fixed sizing is needed. `formatterWidth` controls note compression inside that staff; if omitted, it is derived from `formatterWidthScale`. `paddingRight` gives trailing modifiers like flams and parentheses room so they do not clip. `notesPerSystem: "auto"` wraps note chunks based on available width and `minNoteWidth`; pass a number to force a specific chunk size. `systemGapY` controls the vertical distance between wrapped staff rows.

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

Ghost note rendering is isolated behind `attachGhost`. When VexFlow exposes `Parenthesis`, `ghost: true` adds left and right parentheses around the notehead while keeping the sticking label plain, for example `L`. If `Parenthesis` is unavailable, the note is marked with `__drumcabularyGhost` rather than failing.

## Stem Mode

The renderer defaults to `stemMode: "single"` for this proof of concept. That renders the whole measure as one compact rhythmic voice, which keeps mixed hand/foot vocabulary readable and keeps sixteenth-note beaming continuous.

If you want to inspect the raw voice mapping stem directions, pass:

```js
renderDrumNotationSvg(documentJson, { stemMode: 'mapped' });
```

`mapped` mode uses the `stemDirection` values in `voice_mapping.js`, which can create separate up/down visual groupings.
