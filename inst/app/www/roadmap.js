/* Roadmap canvas v3: chronogram and value chain.
   Investment builds enablers; enablers and the process's target maturity
   make milestones possible; milestones move metrics up their impact curve;
   metrics create value. Runs in the browser: R sends a payload
   ("roadmap-data") and receives the selection as input "<ns>selection". */
(function(){
'use strict';
const S={p:null,sel:null,view:'chrono'};
const esc=s=>String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const arr=x=>x==null?[]:Array.isArray(x)?x:[x];
const fmtM=(v,d=1)=>(v<0?'−':'')+'$'+Math.abs(v).toFixed(d)+'M';
const qlab=t=>{const e=Math.ceil(t*4-1e-9)/4-0.25,y=Math.floor(e+1e-9);return y+' Q'+(Math.round((e-y)*4)+1)};
const cut=(s,n)=>s.length>n?s.slice(0,n-1)+'…':s;
const root=()=>document.querySelector('.rm-root');
const q=s=>root()&&root().querySelector(s);
const LV=l=>'M'+l;

let EN={},MS={},MT={},PR={},DEP={},PRE={};
function index(p){
  EN={};MS={};MT={};PR={};DEP={};PRE={};
  p.enablers.forEach(e=>{EN[e.id]=e;PRE[e.id]=arr(p.prereq[e.id]);DEP[e.id]=[]});
  p.enablers.forEach(e=>PRE[e.id].forEach(x=>DEP[x]&&DEP[x].push(e.id)));
  p.milestones.forEach(m=>{m.metrics=arr(m.metrics);MS[m.id]=m});
  p.metrics.forEach(k=>{k.milestones=p.mlinks.filter(l=>l.metric===k.id).map(l=>l.milestone);MT[k.id]=k});
  p.processes.forEach(x=>{x.path=arr(x.path);PR[x.id]=x});
  p.links=arr(p.links);p.mlinks=arr(p.mlinks);
}
function walk(ids,next){const out=new Set(),st=[...ids];while(st.length){const id=st.pop();(next[id]||[]).forEach(n=>{if(!out.has(n)){out.add(n);st.push(n)}})}return out}
const ensOf=ms=>{const d=new Set(S.p.links.filter(l=>ms.has(l.milestone)).map(l=>l.enabler));return{direct:d,all:new Set([...d,...walk(d,PRE)])}};

function highlight(){
  const s=S.sel,p=S.p;if(!s||!p)return null;let ms,mt,proc,E;
  if(s.type==='milestone'){ms=new Set([s.id]);mt=new Set(MS[s.id].metrics);E=ensOf(ms);proc=new Set([MS[s.id].process,...[...mt].map(k=>MT[k]&&MT[k].process)])}
  else if(s.type==='enabler'){const down=walk([s.id],DEP);ms=new Set(p.links.filter(l=>l.enabler===s.id||down.has(l.enabler)).map(l=>l.milestone));
    E={direct:new Set([s.id]),all:new Set([s.id,...walk([s.id],PRE),...down])};mt=new Set([...ms].flatMap(m=>MS[m]?MS[m].metrics:[]));
    proc=new Set([...[...ms].map(m=>MS[m]&&MS[m].process),...[...mt].map(k=>MT[k]&&MT[k].process)])}
  else if(s.type==='metric'){mt=new Set([s.id]);ms=new Set(MT[s.id].milestones);E=ensOf(ms);proc=new Set([MT[s.id].process])}
  else{ms=new Set(p.milestones.filter(m=>m.process===s.id).map(m=>m.id));mt=new Set(p.metrics.filter(k=>k.process===s.id).map(k=>k.id));E=ensOf(ms);proc=new Set([s.id])}
  return{direct:E.direct,en:E.all,ms,mt,proc}}

const tipM=m=>{const pr=PR[m.process],mts=m.metrics.map(k=>MT[k]).filter(Boolean);
  return `<b>${esc(m.name)}</b><br>${esc(pr?pr.name:m.process)} · ${LV(m.level)}<br>due ${esc(m.due)} · ready ${qlab(m.t_ready)}${m.late?' · <b>late</b>':''}${mts.length?'<br>moves '+mts.map(k=>esc(k.name)).join(', '):'<br>moves no metric'}`};
const lvlTxt=pr=>pr.tgt>pr.cur?`${LV(pr.cur)} → ${LV(pr.tgt)}`:`${LV(pr.cur)} · stays`;

/* ---------- chronogram ---------- */
function renderChrono(H){
  const p=S.p,box=q('.rm-viz'),W=Math.max(720,box.parentElement.clientWidth),L=230,R=24;
  const ens=p.enablers.filter(e=>e.show),ms=p.milestones.filter(m=>m.show);
  const T0=Math.floor(Math.min(...p.enablers.map(e=>e.t0))),T1=Math.max(T0+4,Math.ceil(Math.max(...p.enablers.map(e=>Math.max(e.t1,e.t1_plan)),...ms.map(m=>Math.max(m.t_due,m.t_ready)))));
  const x=t=>L+(t-T0)/(T1-T0)*(W-L-R);
  let y=34;const body=[],pos={};
  const band=(title)=>{body.push(`<text class="c-band" x="0" y="${y+10}">${title}</text>`);y+=24};
  // processes: maturity strip + milestones
  band('Processes · maturity and milestones');
  p.processes.filter(pr=>pr.show).forEach(pr=>{
    const pm=ms.filter(m=>m.process===pr.id);if(!pm.length&&pr.tgt<=pr.cur)return;
    const cy=y+9,off=H&&!H.proc.has(pr.id);
    const tip=`<b>${esc(pr.name)}</b><br>${esc(pr.owner)}<br>${lvlTxt(pr)}${pr.tgt!==pr.base?' (base '+LV(pr.base)+')':''}${pr.value>0?'<br>'+fmtM(pr.value)+' / yr at full adoption':''}`;
    body.push(`<text class="c-lane${off?' off':''}" x="0" y="${cy+1}" data-sel="process:${pr.id}" data-tip="${esc(tip)}">${esc(cut(pr.name,30))}</text><text class="c-lvl${off?' off':''}" x="0" y="${cy+14}">${lvlTxt(pr)}</text>`);
    // strip: level segments over time
    const seg=[{l:pr.cur,t:T0}];pr.path.forEach(s=>seg.push({l:s.level,t:s.t==null?T0:Math.max(T0,s.t)}));
    const sy=cy+9;
    seg.forEach((s,i)=>{const t2=i<seg.length-1?seg[i+1].t:T1;if(t2<=s.t+1e-6)return;const x1=x(s.t),x2=x(t2);
      body.push(`<rect class="c-mat l${s.l}${off?' off':''}" x="${x1}" y="${sy-3}" width="${Math.max(1,x2-x1)}" height="6" rx="1"><title>${LV(s.l)} from ${s.t<=T0?'today':qlab(s.t)}</title></rect>`);
      if(x2-x1>26)body.push(`<text class="c-matl${off?' off':''}" x="${x1+4}" y="${sy+14}">${LV(s.l)}</text>`)});
    body.push(`<line class="c-lane-l" x1="${L}" x2="${W-R}" y1="${cy}" y2="${cy}"/>`);
    pm.forEach(m=>{const xd=x(m.t_due),rad=7;
      let cls=H?(H.ms.has(m.id)?'on':'off'):'';if(S.sel&&S.sel.type==='milestone'&&S.sel.id===m.id)cls+=' sel';
      if(m.late)cls+=' late';if(!m.metrics.length)cls+=' novalue';
      const late=m.late?`<line class="c-late" x1="${xd}" x2="${x(m.t_ready)}" y1="${cy}" y2="${cy}"/><circle class="c-late-dot" cx="${x(m.t_ready)}" cy="${cy}" r="2"/>`:'';
      const anc=xd>W-R-130?'end':xd<L+130?'start':'middle',lab=H&&H.ms.has(m.id)?`<text class="c-rlab" x="${anc==='end'?xd+rad:anc==='start'?xd-rad:xd}" y="${cy-rad-4}" text-anchor="${anc}">${esc(cut(m.name,38))}</text>`:'';
      body.push(`<g class="c-res ${cls}" data-sel="milestone:${m.id}" data-tip="${esc(tipM(m))}">${late}<circle cx="${xd}" cy="${cy}" r="${rad}"/><text class="c-mlv" x="${xd}" y="${cy+3}">${m.level}</text>${lab}</g>`)});
    y+=40});
  y+=6;
  // enablers: group > concept > enabler
  band('Enablers');
  p.groups.forEach(g=>{const ge=ens.filter(e=>e.grp===g.id);if(!ge.length)return;
    body.push(`<circle cx="4" cy="${y+5}" r="3.5" class="c-gdot ${g.id}"/><text class="c-group" x="14" y="${y+9}">${esc(g.name)}</text>`);y+=20;
    [...new Set(ge.map(e=>e.concept))].forEach(cn=>{
      const ce=ge.filter(e=>e.concept===cn);
      const conOff=H&&!ce.some(e=>H.en.has(e.id));
      body.push(`<text class="c-concept${conOff?' off':''}" x="14" y="${y+9}">${esc(cut(cn,34))}</text>`);y+=16;
      ce.forEach(e=>{const cy=y+7,x1=x(e.t0),x2=x(e.t1);pos[e.id]={cy,x1,x2};
        let cls='';if(H)cls=H.direct.has(e.id)?'on':H.en.has(e.id)?'found':'off';
        if(S.sel&&S.sel.type==='enabler'&&S.sel.id===e.id)cls+=' sel';if(e.issue)cls+=' issue';
        const ghost=e.compression>0.005?`<rect class="c-ghost" x="${x1}" y="${cy-3}" width="${Math.max(2,x(e.t1_plan)-x1)}" height="6" rx="3"/>`:'';
        const tip=`<b>${esc(e.name)}</b><br>${LV(e.level)} · ${esc(e.concept)} · ${esc(e.sub)}<br>${e.start} – ${e.end}${e.compression>0.005?' · '+Math.round(e.compression*100)+'% shorter':''}<br>${fmtM(e.cost)} to horizon${e.basis==='per_process'?' · per process ('+e.n+' of '+e.N+')':''}${e.issue?'<br><b>'+esc(e.issue)+'</b>':''}`;
        body.push(`<g class="c-bar ${cls}" data-sel="enabler:${e.id}" data-tip="${esc(tip)}"><text class="c-elab" x="26" y="${cy+3.5}">${esc(cut(e.name,28))}</text><text class="c-elv" x="${L-8}" y="${cy+3.5}">${LV(e.level)}</text>${ghost}<rect class="b ${e.grp}" x="${x1}" y="${cy-3}" width="${Math.max(3,x2-x1)}" height="6" rx="3"/></g>`);
        y+=16});
      y+=4});
    y+=8});
  const Ht=y+8,grid=[];
  for(let t=T0;t<=T1+1e-9;t+=.25){const yr=Math.abs(t-Math.round(t))<1e-6;
    grid.push(`<line class="c-grid${yr?' yr':''}" x1="${x(t)}" x2="${x(t)}" y1="${yr?8:20}" y2="${Ht}"/>`);
    if(yr&&t<T1-1e-9)grid.push(`<text class="c-axis" x="${x(t)+5}" y="16">${Math.round(t)}</text>`)}
  if(p.today>T0&&p.today<T1)grid.push(`<line class="c-today" x1="${x(p.today)}" x2="${x(p.today)}" y1="8" y2="${Ht}"/><text class="c-today-t" x="${x(p.today)+4}" y="28">today</text>`);
  const pairs=new Set(arr(p.issues).filter(i=>i.related_id).map(i=>i.related_id+'>'+i.enabler_id));
  const edges=[];ens.forEach(d=>PRE[d.id].forEach(pr=>{const a=pos[pr],b=pos[d.id];if(!a||!b)return;
    if(!pairs.has(pr+'>'+d.id))return;          // only late dependencies: the value chain shows structure
    const xs=a.x2;
    edges.push(xs<=b.x1+1?`<path class="c-edge bad" d="M${xs},${a.cy}C${xs+14},${a.cy} ${b.x1-14},${b.cy} ${b.x1},${b.cy}"/>`
      :`<path class="c-edge bad" d="M${xs},${a.cy}L${xs},${b.cy}"/>`)}));
  box.innerHTML=`<svg width="${W}" height="${Ht}" viewBox="0 0 ${W} ${Ht}" role="img" aria-label="Chronogram">${grid.join('')}${edges.join('')}${body.join('')}</svg>`;
  q('.rm-legend').innerHTML='<span><i class="lg mstrip"></i>process maturity over time (M1 light → M5 dark)</span><span><i class="lg dot lvl">3</i>milestone and its level</span><span><i class="lg hollow"></i>moves no metric</span><span><i class="lg late"></i>late: ready after due</span><span><i class="lg ghost"></i>plan duration, when shortened</span>'}

/* ---------- value chain ---------- */
function renderChain(H){
  const p=S.p,box=q('.rm-viz'),W=Math.max(760,box.parentElement.clientWidth);
  const ms=p.milestones.filter(m=>m.show),ens=p.enablers.filter(e=>e.show),mts=p.metrics.filter(k=>k.show);
  const msIds=new Set(ms.map(m=>m.id));
  const directIds=new Set(p.links.filter(l=>msIds.has(l.milestone)).map(l=>l.enabler));
  const gi=g=>p.groups.findIndex(x=>x.id===g);
  const byG=(a,b)=>gi(a.grp)-gi(b.grp)||a.concept.localeCompare(b.concept)||a.name.localeCompare(b.name);
  const procs=p.processes.filter(x=>x.show&&(ms.some(m=>m.process===x.id)||mts.some(k=>k.process===x.id)));
  const order=procs.map(x=>x.id);
  const cols=[
    {t:'Foundations',items:ens.filter(e=>!directIds.has(e.id)).sort(byG).map(e=>({id:e.id,type:'enabler',name:e.name,g:e.grp,tag:LV(e.level)}))},
    {t:'Enablers',items:ens.filter(e=>directIds.has(e.id)).sort(byG).map(e=>({id:e.id,type:'enabler',name:e.name,g:e.grp,tag:LV(e.level)}))},
    {t:'Milestones',items:ms.slice().sort((a,b)=>order.indexOf(a.process)-order.indexOf(b.process)||a.level-b.level||a.t_due-b.t_due).map(m=>({id:m.id,type:'milestone',name:m.name,tag:LV(m.level),late:m.late}))},
    {t:'Metrics',items:mts.slice().sort((a,b)=>order.indexOf(a.process)-order.indexOf(b.process)||b.run-a.run).map(k=>({id:k.id,type:'metric',name:k.name,v:k.run}))},
    {t:'Processes',items:procs.map(x=>({id:x.id,type:'process',name:x.name,v:x.value,tag:LV(x.tgt)}))}];
  const NH=22,GAP=6,TOP=30,wts=[.9,.9,1.2,1.1,1.25],ws=wts.reduce((a,b)=>a+b,0),gap=30;
  const cws=wts.map(w=>w/ws*(W-gap*4)),cx0=[];cws.reduce((a,w,i)=>(cx0[i]=a,a+w+gap),0);
  const maxN=Math.max(1,...cols.map(c=>c.items.length)),Ht=TOP+maxN*(NH+GAP)+8,P={},nodes=[],links=[];
  cols.forEach((c,ci)=>{const x0=cx0[ci],nw=cws[ci],off=TOP+(maxN-c.items.length)*(NH+GAP)/2;
    nodes.push(`<text class="c-band" x="${x0}" y="12">${c.t}</text>`);
    c.items.forEach((it,i)=>{const y0=off+i*(NH+GAP);P[it.type+it.id]={x0,x1:x0+nw,cy:y0+NH/2};
      let cls='';if(H){const on=it.type==='enabler'?H.en.has(it.id):it.type==='milestone'?H.ms.has(it.id):it.type==='metric'?H.mt.has(it.id):H.proc.has(it.id);cls=on?'on':'off'}
      if(S.sel&&S.sel.type===it.type&&S.sel.id===it.id)cls+=' sel';if(it.late||(it.type==='enabler'&&EN[it.id].issue))cls+=' bad';
      const hasV=it.v!=null&&it.v>0,tagW=it.tag?it.tag.length*6+8:0,maxc=Math.floor((nw-(hasV?48:14)-(it.g?8:0)-tagW)/6.3);
      const right=hasV?`<text class="n-val" x="${x0+nw-8}" y="${y0+NH/2+3.5}" text-anchor="end">${fmtM(it.v,it.v<10?1:0)}</text>`:'';
      const mark=it.g?`<circle class="c-gdot ${it.g}" cx="${x0+9}" cy="${y0+NH/2}" r="3"/>`:'';
      const tx=x0+(it.g?18:10);
      const tag=it.tag?`<text class="n-tag" x="${tx}" y="${y0+NH/2+3.5}">${esc(it.tag)}</text>`:'';
      nodes.push(`<g class="n ${it.type} ${cls}" data-sel="${it.type}:${it.id}" data-tip="<b>${esc(it.name)}</b>"><rect x="${x0}" y="${y0}" width="${nw}" height="${NH}" rx="11"/>${mark}${tag}<text class="n-t" x="${tx+tagW}" y="${y0+NH/2+3.5}">${esc(cut(it.name,Math.max(4,maxc)))}</text>${right}</g>`)})});
  const curve=(a,b,c)=>`<path class="l ${c}" d="M${a.x1},${a.cy}C${(a.x1+b.x0)/2},${a.cy} ${(a.x1+b.x0)/2},${b.cy} ${b.x0},${b.cy}"/>`;
  const st=on=>H?(on?'on':'off'):'';
  ens.forEach(d=>PRE[d.id].forEach(pr=>{if(!directIds.has(d.id)||directIds.has(pr))return;const a=P['enabler'+pr],b=P['enabler'+d.id];if(a&&b)links.push(curve(a,b,'dep '+st(H&&H.en.has(pr)&&H.en.has(d.id))))}));
  p.links.forEach(l=>{const a=P['enabler'+l.enabler],b=P['milestone'+l.milestone];if(a&&b)links.push(curve(a,b,st(H&&H.ms.has(l.milestone)&&H.en.has(l.enabler))))});
  p.mlinks.forEach(l=>{const a=P['milestone'+l.milestone],b=P['metric'+l.metric];if(a&&b)links.push(curve(a,b,st(H&&H.ms.has(l.milestone)&&H.mt.has(l.metric))))});
  mts.forEach(k=>{const a=P['metric'+k.id],b=P['process'+k.process];if(a&&b)links.push(curve(a,b,st(H&&H.mt.has(k.id))))});
  box.innerHTML=`<svg width="${W}" height="${Ht}" viewBox="0 0 ${W} ${Ht}" role="img" aria-label="Value chain">${links.join('')}${nodes.join('')}</svg>`;
  q('.rm-legend').innerHTML='<span>Foundations are needed by enablers · enablers make milestones possible · milestones move metrics up their curve · metrics create value for processes</span><span>M = maturity level · $ = value per year at full adoption · dashed = prerequisite</span>'}

function render(){
  if(!S.p||!root())return;const H=highlight();
  root().querySelectorAll('[data-view]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.view===S.view));
  (S.view==='chrono'?renderChrono:renderChain)(H)}

function setSel(sel){
  S.sel=sel;render();
  if(window.Shiny&&S.p)Shiny.setInputValue(S.p.ns+'selection',sel?sel.type+':'+sel.id:'',{priority:'event'})}

const gone=s=>(s.type==='milestone'&&!(MS[s.id]&&MS[s.id].show))||(s.type==='enabler'&&!(EN[s.id]&&EN[s.id].show))||(s.type==='metric'&&!MT[s.id]);
if(window.Shiny)Shiny.addCustomMessageHandler('roadmap-data',msg=>{
  S.p=typeof msg==='string'?JSON.parse(msg):msg;index(S.p);
  if(S.sel&&gone(S.sel))setSel(null);else render()});

document.addEventListener('click',ev=>{
  const r=root();if(!r||!r.contains(ev.target))return;
  const t=ev.target.closest('[data-sel],[data-view],.rm-clear');
  if(!t){if(ev.target.closest('.rm-viz svg')&&S.sel)setSel(null);return}
  if(t.dataset.sel){const[type,id]=t.dataset.sel.split(':');setSel(S.sel&&S.sel.type===type&&S.sel.id===id?null:{type,id});return}
  if(t.dataset.view){S.view=t.dataset.view;render();return}
  if(t.classList.contains('rm-clear'))setSel(null)});

let tip;document.addEventListener('mousemove',ev=>{
  if(!tip){tip=document.createElement('div');tip.id='tip';tip.hidden=true;document.body.appendChild(tip)}
  const t=ev.target.closest&&ev.target.closest('[data-tip]');if(!t||!t.closest('.rm-root,.fr-root')){tip.hidden=true;return}
  tip.innerHTML=t.dataset.tip;tip.hidden=false;const w=tip.offsetWidth,h=tip.offsetHeight;
  tip.style.left=Math.min(ev.clientX+14,innerWidth-w-8)+'px';tip.style.top=Math.min(ev.clientY+14,innerHeight-h-8)+'px'});
let rz;window.addEventListener('resize',()=>{clearTimeout(rz);rz=setTimeout(render,120)});
$(document).on('shown.bs.tab shown',()=>setTimeout(render,0));
})();
