// Browser-only diagnostic assertions; run against the real vendored VexFlow.
import { engravingCases } from './engraving_cases.js';
const el=id=>document.getElementById(id);
const assert=(condition,message)=>{if(!condition) throw new Error(message);};
const change=id=>el(id).dispatchEvent(new Event('change'));
try {
  let rendered=0;
  for(const c of engravingCases) {
    el('case').value=c.id; change('case');
    const svg=el('preview').querySelector('svg');
    if(c.expected.status==='unsupported') {
      assert(!svg && el('status').textContent.includes('Not yet supported'),c.id+' must not fake output');
      continue;
    }
    assert(svg,c.id+' must render real SVG');
    const diagnostics=JSON.parse(el('diagnostics').textContent);
    assert(diagnostics.actualEventCount===c.expected.noteCount,c.id+' event count');
    assert(svg.querySelectorAll('[data-drum-note-index]').length===c.expected.noteCount,c.id+' selectable geometry count');
    rendered++;
  }
  el('case').value='money-beat'; change('case');
  const before=JSON.parse(el('diagnostics').textContent).renderCount;
  el('width').value='560'; change('width');
  const narrow=el('preview').querySelector('svg');
  const narrowWidth=narrow.getAttribute('width');
  assert(JSON.parse(el('diagnostics').textContent).renderCount===before+1,'width must invoke renderer');
  el('width').value='1200'; change('width');
  assert(el('preview').querySelector('svg')!==narrow,'fresh SVG after resize');
  assert(el('preview').querySelector('svg').getAttribute('width')!==narrowWidth,'fresh SVG width');
  el('preview').querySelector('[data-drum-note-index="2"]').dispatchEvent(new MouseEvent('click',{bubbles:true}));
  const info=JSON.parse(el('inspection').textContent);
  assert(info.sourceNoteIndex===2 && info.geometry.svgBounds.width>0,'selection reads real geometry');
  assert(el('preview').querySelector('.lab-highlight'),'selection highlight');
  assert(info.canonicalEventId.startsWith('Unavailable'),'no fabricated canonical identity');
  el('reset').click(); assert(el('width').value==='900','reset width');
  assert(!el('download').disabled,'SVG snapshot download available');
  document.body.dataset.selftest='passed';
  const result=document.createElement('pre'); result.id='selftest-result'; result.textContent=JSON.stringify({status:'passed',renderedCases:rendered}); document.body.append(result);
} catch(error) {
  document.body.dataset.selftest='failed';
  const result=document.createElement('pre'); result.id='selftest-result'; result.textContent=error.stack; document.body.append(result);
}
