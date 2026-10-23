// RESPONSIVE SWEEP (390 phone / 820 tablet / 1440 laptop) — Chrome MCP javascript_tool mein, logged-in /app tab par chalao.
// Kyun iframe: Chrome ki window maximised ho to resize_window kuch nahi badalta (innerWidth 1536 hi rehta). Same-origin iframe ka viewport
// asli width hota hai, isliye CSS media queries bilkul waise chalti hain. Founder ki window ko haath nahi lagta.
// Chalane ke baad ~3 minute: `JSON.stringify(window.__sweep.filter(r=>r.over||r.off?.length||r.err||r.txt<200))` aur `window.__done`.
// Screenshot ke liye: document.body.innerHTML=''; ek iframe (width 390/820) banao, src=path, phir computer screenshot.
window.__sweep = []; window.__done = false;
const paths = ['/app','/app/mail/inbox','/app/calendar','/app/people','/app/settings','/app/billing','/app/search','/app/crm','/app/work','/app/storage','/app/domains','/app/security','/app/devices','/app/account','/app/ai-center','/app/analytics'];
const widths = [390, 820, 1440];
(async () => {
  for (const w of widths) for (const path of paths) {
    document.body.innerHTML = '';
    const f = document.createElement('iframe');
    f.style.cssText = 'width:' + w + 'px;height:800px;border:0;background:#000'; f.src = path; document.body.appendChild(f);
    await new Promise(r => f.addEventListener('load', r, { once: true })); await new Promise(r => setTimeout(r, 3500));
    let o; try {
      const W = f.contentWindow, D = W.document, iw = W.innerWidth, off = [], small = [];
      for (const el of D.querySelectorAll('body *')) {
        const r = el.getBoundingClientRect(); if (!r.width || !r.height) continue;
        const cs = W.getComputedStyle(el); if (cs.visibility === 'hidden' || cs.display === 'none' || cs.position === 'fixed') continue;
        if (r.right > iw + 1 && off.length < 4) { let c = false; for (let p = el.parentElement; p && p !== D.body; p = p.parentElement) { if (/(auto|scroll|hidden|clip)/.test(W.getComputedStyle(p).overflowX)) { c = true; break; } } if (!c) off.push(el.tagName + '.' + String(el.className).slice(0, 40) + ' r' + Math.round(r.right)); }
        if (/^(BUTTON|A|SELECT)$/.test(el.tagName) || el.getAttribute('role') === 'button') { if ((r.height < 32 || r.width < 32) && small.length < 40 && !el.closest('[aria-hidden=true]')) small.push((el.getAttribute('aria-label') || el.textContent || el.tagName).trim().slice(0, 22) + ' ' + Math.round(r.width) + 'x' + Math.round(r.height)); }
      }
      o = { w, path, at: W.location.pathname, over: D.documentElement.scrollWidth > iw + 1, sw: D.documentElement.scrollWidth, off, smallN: small.length, small: small.slice(0, 4), txt: (D.body.innerText || '').length };
    } catch (e) { o = { w, path, err: e.message }; }
    window.__sweep.push(o);
  }
  window.__done = true;
})();
