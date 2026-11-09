/* Roadmap Editor — browser side.
   Board: boxes in four columns (Concepts · Enablers · Results · Processes).
   Drag a box onto another to connect; click a box to focus its links;
   click a line to edit or remove it (Delete key). Everything here runs in
   the browser; R only receives connect / disconnect / selection events. */
(function () {
  'use strict';
  const SVGNS = 'http://www.w3.org/2000/svg';
  const BH = 38, GAP = 6, TOP = 40, MINW = 960;
  // column x and width as a share of the board width
  const LAYOUT = { concept: [0, 0.15], enabler: [0.2, 0.27], result: [0.56, 0.25], process: [0.85, 0.15] };
  const TARGETS = { enabler: ['enabler', 'result', 'concept'], result: ['process'] };

  const B = { el: null, data: null, pos: {}, selBox: '', selLink: '', drag: null, pendingFocus: '', q: '' };
  const esc = s => String(s == null ? '' : s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const kindOf = k => k.slice(0, k.indexOf(':'));
  const clip = (s, n) => (s.length > n ? s.slice(0, Math.max(1, n - 1)) + '…' : s);
  const send = (name, v) => { if (window.Shiny && B.data) Shiny.setInputValue(B.data.ns + name, v, { priority: 'event' }); };
  const typing = () => { const a = document.activeElement; return a && /^(INPUT|TEXTAREA|SELECT)$/.test(a.tagName); };

  // ---------- layout and drawing ----------
  function render() {
    const el = B.el, D = B.data;
    if (!el || !D || !el.clientWidth) return;
    const W = Math.max(el.clientWidth, MINW);
    const P = {};
    let boxes = '', heads = '', maxN = 0;
    D.cols.forEach(c => {
      const [fx, fw] = LAYOUT[c.key];
      const x0 = Math.round(fx * W), w = Math.round(fw * W) - (c.key === 'process' ? 2 : 0);
      const n = Math.max(1, Math.floor((w - 22) / 6.6));
      maxN = Math.max(maxN, c.items.length);
      heads += `<g class="bh"><text class="bh-t" x="${x0}" y="16">${esc(c.title)}<tspan class="bh-n" dx="6">${c.items.length}</tspan></text>` +
        `<g class="bh-add" data-add="${c.key}" role="button" tabindex="0"><title>Add a ${c.key}</title>` +
        `<rect x="${x0 + w - 22}" y="2" width="22" height="20" rx="4"/><text x="${x0 + w - 11}" y="16.5">+</text></g></g>`;
      if (!c.items.length) boxes += `<text class="bx-empty" x="${x0}" y="${TOP + 18}">none yet</text>`;
      c.items.forEach((it, i) => {
        const y0 = TOP + i * (BH + GAP);
        P[it.id] = { x0, x1: x0 + w, y0, cy: y0 + BH / 2, kind: c.key };
        boxes += `<g class="bx${it.g ? ' g-' + esc(it.g) : ''}" data-key="${esc(it.id)}"><title>${esc(it.name)}${it.meta ? ' · ' + esc(it.meta) : ''}</title>` +
          `<rect class="bx-r" x="${x0}" y="${y0}" width="${w}" height="${BH}" rx="6"/>` +
          (it.g ? `<rect class="bx-g" x="${x0}" y="${y0 + 6}" width="3" height="${BH - 12}" rx="1.5"/>` : '') +
          `<text class="bx-t" x="${x0 + 11}" y="${y0 + 16}">${esc(clip(it.name, n))}</text>` +
          `<text class="bx-m" x="${x0 + 11}" y="${y0 + 30}">${esc(clip(it.meta || '', n + 6))}</text></g>`;
      });
    });
    const H = TOP + maxN * (BH + GAP) + 16;
    const gapE = (LAYOUT.result[0] - LAYOUT.enabler[0] - LAYOUT.enabler[1]) * W;
    let links = '';
    D.links.forEach(l => {
      const a = P[l.from], b = P[l.to];
      if (!a || !b) return;
      let d;
      if (l.kind === 'dep') {
        const bulge = Math.min(gapE * 0.85, 16 + Math.abs(b.cy - a.cy) * 0.22);
        d = `M${a.x1},${a.cy}C${a.x1 + bulge},${a.cy} ${b.x1 + bulge},${b.cy} ${b.x1 + 4},${b.cy}`;
      } else if (l.kind === 'cpt') {
        const m = (a.x0 + b.x1) / 2;
        d = `M${a.x0},${a.cy}C${m},${a.cy} ${m},${b.cy} ${b.x1},${b.cy}`;
      } else {
        const m = (a.x1 + b.x0) / 2;
        d = `M${a.x1},${a.cy}C${m},${a.cy} ${m},${b.cy} ${b.x0 - 3},${b.cy}`;
      }
      const v = l.value != null && l.value !== 1 && (l.kind === 're' || l.kind === 'rp' || l.kind === 'lead') ? l.value : null;
      links += `<g class="lk k-${l.kind}" data-link="${esc(l.id)}" data-from="${esc(l.from)}" data-to="${esc(l.to)}">` +
        `<path class="lk-p" d="${d}"${l.kind === 'cpt' ? '' : ' marker-end="url(#ed-ar)"'}/><path class="lk-h" d="${d}"/>` +
        (v != null ? `<text class="lk-v" x="${(a.x1 + b.x0) / 2}" y="${(a.cy + b.cy) / 2 - 4}">${esc(v)}</text>` : '') + '</g>';
    });
    el.innerHTML = `<svg class="ed-svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">` +
      `<defs><marker id="ed-ar" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto-start-reverse">` +
      `<path d="M0,0.5L7.5,4L0,7.5z" class="lk-ar"/></marker></defs>` +
      `<g class="lks">${links}</g>${heads}<g class="bxs">${boxes}</g><path class="rub" d=""/></svg>`;
    B.pos = P;
    if (B.selBox && !P[B.selBox]) B.selBox = '';
    if (B.selLink && !el.querySelector(`[data-link="${CSS.escape(B.selLink)}"]`)) { B.selLink = ''; send('sel_link', ''); }
    if (B.pendingFocus && P[B.pendingFocus]) { select(B.pendingFocus, true); B.pendingFocus = ''; }
    paint();
  }

  // selection, focus and search are classes only: no re-render
  function paint() {
    const el = B.el;
    if (!el || !el.firstChild) return;
    const svg = el.firstChild;
    const rel = new Set();
    svg.classList.toggle('focus', !!(B.selBox || B.selLink));
    svg.querySelectorAll('.lk').forEach(g => {
      const on = (B.selBox && (g.dataset.from === B.selBox || g.dataset.to === B.selBox)) || g.dataset.link === B.selLink;
      g.classList.toggle('on', !!on);
      g.classList.toggle('sel', g.dataset.link === B.selLink);
      if (on) { rel.add(g.dataset.from); rel.add(g.dataset.to); }
    });
    const q = B.q.toLowerCase();
    svg.querySelectorAll('.bx').forEach(g => {
      const k = g.dataset.key;
      g.classList.toggle('sel', k === B.selBox);
      g.classList.toggle('rel', rel.has(k) && k !== B.selBox);
      const t = g.querySelector('title').textContent.toLowerCase();
      g.classList.toggle('miss', !!q && !(t.includes(q) || k.toLowerCase().includes(q)));
    });
  }

  function select(key, scroll) {
    B.selBox = key; B.selLink = '';
    send('sel_box', key); send('sel_link', '');
    paint();
    if (scroll) {
      const g = B.el.querySelector(`.bx[data-key="${CSS.escape(key)}"]`);
      if (g) g.scrollIntoView({ block: 'center', behavior: 'smooth' });
    }
  }
  function selectLink(id) {
    B.selLink = id; B.selBox = '';
    send('sel_link', id); send('sel_box', '');
    paint();
  }
  function clear() {
    if (!B.selBox && !B.selLink) return;
    B.selBox = ''; B.selLink = '';
    send('sel_box', ''); send('sel_link', '');
    paint();
  }

  // ---------- drag to connect ----------
  function svgPoint(e) {
    const r = B.el.firstChild.getBoundingClientRect();
    return { x: e.clientX - r.left, y: e.clientY - r.top };
  }
  function boxAt(e) {
    const t = document.elementFromPoint(e.clientX, e.clientY);
    const g = t && t.closest && t.closest('.bx');
    return g && B.el.contains(g) ? g : null;
  }
  function startDrag(dr) {
    const kind = kindOf(dr.from);
    if (!TARGETS[kind]) return false;
    dr.active = true;
    const svg = B.el.firstChild;
    svg.classList.add('dragging');
    svg.querySelectorAll('.bx').forEach(g => {
      const ok = g.dataset.key !== dr.from && TARGETS[kind].includes(kindOf(g.dataset.key));
      g.classList.toggle('tgt', ok);
      g.classList.toggle('src', g.dataset.key === dr.from);
    });
    autoscroll();
    return true;
  }
  function autoscroll() {
    const dr = B.drag;
    if (!dr || !dr.active) return;
    const y = dr.cy, edge = 56;
    if (y < edge) window.scrollBy(0, -Math.ceil((edge - y) / 4));
    else if (y > window.innerHeight - edge) window.scrollBy(0, Math.ceil((y - window.innerHeight + edge) / 4));
    requestAnimationFrame(autoscroll);
  }
  function moveDrag(e) {
    const dr = B.drag;
    dr.cy = e.clientY;
    const a = B.pos[dr.from], p = svgPoint(e);
    const x = p.x < a.x0 ? a.x0 : a.x1;
    B.el.querySelector('.rub').setAttribute('d', `M${x},${a.cy}L${p.x},${p.y}`);
    const g = boxAt(e);
    B.el.querySelectorAll('.bx.hover').forEach(h => { if (h !== g) h.classList.remove('hover'); });
    if (g && g.classList.contains('tgt')) g.classList.add('hover');
  }
  function endDrag(e) {
    const dr = B.drag;
    B.drag = null;
    if (!dr) return;
    if (!dr.active) { select(dr.from); return; }
    const g = boxAt(e);
    const svg = B.el.firstChild;
    svg.classList.remove('dragging');
    svg.querySelectorAll('.bx').forEach(b => b.classList.remove('tgt', 'src', 'hover'));
    B.el.querySelector('.rub').setAttribute('d', '');
    if (g && g.dataset.key !== dr.from) {
      send('connect', { from: dr.from, to: g.dataset.key, n: Date.now() });
      B.selBox = dr.from; B.selLink = '';
      send('sel_box', dr.from);
      paint();
    }
  }

  document.addEventListener('pointerdown', e => {
    if (!B.el || !B.el.contains(e.target) || e.button !== 0) return;
    const add = e.target.closest('.bh-add');
    if (add) { send('add', add.dataset.add); e.preventDefault(); return; }
    const g = e.target.closest('.bx');
    if (g) { e.preventDefault(); B.drag = { from: g.dataset.key, x: e.clientX, y: e.clientY, cy: e.clientY, active: false }; return; }
    const l = e.target.closest('.lk');
    if (l) { selectLink(l.dataset.link); return; }
    clear();
  });
  document.addEventListener('pointermove', e => {
    const dr = B.drag;
    if (!dr) return;
    if (!dr.active && Math.hypot(e.clientX - dr.x, e.clientY - dr.y) > 5 && !startDrag(dr)) return;
    if (dr.active) moveDrag(e);
  });
  document.addEventListener('pointerup', endDrag);
  document.addEventListener('pointercancel', () => { if (B.drag) { B.drag = null; render(); } });

  document.addEventListener('keydown', e => {
    if (typing()) return;
    if ((e.key === 'Delete' || e.key === 'Backspace') && B.selLink && B.el && B.el.offsetParent) {
      e.preventDefault();
      send('disconnect', B.selLink);
      B.selLink = ''; send('sel_link', '');
    } else if (e.key === 'Escape') {
      clear();
    } else if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'z' && !e.shiftKey) {
      const u = document.getElementById('undo');
      if (u && !u.disabled) { e.preventDefault(); u.click(); }
    }
  });

  // search: dim boxes that don't match; Enter focuses the first match
  document.addEventListener('input', e => {
    if (!e.target.classList.contains('ed-search')) return;
    B.q = e.target.value.trim();
    paint();
  });
  document.addEventListener('keydown', e => {
    if (e.key !== 'Enter' || !e.target.classList.contains('ed-search') || !B.el) return;
    const g = B.el.querySelector('.bx:not(.miss)');
    if (g) select(g.dataset.key, true);
  });

  // item lists: a row with data-pick sets its container's input
  document.addEventListener('click', e => {
    const r = e.target.closest('[data-pick]');
    if (!r) return;
    const box = r.closest('[data-input]');
    if (box && window.Shiny) Shiny.setInputValue(box.dataset.input, r.dataset.pick, { priority: 'event' });
  });

  // unsaved changes: warn before leaving
  let dirty = false;
  window.addEventListener('beforeunload', e => { if (dirty) { e.preventDefault(); e.returnValue = ''; } });

  let rt = null;
  window.addEventListener('resize', () => { clearTimeout(rt); rt = setTimeout(render, 120); });
  $(document).on('shown.bs.tab', render);

  $(document).on('shiny:connected', () => {
    Shiny.addCustomMessageHandler('ed-board', m => {
      B.el = document.getElementById(m.id);
      B.data = JSON.parse(m.data);
      if (!B.drag) render();
    });
    Shiny.addCustomMessageHandler('ed-focus', m => {
      B.el = B.el || document.getElementById(m.id);
      if (B.pos[m.key] && B.el.clientWidth) setTimeout(() => select(m.key, true), 60);
      else B.pendingFocus = m.key;
    });
    Shiny.addCustomMessageHandler('ed-clear', m => clear());
    Shiny.addCustomMessageHandler('ed-dirty', v => { dirty = !!v; document.body.classList.toggle('ed-is-dirty', dirty); });
    Shiny.addCustomMessageHandler('ed-undo', v => { const u = document.getElementById('undo'); if (u) u.disabled = !v; });
  });
})();
