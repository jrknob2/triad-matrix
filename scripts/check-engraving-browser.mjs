import { spawn } from 'node:child_process';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
const chrome=process.env.CHROME_BIN ?? '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const profile=await mkdtemp(join(tmpdir(),'drumcabulary-lab-'));
const server=spawn(process.execPath,['web/sheet_notation/server.mjs'],{env:{...process.env,PORT:'0'},stdio:['ignore','pipe','inherit']});
try {
  const port=await new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>reject(new Error('Server startup timed out')),10000);
    server.once('error',reject);
    server.stdout.on('data',data=>{const match=String(data).match(/127\.0\.0\.1:(\d+)/);if(match){clearTimeout(timer);resolve(match[1]);}});
  });
  const output=await new Promise((resolve,reject)=>{
    const child=spawn(chrome,['--headless','--disable-gpu',`--user-data-dir=${profile}`,
      '--dump-dom','--virtual-time-budget=10000',`http://127.0.0.1:${port}/lab/engraving_lab.html?selftest=1`]);
    let dom=''; let errors='';
    const timer=setTimeout(()=>{child.kill();reject(new Error('Chrome test timed out'));},30000);
    child.once('error',reject);
    child.stdout.on('data',chunk=>{dom+=chunk;}); child.stderr.on('data',chunk=>{errors+=chunk;});
    child.once('close',code=>{clearTimeout(timer); code===0?resolve(dom):reject(new Error(`Chrome exit ${code}: ${errors}`));});
  });
  if(!output.includes('data-selftest="passed"')) {
    throw new Error(output.match(/<pre id="selftest-result">([\s\S]*?)<\/pre>/)?.[1] ?? 'Browser checks did not finish. Check browser module loading.');
  }
  console.log('Real VexFlow browser checks passed: 14 rendered cases, unsupported case, width rerender, live selection geometry, reset and SVG export availability.');
} finally {
  server.kill();
  await rm(profile,{recursive:true,force:true,maxRetries:5,retryDelay:200});
}
