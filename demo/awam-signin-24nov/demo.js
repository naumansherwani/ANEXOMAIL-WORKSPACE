/* AWAM SIGN-IN DEMO (24 Nov 2026), DEMO ONLY: nothing here is in src/. It is injected into the REAL awam /auth page by run.cjs,
 * so what he sees is the real page with only these changes. Options: window.GG = { state: "idle" | "verify" | "passkey" }.
 * Texts: right card heading "Enter The Global Grid" + sub "Your enterprise. Your network. Your access."; left: logo palette, grid, scan light,
 * INSIDE THE GLOBAL GRID, Rule 52 technology list; right: navy glow, grid, dust, glass card, amber floor light.
 * WEBSITE PROMISES (his 17 Nov): the HTTP/3, AES-256 and X25519MLKEM768 list lines must NOT go live on the awam page until K5b is proven. */
(() => {
  const GG = window.GG || { state: "idle" };
  for (const e of document.querySelectorAll("h1,h2,p,div")) if (e.children.length === 0) {
    const t = e.textContent.trim();
    if (t === "Sign in" && e.tagName !== "BUTTON") e.textContent = "Enter The Global Grid";
    else if (t.startsWith("Your mail, people, calendar and work")) e.textContent = "Your enterprise. Your network. Your access.";
  }
  const css = document.createElement("style");
  css.textContent = `
  main{background:#070d1a!important}
  aside .ax-auth-cinema-bg{background:linear-gradient(135deg,#0b1220 0%,#1E3557 38%,#2C4C79 62%,#0b1220 100%)!important;background-size:400% 400%!important}
  aside .ax-auth-cinema-mesh{background-image:radial-gradient(ellipse 60% 50% at 35% 30%,rgba(111,166,242,.20) 0%,transparent 70%),radial-gradient(ellipse 50% 60% at 70% 75%,rgba(195,204,216,.10) 0%,transparent 70%)!important}
  .gg-grid,.gg-rgrid{position:absolute;inset:0;pointer-events:none;background-image:linear-gradient(rgba(195,204,216,.08) 1px,transparent 1px),linear-gradient(90deg,rgba(195,204,216,.08) 1px,transparent 1px);background-size:44px 44px;-webkit-mask-image:radial-gradient(ellipse 75% 60% at 50% 45%,#000 20%,transparent 75%);mask-image:radial-gradient(ellipse 75% 60% at 50% 45%,#000 20%,transparent 75%);animation:ggdrift 18s linear infinite}
  .gg-rgrid{opacity:.65}
  @keyframes ggdrift{from{background-position:0 0}to{background-position:44px 44px}}
  .gg-scan{position:absolute;left:0;right:0;height:140px;pointer-events:none;background:linear-gradient(180deg,transparent,rgba(195,204,216,.10),transparent);animation:ggscan 7s ease-in-out infinite}
  @keyframes ggscan{from{top:-140px}to{top:100%}}
  .gg-eyebrow{font-size:10.5px;letter-spacing:.5em;margin-right:-.5em;color:#C3CCD8;opacity:.75;text-transform:uppercase;margin-bottom:-14px}
  aside .gg-tag{background-image:linear-gradient(170deg,#F4F7FB 0%,#C3CCD8 55%,#8E9BB0 100%);-webkit-background-clip:text;background-clip:text;color:transparent!important}
  @keyframes ggin{from{opacity:0;transform:translateX(-8px)}to{opacity:.9;transform:none}}
  main > div.flex.flex-1{position:relative;background:radial-gradient(ellipse 70% 55% at 50% 42%,rgba(44,76,121,.38) 0%,rgba(30,53,87,.22) 40%,transparent 75%),linear-gradient(180deg,#0a1324 0%,#070d1a 60%,#05080f 100%)!important;overflow:hidden}
  .gg-rbeam{position:absolute;left:50%;top:-10%;width:2px;height:120%;pointer-events:none;background:linear-gradient(180deg,transparent,rgba(111,166,242,.35),transparent);transform:translateX(-50%);filter:blur(1px);opacity:.5}
  .gg-rfloor{position:absolute;left:10%;right:10%;bottom:0;height:2px;pointer-events:none;background:linear-gradient(90deg,transparent,rgba(224,170,90,.55),transparent);box-shadow:0 0 40px 6px rgba(224,170,90,.18)}
  main .ax-in [class*="rounded-2xl"],main .ax-in [class*="rounded-3xl"]{position:relative;background:linear-gradient(160deg,rgba(24,40,68,.72),rgba(10,18,34,.78))!important;border:1px solid rgba(160,190,235,.22)!important;backdrop-filter:blur(14px);box-shadow:0 0 0 1px rgba(111,166,242,.06),0 30px 80px rgba(0,0,0,.55),0 0 90px rgba(44,76,121,.35)!important}
  .gg-dust{position:absolute;inset:0;pointer-events:none}
  /* idea 2: while signing in a silver line runs along the top edge of the card, then the whole card lights once */
  main .ax-in .gg-verify::before{content:"";position:absolute;left:0;top:-1px;height:2px;width:35%;border-radius:2px;background:linear-gradient(90deg,transparent,#C3CCD8,#6FA6F2,transparent);box-shadow:0 0 14px 2px rgba(111,166,242,.55);animation:ggrun 1.4s ease-in-out infinite}
  @keyframes ggrun{from{left:4%}to{left:61%}}
  /* idea 3: passkey touch: the edge of the card glows blue like a device was touched */
  main .ax-in .gg-passkey{border-color:rgba(111,166,242,.75)!important;box-shadow:0 0 0 1px rgba(111,166,242,.45),0 0 28px 4px rgba(111,166,242,.35),0 30px 80px rgba(0,0,0,.55),0 0 110px rgba(111,166,242,.28)!important;animation:ggpulse 1.6s ease-in-out infinite}
  @keyframes ggpulse{50%{box-shadow:0 0 0 1px rgba(111,166,242,.65),0 0 46px 8px rgba(111,166,242,.5),0 30px 80px rgba(0,0,0,.55),0 0 130px rgba(111,166,242,.4)}}
  @media (prefers-reduced-motion:reduce){.gg-grid,.gg-rgrid,.gg-scan,.gg-verify::before,.gg-passkey{animation:none!important}}`;
  document.head.appendChild(css);
  const aside = document.querySelector("aside");
  if (aside) {
    const g = document.createElement("div"); g.className = "gg-grid"; const s = document.createElement("div"); s.className = "gg-scan";
    aside.insertBefore(g, aside.children[2]); aside.insertBefore(s, aside.children[3]);
    const stack = aside.querySelector(".relative.z-10"); const eb = document.createElement("div"); eb.className = "gg-eyebrow"; eb.textContent = "Inside the Global Grid"; stack.insertBefore(eb, stack.children[1]);
    const trust = stack.querySelector(".flex.flex-col.gap-4");
    if (trust) { trust.innerHTML = ""; trust.style.gap = "11px";
      ["Rust WASM kernel verifies every answer", "Signed answers: Ed25519, replay refused (Rule 52)", "Rust + Tokio + Axum engine", "WebTransport · HTTP/3 · QUIC", "TLS 1.3 · AES-256-GCM · X25519MLKEM768", "Argon2id · passkeys · device-bound sessions", "PostgreSQL 16 RLS · hash-chained ledger"].forEach((t, i) => {
        const d = document.createElement("div"); d.style.cssText = "display:flex;align-items:center;gap:10px;text-align:left;color:#C3CCD8;font-size:12.5px;opacity:0;animation:ggin .6s ease forwards;animation-delay:" + (0.2 + i * 0.12) + "s";
        d.innerHTML = '<span style="width:5px;height:5px;border-radius:50%;background:#6FA6F2;box-shadow:0 0 8px #6FA6F2;flex:none"></span><span>' + t + "</span>"; trust.appendChild(d); }); }
    setInterval(() => { const p = stack.querySelector("p"); if (p) p.classList.add("gg-tag"); }, 200);
  }
  const rp = document.querySelector("main > div.flex.flex-1");
  if (rp) {
    for (const c of ["gg-rgrid", "gg-rbeam", "gg-rfloor"]) { const d = document.createElement("div"); d.className = c; rp.insertBefore(d, rp.firstChild); }
    const cv = document.createElement("canvas"); cv.className = "gg-dust"; rp.insertBefore(cv, rp.firstChild); cv.width = rp.clientWidth; cv.height = rp.clientHeight; const x = cv.getContext("2d");
    const P = Array.from({ length: 46 }, () => ({ x: Math.random(), y: Math.random(), v: .0004 + Math.random() * .0012, s: .5 + Math.random() * 1.3, p: Math.random() * 6 }));
    const f = () => { x.clearRect(0, 0, cv.width, cv.height); for (const p of P) { p.y -= p.v; p.p += .03; if (p.y < 0) { p.y = 1; p.x = Math.random(); } x.globalAlpha = .2 + .45 * Math.abs(Math.sin(p.p)); x.fillStyle = "#bfd6ff"; x.beginPath(); x.arc(p.x * cv.width, p.y * cv.height, p.s, 0, 6.3); x.fill(); } requestAnimationFrame(f); };
    if (!matchMedia("(prefers-reduced-motion:reduce)").matches) f();
  }
  const card = document.querySelector('main .ax-in [class*="rounded-2xl"],main .ax-in [class*="rounded-3xl"]');
  if (card && GG.state === "verify") card.classList.add("gg-verify");
  if (card && GG.state === "passkey") card.classList.add("gg-passkey");
})();
