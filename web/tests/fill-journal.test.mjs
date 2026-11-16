import test from 'node:test';
import assert from 'node:assert/strict';
import { FILL_SIZE, findFillRuns, includesFillPoint, validFillRuns } from '../fill.mjs';
import { readState, persistState, STORAGE_KEY, makeBackup, validateBackup } from '../data.mjs';

const makeImage=()=>{
 const width=FILL_SIZE,height=FILL_SIZE,data=new Uint8ClampedArray(width*height*4);
 for(let i=0;i<data.length;i+=4)data.set([255,255,255,255],i);
 return {width,height,data};
};
const rect=(img,x0,y0,x1,y1)=>{
 for(let x=x0;x<=x1;x++)for(const y of [y0,y1]){const i=(y*FILL_SIZE+x)*4;img.data[i]=0;img.data[i+1]=0;img.data[i+2]=0}
 for(let y=y0;y<=y1;y++)for(const x of [x0,x1]){const i=(y*FILL_SIZE+x)*4;img.data[i]=0;img.data[i+1]=0;img.data[i+2]=0}
};
test('tap fill stays inside a closed black-line shape',()=>{
 const img=makeImage();rect(img,80,80,180,180);
 const runs=findFillRuns(img,120,120);
 assert.ok(validFillRuns(runs));assert.ok(includesFillPoint(runs,120,120));
 assert.equal(includesFillPoint(runs,10,10),false);
 assert.equal(includesFillPoint(runs,81,120),false,'dark-line margin remains unfilled');
});
test('background fill does not cross a closed outline',()=>{
 const img=makeImage();rect(img,80,80,180,180);
 const runs=findFillRuns(img,15,15);
 assert.ok(runs.length>0);assert.equal(includesFillPoint(runs,120,120),false);
});
test('taps on dark ink and out of bounds fail safely',()=>{
 const img=makeImage();rect(img,80,80,180,180);
 assert.throws(()=>findFillRuns(img,80,100),/white area/);
 assert.throws(()=>findFillRuns(img,-1,300),/inside/);
 assert.throws(()=>findFillRuns({width:1,height:1,data:[]},0,0),/could not be read/);
});
test('old drawing and monthly journal backup still work alongside new daily entries',()=>{
 const old={notes:{'2026-11':'Older note'},drawings:{'2026-11-season':{strokes:[{tool:'pen',color:'#123456',width:5,points:[[1,2],[3,4]]}]}}};
 const store=new Map([[STORAGE_KEY,JSON.stringify(old)]]);
 const storage={getItem:k=>store.get(k)??null,setItem:(k,v)=>store.set(k,String(v))};
 const initial=readState(storage);assert.equal(initial.error,null);
 const newer=structuredClone(initial.state);
 newer.journalEntries['2026-11-16']='Dear Journal, today I colored a picture.';
 const img=makeImage();rect(img,80,80,180,180);
 newer.drawings['2026-11-season'].strokes.push({tool:'fill',color:'#33aaff',width:1,points:[[120*1000/FILL_SIZE,120*1000/FILL_SIZE]],runs:findFillRuns(img,120,120)});
 assert.ok(persistState(storage,newer,initial.raw).ok);
 const after=readState(storage);
 assert.equal(after.state.notes['2026-11'],'Older note');
 assert.equal(after.state.journalEntries['2026-11-16'],newer.journalEntries['2026-11-16']);
 assert.deepEqual(after.state.drawings['2026-11-season'].strokes[0],old.drawings['2026-11-season'].strokes[0]);
 const backup=makeBackup(after.state);assert.equal(backup.version,1);
 assert.equal(validateBackup(backup).ok,true);
 assert.deepEqual(validateBackup(backup).data.drawings['2026-11-season'].strokes[1].runs,newer.drawings['2026-11-season'].strokes[1].runs);
});
test('malformed fill data and invalid journal dates are rejected before restore',()=>{
 const data={drawings:{'2026-11-season':{strokes:[{tool:'fill',color:'#f00',width:1,points:[[1,1]],runs:[[0,0,513]]}]}}};
 assert.equal(validateBackup(makeBackup(data)).ok,false);
 assert.equal(validateBackup(makeBackup({journalEntries:{'2026-02-30':'Impossible'}})).ok,false);
 assert.equal(validateBackup(makeBackup({journalEntries:{'2026-11-16':42}})).ok,false);
});
