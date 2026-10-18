import assert from 'node:assert/strict';
import { test } from 'node:test';
import { engravingCases } from '../../web/sheet_notation/lab/engraving_cases.js';
import { createLabSession } from '../../web/sheet_notation/lab/engraving_lab_state.js';
import { renderDrumNotationSvgWithMetadata } from '../../web/sheet_notation/renderer.js';
import { createFakeVexFlow } from './fake_vexflow.mjs';

test('reference registry is deterministic, uniquely identified and immutable',()=>{
  assert.equal(engravingCases.length,15);
  assert.equal(new Set(engravingCases.map(c=>c.id)).size,15);
  assert.ok(Object.isFrozen(engravingCases[0].input.document.measures[0].notes));
  for(const c of engravingCases) {
    assert.ok(c.description && c.input.document && c.expected.status);
    if(c.expected.status==='unsupported') assert.ok(c.expected.reason);
  }
});
for(const c of engravingCases) {
  test(`engraving reference: ${c.id}`,()=>{
    const original=JSON.stringify(c);
    let calls=0; let fake;
    const session=createLabSession((doc,options)=>{
      calls++; fake=createFakeVexFlow();
      return renderDrumNotationSvgWithMetadata(doc,{...options,vexFlow:fake});
    });
    const output=session.render(c);
    assert.equal(output.status,c.expected.status);
    if(c.expected.status==='unsupported') {
      assert.equal(calls,0); assert.ok(output.reason); assert.equal(output.svg,undefined);
    } else {
      assert.match(output.svg,/<svg/);
      assert.equal(output.notes.length,c.expected.noteCount);
      assert.equal(fake.calls.notes.length,c.expected.noteCount);
      if(c.expected.tupletCount!==undefined) assert.equal(fake.calls.tuplets.length,c.expected.tupletCount);
      if(c.expected.restCount!==undefined) assert.equal(output.notes.filter(n=>n.rest).length,c.expected.restCount);
      if(c.expected.voicesPerEvent) assert.ok(output.notes.every(n=>n.voices.length===c.expected.voicesPerEvent));
      assert.deepEqual([...output.notes.map(n=>n.index)].sort((a,b)=>a-b),Array.from({length:c.expected.noteCount},(_,i)=>i));
    }
    assert.equal(JSON.stringify(c),original,'render must not mutate fixture');
  });
}
test('width changes rerender through the real entry point and preserve note semantics',()=>{
  const seen=[];
  const session=createLabSession((doc,options)=>{
    seen.push(options.availableWidth);
    return renderDrumNotationSvgWithMetadata(doc,{...options,vexFlow:createFakeVexFlow()});
  });
  const c=engravingCases[0];
  const a=session.render(c,{availableWidth:560});
  const b=session.render(c,{availableWidth:1200});
  assert.deepEqual(seen,[560,1200]); assert.equal(b.renderCount,2);
  assert.notEqual(a.svg,b.svg);
  assert.deepEqual(a.notes.map(n=>n.voices),b.notes.map(n=>n.voices));
  assert.throws(()=>session.render(c,{availableWidth:NaN}),/Width/);
});
