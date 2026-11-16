import test from 'node:test';
import assert from 'node:assert/strict';
import {STORAGE_KEY,RECOVERY_KEY,readState,persistState,makeBackup,validateBackup,overdueTasks,moveUnfinished,validDate} from '../data.mjs';
class MemoryStore{m=new Map();getItem(k){return this.m.has(k)?this.m.get(k):null}setItem(k,v){this.m.set(k,String(v))}}
test('current preview localStorage key stays the same',()=>assert.equal(STORAGE_KEY,'creative-moments-browser-preview-v1'));
test('legacy browser records survive read and export',()=>{const store=new MemoryStore();const old={tasks:{'2026-11':[{title:'Call Mom',done:false}]},notes:{'2026-11':'Test notes'},days:{'2026-11-15':'day'},drawings:{'2026-11-season':{strokes:[{color:'#123456',width:3,points:[[1,2],[4,5]]}],updated:123}},joy:{'2026-11':'joy'},carry:{'2026-11':'later'}};store.setItem(STORAGE_KEY,JSON.stringify(old));const {state,error}=readState(store);assert.equal(error,null);assert.equal(state.notes['2026-11'],'Test notes');assert.deepEqual(state.drawings['2026-11-season'].strokes,old.drawings['2026-11-season'].strokes);const backup=makeBackup(state);const valid=validateBackup(backup);assert.equal(valid.ok,true);assert.equal(valid.data.days['2026-11-15'],'day')});
test('corrupted primary storage is not overwritten by read',()=>{const s=new MemoryStore();s.setItem(STORAGE_KEY,'{bad');const out=readState(s);assert.match(out.error,/NOT overwritten/);assert.equal(s.getItem(STORAGE_KEY),'{bad')});
test('storage quota failure is reported',()=>{const s={setItem(){throw Object.assign(Error('quota'),{name:'QuotaExceededError'})}};const out=persistState(s,{tasks:{}});assert.equal(out.ok,false);assert.match(out.error,/not saved/)});
test('unsupported and invalid backups fail closed',()=>{assert.equal(validateBackup({format:'unexpected',version:1,data:{}}).ok,false);assert.equal(validateBackup({format:'creative-moments-web-backup',version:2,data:{}}).ok,false);assert.equal(validateBackup({format:'creative-moments-web-backup',version:1,data:{tasks:{'2026-11':[{title:'A',dueDate:'2026-02-30'}]}}}).ok,false)});
test('leap-year dates validate',()=>{assert.equal(validDate('2028-02-29'),true);assert.equal(validDate('2027-02-29'),false)});
test('overdue list respects date and completion',()=>{const state={tasks:{'2026-11':[{title:'A',done:false,dueDate:'2026-11-14'},{title:'B',done:false,dueDate:'2026-11-20'},{title:'C',done:true,dueDate:'2026-11-11'},{title:'D',done:false}]}};assert.deepEqual(overdueTasks(state,'2026-11-15').map(t=>t.task.title),['A'])});
test('carry-forward moves unfinished once and preserves done tasks and ID',()=>{const s={tasks:{'2026-10':[{id:'a',title:'A',done:false,dueDate:'2026-10-03'},{id:'b',title:'B',done:true}]}};assert.equal(moveUnfinished(s,'2026-11').moved,1);assert.equal(s.tasks['2026-10'].length,1);assert.equal(s.tasks['2026-11'][0].id,'a');assert.equal(s.tasks['2026-11'][0].dueDate,'2026-11-01');assert.equal(moveUnfinished(s,'2026-11').moved,0);assert.equal(s.tasks['2026-11'].length,1)});
test('prior browser state fails closed if known field types are corrupt, without replacing original bytes',()=>{
 const store=new MemoryStore();const bad='{"tasks":{"2026-11":{"not":"an array"}}}';store.setItem(STORAGE_KEY,bad);
 const result=readState(store);assert.match(result.error,/NOT overwritten/);assert.equal(store.getItem(STORAGE_KEY),bad);
});
test('old unpadded day notes remain readable',()=>{
 const store=new MemoryStore();store.setItem(STORAGE_KEY,JSON.stringify({days:{'2026-11-1':'remembered'}}));
 const result=readState(store);assert.equal(result.error,null);assert.equal(result.state.days['2026-11-1'],'remembered');
});
test('malformed day-key backup fails without normalizing any data',()=>{
 const file={format:'creative-moments-web-backup',version:1,data:{days:{'secret':'do not import'}}};
 assert.equal(validateBackup(file).ok,false);
});
test('move unfinished de-duplicates an existing target ID and removes its old month record',()=>{
 const state={tasks:{'2026-10':[{id:'same',title:'A',done:false}], '2026-11':[{id:'same',title:'A',done:false}]}};
 assert.equal(moveUnfinished(state,'2026-11').moved,0);
 assert.equal(state.tasks['2026-10'].length,0);
 assert.equal(state.tasks['2026-11'].length,1);
});
test('legacy id-less carry-forward moves only once and gives task a stable ID',()=>{
 const state={tasks:{'2026-10':[{title:'Old checklist',done:false}]}};
 assert.equal(moveUnfinished(state,'2026-11').moved,1);
 assert.equal(moveUnfinished(state,'2026-11').moved,0);
 assert.equal(state.tasks['2026-10'].length,0);
 assert.ok(state.tasks['2026-11'][0].id);
});
test('recovery snapshot is a different key from primary state',()=>{
 assert.notEqual(RECOVERY_KEY,STORAGE_KEY);
});

test('stale tab cannot overwrite newer checklist edits without first refreshing',()=>{
 const store=new MemoryStore();
 const original=JSON.stringify({tasks:{'2026-11':[{title:'Original',done:false}]}});
 store.setItem(STORAGE_KEY,original);
 const first=readState(store),second=readState(store);
 assert.equal(first.raw,original);
 const a=structuredClone(first.state);a.tasks['2026-11'].push({title:'Added by tab A',done:false});
 assert.equal(persistState(store,a,first.raw).ok,true);
 const b=structuredClone(second.state);b.tasks['2026-11'].push({title:'Added by tab B',done:false});
 const blocked=persistState(store,b,second.raw);
 assert.equal(blocked.ok,false);assert.equal(blocked.conflict,true);
 assert.equal(JSON.parse(store.getItem(STORAGE_KEY)).tasks['2026-11'][1].title,'Added by tab A');
});
test('stale restore is rejected before replacing work',()=>{
 const store=new MemoryStore();store.setItem(STORAGE_KEY,JSON.stringify({notes:{'2026-11':'current'}}));
 const start=readState(store);
 store.setItem(STORAGE_KEY,JSON.stringify({notes:{'2026-11':'newest'}}));
 const attempted=persistState(store,validateBackup(makeBackup({notes:{'2026-11':'older'}})).data,start.raw);
 assert.equal(attempted.ok,false);assert.equal(attempted.conflict,true);
 assert.match(store.getItem(STORAGE_KEY),/newest/);
});
test('browser storage access denial returns protected read-error state',()=>{
 const storage={getItem(){throw Object.assign(Error('denied'),{name:'SecurityError'})}};
 const result=readState(storage);
 assert.match(result.error,/NOT overwritten/);
 assert.equal(result.raw,undefined);
});
