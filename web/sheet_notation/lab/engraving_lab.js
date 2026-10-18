import { engravingCases } from './engraving_cases.js';
import { createLabSession, labDefaults } from './engraving_lab_state.js';
const el = (id) => document.getElementById(id);
const session = createLabSession();
let frame;
let rawSvg;
const show = (id, value) => { el(id).textContent = typeof value === 'string' ? value : JSON.stringify(value,null,2); };
for (const testCase of engravingCases) el('case').add(new Option(testCase.title,testCase.id));
function boundsInSvg(element, svg) {
  const box = element.getBBox();
  const matrix = svg.getScreenCTM().inverse().multiply(element.getScreenCTM());
  const points = [[box.x,box.y],[box.x+box.width,box.y],
    [box.x,box.y+box.height],[box.x+box.width,box.y+box.height]].map(([x,y]) => new DOMPoint(x,y).matrixTransform(matrix));
  const x = Math.min(...points.map(p=>p.x));
  const y = Math.min(...points.map(p=>p.y));
  return {x,y,width:Math.max(...points.map(p=>p.x))-x,height:Math.max(...points.map(p=>p.y))-y};
}
function inspect(index) {
  const note = frame?.notes?.find(n=>n.index === index);
  if (!note) return;
  el('event').value = String(index);
  const svg = el('preview').querySelector('svg');
  svg.querySelector('.lab-highlight')?.remove();
  const node = svg.querySelector(`[data-drum-note-index="${index}"]`);
  let geometry = 'Unavailable: renderer did not emit a selectable SVG element.';
  if (node) {
    try {
      const box = boundsInSvg(node,svg);
      const local = node.getBBox();
      geometry = {element:node.tagName, localBounds:{x:local.x,y:local.y,width:local.width,height:local.height}, svgBounds:box,
        units:'SVG coordinates; measured from the live rendered event group',
        voiceGeometry:'Per-voice geometry mapping is unavailable; bounds cover the event.'};
      const rect = document.createElementNS('http://www.w3.org/2000/svg','rect');
      for(const [key,value] of Object.entries(box)) rect.setAttribute(key,String(value));
      rect.setAttribute('class','lab-highlight'); svg.append(rect);
    } catch(error) { geometry = `Unavailable: ${error.message}`; }
  }
  show('inspection',{sourceNoteIndex:note.index, measureIndex:note.measureIndex,
    measureNoteIndex:note.measureNoteIndex, voices:note.voices, rest:note.rest,
    sticking:note.sticking ?? 'Not authored', articulation:{accent:note.accent,ghost:note.ghost,flam:note.flam,tie:note.tie},
    resolvedNoteValue:note.value, onset:'Unavailable: renderer metadata supplies no musical onset.',
    duration:'Unavailable: resolved note value is present, but no authoritative performed duration is supplied.',
    canonicalEventId:'Unavailable: no canonical mapping or Dart diagnostic conversion is attached.', geometry});
}
export function refresh() {
  const testCase = engravingCases.find(c=>c.id === el('case').value);
  show('title',testCase.title); show('description',testCase.description); show('source',testCase);
  el('preview').replaceChildren(); el('event').replaceChildren(); el('download').disabled = true;
  show('inspection','No event selected.'); rawSvg = null;
  try {
    frame = session.render(testCase,{availableWidth:Number(el('width').value), showSticking:el('sticking').checked,
      stemMode:el('stem').value, preserveMeasures:el('measures').checked});
    if(frame.status === 'unsupported') {
      show('status',`Not yet supported — ${frame.reason}`); show('diagnostics',{status:frame.status,reason:frame.reason}); return;
    }
    rawSvg = frame.svg;
    el('preview').innerHTML = rawSvg;
    // Match the production WebView host's ordered StaveNote fallback. Only map
    // when the complete geometry count matches the renderer metadata count.
    const svg = el('preview').querySelector('svg');
    const attributed = svg.querySelectorAll('[data-drum-note-index]');
    const fallback = svg.querySelectorAll('.vf-stavenote');
    if (attributed.length === 0 && fallback.length === frame.notes.length) {
      fallback.forEach((node, index) => node.setAttribute('data-drum-note-index', String(frame.notes[index].index)));
    }

    show('status',`Rendered ${frame.notes.length} events · render ${frame.renderCount} · width ${frame.options.availableWidth}`);
    show('diagnostics',{status:frame.status,renderCount:frame.renderCount,options:frame.options,
      expected:testCase.expected, actualEventCount:frame.notes.length,
      canonicalMapping:'Unavailable. This lab exercises render-ready JSON directly, not CanonicalMusicalDocument.',
      limitations:'Articulation/sticking are render-document aggregates. No per-voice structured sticking is inferred. Grouping is existing layout spacing/beaming, not phrase brackets.'});
    for(const note of frame.notes) el('event').add(new Option(`${note.index}: ${note.rest?'rest':note.voices.join(' + ')}`,String(note.index)));
    for(const node of el('preview').querySelectorAll('[data-drum-note-index]')) {
      node.setAttribute('tabindex','0'); node.setAttribute('role','button');
      node.setAttribute('aria-label',`Inspect source event ${node.getAttribute('data-drum-note-index')}`);
      const select = () => inspect(Number(node.getAttribute('data-drum-note-index')));
      node.addEventListener('click',select);
      node.addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();select();}});
    }
    el('download').disabled = false;
    if(frame.notes.length) inspect(frame.notes[0].index);
  } catch(error) {
    frame = null; show('status',`Render failed: ${error.message}`); show('diagnostics',error.stack ?? error.message);
  }
}
el('controls').addEventListener('submit',e=>{e.preventDefault();refresh();});
for(const id of ['case','width','stem','sticking','measures']) el(id).addEventListener('change',refresh);
el('event').addEventListener('change',()=>inspect(Number(el('event').value)));
el('reset').addEventListener('click',()=>{
  el('width').value=labDefaults.availableWidth; el('stem').value=labDefaults.stemMode;
  el('sticking').checked=labDefaults.showSticking; el('measures').checked=labDefaults.preserveMeasures; refresh();
});
el('download').addEventListener('click',()=>{
  if(!rawSvg) return;
  const url=URL.createObjectURL(new Blob([rawSvg],{type:'image/svg+xml'}));
  const a=document.createElement('a'); a.href=url; a.download=`${el('case').value}-${el('width').value}.svg`; a.click();
  setTimeout(()=>URL.revokeObjectURL(url),1000);
});
refresh();
if(new URLSearchParams(location.search).has('selftest')) import('./engraving_lab_checks.js');
