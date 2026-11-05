/* Roadmap canvas: timeline, value chain, KPI list and highlighting.
   Runs fully in the browser; R sends a payload (custom message
   "roadmap-data") and receives the selection as input "<ns>selection". */
(function(){
'use strict';
const S={p:null,sel:null,view:'timeline',alldeps:false};
const esc=s=>String(s==null?'':s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const arr=x=>x==null?[]:Array.isArray(x)?x:[x];
const clamp=(v,a,b)=>Math.max(a,Math.min(b,v));
const fmtM=(v,d=1)=>(v<0?'−':'')+'$'+Math.abs(v).toFixed(d)+'M';
const fmtN=(v,u)=>{const s=Math.abs(v)>=1000?Number(v).toLocaleString('en-US'):String(v);return u==='$M'?'$'+s+'M':u==='%'?s+'%':s+' '+u};
const GCOL=g=>`var(--${g})`;
const root=()=>document.querySelector('.rm-root');
const q=s=>root()&&root().querySelector(s);

let EN={},KP={},DEP={},PRE={};
function index(p){
  EN={};KP={};DEP={};PRE={};
  p.enablers.forEach(e=>{EN[e.id]=e;PRE[e.id]=arr(p.prereq[e.id]);DEP[e.id]=[]});
  p.enablers.forEach(e=>PRE[e.id].forEach(x=>DEP[x]&&DEP[x].push(e.id)));
  p.kpis.forEach(k=>KP[k.id]=k);
}
function walk(ids,next){const out=new Set(),st=[...ids];while(st.length){const id=st.pop();(next[id]||[]).forEach(n=>{if(!out.has(n)){out.add(n);st.push(n)}})}return out}

function highlight(){
  const s=S.sel,p=S.p;if(!s||!p)return null;let direct,en,kpi,proc;
  if(s.type==='kpi'){direct=new Set(p.links.filter(l=>l.kpi===s.id).map(l=>l.enabler));en=new Set([...direct,...walk(direct,PRE)]);kpi=new Set([s.id]);proc=new Set([KP[s.id].process])}
  else if(s.type==='enabler'){const down=walk([s.id],DEP);direct=new Set([s.id]);en=new Set([s.id,...walk([s.id],PRE),...down]);
    kpi=new Set(p.links.filter(l=>l.enabler===s.id||down.has(l.enabler)).map(l=>l.kpi));proc=new Set([...kpi].map(k=>KP[k]&&KP[k].process))}
  else{kpi=new Set(p.kpis.filter(k=>k.process===s.id).map(k=>k.id));direct=new Set(p.links.filter(l=>kpi.has(l.kpi)).map(l=>l.enabler));
    en=new Set([...direct,...walk(direct,PRE)]);proc=new Set([s.id])}
  return{direct,en,kpi,proc}}

function renderKpis(H){
  const ks=S.p.kpis.filter(k=>k.show);const box=q('.rm-klist');
  q('.rm-kcount').textContent=ks.length+' shown';
  box.innerHTML=ks.map(k=>{const cls=S.sel&&S.sel.type==='kpi'&&S.sel.id===k.id?'sel':H?(H.kpi.has(k.id)?'hl':'dim'):'';
    return `<button class="kcard ${cls}" data-sel="kpi:${k.id}"><span class="ktop"><span class="kn">${esc(k.name)}</span><span class="kv">${fmtM(k.run)}/yr</span></span>
      <span class="km"><span>${esc(k.process_name)}</span>·<span class="mono">${fmtN(k.baseline,k.unit)} → ${fmtN(k.target,k.unit)}</span></span></button>`}).join('')||'<div class="fsec hint">No KPI matches the filters.</div>'}

function legend(extra){q('.rm-legend').innerHTML=S.p.groups.map(g=>`<span><i class="dot ${g.id}"></i>${esc(g.name)}</span>`).join('')+extra}

function issueSets(){const ids=new Set(),pairs=new Set();arr(S.p.issues).forEach(i=>{ids.add(i.enabler_id);if(i.related_id)pairs.add(i.related_id+'>'+i.enabler_id)});return{ids,pairs}}
function renderTimeline(H){
  const p=S.p,box=q('.rm-viz'),W=Math.max(760,box.parentElement.clientWidth-2),L=220,R=56;
  const T0=Math.floor(Math.min(...p.enablers.map(e=>Math.min(e.t0,e.t1_plan)))),T1=Math.ceil(Math.max(...p.enablers.map(e=>Math.max(e.t1,e.t1_plan))));const IS=issueSets();
  const x=t=>L+(t-T0)/(T1-T0)*(W-L-R);const ens=p.enablers.filter(e=>e.show);
  let y=46;const pos={},body=[];const msY=y+4;
  p.milestones.forEach(mm=>{if(!EN[mm.enabler])return;const cls=H?(H.en.has(mm.enabler)?'on':'off'):'';const mx=x(mm.t);
    body.push(`<g class="ms ${cls}" data-sel="enabler:${mm.enabler}" data-tip="<b>${esc(mm.id)} · ${esc(mm.name)}</b><br>${esc(mm.date)}${Math.abs(mm.t-mm.t_plan)>0.02?' → moved to '+(Math.floor(mm.t))+'-'+String(Math.min(12,Math.floor((mm.t%1)*12)+1)).padStart(2,'0'):''} · ${esc(EN[mm.enabler].name)}">
      <path d="M${mx},${msY-6}L${mx+6},${msY}L${mx},${msY+6}L${mx-6},${msY}Z"/><text class="${H&&H.en.has(mm.enabler)?'t-ms':'t-q'}" x="${mx}" y="${msY+17}" text-anchor="middle">${esc(mm.id)}</text></g>`)});
  body.push(`<text class="t-grp" x="0" y="${msY+4}">Milestones</text>`);y+=34;
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
  legend(`<span><svg width="22" height="10"><rect x="1" y="1" width="20" height="8" rx="2" style="fill:var(--ink)"/></svg>direct enabler</span><span><svg width="22" height="10"><rect x="1" y="1" width="20" height="8" rx="2" style="fill:var(--ink);fill-opacity:.3;stroke:var(--ink);stroke-dasharray:3 2"/></svg>foundation (prerequisite)</span><span>◇ milestone</span><span>label = capex incl. overrun, scenario effort</span><span><svg width="22" height="10"><rect x="1" y="1" width="20" height="8" rx="2" class="plan-ghost"/></svg>plan duration (when shortened)</span><span style="color:var(--neg)">⚠ red = date issue</span>`)}

function renderChain(H){
  const p=S.p,box=q('.rm-viz'),W=Math.max(700,box.parentElement.clientWidth-4);const ens=p.enablers.filter(e=>e.show);const ks=p.kpis.filter(k=>k.show);
  const procs=p.processes.filter(x=>x.show);const en=g=>ens.filter(e=>e.grp===g).map(e=>({id:e.id,type:'enabler',name:e.name,g:e.grp}));
  const cols=[{t:'Infrastructure',items:en('infra')},{t:'Data',items:en('data')},{t:'People',items:en('people')},{t:'Digital solutions',items:en('digital')},
    {t:'Processes',items:procs.map(x=>({id:x.id,type:'process',name:x.name}))},{t:'KPIs',items:ks.map(k=>({id:k.id,type:'kpi',name:k.name,run:k.run}))}];
  const NH=24,GAP=7,TOP=34,wts=[.9,.9,.95,1.1,1.05,1.3],ws=wts.reduce((a,b)=>a+b,0),cws=wts.map(w=>w/ws*W),cx0=[];cws.reduce((a,w,i)=>(cx0[i]=a,a+w),0);
  const maxN=Math.max(1,...cols.map(c=>c.items.length)),Ht=TOP+maxN*(NH+GAP)+10,P={},nodes=[],links=[];
  cols.forEach((c,ci)=>{const x0=cx0[ci]+2,nw=cws[ci]-(ci===cols.length-1?6:24),off=TOP+(maxN-c.items.length)*(NH+GAP)/2;
    nodes.push(`<text class="t-grp" x="${x0}" y="14">${c.t}</text>`);
    c.items.forEach((it,i)=>{const y0=off+i*(NH+GAP);P[it.type+it.id]={x0,x1:x0+nw,cy:y0+NH/2};
      let cls='';if(H){const on=it.type==='enabler'?H.en.has(it.id):it.type==='kpi'?H.kpi.has(it.id):H.proc.has(it.id);cls=on?'on':'off'}
      if(S.sel&&S.sel.type===it.type&&S.sel.id===it.id)cls+=' sel';
      if(it.type==='enabler'&&EN[it.id]&&EN[it.id].issue)cls+=' issue';
      const maxc=Math.floor((nw-(it.type==='kpi'?44:14))/5.4),nm=it.name.length>maxc?it.name.slice(0,maxc-1)+'…':it.name;
      const right=it.type==='kpi'?`<text class="t-nodev" x="${x0+nw-5}" y="${y0+NH/2+3.5}" text-anchor="end">${fmtM(it.run,0)}</text>`:'';
      const bar=it.g?`<rect x="${x0}" y="${y0}" width="4" height="${NH}" style="fill:${GCOL(it.g)};stroke:none"/>`:'';
      nodes.push(`<g class="node ${cls}" data-sel="${it.type}:${it.id}" data-tip="<b>${esc(it.name)}</b>"><rect x="${x0}" y="${y0}" width="${nw}" height="${NH}" rx="3"/>${bar}<text class="t-node" x="${x0+9}" y="${y0+NH/2+3.5}">${esc(nm)}</text>${right}</g>`)})});
  const curve=(a,b,c)=>`<path class="lnk ${c}" d="M${a.x1},${a.cy}C${(a.x1+b.x0)/2},${a.cy} ${(a.x1+b.x0)/2},${b.cy} ${b.x0},${b.cy}"/>`;
  const st=on=>H?(on?'on':'off'):'';
  ens.forEach(d=>PRE[d.id].forEach(pr=>{const a=P['enabler'+pr],b=P['enabler'+d.id];if(a&&b)links.push(curve(a,b,'pre '+st(H&&H.en.has(pr)&&H.en.has(d.id))))}));
  const seen=new Set();p.links.forEach(l=>{const k=KP[l.kpi];if(!k)return;const key=l.enabler+k.process;if(seen.has(key))return;
    const a=P['enabler'+l.enabler],b=P['process'+k.process];if(!a||!b)return;seen.add(key);
    const on=H&&H.en.has(l.enabler)&&H.proc.has(k.process)&&p.links.some(x=>x.enabler===l.enabler&&H.kpi.has(x.kpi)&&KP[x.kpi].process===k.process);
    links.push(curve(a,b,st(on)))});
  ks.forEach(k=>{const a=P['process'+k.process],b=P['kpi'+k.id];if(a&&b)links.push(curve(a,b,st(H&&H.kpi.has(k.id))))});
  box.innerHTML=`<svg width="${W}" height="${Ht}" viewBox="0 0 ${W} ${Ht}" role="img" aria-label="Value chain">${links.join('')}${nodes.join('')}</svg>`;
  legend('<span>– – prerequisite</span><span>── contributes to</span><span>KPI label = run-rate $M/yr</span>')}

function render(){
  if(!S.p||!root())return;const H=highlight();renderKpis(H);
  const IL=arr(S.p.issues),nl=IL.filter(i=>i.type==='prereq_ends_later').length,nb=IL.length-nl,bi=q('.rm-issues');if(bi)bi.textContent=IL.length?'⚠ '+[nl?`${nl} late dependenc${nl>1?'ies':'y'}`:'',nb?`${nb} date error${nb>1?'s':''}`:''].filter(Boolean).join(', '):'';
  root().querySelectorAll('[data-view]').forEach(b=>b.setAttribute('aria-pressed',b.dataset.view===S.view));
  (S.view==='timeline'?renderTimeline:renderChain)(H)}

function setSel(sel){
  S.sel=sel;render();
  if(window.Shiny&&S.p)Shiny.setInputValue(S.p.ns+'selection',sel?sel.type+':'+sel.id:'',{priority:'event'});
  const c=q('.rm-clearsel');if(c)c.hidden=!sel}

if(window.Shiny)Shiny.addCustomMessageHandler('roadmap-data',msg=>{
  S.p=typeof msg==='string'?JSON.parse(msg):msg;index(S.p);
  if(S.sel&&((S.sel.type==='kpi'&&!KP[S.sel.id])||(S.sel.type==='enabler'&&!EN[S.sel.id])))setSel(null);else render()});

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
