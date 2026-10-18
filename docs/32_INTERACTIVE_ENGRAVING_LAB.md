# Interactive Engraving Lab — Pass 3A

Development-only browser diagnostics. No production navigation, renderer,
notation grammar, canonical adapter, playback, LED or persistence changes.
Lab assets live in `web/sheet_notation/lab/`, a subdirectory not included by
the current Flutter asset declarations, which list the runtime root and vendor
directory explicitly.

## Launch from VS Code

Open this repository folder in VS Code and use **Terminal → New Terminal**:

```sh
npm run demo:sheet-notation
```

Open **http://127.0.0.1:8087/lab/engraving_lab.html** in your browser. VS Code can also
open it with **Simple Browser: Show** from the command palette. Stop the server
with Ctrl+C. The existing demo remains at `/demo.html` and remains the root page.
If dependencies are missing, run `npm install` first. The lab itself loads the
already-vendored `web/sheet_notation/vendor/vexflow.js`, with no CDN or framework.
`PORT=8088 npm run demo:sheet-notation` selects a different port when needed.
Do not open the HTML via `file://`; ES modules require the local HTTP server.

## Use and inspect

1. Select a deterministic reference case. Read its description and expected
   properties; open the input disclosure to see the exact render-ready JSON.
2. Change width (280–2000 SVG units) and leave the field, or press Render / Refresh.
   Each change calls the actual renderer again; it does not scale old SVG.
3. Toggle existing show-sticking, stem-mode or preserve-measures options.
   Preserve-measures can intentionally prevent automatic system reflow.
4. Click a rendered event, Tab/Enter on an SVG event, or use the source-index
   selector. Inspect source index, source measure/note index, voices, resolved
   note value, available sticking/articulation and measured SVG bounds.
5. Reset defaults restores width 900, sticking shown, single stems and automatic
   reflow for the currently selected case.
6. Save SVG downloads the unmodified renderer result, without the lab selection
   overlay or focus attributes. Compare snapshots manually at the same width and
   options. There are no pixel-perfect screenshot assertions.

Geometry is measured on the live VexFlow event group with `getBBox` and SVG
transforms. Local and root-SVG coordinates are identified explicitly. The lab
uses renderer note attributes, or the production WebView host's ordered
`.vf-stavenote` fallback only when its complete count matches renderer metadata.
It does not guess the nearest stem or map individual noteheads to instruments.
Selection highlights the event's measured bounding box.

The renderer's metadata has no canonical event IDs, onset or performed duration.
The inspector explicitly reports those as unavailable. A resolved note value is
shown separately; it is not presented as authoritative timing. Sticking and
articulation are the render document's aggregate fields, not inferred structured
per-voice assignments. Per-voice SVG geometry mapping is also unavailable.

## Reference registry

`web/sheet_notation/lab/engraving_cases.js` is a deeply frozen registry with stable
case IDs, descriptions, input documents/options, expected status and structural
properties. Inputs are render-ready JSON, not invented text syntax.

| ID | Expected behavior |
| --- | --- |
| `money-beat` | 8 eighth events; hi-hat throughout, kick 1/3, snare 2/4 |
| `eighth-sticking` | 8 alternating eighth events |
| `sixteenth-sticking` | 16 alternating sixteenth events |
| `simultaneous` | 4 quarter events, each containing kick/snare/hi-hat |
| `dynamics` | 8 eighth events with explicit accents and ghosts |
| `group-3` | 16 ordinary sixteenths, existing 3-note layout grouping |
| `group-5` | 16 ordinary sixteenths, existing 5-note layout grouping |
| `group-6` | 16 ordinary sixteenths, existing 6-note layout grouping |
| `group-7` | 16 ordinary sixteenths, existing 7-note layout grouping |
| `cross-beat` | 5 ordinary sixteenths grouped across a quarter boundary |
| `cross-measure` | **Not yet supported**, with explicit reason and no SVG |
| `triplets` | 12 eighth triplets, four actual renderer 3:2 tuplets |
| `mixed-values` | Half + quarter + two eighths |
| `rests` | 8 eighth events, four explicit rests |
| `dense-labels` | 32 thirty-second events with sticking labels |

Pedagogical groups exercise existing spacing/beam breaks only: no new brackets
or tuplets. Five ordinary sixteenths still occupy 5/4 quarter-note beats according
to their source values. The lab does not implement a timing engine to calculate
this during rendering. True triplets use existing `feel: 'triplet'` behavior.

The cross-measure case requests explicit phrase membership straddling two source
measures. The renderer API has no such phrase-group references. Flattening or
reflowing those measures would not establish that support, so the lab declines to
render a substitute. Other groups need not fill the final pedagogical group;
partial groups are intentional.

## Tests and static checks

```sh
npm run test:engraving-lab
npm run test:sheet-notation
npm run test:engraving-browser
```

The first command runs 17 registry/structural tests through the actual renderer
entry point with the existing fake VexFlow test double. The full notation command
includes those tests: **78 tests passed** (61 existing + 17 new).

The browser command launches a temporary localhost server and headless Chrome
against the real vendored VexFlow. It checks all 14 supported SVG outputs and
selectable event counts, explicit unsupported status, fresh rendering on width
changes, actual selection geometry/highlighting, reset, and export availability.
It does not compare pixels or actually trigger a file download. Chrome on macOS
is the default; elsewhere set `CHROME_BIN` to a Chrome/Chromium executable:

```sh
CHROME_BIN=/path/to/chromium npm run test:engraving-browser
```

The script removes its temporary browser profile and stops its temporary server.
If Chrome is unavailable, structural tests still run; browser validation must be
reported as not run rather than claimed as passing.

Syntax-check new JS/MJS with `node --check <file>`. All new JS/MJS files and the
updated server passed syntax checks. Real-browser checks passed. No unrelated
failures occurred in this JavaScript/browser validation. Dart tests were not
rerun because no Dart code or consumers changed.

## Add a reference case

Add an entry to `engraving_cases.js` with a new stable ID, title, description,
render-ready `input.document`, optional existing renderer options and
`expected.status`. Supported cases need `expected.noteCount`; optionally add
`restCount`, `voicesPerEvent` or `tupletCount` (asserted by structural tests).
Unsupported cases need a clear reason and their intended input; do not call the
renderer with an approximation. Update the registry-count assertion and this
case table when adding a case. The browser test automatically exercises every
registry entry. Keep data deterministic; do not use random values or timestamps.

## Integration boundary

The entry point is `renderDrumNotationSvgWithMetadata` from the unchanged
`renderer.js`, which validates with `document.js` and engraves through existing
VexFlow. `types.d.ts` documents the render API; the lab also uses the already
implemented `showSticking` option. No new renderer options are introduced.

`CanonicalMusicalDocument` and `SheetToCanonicalAdapter` remain Dart-only,
opt-in Pass 2 foundations. The lab neither executes that conversion nor creates
a canonical-to-VexFlow bridge. See `31_CANONICAL_MUSICAL_MODEL_CONTRACT.md` for
canonical timing and identity constraints. Pass 3B is not started here.
