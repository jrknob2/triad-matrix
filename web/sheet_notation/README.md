# Drumcabulary Sheet Notation Runtime

This folder implements the sheet-notation runtime for the Drumcabulary notation
language.

The notation language itself is defined in one place:

- `../../docs/18_NOTATION_LANGUAGE_CONTRACT.md`

The app rendering pipeline is defined in:

- `../../docs/19_NOTATION_RENDERING_PIPELINE_DESIGN.md`

Do not redefine notation grammar, token meaning, grouping behavior, voice
labels, durations, triplet behavior, or YAML authoring rules in this README.
Do not redefine Flutter/WebView/PDF pipeline ownership here. Update the relevant
contract first, then update this runtime and its tests.

## Runtime Scope

The renderer accepts render-ready JSON and returns SVG markup.

Runtime responsibilities:

- validate render-ready notation documents
- map Drumcabulary voices and durations to VexFlow concepts
- render SVG sheet notation
- expose metadata for interactive WebView use
- support generated WebView bundle output

Runtime exclusions:

- lesson YAML schema ownership
- product flow ownership
- progress tracking
- assessment
- user recommendation logic
- notation-language contract ownership

## Files

- `types.d.ts`: JSON contract types for the runtime API.
- `document.js`: render-document parsing and validation.
- `duration.js`: note-value conversion helpers.
- `voice_mapping.js`: drum voice to staff-position mapping.
- `renderer.js`: VexFlow SVG renderer.
- `demo.js`: demo phrase data and render helper.
- `demo.html`: browser demo.
- `server.mjs`: local static server for the demo.
- `app_host.html`: Flutter WebView host page.
- `app_renderer.js`: generated WebView renderer bundle.
- `build_app_renderer_bundle.mjs`: bundle generator for `app_renderer.js`.

Do not edit `app_renderer.js` by hand. Regenerate it from source files with:

```sh
npm run build:sheet-notation-app
```

## Browser Demo

Run the browser demo from the repo root:

```sh
npm run demo:sheet-notation
```

Then open:

```text
http://127.0.0.1:8087/demo.html
```

Do not open `demo.html` directly with `file://`; the demo uses browser ES
modules and should be served over HTTP.

## Runtime API

For browser/WebView usage, load VexFlow globally and call:

```js
window.renderDrumNotationSvg(documentJson);
```

For interactive browser/WebView usage, call:

```js
const { svg, notes } = renderDrumNotationSvgWithMetadata(documentJson, options);
```

The metadata result exposes selectable note information for the Flutter WebView
integration.

## Renderer Options

Common options:

```js
renderDrumNotationSvg(documentJson, {
  availableWidth: container.clientWidth,
  paddingRight: 12,
  notesPerSystem: 'auto',
  grouping: '3535',
  systemGapY: 140,
});
```

Renderer options tune layout only. They do not define notation language rules.

## Stem Mode

The renderer defaults to `stemMode: "single"` for the current proof of concept.
That renders the whole measure as one compact rhythmic voice.

For debugging the raw voice mapping stem directions, pass:

```js
renderDrumNotationSvg(documentJson, { stemMode: 'mapped' });
```

`mapped` mode uses `voice_mapping.js` stem directions and can create separate
up/down visual groupings.
