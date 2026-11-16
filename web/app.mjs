import { STORAGE_KEY, RECOVERY_KEY, monthKey, validDate, readState, persistState, makeBackup, validateBackup, overdueTasks, moveUnfinished } from './data.mjs';

const MONTHS=['January','February','March','April','May','June','July','August','September','October','November','December'];
const THEMES=['Winter Stillness','Quiet Connections','Fresh Beginnings','Rain & Renewal','In Full Bloom','Lakeside Light','Coastal Calm','Golden Fields','Orchard Abundance','Autumn Color','A Quiet Pause','Winter Wonder'];
const TYPES={season:'Color the season',sketch:'Sketch an idea',patterns:'Explore patterns',free:'Free doodle'};
const getDayKey=date=>`${date.getFullYear()}-${String(date.getMonth()+1).padStart(2,'0')}-${String(date.getDate()).padStart(2,'0')}`;
const today=()=>getDayKey(new Date());
const storage=(()=>{try{return globalThis.localStorage}catch{return {getItem(){throw Error('Storage access denied')},setItem(){throw Error('Storage access denied')}}}})();
const stored=readState(storage);
let lastStoredRaw=stored.raw;
let externalUpdate=false;
let state=stored.state;
let storageBlocked=!!stored.error;
let error=stored.error;
let screen='home';
let selected=new Date(new Date().getFullYear(),new Date().getMonth(),1);
let editDay=null;
let drawMode='season',brushColor='#764880',brushSize=6,brushTool='pen';
let strokes=[],redoStack=[],pointerMap=new Map(),activeStroke=null,zoom=1,panX=0,panY=0,gesture=null;
let editorCanvas=null,editorCtx=null,editorLayer=null;
const app=document.getElementById('app');
const printable=document.getElementById('print-sheet');
function node(tag,cls='',value){const x=document.createElement(tag);if(cls)x.className=cls;if(value!==undefined)x.textContent=String(value);return x}
function add(parent,...children){for(const c of children)if(c!==null&&c!==undefined)parent.append(c);return parent}
function btn(label,onClick,cls='button'){const x=node('button',cls,label);x.type='button';x.onclick=onClick;return x}
function label(textValue,control){const x=node('label','label',textValue);if(control)x.htmlFor=control;return x}
function input(type='text',id='',value=''){const x=node('input','input');x.type=type;x.value=value??'';if(id)x.id=id;return x}
function region(cls='panel'){return node('section',cls)}
function sceneSrc(month){return `/assets/scene-${String(month).padStart(2,'0')}.webp`}
function currentMonth(){return monthKey(selected.getFullYear(),selected.getMonth()+1)}
function currentCaption(){return `${MONTHS[selected.getMonth()]} ${selected.getFullYear()}`}
function uniqueID(){return typeof crypto?.randomUUID==='function'?crypto.randomUUID():`${Date.now()}-${Math.random().toString(36).slice(2)}`}
function commit(change){
 if(storageBlocked){showError(error||'Data storage is locked. No change was saved.');return false}
 if(externalUpdate){showError('This planner changed in another tab. Reload the page before editing to prevent overwriting those changes.');return false}
 const next=structuredClone(state);
 try{change(next)}catch(e){showError('The change could not be applied.');return false}
 const result=persistState(storage,next,lastStoredRaw);
 if(!result.ok){if(result.conflict)externalUpdate=true;showError(result.error);return false}
 state=next;lastStoredRaw=JSON.stringify(next);error=null;const status=document.getElementById('save-status');if(status){status.textContent='Saved on this device';status.className='status'}return true;
}
function showError(message){error=message;const status=document.getElementById('save-status');if(status){status.textContent=message;status.className='status bad'}else alert(message)}
function showStatus(message){const status=document.getElementById('save-status');if(status){status.textContent=message;status.className='status'}}
function navigate(to){screen=to;editDay=null;render();window.scrollTo({top:0,behavior:'instant'})}
function monthStep(n){selected=new Date(selected.getFullYear(),selected.getMonth()+n,1);render()}
function shell(title,subtitle){
 app.replaceChildren();const root=node('div','app');const hd=node('header','topbar');
 if(screen!=='home')hd.append(btn('‹ Home',()=>navigate('home'),'back'));
 add(hd,node('div','logo','CM'));
 const brand=node('div','app-title');add(brand,node('strong','',title),node('small','',subtitle||'Plan · Create · Reflect'));hd.append(brand);
 hd.append(node('span','pill','WEB APP'));root.append(hd);
 const main=node('main','body');main.id='main';root.append(main);app.append(root);
 return main;
}
function notice(main){
 const panel=node('div','notice');panel.textContent='Your entries stay in this browser on this device. Use Backup & Restore to keep a separate copy. Nothing syncs automatically.';
 main.append(panel);
 if(error){const e=node('div','notice error',error);e.setAttribute('role','alert');main.append(e)}
 if(externalUpdate)main.append(btn('Reload latest saved work',()=>location.reload(),'button secondary'));
}
function monthChooser(main){
 const bar=region('panel flex between');const left=node('div','flex');add(left,btn('‹',()=>monthStep(-1),'button secondary small'),node('h2','month-name',currentCaption()),btn('›',()=>monthStep(1),'button secondary small'));bar.append(left);
 bar.append(btn('Today',()=>{selected=new Date(new Date().getFullYear(),new Date().getMonth(),1);render()},'button outline small'));main.append(bar);
}
function editable(parent,title,field,key,rows=4){
 const wrap=node('div','field'),id=`field-${field}-${key}`;
 const ta=node('textarea','textarea');ta.id=id;ta.rows=rows;ta.value=state[field]?.[key]||'';ta.placeholder='Write here…';
 ta.addEventListener('input',()=>{commit(s=>{s[field][key]=ta.value})});
 add(wrap,label(title,id),ta);parent.append(wrap);return ta;
}
function home(){
 const main=shell('Creative Moments','Your space to plan, create, and reflect');
 add(main,node('h1','','Creative Moments'),node('p','lead','Make time for your plans, ideas, and creativity.'));notice(main);
 const grid=node('div','cards');[
 ['▦','My Planner','Calendars, today, and checklists','planner'],
 ['✎','Color & Draw','Seasonal art and freehand drawing','draw'],
 ['▤','My Journal','Notes, joy, and reflections','journal'],
 ['▧','My Creations','Find and reopen your drawings','gallery']
 ].forEach(([symbol,title,caption,go])=>{const c=node('button','card');c.type='button';add(c,node('span','symbol',symbol),node('b','',title),node('span','',caption));c.onclick=()=>navigate(go);grid.append(c)});main.append(grid);
 const footer=region('panel soft');add(footer,node('h3','','Your work, your space'),node('p','muted','No sign-in. Save a backup to keep your writing and artwork safe.'),btn('Backup & Restore',()=>navigate('backup'),'button secondary'));main.append(footer);
 {const status=node('div','status',error||'Saved locally on this device');status.id='save-status';main.append(status)}
}
function photoCover(main){
 const panel=region();panel.append(node('h3','','My personalized cover'));
 const layout=node('div','cover');const img=node('img');img.alt='Your cover image';img.src=state.coverImage||'/assets/scene-01.webp';const body=node('div','cover-content');
 const title=input('text','cover-name',state.coverName||'My Creative Moments');title.maxLength=100;title.oninput=()=>commit(s=>{s.coverName=title.value});
 const imageInput=input('file');imageInput.accept='image/png,image/jpeg,image/webp';imageInput.className='backup-input';imageInput.id='photo-picker';
 imageInput.onchange=async()=>{const file=imageInput.files?.[0];if(!file)return;if(file.size>15*1024*1024){alert('Choose a photo under 15 MB.');return}try{const data=await resizePhoto(file);if(commit(s=>{s.coverImage=data})){img.src=data;showStatus('Cover photo saved')}}catch(e){showError('Could not load that photo. Try a JPG or PNG.')}};
 const actions=node('div','flex');const choose=btn('Choose photo',()=>imageInput.click(),'button secondary small');const remove=btn('Remove photo',()=>{if(!state.coverImage)return;if(confirm('Remove your current cover photo?')){if(commit(s=>{s.coverImage=''}))img.src='/assets/scene-01.webp'}},'button outline small');add(actions,choose,remove,imageInput);
 add(body,label('Cover title','cover-name'),title,actions);add(layout,img,body);panel.append(layout);main.append(panel);
}
async function resizePhoto(file){return new Promise((resolve,reject)=>{const object=URL.createObjectURL(file);const img=new Image();img.onload=()=>{try{const c=document.createElement('canvas');c.width=750;c.height=750;const ctx=c.getContext('2d');const s=Math.max(750/img.naturalWidth,750/img.naturalHeight);ctx.drawImage(img,(750-img.naturalWidth*s)/2,(750-img.naturalHeight*s)/2,img.naturalWidth*s,img.naturalHeight*s);resolve(c.toDataURL('image/jpeg',.78))}catch(e){reject(e)}finally{URL.revokeObjectURL(object)}};img.onerror=()=>{URL.revokeObjectURL(object);reject(Error('Image not decoded'))};img.src=object})}
function planner(){
 const main=shell('My Planner','Calendars · Checklists · Today');notice(main);
 const top=node('div','flex');add(top,btn('Today & overdue',()=>navigate('today'),'button'),btn('Backup & Restore',()=>navigate('backup'),'button secondary'));main.append(top);
 photoCover(main);monthChooser(main);
 const record=currentMonth();const panel=region();panel.append(node('h2','',`My checklist · ${MONTHS[selected.getMonth()]}`));
 const itemList=node('div','stack');renderTaskList(itemList,record);
 const addform=node('div','field');const newTitle=input('text','new-task');newTitle.placeholder='New task';newTitle.maxLength=2000;
 const due=input('date','new-due');due.setAttribute('aria-label','Optional due date');
 const entry=node('div','entry');const addTask=()=>{const title=newTitle.value.trim();if(!title)return;const date=due.value;if(date&&!validDate(date)){alert('Please choose a valid date.');return}if(commit(s=>{if(!Array.isArray(s.tasks[record]))s.tasks[record]=[];s.tasks[record].push({id:uniqueID(),title,done:false,dueDate:date})})){newTitle.value='';due.value='';renderTaskList(itemList,record)}};
 newTitle.addEventListener('keydown',e=>{if(e.key==='Enter')addTask()});add(entry,newTitle,due,btn('Add',addTask));add(addform,label('Add a task (date optional)','new-task'),entry);add(panel,itemList,addform);
 const prevDate=new Date(selected.getFullYear(),selected.getMonth()-1,1),prevKey=monthKey(prevDate.getFullYear(),prevDate.getMonth()+1);const outstanding=(state.tasks[prevKey]||[]).filter(t=>!t.done).length;
 if(outstanding){const carry=btn(`Move ${outstanding} unfinished task${outstanding===1?'':'s'} from ${MONTHS[prevDate.getMonth()]}`,()=>{if(!confirm(`Move unfinished tasks from ${MONTHS[prevDate.getMonth()]} into ${currentCaption()}? Completed tasks will stay behind.`))return;const count=outstanding;if(commit(s=>moveUnfinished(s,record))){render();showStatus(`Moved ${count} task${count===1?'':'s'}`)}},'button outline');panel.append(carry)}main.append(panel);
 const cal=region();cal.append(node('h2','','Calendar notes'));const days=node('div','weekgrid');
 ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'].forEach(d=>days.append(node('div','weekday',d)));
 const first=(new Date(selected.getFullYear(),selected.getMonth(),1).getDay()+6)%7;for(let b=0;b<first;b++)days.append(node('span'));
 const maxDays=new Date(selected.getFullYear(),selected.getMonth()+1,0).getDate();for(let day=1;day<=maxDays;day++){
 const k=`${record}-${String(day).padStart(2,'0')}`;const oldK=`${record}-${day}`;
 const d=btn(String(day),()=>{editDay=day;render()},'day'+(state.days[k]||state.days[oldK]?' marked':'')+(k===today()?' today':''));d.setAttribute('aria-label',`Edit notes for ${MONTHS[selected.getMonth()]} ${day}`);days.append(d)}cal.append(days);main.append(cal);
 if(editDay){const daypanel=region();const key=`${record}-${String(editDay).padStart(2,'0')}`;const legacyKey=`${record}-${editDay}`;const area=node('textarea','textarea');area.value=state.days[key]??state.days[legacyKey]??'';area.setAttribute('aria-label','Notes for selected day');area.oninput=()=>commit(s=>{s.days[key]=area.value});add(daypanel,node('h3','',`${MONTHS[selected.getMonth()]} ${editDay}`),area,btn('Done',()=>{editDay=null;render()},'button secondary'));main.append(daypanel);requestAnimationFrame(()=>daypanel.scrollIntoView({block:'nearest',behavior:'smooth'}))}
 const focus=region();focus.append(node('h2','','Monthly focus'));editable(focus,'What matters this month?', 'focus',record);main.append(focus);
 const actions=node('div','flex print-actions');add(actions,btn('Print / Save PDF',printMonth,'button secondary'),btn('Write in My Journal',()=>navigate('journal'),'button outline'));main.append(actions);
 {const status=node('div','status','Saved locally on this device');status.id='save-status';status.setAttribute('role','status');main.append(status)}
}
function renderTaskList(list,key){list.replaceChildren();const items=state.tasks[key]||[];if(!items.length)list.append(node('p','muted','No tasks yet. Add one below.'));
 items.forEach((item,index)=>{const line=node('div','task');const checkbox=input('checkbox');checkbox.className='';checkbox.checked=!!item.done;checkbox.setAttribute('aria-label',`Complete ${item.title}`);checkbox.onchange=()=>{if(commit(s=>{s.tasks[key][index].done=checkbox.checked}))renderTaskList(list,key)};
 const content=node('div','task-copy'+(item.done?' done':''));content.append(node('span','',item.title));if(item.dueDate)content.append(node('small','due',`Due ${item.dueDate}`));const edit=btn('Edit',()=>taskDialog(key,index),'button secondary small');edit.setAttribute('aria-label',`Edit ${item.title}`);const del=btn('×',()=>{if(confirm(`Delete "${item.title}"?`)){if(commit(s=>s.tasks[key].splice(index,1)))renderTaskList(list,key)}},'button outline small');del.setAttribute('aria-label',`Delete ${item.title}`);add(line,checkbox,content,edit,del);list.append(line)})}
function taskDialog(key,index){const original=state.tasks[key]?.[index];if(!original)return;const dlg=node('dialog','dialog');dlg.setAttribute('aria-label','Edit task');
 dlg.append(node('h2','','Edit task'));const f1=node('div','field'),title=input('text','edit-title',original.title);title.maxLength=2000;add(f1,label('Task','edit-title'),title);const f2=node('div','field'),due=input('date','edit-due',original.dueDate||'');add(f2,label('Due date (optional)','edit-due'),due);const actions=node('div','dialog-actions');add(actions,btn('Cancel',()=>dlg.close(),'button outline'),btn('Save changes',()=>{const name=title.value.trim();if(!name){title.focus();return}if(due.value&&!validDate(due.value)){alert('Select a valid date.');return}if(commit(s=>{s.tasks[key][index].title=name;s.tasks[key][index].dueDate=due.value})){dlg.close();render()}},'button'));add(dlg,f1,f2,actions);document.body.append(dlg);dlg.addEventListener('close',()=>dlg.remove());dlg.showModal();title.focus()}
function todayScreen(){const main=shell('Today & overdue','Your dated tasks');notice(main);const tasks=overdueTasks(state,today());main.append(node('h2','',new Date().toLocaleDateString(undefined,{weekday:'long',month:'long',day:'numeric'})));
 if(!tasks.length)main.append(node('div','panel','No tasks due or overdue today.'));
 else{const groups=new Map();tasks.forEach(x=>{const due=x.task.dueDate;let arr=groups.get(due)||[];arr.push(x);groups.set(due,arr)});for(const [date,items] of groups){const box=region('panel todaybox');box.append(node('h3','',date===today()?'Due today':`Overdue · ${date}`));const list=node('div','stack');items.forEach(({month,task})=>{const record=state.tasks[month]||[];const ix=record.findIndex(t=>t===task||t.id&&t.id===task.id);if(ix<0)return;const row=node('div','task');const ck=input('checkbox');ck.checked=!!task.done;ck.setAttribute('aria-label',`Complete ${task.title}`);ck.onchange=()=>{if(commit(s=>s.tasks[month][ix].done=ck.checked))render()};const title=node('div','task-copy');add(title,node('strong','',task.title),node('small','due',`${month} planner`));add(row,ck,title,btn('Edit',()=>taskDialog(month,ix),'button secondary small'));list.append(row)});box.append(list);main.append(box)}}
 const help=region();add(help,node('p','muted','Only tasks with due dates appear here. Tasks without dates stay in their month checklist.'),btn('Open My Planner',()=>navigate('planner'),'button secondary'));main.append(help)}
function journal(){const main=shell('My Journal','Write · Remember · Reflect');notice(main);monthChooser(main);const box=region();box.append(node('h2','',`A quiet moment · ${THEMES[selected.getMonth()]}`));const key=currentMonth();editable(box,'Notes & inspiration','notes',key,6);editable(box,'Something I enjoyed creating','joy',key,4);editable(box,'An idea to carry forward','carry',key,4);{const status=node('div','status','Saved locally on this device');status.id='save-status';status.setAttribute('role','status');box.append(status)}main.append(box);main.append(btn('View this month in My Planner',()=>navigate('planner'),'button secondary'))}
function drawSelection(){
 const main=shell('Color & Draw','Seasonal pictures and doodles');notice(main);monthChooser(main);
 main.append(node('h2','','Choose how to create'));const choices=node('div','art-options');for(const [key,title] of Object.entries(TYPES))choices.append(btn(title,()=>openEditor(key),'art-choice'));main.append(choices);
 main.append(node('h2','','Seasonal pictures'));const grid=node('div','scene-grid');for(let m=1;m<=12;m++){
 const choice=node('button','scene');choice.type='button';const image=node('img');image.src=sceneSrc(m);image.alt=`${MONTHS[m-1]} coloring illustration`;image.loading='lazy';add(choice,image,node('b','',MONTHS[m-1]));choice.onclick=()=>{selected=new Date(selected.getFullYear(),m-1,1);openEditor('season')};grid.append(choice)}main.append(grid);
}
function drawingKey(){return `${currentMonth()}-${drawMode}`}
function openEditor(mode){drawMode=mode;const d=state.drawings[drawingKey()];strokes=Array.isArray(d?.strokes)?structuredClone(d.strokes):[];redoStack=[];zoom=1;panX=0;panY=0;screen='editor';render()}
function drawStroke(ctx,stroke){if(!stroke||!Array.isArray(stroke.points)||!stroke.points.length)return;
 ctx.save();const erased=stroke.tool==='eraser';ctx.globalCompositeOperation=erased?'destination-out':'source-over';ctx.globalAlpha=stroke.tool==='marker'?.35:1;ctx.strokeStyle=erased?'#000':stroke.color||'#764880';ctx.lineWidth=stroke.width||6;ctx.lineCap='round';ctx.lineJoin='round';ctx.beginPath();const points=stroke.points;ctx.moveTo(points[0][0],points[0][1]);for(let i=1;i<points.length;i++)ctx.lineTo(points[i][0],points[i][1]);if(points.length===1)ctx.lineTo(points[0][0]+.1,points[0][1]+.1);ctx.stroke();ctx.restore()}
function redraw(){if(!editorCtx)return;editorCtx.clearRect(0,0,1000,1000);strokes.forEach(s=>drawStroke(editorCtx,s));if(activeStroke)drawStroke(editorCtx,activeStroke)}
function persistDrawing(){const snapshot=structuredClone(strokes);return commit(s=>{s.drawings[drawingKey()]={strokes:snapshot,updated:Date.now()}})}
function saveDrawing(){if(!persistDrawing())showError('Drawing was not saved. Please export or try again.');else showStatus('Drawing saved on this device')}
function setZoom(){if(editorLayer)editorLayer.style.transform=`translate(${panX}px,${panY}px) scale(${zoom})`}
function drawEditor(){
 const main=shell(TYPES[drawMode],currentCaption());notice(main);
 const top=node('div','flex between');add(top,btn('‹ Color & Draw',()=>navigate('draw'),'button secondary'),node('span','tag','Finger · stylus · mouse'));main.append(top);
 const tools=region();const toolrow=node('div','tools');const choices=[];
 for(const [kind,text] of [['pen','Pen'],['marker','Marker'],['eraser','Eraser']]){const b=btn(text,()=>{brushTool=kind;for(const x of choices){const enabled=x.dataset.tool===kind;x.classList.toggle('active',enabled);x.setAttribute('aria-pressed',String(enabled))}},'tool-button'+(brushTool===kind?' active':''));b.dataset.tool=kind;b.setAttribute('aria-pressed',String(brushTool===kind));choices.push(b);toolrow.append(b)}
 const picker=input('color');picker.className='color';picker.value=brushColor;picker.setAttribute('aria-label','Pen color');picker.oninput=()=>brushColor=picker.value;
 const range=input('range');range.className='range';range.min='2';range.max='30';range.value=brushSize;range.setAttribute('aria-label','Brush width');range.oninput=()=>brushSize=Number(range.value);
 add(toolrow,node('span','tool-label','Color'),picker,node('span','tool-label','Size'),range);tools.append(toolrow);
 const viewport=node('div','canvas-viewport');viewport.setAttribute('aria-label','Drawing area');
 const layer=node('div','art-layer');editorLayer=layer; if(drawMode==='season'){const image=node('img');image.src=sceneSrc(selected.getMonth()+1);image.alt='Seasonal illustration for coloring';image.draggable=false;layer.append(image)}
 const canvas=node('canvas');canvas.width=1000;canvas.height=1000;canvas.setAttribute('aria-label','Draw here');layer.append(canvas);viewport.append(layer);tools.append(viewport);editorCanvas=canvas;editorCtx=canvas.getContext('2d');redraw();setZoom();
 const toolbar=node('div','tools');const zlabel=node('span','muted',`${Math.round(zoom*100)}%`);const updateZoom=()=>{zlabel.textContent=`${Math.round(zoom*100)}%`;setZoom()};
 add(toolbar,btn('Zoom −',()=>{zoom=Math.max(1,+(zoom-.25).toFixed(2));updateZoom()},'tool-button'),zlabel,btn('Zoom +',()=>{zoom=Math.min(3,+(zoom+.25).toFixed(2));updateZoom()},'tool-button'),btn('Reset view',()=>{zoom=1;panX=0;panY=0;updateZoom()},'tool-button'));
 tools.append(toolbar);main.append(tools);
 const actions=node('div','flex between');const undo=btn('Undo',()=>{if(!strokes.length)return;redoStack.push(strokes.pop());redraw();saveDrawing()},'button secondary');const redo=btn('Redo',()=>{if(!redoStack.length)return;strokes.push(redoStack.pop());redraw();saveDrawing()},'button secondary');
 const clear=btn('Clear drawing',()=>{if(!strokes.length)return;if(confirm('Clear all strokes in this drawing? This cannot be undone after leaving the editor.')){redoStack.push(...strokes.slice().reverse());strokes=[];redraw();saveDrawing()}},'button outline');
 add(actions,undo,redo,clear,btn('Share / Save PNG',shareDrawing));main.append(actions);
 main.append(node('p','help','Use two fingers to zoom or pan. A mouse can draw by dragging. This is a browser drawing tool, not Apple PencilKit. Seasonal coloring is freehand, not tap-to-fill.'));
 {const status=node('div','status','Saved locally on this device');status.id='save-status';status.setAttribute('role','status');main.append(status)}
 const pointers=pointerMap; pointers.clear();let gestureStart=null;
 function coords(ev){const r=canvas.getBoundingClientRect();return [Math.max(-100,Math.min(1100,(ev.clientX-r.left)/r.width*1000)),Math.max(-100,Math.min(1100,(ev.clientY-r.top)/r.height*1000))]}
 const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y);
 const center=(a,b)=>({x:(a.x+b.x)/2,y:(a.y+b.y)/2});
 function start(ev){if(ev.button!==undefined&&ev.button!==0)return;canvas.setPointerCapture(ev.pointerId);pointers.set(ev.pointerId,{x:ev.clientX,y:ev.clientY});if(pointers.size===1){activeStroke={tool:brushTool,color:brushColor,width:brushSize*(brushTool==='marker'?3:brushTool==='eraser'?3:1),points:[coords(ev)]};redraw()}
 if(pointers.size===2){activeStroke=null;redraw();const [a,b]=[...pointers.values()];gestureStart={distance:dist(a,b),center:center(a,b),zoom,panX,panY}}}
 function move(ev){if(!pointers.has(ev.pointerId))return;pointers.set(ev.pointerId,{x:ev.clientX,y:ev.clientY});if(pointers.size>=2){const [a,b]=[...pointers.values()];if(!gestureStart)gestureStart={distance:dist(a,b),center:center(a,b),zoom,panX,panY};zoom=Math.max(1,Math.min(3,gestureStart.zoom*dist(a,b)/Math.max(1,gestureStart.distance)));const c=center(a,b);panX=gestureStart.panX+c.x-gestureStart.center.x;panY=gestureStart.panY+c.y-gestureStart.center.y;updateZoom();return}if(activeStroke){activeStroke.points.push(coords(ev));redraw()}}
 function end(ev){if(!pointers.has(ev.pointerId))return;const wasSingle=pointers.size===1;pointers.delete(ev.pointerId);if(wasSingle&&activeStroke){activeStroke.points.push(coords(ev));strokes.push(activeStroke);redoStack=[];activeStroke=null;redraw();saveDrawing()}if(pointers.size<2)gestureStart=null;else if(pointers.size===1){activeStroke=null;redraw()}}
 canvas.addEventListener('pointerdown',start);canvas.addEventListener('pointermove',move);canvas.addEventListener('pointerup',end);canvas.addEventListener('pointercancel',e=>{pointers.delete(e.pointerId);activeStroke=null;gestureStart=null;redraw()});
}
function compositeCanvas(key,size=1000){
 const match=key.match(/^(\d{4})-(\d{2})-(season|sketch|patterns|free)$/);if(!match)return Promise.reject(Error('Bad drawing key'));
 const [,year,month,mode]=match;const drawing=state.drawings[key];const out=document.createElement('canvas');out.width=size;out.height=size;const ctx=out.getContext('2d');ctx.fillStyle='#fff';ctx.fillRect(0,0,size,size);
 const art=document.createElement('canvas');art.width=1000;art.height=1000;const ac=art.getContext('2d');for(const s of drawing?.strokes||[])drawStroke(ac,s);
 const finish=()=>{ctx.drawImage(art,0,0,size,size);return out};
 if(mode!=='season')return Promise.resolve(finish());
 return new Promise(resolve=>{const img=new Image();img.crossOrigin='anonymous';img.onload=()=>{ctx.drawImage(img,0,0,size,size);resolve(finish())};img.onerror=()=>resolve(finish());img.src=sceneSrc(Number(month))});
}
async function shareDrawing(){if(!persistDrawing())return;const key=drawingKey();try{const canvas=await compositeCanvas(key);const blob=await new Promise(r=>canvas.toBlob(r,'image/png'));if(!blob)throw Error('Cannot encode image');const name=`Creative-Moments-${key}.png`;
 const file=new File([blob],name,{type:'image/png'});if(navigator.canShare?.({files:[file]})){try{await navigator.share({files:[file],title:'Creative Moments'});return}catch(e){if(e.name==='AbortError')return}}
 downloadBlob(blob,name)}catch(e){showError('Could not export this drawing. Please try again.')}}
function downloadBlob(blob,name){const url=URL.createObjectURL(blob);const link=document.createElement('a');link.href=url;link.download=name;document.body.append(link);link.click();link.remove();setTimeout(()=>URL.revokeObjectURL(url),15000)}
function gallery(){
 const main=shell('My Creations','Browse · Reopen · Share');notice(main);const keys=Object.keys(state.drawings||{}).filter(k=>/^\d{4}-(0[1-9]|1[0-2])-(season|sketch|patterns|free)$/.test(k)&&state.drawings[k]?.strokes?.length).sort().reverse();
 if(!keys.length){const box=region();add(box,node('h2','','Your gallery is waiting'),node('p','muted','Create a drawing and it will appear here. Your pictures are saved separately for each month and activity.'),btn('Start drawing',()=>navigate('draw')));main.append(box);return}
 const grid=node('div','gallery');keys.forEach(k=>{const [year,month,mode]=k.split('-');const c=node('button','saved');const im=node('img');im.alt=`Saved ${TYPES[mode]} drawing from ${MONTHS[Number(month)-1]} ${year}`;im.loading='lazy';add(c,im,node('strong','',`${MONTHS[Number(month)-1]} ${year}`),node('span','',TYPES[mode]));c.onclick=()=>{selected=new Date(Number(year),Number(month)-1,1);openEditor(mode)};grid.append(c);compositeCanvas(k,370).then(canvas=>{if(c.isConnected)im.src=canvas.toDataURL('image/png')}).catch(()=>{im.src=sceneSrc(Number(month))})});main.append(grid);
 main.append(node('p','muted','Select any creation to keep drawing or share it as a PNG.'));
}
function backup(){
 const main=shell('Backup & Restore','Protect your plans, journal, and artwork');
 const warning=region('panel warn');add(warning,node('h2','','Keep a copy of your work'),node('p','','Creative Moments saves locally in this browser. It does not sync to your other devices. Clearing website data, switching browsers, or removing the app may erase entries unless you have an exported backup.'));main.append(warning);
 const saveBox=region();add(saveBox,node('h3','','1. Export your backup'),node('p','muted','Downloads a JSON file containing your plans, journal entries, cover photo, and editable drawings. Keep it in Files, iCloud Drive, or another safe place.'),btn('Download complete backup',downloadBackup));main.append(saveBox);
 const importBox=region();add(importBox,node('h3','','2. Restore a backup'),node('p','muted','Choose an exported Creative Moments JSON file. Nothing will be replaced until you review and confirm the import.'));
 const picker=input('file','backup-file');picker.accept='.json,application/json';picker.className='backup-input';const restore=btn('Choose backup file',()=>picker.click(),'button secondary');picker.onchange=async()=>{const file=picker.files?.[0];picker.value='';if(!file)return;if(file.size>10_000_000){alert('This file is larger than the supported 10 MB backup limit. Nothing was changed.');return}try{const raw=JSON.parse(await file.text());const checked=validateBackup(raw);if(!checked.ok){alert(`${checked.error} Nothing was changed.`);return}reviewImport(checked.data,raw.exportedAt)}catch{alert('This file could not be read as a Creative Moments backup. Nothing was changed.')}};add(importBox,restore,picker);main.append(importBox);
 let recoveryRaw=null;try{recoveryRaw=storage.getItem(RECOVERY_KEY)}catch{}if(recoveryRaw){const recovery=region('panel soft');add(recovery,node('h3','','Previous version available'),node('p','muted','A local copy was saved immediately before your last restore. You can download it or review it before recovering. It is not a substitute for an external backup.'));const controls=node('div','flex');controls.append(btn('Download previous version',()=>downloadBlob(new Blob([recoveryRaw],{type:'application/json'}),`CreativeMoments-before-restore-${today()}.json`),'button secondary'));controls.append(btn('Review previous version',()=>{try{const parsed=JSON.parse(recoveryRaw);const checked=validateBackup(makeBackup(parsed));if(!checked.ok){showError('The previous version cannot be verified. Download it for technical recovery.');return}reviewImport(checked.data,'')}catch{showError('The previous version could not be decoded. Download it for recovery.') }},'button outline'));recovery.append(controls);main.append(recovery)}
 const counts=region('panel soft');counts.append(node('h3','','What this browser currently contains'));const taskCount=Object.values(state.tasks||{}).filter(Array.isArray).reduce((n,ts)=>n+ts.length,0);const drawings=Object.values(state.drawings||{}).filter(d=>d?.strokes?.length).length;
 add(counts,node('p','',`${taskCount} task${taskCount===1?'':'s'} · ${drawings} drawing${drawings===1?'':'s'}`),node('p','muted','Journal entries and daily notes are also included in a backup. Save a new backup after important changes.'));
 main.append(counts);
 if(storageBlocked){const rescue=region('panel warn');add(rescue,node('h3','','Read error — recovery mode'),node('p','muted','Your stored data could not be decoded. We will not overwrite it. You can download the untouched raw browser storage for technical recovery.'),btn('Download raw data',()=>{try{const raw=storage.getItem(STORAGE_KEY);downloadBlob(new Blob([raw||''],{type:'text/plain'}),'CreativeMoments-corrupt-storage.txt')}catch{alert('Browser storage is blocked. Allow site data access to recover the original bytes. Nothing was changed.')}},'button danger'));main.append(rescue)}
 {const status=node('div','status',error||'You are viewing your local data');status.id='save-status';main.append(status)}
}
function downloadBackup(){
 if(storageBlocked){showError('Your saved browser data could not be read. Download the raw data instead; do not export an empty backup.');return false}
 try{const content=JSON.stringify(makeBackup(state),null,2);downloadBlob(new Blob([content],{type:'application/json'}),`CreativeMoments-backup-${today()}.json`);showStatus('Backup download requested. Verify the file is in Files or Downloads.');return true}catch{showError('Backup could not be prepared. No data was changed.');return false}
}
function reviewImport(next,exportedAt){
 const dlg=node('dialog','dialog');dlg.setAttribute('aria-label','Review backup restore');const tasks=Object.values(next.tasks).filter(Array.isArray).reduce((n,x)=>n+x.length,0);const drawings=Object.values(next.drawings).filter(d=>d?.strokes?.length).length;
 add(dlg,node('h2','','Review imported backup'),node('p','',`This file contains ${tasks} tasks and ${drawings} drawings, plus its journal/notes.`));
 if(exportedAt){const date=new Date(exportedAt);if(!Number.isNaN(date.valueOf()))dlg.append(node('p','muted',`Exported ${date.toLocaleString()}`))}
 dlg.append(node('p','', 'Restoring replaces ALL current browser data, including notes and drawings. Keep a separate backup first.'));
 const actions=node('div','dialog-actions');add(actions,btn('Cancel',()=>dlg.close(),'button outline'),btn('Replace my browser data',()=>{
 if(!confirm('Final confirmation: replace every current note, task, cover and drawing with this backup?'))return;
 if(storageBlocked){alert('Current storage has a read error. Please export the raw data before restoring.');return}
 if(externalUpdate){alert('Saved work changed in another tab. Reload before restoring. Nothing was replaced.');return}
 // Preserve a local pre-restore recovery snapshot BEFORE writing the replacement.
 try{const previous=storage.getItem(STORAGE_KEY);
   if(previous!==lastStoredRaw){externalUpdate=true;alert('Saved work changed in another tab. Reload before restoring. Nothing was replaced.');return}
   if(previous!==null)storage.setItem(RECOVERY_KEY,previous)
 }catch{alert('Could not make the pre-restore recovery copy. Download a backup of current data before replacing it. Nothing changed.');return}
 const result=persistState(storage,next,lastStoredRaw);if(!result.ok){if(result.conflict)externalUpdate=true;alert(result.error+' Nothing was replaced.');return}
 state=next;lastStoredRaw=JSON.stringify(next);error=null;dlg.close();navigate('home');alert('Backup restored. Your previous browser data is also retained as a local recovery copy.')
 },'button danger'));
 dlg.append(actions);document.body.append(dlg);dlg.addEventListener('close',()=>dlg.remove());dlg.showModal();
}
async function printMonth(){
 try{
 const key=currentMonth(),tasks=state.tasks[key]||[];
 printable.replaceChildren();const page=node('section','print-page');add(page,node('h1','',state.coverName||'My Creative Moments'),node('h2','',`${currentCaption()} · ${THEMES[selected.getMonth()]}`));
 if(state.focus[key])add(page,node('h3','','Monthly focus'),node('p','',state.focus[key]));
 const table=node('table','print-calendar'),head=node('tr');['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'].forEach(name=>head.append(node('th','',name)));table.append(head);
 const offset=(new Date(selected.getFullYear(),selected.getMonth(),1).getDay()+6)%7,count=new Date(selected.getFullYear(),selected.getMonth()+1,0).getDate();let tr=node('tr');for(let i=0;i<offset;i++)tr.append(node('td'));for(let d=1;d<=count;d++){if((offset+d-1)%7===0&&d>1){table.append(tr);tr=node('tr')}const cell=node('td');cell.append(node('strong','',String(d)));const note=state.days[`${key}-${String(d).padStart(2,'0')}`]??state.days[`${key}-${d}`];if(note)cell.append(node('small','', ' · Note'));tr.append(cell)}table.append(tr);page.append(table);
 add(page,node('h2','','Checklist'));if(!tasks.length)page.append(node('p','','No tasks added.'));else tasks.forEach(task=>page.append(node('p','',`${task.done?'☑':'☐'} ${task.title}${task.dueDate?` (due ${task.dueDate})`:''}`)));
 for(let d=1;d<=count;d++){const value=state.days[`${key}-${String(d).padStart(2,'0')}`]??state.days[`${key}-${d}`];if(!value)continue;const box=node('div','print-notes');add(box,node('h3','',`${MONTHS[selected.getMonth()]} ${d}`),node('p','',value));page.append(box)}
 for(const [prop,title] of [['notes','Notes & inspiration'],['joy','Something I enjoyed creating'],['carry','An idea to carry forward']])if(state[prop][key])add(page,node('h3','',title),node('p','',state[prop][key]));printable.append(page);
 const artPage=node('section','print-page');artPage.append(node('h2','',`${currentCaption()} · My drawings`));for(const mode of Object.keys(TYPES)){const k=`${key}-${mode}`;if(!state.drawings[k]?.strokes?.length)continue;const c=await compositeCanvas(k,500);const img=node('img','print-art');img.src=c.toDataURL('image/png');img.alt=TYPES[mode];add(artPage,node('h3','',TYPES[mode]),img)}printable.append(artPage);
 await Promise.all([...printable.querySelectorAll('img')].map(img=>img.decode?.().catch(()=>{})||Promise.resolve()));
 requestAnimationFrame(()=>window.print());
 }catch{showError('Could not prepare the printable calendar. No saved data was changed.')}
}
function render(){editorCanvas=null;editorCtx=null;editorLayer=null;
 switch(screen){case 'home':return home();case 'planner':return planner();case 'today':return todayScreen();case 'journal':return journal();case 'draw':return drawSelection();case 'editor':return drawEditor();case 'gallery':return gallery();case 'backup':return backup();default:screen='home';return home()}}
render();
window.addEventListener('storage',ev=>{if(ev.key===STORAGE_KEY && ev.newValue!==lastStoredRaw){externalUpdate=true;showError('Your work changed in another tab. Reload this page to see those changes before editing.');render()}});
if('serviceWorker' in navigator && (location.protocol==='https:' || ['localhost','127.0.0.1','[::1]'].includes(location.hostname)))navigator.serviceWorker.register('/sw.js').catch(()=>{});
