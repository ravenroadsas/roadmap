/* Roadmap canvas: timeline, value chain, results list and highlighting.
   Value chain: process -> results (KPIs and milestones) -> required enablers
   -> foundations. Runs fully in the browser; R sends a payload (custom
   message "roadmap-data") and receives the selection as input "<ns>selection". */
(function(){
'use strict';
const S={p:null,sel:null,view:'timeline',alldeps:false};
const esc=s=>String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const arr=x=>x==null?[]:Array.isArray(x)?x:[x];
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const fmtM=(v,d=1)=>(v<0?'−':'')+'$'+Math.abs(v).toFixed(d)+'M';
const fmtN=(v,u)=>{const s=Math.abs(v)>=1000?Number(v).toLocaleString('en-US'):String(v);return u==='$M'?'$'+s+'M':u==='%'?s+'%':s+' '+u};
const qlab=t=>{const e=Math.ceil(t*4-1e-9)/4-0.25,y=Math.floor(e+1e-9);return y+'Q'+(Math.round((e-y)*4)+1)};
const GCOL=g=>`var(--${g})`;
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

const KIND={kpi:'KPI',milestone:'MILESTONE'};
function renderResults(H){
  const ks=S.p.results.filter(k=>k.show);const box=q('.rm-klist');
  const nk=ks.filter(k=>k.kind==='kpi').length;
  q('.rm-kcount').textContent=`${nk} KPIs · ${ks.length-nk} milestones`;
  box.innerHTML=ks.map(k=>{const cls=S.sel&&S.sel.type==='result'&&S.sel.id===k.id?'sel':H?(H.res.has(k.id)?'hl':'dim'):'';
    const what=k.kind==='kpi'?`<span class="mono">${fmtN(k.baseline,k.unit)} → ${fmtN(k.target,k.unit)}</span>·`:'';
    const due=`<span class="mono${k.late?' neg':''}">due ${esc(k.due)}${k.late?' ⚠ ready '+qlab(k.t_ready):''}</span>`;
    return `<button class="kcard ${cls}${k.late?' late':''}" data-sel="result:${k.id}"><span class="ktop"><span class="kn"><span class="ktag ${k.kind}">${KIND[k.kind]}</span> ${esc(k.name)}</span><span class="kv">${k.run>0?fmtM(k.run)+'/yr':''}</span></span>
      <span class="km"><span>${esc(k.process_name)}${k.procs.length>1?' <span class="shared-tag">+'+(k.procs.length-1)+' shared</span>':''}</span>·${what}${due}</span></button>`}).join('')||'<div class="fsec hint">No result matches the filters.</div>'}

function legend(extra){q('.rm-legend').innerHTML=S.p.groups.map(g=>`<span><i class="dot ${g.id}"></i>${esc(g.name)}</span>`).join('')+extra}

function issueSets(){const ids=new Set(),pairs=new Set();arr(S.p.issues).forEach(i=>{ids.add(i.enabler_id);if(i.related_id)pairs.add(i.related_id+'>'+i.enabler_id)});return{ids,pairs}}
function renderTimeline(H){
  const p=S.p,box=q('.rm-viz'),W=Math.max(760,box.parentElement.clientWidth-2),L=220,R=56;
  const T0=Math.floor(Math.min(...p.enablers.map(e=>Math.min(e.t0,e.t1_plan)))),T1=Math.ceil(Math.max(...p.enablers.map(e=>Math.max(e.t1,e.t1_plan))));const IS=issueSets();
  const x=t=>L+(t-T0)/(T1-T0)*(W-L-R);const ens=p.enablers.filter(e=>e.show);
  let y=46;const pos={},body=[];
  // results: one lane per process, KPIs (circle) and milestones (diamond) at their due date
  const shownR=p.results.filter(r=>r.show);
  body.push(`<text class="t-grp" x="0" y="${y+8}">Results (due date)</text><line class="gl" x1="0" x2="${W}" y1="${y+14}" y2="${y+14}"/>`);y+=20;
  p.processes.filter(pr=>shownR.some(r=>r.procs.includes(pr.id))).forEach(pr=>{const cy=y+9;
    const pcls=H?(H.proc.has(pr.id)?'':'off'):'';
    body.push(`<text class="t-lbl lane ${pcls}" x="14" y="${cy+4}" data-sel="process:${pr.id}" data-tip="<b>${esc(pr.name)}</b>">${esc(pr.name.length>32?pr.name.slice(0,31)+'…':pr.name)}</text><line class="lane-l" x1="${L}" x2="${W-R}" y1="${cy}" y2="${cy}"/>`);
    shownR.filter(r=>r.procs.includes(pr.id)).forEach(r=>{const xd=x(r.t_due);let cls=H?(H.res.has(r.id)?'on':'off'):'';
      const shr=r.procs.length>1?r.shares[r.procs.indexOf(pr.id)]:1;if(r.procs.length>1&&r.process!==pr.id)cls+=' shared';
      if(S.sel&&S.sel.type==='result'&&S.sel.id===r.id)cls+=' sel';if(r.late)cls+=' late';
      const shape=r.kind==='milestone'?`<path d="M${xd},${cy-6}L${xd+6},${cy}L${xd},${cy+6}L${xd-6},${cy}Z"/>`:`<circle cx="${xd}" cy="${cy}" r="5"/>`;
      const lateMark=r.late?`<line class="late-l" x1="${xd}" x2="${x(r.t_ready)}" y1="${cy}" y2="${cy}"/><circle class="late-r" cx="${x(r.t_ready)}" cy="${cy}" r="3"/>`:'';
      const lab=H&&H.res.has(r.id)?`<text class="t-ms" x="${xd+9}" y="${cy-6}">${esc(r.name.length>40?r.name.slice(0,39)+'…':r.name)}</text>`:'';
      body.push(`<g class="res ${cls}" data-sel="result:${r.id}" data-tip="<b>${KIND[r.kind]} · ${esc(r.name)}</b><br>${esc(pr.name)}${r.procs.length>1?' · share '+Math.round(shr*100)+'%'+(r.process===pr.id?' (lead)':''):''}<br>due ${esc(r.due)} · ready ${qlab(r.t_ready)}${r.late?'<br><b>⚠ late</b>':''}${r.run>0?'<br>'+fmtM(r.run)+'/yr at full adoption':''}">${lateMark}${shape}${lab}</g>`)});
    y+=22});
  y+=6;
  p.groups.forEach(g=>{const rows=ens.filter(e=>e.grp===g.id);if(!rows.length)return;
    y+=8;body.push(`<rect x="0" y="${y-1}" width="9" height="9" rx="2" style="fill:${GCOL(g.id)}"/><text class="t-grp" x="14" y="${y+7}">${esc(g.name)}</text><line class="gl" x1="0" x2="${W}" y1="${y+14}" y2="${y+14}"/>`);y+=22;
    rows.forEach(e=>{const cy=y+9,x1=x(e.t0),x2=x(e.t1);pos[e.id]={cy,x1,x2};
      let cls='';if(H)cls=H.direct.has(e.id)?'on':H.en.has(e.id)?'found':'off';
      if(S.sel&&S.sel.type==='enabler'&&S.sel.id===e.id)cls+=' sel';
      const iss=IS.ids.has(e.id)||e.issue;if(iss)cls+=' issue';
      const comp=e.compression>0?`<br>${Math.round(e.compression*100)}% shorter with extra resources (plan ends ${e.end})`:'';
      const ghost=e.compression>0?`<rect class="plan-ghost" x="${x1}" y="${cy-6}" width="${Math.max(3,x(e.t1_plan)-x1)}" height="12" rx="2"/>`:'';
      const nm=(iss?'⚠ ':'')+(e.name.length>32?e.name.slice(0,31)+'…':e.name);
      body.push(`<g class="bar ${cls}" data-sel="enabler:${e.id}" data-tip="<b>${esc(e.name)}</b><br>${esc(g.name)} › ${esc(e.sub)}<br>${e.start} – ${e.end}${comp}<br>Capex ${fmtM(e.capex)} · Opex ${fmtM(e.opex)}/yr<br>FTE ${e.fte_int} internal · ${e.fte_ext} partner${e.issue?'<br><b>⚠ '+esc(e.issue)+'</b>':''}">
        <text class="t-lbl" x="14" y="${cy+4}">${esc(nm)}</text>${ghost}
        <rect class="b" x="${x1}" y="${cy-6}" width="${Math.max(3,x2-x1)}" height="12" style="fill:${GCOL(e.grp)};stroke:${GCOL(e.grp)}"/>
        <text class="t-cost" x="${x2+5}" y="${cy+3.5}">${fmtM(e.capex)}</text></g>`);y+=22})});
  const Ht=y+12,grid=[];
  for(let t=T0;t<=T1+1e-9;t+=.25){const yr=Math.abs(t-Math.round(t))<1e-6;
    grid.push(`<line class="gl ${yr?'y':''}" x1="${x(t)}" x2="${x(t)}" y1="${yr?14:30}" y2="${Ht}"/>`);
    if(yr&&t<T1-1e-9)grid.push(`<text class="t-axis" x="${x(t)+4}" y="14">${Math.round(t)}</text>`);
    if(t<T1-1e-9)grid.push(`<text class="t-q" x="${x(t+.125)}" y="38" text-anchor="middle">Q${Math.round((t-Math.floor(t+1e-9))*4)+1}</text>`)}
  if(p.today>T0&&p.today<T1)grid.push(`<line class="today" x1="${x(p.today)}" x2="${x(p.today)}" y1="20" y2="${Ht}"/><text class="t-today" x="${x(p.today)+3}" y="27">today</text>`);
  const edges=[];ens.forEach(d=>PRE[d.id].forEach(pr=>{if(!pos[pr]||!pos[d.id])return;
    const bad=IS.pairs.has(pr+'>'+d.id);const on=H&&H.en.has(pr)&&H.en.has(d.id);if(!on&&!S.alldeps&&!bad)return;const a=pos[pr],b=pos[d.id],sg=b.cy>a.cy?1:-1;
    const ec=bad?'issue':on?'':'faint',mk=bad?'url(#rm-ahr)':'url(#rm-ah)';
    if(a.x2<=b.x1+1){const mx=(a.x2+b.x1)/2;edges.push(`<path class="edge ${ec}" d="M${a.x2},${a.cy}C${Math.max(mx,a.x2+18)},${a.cy} ${Math.min(mx,b.x1-18)},${b.cy} ${b.x1-1},${b.cy}" marker-end="${mk}"/>`)}
    else{const xt=clamp(a.x2,b.x1,b.x2);edges.push(`<circle cx="${a.x2}" cy="${a.cy}" r="2" class="arrowhead ${bad?'issue':''}" ${on||bad?'':'opacity=".2"'}/><path class="edge ${ec}" d="M${a.x2},${a.cy+sg*6}L${bad?a.x2:xt},${b.cy-sg*8}" marker-end="${mk}"/>`)}}));
  box.innerHTML=`<svg width="${W}" height="${Ht}" viewBox="0 0 ${W} ${Ht}" role="img" aria-label="Enabler timeline"><defs><marker id="rm-ah" viewBox="0 0 6 6" refX="5" refY="3" markerWidth="6" markerHeight="6" orient="auto"><path class="arrowhead" d="M0,0L6,3L0,6Z"/></marker><marker id="rm-ahr" viewBox="0 0 6 6" refX="5" refY="3" markerWidth="6" markerHeight="6" orient="auto"><path class="arrowhead issue" d="M0,0L6,3L0,6Z"/></marker></defs>${grid.join('')}${body.join('')}${edges.join('')}</svg>`;
  legend(`<span>● KPI</span><span>◆ milestone</span><span>◇ shared, in another process's lane</span><span style="color:var(--neg)">●— late result (line to the date it can be ready)</span><span><svg width="22" height="10"><rect x="1" y="1" width="20" height="8" rx="2" style="fill:var(--ink)"/></svg>required enabler</span><span><svg width="22" height="10"><rect x="1" y="1" width="20" height="8" rx="2" style="fill:var(--ink);fill-opacity:.3;stroke:var(--ink);stroke-dasharray:3 2"/></svg>foundation (prerequisite)</span><span>label = capex incl. overrun, scenario effort</span><span><svg width="22" height="10"><rect x="1" y="1" width="20" height="8" rx="2" class="plan-ghost"/></svg>plan duration (when shortened)</span><span style="color:var(--neg)">⚠ red = date issue</span>`)}

function renderChain(H){
  const p=S.p,box=q('.rm-viz'),W=Math.max(760,box.parentElement.clientWidth-4);const ens=p.enablers.filter(e=>e.show);
  const rs=p.results.filter(k=>k.show);const procs=p.processes.filter(x=>x.show);
  const runP={};rs.forEach(r=>r.procs.forEach((pid,i)=>runP[pid]=(runP[pid]||0)+r.run*(r.shares[i]==null?1:r.shares[i])));
  const en=g=>ens.filter(e=>e.grp===g).map(e=>({id:e.id,type:'enabler',name:e.name,g:e.grp}));
  const order=procs.map(x=>x.id);
  const cols=[{t:'Infrastructure',items:en('infra')},{t:'Data',items:en('data')},{t:'People',items:en('people')},{t:'Digital solutions',items:en('digital')},
    {t:'Results (KPI ● · milestone ◆)',items:rs.slice().sort((a,b)=>order.indexOf(a.process)-order.indexOf(b.process)||a.kind.localeCompare(b.kind)).map(k=>({id:k.id,type:'result',name:(k.kind==='kpi'?'● ':'◆ ')+k.name,run:k.run,late:k.late}))},
    {t:'Processes (value)',items:procs.map(x=>({id:x.id,type:'process',name:x.name,run:runP[x.id]||0}))}];
  const NH=24,GAP=6,TOP=34,wts=[.85,.85,.9,1.05,1.45,1.15],ws=wts.reduce((a,b)=>a+b,0),cws=wts.map(w=>w/ws*W),cx0=[];cws.reduce((a,w,i)=>(cx0[i]=a,a+w),0);
  const maxN=Math.max(1,...cols.map(c=>c.items.length)),Ht=TOP+maxN*(NH+GAP)+10,P={},nodes=[],links=[];
  cols.forEach((c,ci)=>{const x0=cx0[ci]+2,nw=cws[ci]-(ci===cols.length-1?6:24),off=TOP+(maxN-c.items.length)*(NH+GAP)/2;
    nodes.push(`<text class="t-grp" x="${x0}" y="14">${c.t}</text>`);
    c.items.forEach((it,i)=>{const y0=off+i*(NH+GAP);P[it.type+it.id]={x0,x1:x0+nw,cy:y0+NH/2};
      let cls='';if(H){const on=it.type==='enabler'?H.en.has(it.id):it.type==='result'?H.res.has(it.id):H.proc.has(it.id);cls=on?'on':'off'}
      if(S.sel&&S.sel.type===it.type&&S.sel.id===it.id)cls+=' sel';
      if((it.type==='enabler'&&EN[it.id]&&EN[it.id].issue)||it.late)cls+=' issue';
      const hasV=it.type!=='enabler'&&it.run>0,maxc=Math.floor((nw-(hasV?44:14))/5.4),nm=it.name.length>maxc?it.name.slice(0,maxc-1)+'…':it.name;
      const right=hasV?`<text class="t-nodev" x="${x0+nw-5}" y="${y0+NH/2+3.5}" text-anchor="end">${fmtM(it.run,0)}</text>`:'';
      const bar=it.g?`<rect x="${x0}" y="${y0}" width="4" height="${NH}" style="fill:${GCOL(it.g)};stroke:none"/>`:'';
      nodes.push(`<g class="node ${cls}" data-sel="${it.type}:${it.id}" data-tip="<b>${esc(it.name)}</b>${it.late?'<br>⚠ late':''}"><rect x="${x0}" y="${y0}" width="${nw}" height="${NH}" rx="3"/>${bar}<text class="t-node" x="${x0+9}" y="${y0+NH/2+3.5}">${esc(nm)}</text>${right}</g>`)})});
  const curve=(a,b,c)=>`<path class="lnk ${c}" d="M${a.x1},${a.cy}C${(a.x1+b.x0)/2},${a.cy} ${(a.x1+b.x0)/2},${b.cy} ${b.x0},${b.cy}"/>`;
  const st=on=>H?(on?'on':'off'):'';
  ens.forEach(d=>PRE[d.id].forEach(pr=>{const a=P['enabler'+pr],b=P['enabler'+d.id];if(a&&b)links.push(curve(a,b,'pre '+st(H&&H.en.has(pr)&&H.en.has(d.id))))}));
  p.links.forEach(l=>{const a=P['enabler'+l.enabler],b=P['result'+l.result];if(a&&b)links.push(curve(a,b,st(H&&H.res.has(l.result)&&H.en.has(l.enabler))))});
  rs.forEach(r=>r.procs.forEach(pid=>{const a=P['result'+r.id],b=P['process'+pid];if(a&&b)links.push(curve(a,b,st(H&&H.res.has(r.id))+(pid!==r.process?' pre':'')))}));
  box.innerHTML=`<svg width="${W}" height="${Ht}" viewBox="0 0 ${W} ${Ht}" role="img" aria-label="Value chain">${links.join('')}${nodes.join('')}</svg>`;
  legend('<span>– – prerequisite / shared with</span><span>── required by / belongs to (lead)</span><span>label = run-rate $M/yr</span><span style="color:var(--neg)">red = late result or date issue</span>')}

function render(){
  if(!S.p||!root())return;const H=highlight();renderResults(H);
  const IL=arr(S.p.issues),nl=IL.filter(i=>i.type==='prereq_ends_later').length,nb=IL.length-nl,nr=S.p.results.filter(r=>r.late).length,bi=q('.rm-issues');
  if(bi)bi.textContent=(IL.length||nr)?'⚠ '+[nr?`${nr} late result${nr>1?'s':''}`:'',nl?`${nl} late dependenc${nl>1?'ies':'y'}`:'',nb?`${nb} date error${nb>1?'s':''}`:''].filter(Boolean).join(', '):'';
  root().querySelectorAll('[data-view]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.view===S.view));
  (S.view==='timeline'?renderTimeline:renderChain)(H)}

function setSel(sel){
  S.sel=sel;render();
  if(window.Shiny&&S.p)Shiny.setInputValue(S.p.ns+'selection',sel?sel.type+':'+sel.id:'',{priority:'event'});
  const c=q('.rm-clearsel');if(c)c.hidden=!sel}

if(window.Shiny)Shiny.addCustomMessageHandler('roadmap-data',msg=>{
  S.p=typeof msg==='string'?JSON.parse(msg):msg;index(S.p);
  if(S.sel&&((S.sel.type==='result'&&!RS[S.sel.id])||(S.sel.type==='enabler'&&!EN[S.sel.id])))setSel(null);else render()});

document.addEventListener('click',ev=>{
  const r=root();if(!r||!r.contains(ev.target))return;
  const t=ev.target.closest('[data-sel],[data-view],.rm-clearsel');
  if(!t){if(ev.target.closest('.rm-viz svg')&&S.sel)setSel(null);return}
  if(t.dataset.sel){const[type,id]=t.dataset.sel.split(':');setSel(S.sel&&S.sel.type===type&&S.sel.id===id?null:{type,id});return}
  if(t.dataset.view){S.view=t.dataset.view;render();return}
  if(t.classList.contains('rm-clearsel'))setSel(null)});
document.addEventListener('change',ev=>{if(ev.target.classList&&ev.target.classList.contains('rm-alldeps')){S.alldeps=ev.target.checked;render()}});

let tip;document.addEventListener('mousemove',ev=>{
  if(!tip){tip=document.createElement('div');tip.id='tip';tip.hidden=true;document.body.appendChild(tip)}
  const t=ev.target.closest&&ev.target.closest('.rm-root [data-tip]');if(!t){tip.hidden=true;return}
  tip.innerHTML=t.dataset.tip;tip.hidden=false;const w=tip.offsetWidth,h=tip.offsetHeight;
  tip.style.left=Math.min(ev.clientX+14,innerWidth-w-8)+'px';tip.style.top=Math.min(ev.clientY+14,innerHeight-h-8)+'px'});
let rz;window.addEventListener('resize',()=>{clearTimeout(rz);rz=setTimeout(render,120)});
document.addEventListener('shown.bs.tab',()=>setTimeout(render,0));
$(document).on('shown.bs.tab shown',()=>setTimeout(render,0));
})();
