/* Roadmap canvas v2: chronogram and value chain.
   Enablers make results possible; results generate value for processes.
   Runs in the browser: R sends a payload ("roadmap-data") and receives the
   selection as input "<ns>selection". */
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

let EN={},RS={},DEP={},PRE={};
function index(p){
  EN={};RS={};DEP={};PRE={};
  p.enablers.forEach(e=>{EN[e.id]=e;PRE[e.id]=arr(p.prereq[e.id]);DEP[e.id]=[]});
  p.enablers.forEach(e=>PRE[e.id].forEach(x=>DEP[x]&&DEP[x].push(e.id)));
  p.results.forEach(r=>{r.procs=arr(r.procs);r.shares=arr(r.shares);RS[r.id]=r});
}
function walk(ids,next){const out=new Set(),st=[...ids];while(st.length){const id=st.pop();(next[id]||[]).forEach(n=>{if(!out.has(n)){out.add(n);st.push(n)}})}return out}

function highlight(){
  const s=S.sel,p=S.p;if(!s||!p)return null;let direct,en,res,proc;
  if(s.type==='result'){direct=new Set(p.links.filter(l=>l.result===s.id).map(l=>l.enabler));en=new Set([...direct,...walk(direct,PRE)]);res=new Set([s.id]);proc=new Set(RS[s.id].procs)}
  else if(s.type==='enabler'){const down=walk([s.id],DEP);direct=new Set([s.id]);en=new Set([s.id,...walk([s.id],PRE),...down]);
    res=new Set(p.links.filter(l=>l.enabler===s.id||down.has(l.enabler)).map(l=>l.result));proc=new Set([...res].flatMap(k=>RS[k]?RS[k].procs:[]))}
  else{res=new Set(p.results.filter(k=>k.procs.includes(s.id)).map(k=>k.id));direct=new Set(p.links.filter(l=>res.has(l.result)).map(l=>l.enabler));
    en=new Set([...direct,...walk(direct,PRE)]);proc=new Set([s.id])}
  return{direct,en,res,proc}}

const tipR=(r,pname)=>`<b>${esc(r.name)}</b><br>${esc(pname)}${r.procs.length>1?' · shared':''}<br>due ${esc(r.due)} · ready ${qlab(r.t_ready)}${r.late?' · <b>late</b>':''}${r.measured?'<br>'+esc(r.measure):''}${r.run>0?'<br>'+fmtM(r.run)+' / yr at full adoption':'<br>no value of its own'}`;

/* ---------- chronogram ---------- */
function renderChrono(H){
  const p=S.p,box=q('.rm-viz'),W=Math.max(720,box.parentElement.clientWidth),L=230,R=24;
  const ens=p.enablers.filter(e=>e.show),rs=p.results.filter(r=>r.show);
  const T0=Math.floor(Math.min(...p.enablers.map(e=>e.t0))),T1=Math.max(T0+4,Math.ceil(Math.max(...p.enablers.map(e=>Math.max(e.t1,e.t1_plan)),...rs.map(r=>Math.max(r.t_due,r.t_ready)))));
  const x=t=>L+(t-T0)/(T1-T0)*(W-L-R);
  const maxRun=Math.max(1e-9,...rs.map(r=>r.run));
  let y=34;const body=[],pos={};
  const band=(title)=>{body.push(`<text class="c-band" x="0" y="${y+10}">${title}</text>`);y+=24};
  // results: one lane per process in scope
  band('Results');
  p.processes.filter(pr=>pr.show&&rs.some(r=>r.procs.includes(pr.id))).forEach(pr=>{
    const cy=y+8,off=H&&!H.proc.has(pr.id);
    body.push(`<text class="c-lane${off?' off':''}" x="0" y="${cy+4}" data-sel="process:${pr.id}" data-tip="<b>${esc(pr.name)}</b><br>${esc(pr.owner)}">${esc(cut(pr.name,34))}</text><line class="c-lane-l" x1="${L}" x2="${W-R}" y1="${cy}" y2="${cy}"/>`);
    rs.filter(r=>r.procs.includes(pr.id)).forEach(r=>{
      const xd=x(r.t_due),rad=r.run>0?3.5+5*Math.sqrt(r.run/maxRun):3.5;
      let cls=H?(H.res.has(r.id)?'on':'off'):'';if(S.sel&&S.sel.type==='result'&&S.sel.id===r.id)cls+=' sel';
      if(r.late)cls+=' late';if(r.run<=0)cls+=' novalue';if(r.procs.length>1&&r.process!==pr.id)cls+=' shared';
      const late=r.late?`<line class="c-late" x1="${xd}" x2="${x(r.t_ready)}" y1="${cy}" y2="${cy}"/><circle class="c-late-dot" cx="${x(r.t_ready)}" cy="${cy}" r="2"/>`:'';
      const anc=xd>W-R-130?'end':xd<L+130?'start':'middle',lab=H&&H.res.has(r.id)?`<text class="c-rlab" x="${anc==='end'?xd+rad:anc==='start'?xd-rad:xd}" y="${cy-rad-4}" text-anchor="${anc}">${esc(cut(r.name,38))}</text>`:'';
      body.push(`<g class="c-res ${cls}" data-sel="result:${r.id}" data-tip="${tipR(r,pr.name)}">${late}<circle cx="${xd}" cy="${cy}" r="${rad.toFixed(1)}"/>${lab}</g>`)});
    y+=24});
  y+=10;
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
        const tip=`<b>${esc(e.name)}</b><br>${esc(e.concept)} · ${esc(e.sub)}<br>${e.start} – ${e.end}${e.compression>0.005?' · '+Math.round(e.compression*100)+'% shorter':''}<br>${fmtM(e.cost)} to horizon${e.basis==='per_process'?' · per process ('+e.n+' of '+e.N+')':''}${e.issue?'<br><b>'+esc(e.issue)+'</b>':''}`;
        body.push(`<g class="c-bar ${cls}" data-sel="enabler:${e.id}" data-tip="${tip}"><text class="c-elab" x="26" y="${cy+3.5}">${esc(cut(e.name,32))}</text>${ghost}<rect class="b ${e.grp}" x="${x1}" y="${cy-3}" width="${Math.max(3,x2-x1)}" height="6" rx="3"/></g>`);
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
    const bad=pairs.has(pr+'>'+d.id);if(!bad)return;          // only late dependencies: the value chain shows structure
    const xs=a.x2;
    edges.push(xs<=b.x1+1?`<path class="c-edge${bad?' bad':''}" d="M${xs},${a.cy}C${xs+14},${a.cy} ${b.x1-14},${b.cy} ${b.x1},${b.cy}"/>`
      :`<path class="c-edge${bad?' bad':''}" d="M${xs},${a.cy}L${xs},${b.cy}"/>`)}));
  box.innerHTML=`<svg width="${W}" height="${Ht}" viewBox="0 0 ${W} ${Ht}" role="img" aria-label="Chronogram">${grid.join('')}${edges.join('')}${body.join('')}</svg>`;
  q('.rm-legend').innerHTML='<span><i class="lg dot"></i>result, size = value</span><span><i class="lg hollow"></i>no value of its own</span><span><i class="lg late"></i>late: ready after due</span><span><i class="lg shared"></i>shared, outside its lead process</span><span><i class="lg ghost"></i>plan duration, when shortened</span>'}

/* ---------- value chain ---------- */
function renderChain(H){
  const p=S.p,box=q('.rm-viz'),W=Math.max(720,box.parentElement.clientWidth);
  const rs=p.results.filter(r=>r.show),ens=p.enablers.filter(e=>e.show);
  const directIds=new Set(p.links.filter(l=>RS[l.result]&&RS[l.result].show).map(l=>l.enabler));
  const gi=g=>p.groups.findIndex(x=>x.id===g);
  const byG=(a,b)=>gi(a.grp)-gi(b.grp)||a.concept.localeCompare(b.concept)||a.name.localeCompare(b.name);
  const procs=p.processes.filter(x=>x.show&&rs.some(r=>r.procs.includes(x.id)));
  const order=procs.map(x=>x.id);
  const cols=[
    {t:'Foundations',items:ens.filter(e=>!directIds.has(e.id)).sort(byG).map(e=>({id:e.id,type:'enabler',name:e.name,g:e.grp}))},
    {t:'Enablers',items:ens.filter(e=>directIds.has(e.id)).sort(byG).map(e=>({id:e.id,type:'enabler',name:e.name,g:e.grp}))},
    {t:'Results',items:rs.slice().sort((a,b)=>order.indexOf(a.process)-order.indexOf(b.process)||b.run-a.run).map(r=>({id:r.id,type:'result',name:r.name,v:r.run_scope,late:r.late}))},
    {t:'Processes',items:procs.map(x=>({id:x.id,type:'process',name:x.name,v:x.value}))}];
  const NH=22,GAP=6,TOP=30,wts=[1,1,1.35,1.2],ws=wts.reduce((a,b)=>a+b,0),gap=36;
  const cws=wts.map(w=>w/ws*(W-gap*3)),cx0=[];cws.reduce((a,w,i)=>(cx0[i]=a,a+w+gap),0);
  const maxN=Math.max(1,...cols.map(c=>c.items.length)),Ht=TOP+maxN*(NH+GAP)+8,P={},nodes=[],links=[];
  cols.forEach((c,ci)=>{const x0=cx0[ci],nw=cws[ci],off=TOP+(maxN-c.items.length)*(NH+GAP)/2;
    nodes.push(`<text class="c-band" x="${x0}" y="12">${c.t}</text>`);
    c.items.forEach((it,i)=>{const y0=off+i*(NH+GAP);P[it.type+it.id]={x0,x1:x0+nw,cy:y0+NH/2};
      let cls='';if(H){const on=it.type==='enabler'?H.en.has(it.id):it.type==='result'?H.res.has(it.id):H.proc.has(it.id);cls=on?'on':'off'}
      if(S.sel&&S.sel.type===it.type&&S.sel.id===it.id)cls+=' sel';if(it.late||(it.type==='enabler'&&EN[it.id].issue))cls+=' bad';
      const hasV=it.v!=null&&it.v>0,maxc=Math.floor((nw-(hasV?52:18)-(it.g?8:0))/6.3);
      const right=hasV?`<text class="n-val" x="${x0+nw-8}" y="${y0+NH/2+3.5}" text-anchor="end">${fmtM(it.v,it.v<10?1:0)}</text>`:'';
      const mark=it.g?`<circle class="c-gdot ${it.g}" cx="${x0+9}" cy="${y0+NH/2}" r="3"/>`:'';
      nodes.push(`<g class="n ${it.type} ${cls}" data-sel="${it.type}:${it.id}" data-tip="<b>${esc(it.name)}</b>"><rect x="${x0}" y="${y0}" width="${nw}" height="${NH}" rx="11"/>${mark}<text class="n-t" x="${x0+(it.g?18:10)}" y="${y0+NH/2+3.5}">${esc(cut(it.name,maxc))}</text>${right}</g>`)})});
  const curve=(a,b,c)=>`<path class="l ${c}" d="M${a.x1},${a.cy}C${(a.x1+b.x0)/2},${a.cy} ${(a.x1+b.x0)/2},${b.cy} ${b.x0},${b.cy}"/>`;
  const st=on=>H?(on?'on':'off'):'';
  ens.forEach(d=>PRE[d.id].forEach(pr=>{if(!directIds.has(d.id)||directIds.has(pr))return;const a=P['enabler'+pr],b=P['enabler'+d.id];if(a&&b)links.push(curve(a,b,'dep '+st(H&&H.en.has(pr)&&H.en.has(d.id))))}));
  p.links.forEach(l=>{const a=P['enabler'+l.enabler],b=P['result'+l.result];if(a&&b)links.push(curve(a,b,st(H&&H.res.has(l.result)&&H.en.has(l.enabler))))});
  rs.forEach(r=>r.procs.forEach(pid=>{const a=P['result'+r.id],b=P['process'+pid];if(a&&b)links.push(curve(a,b,st(H&&H.res.has(r.id))+(pid!==r.process?' dep':'')))}));
  box.innerHTML=`<svg width="${W}" height="${Ht}" viewBox="0 0 ${W} ${Ht}" role="img" aria-label="Value chain">${links.join('')}${nodes.join('')}</svg>`;
  q('.rm-legend').innerHTML='<span>Foundations are needed by enablers · enablers make results possible · results create value for processes</span><span>dashed = prerequisite or shared</span>'}

function render(){
  if(!S.p||!root())return;const H=highlight();
  root().querySelectorAll('[data-view]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.view===S.view));
  (S.view==='chrono'?renderChrono:renderChain)(H)}

function setSel(sel){
  S.sel=sel;render();
  if(window.Shiny&&S.p)Shiny.setInputValue(S.p.ns+'selection',sel?sel.type+':'+sel.id:'',{priority:'event'})}

if(window.Shiny)Shiny.addCustomMessageHandler('roadmap-data',msg=>{
  S.p=typeof msg==='string'?JSON.parse(msg):msg;index(S.p);
  if(S.sel&&((S.sel.type==='result'&&!(RS[S.sel.id]&&RS[S.sel.id].show))||(S.sel.type==='enabler'&&!(EN[S.sel.id]&&EN[S.sel.id].show))))setSel(null);else render()});

document.addEventListener('click',ev=>{
  const r=root();if(!r||!r.contains(ev.target))return;
  const t=ev.target.closest('[data-sel],[data-view],.rm-clear');
  if(!t){if(ev.target.closest('.rm-viz svg')&&S.sel)setSel(null);return}
  if(t.dataset.sel){const[type,id]=t.dataset.sel.split(':');setSel(S.sel&&S.sel.type===type&&S.sel.id===id?null:{type,id});return}
  if(t.dataset.view){S.view=t.dataset.view;render();return}
  if(t.classList.contains('rm-clear'))setSel(null)});

let tip;document.addEventListener('mousemove',ev=>{
  if(!tip){tip=document.createElement('div');tip.id='tip';tip.hidden=true;document.body.appendChild(tip)}
  const t=ev.target.closest&&ev.target.closest('.rm-root [data-tip]');if(!t){tip.hidden=true;return}
  tip.innerHTML=t.dataset.tip;tip.hidden=false;const w=tip.offsetWidth,h=tip.offsetHeight;
  tip.style.left=Math.min(ev.clientX+14,innerWidth-w-8)+'px';tip.style.top=Math.min(ev.clientY+14,innerHeight-h-8)+'px'});
let rz;window.addEventListener('resize',()=>{clearTimeout(rz);rz=setTimeout(render,120)});
$(document).on('shown.bs.tab shown',()=>setTimeout(render,0));
})();
