// Render-ready JSON fixtures, not a new authored-text parser or canonical adapter.
const snare = (count, value = '16n') => Array.from({ length: count }, (_, i) => ({
  value, voices: ['snare'], sticking: i % 2 ? 'L' : 'R',
}));
const doc = (notes, extra = {}) => ({ timeSignature: '4/4', subdivision: '16n',
  feel: 'straight', measures: [{ notes }], ...extra });
const fixture = (id, title, description, document, options = {}, properties = {}) => ({
  id, title, description, input: { document, options }, expected: {
    status: 'supported', noteCount: document.measures.reduce((sum, m) => sum + m.notes.length, 0),
    ...properties,
  },
});
const grouping = (size) => fixture(`group-${size}`, `${size}-note pedagogical grouping`,
  `Ordinary sixteenths grouped by ${size} using existing beam breaks/spacing. No tuplet bracket or rhythmic scaling.`,
  doc(snare(16)), { grouping: [size], groupGap: 12 }, { tupletCount: 0 });
export const engravingCases = deepFreeze([
  fixture('money-beat', 'Standard money beat', 'Eight hi-hat eighths; kick on beats 1/3, snare on 2/4. No invented hand cues.',
    doc(Array.from({length: 8}, (_, i) => ({ value: '8n', voices: ['hihat',
      ...(i === 0 || i === 4 ? ['kick'] : i === 2 || i === 6 ? ['snare'] : [])] })))),
  fixture('eighth-sticking', 'Eighth-note sticking', 'Eight alternating eighth notes fill 4/4.', doc(snare(8, '8n'))),
  fixture('sixteenth-sticking', 'Sixteenth-note sticking', 'Sixteen alternating sixteenths fill 4/4.', doc(snare(16))),
  fixture('simultaneous', 'Simultaneous kick, snare and hi-hat', 'Four quarter-note events; each event contains all three instruments.',
    doc(Array.from({length:4}, () => ({value:'4n', voices:['kick','snare','hihat']}))), {}, { voicesPerEvent: 3 }),
  fixture('dynamics', 'Accents and ghost notes', 'Alternating hands with explicit aggregate accents/ghosts supported by the render document.',
    doc(snare(8, '8n').map((n,i) => ({...n, accent:i%4 === 0, ghost:i%4 === 2})))),
  grouping(3), grouping(5), grouping(6), grouping(7),
  fixture('cross-beat', 'Grouping across quarter-note beats', 'Five ordinary sixteenths occupy 5/4 beats. Existing layout grouping crosses the quarter boundary; no quintuplet.',
    doc(snare(5)), {grouping:[5], groupGap:12}, {tupletCount:0}),
  {id:'cross-measure', title:'Grouping across measure boundaries',
    description:'An explicit phrase group joining the last two events of measure 1 and first three of measure 2.',
    input:{document:{...doc(snare(16)), measures:[{notes:snare(16)},{notes:snare(16)}]},
      requestedPhraseMembers:[14,15,16,17,18]},
    expected:{status:'unsupported', reason:'The render-document API has no explicit phrase-group membership across measures. Layout grouping cannot represent this faithfully; no substitute rendering is shown.'}},
  fixture('triplets', 'True triplets', 'Twelve eighth-note triplets in 4/4, using the renderer’s existing triplet feel (3:2), independent of pedagogical grouping.',
    doc(snare(12, '8n'), {feel:'triplet'}), {}, {tupletCount:4}),
  fixture('mixed-values', 'Mixed note durations', 'Half + quarter + two eighths fill four beats. Inspect resolved note values.',
    doc(['2n','4n','8n','8n'].map((value,i) => ({value, voices:['snare'], sticking:i%2?'L':'R'})))),
  fixture('rests', 'Rests', 'Alternate sounding eighths and explicit eighth rests.',
    doc(snare(8,'8n').map((n,i) => i%2 ? {value:'8n', rest:true} : n)), {}, {restCount:4}),
  fixture('dense-labels', 'Dense notation with sticking labels', 'Thirty-two 32nds in one measure; resize to test collisions and system wrapping.',
    doc(snare(32,'32n')), {minNoteWidth:32}),
]);
export function deepFreeze(value) {
  if (value && typeof value === 'object') {
    Object.values(value).forEach(deepFreeze);
    Object.freeze(value);
  }
  return value;
}
