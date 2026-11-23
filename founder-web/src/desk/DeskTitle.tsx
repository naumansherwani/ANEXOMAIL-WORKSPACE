import { useEffect, useRef } from "react";

/** Anexomail Command Center title (his 23 Nov 2026 11:48 "perfect hain", demo V24 = docs/claude/admin-desk/demo/COMMAND-CENTER-DEMO-23NOV-V24-LIGHT-SOFT-CENTRE.html).
 *  Replaces ONLY the big page title: ANEXOMAIL / COMMAND CENTER OS / Senior Executive. Every Desk colour, card, rail and clock stays as it was.
 *  Colours = the original Anexomail logo A (steel #2C4C79, navy #1E3557, silver #E6EBF1 / #C3CCD8). Own file, own CSS; pure CSS + one canvas, no network, no third party.
 *  Back to the old title: restore backups/desk/20261123-1150-before-command-center-title/DeskShell.tsx. Reduced motion = still picture. */
export const TITLE_CSS = `
.dsk-ttl{margin:4px 0 0;font-family:inherit;font-weight:600;line-height:1.05}
.dsk-hero{position:relative;padding:6px 0 4px;isolation:isolate}
.dsk-ttl .l1{display:block;position:relative;width:fit-content;font-size:clamp(28px,4.6vw,46px);font-weight:300;letter-spacing:.16em;margin-right:-.16em;color:#2C4C79;-webkit-text-stroke:.6px #E6EBF1;paint-order:stroke fill;text-shadow:0 0 26px rgba(44,76,121,.95),0 0 2px rgba(230,235,241,.5)}
.dsk-ttl .l2{display:block;width:fit-content;font-size:clamp(10px,1.3vw,13px);letter-spacing:.5em;font-weight:500;margin-top:10px;line-height:1.2;color:#DCE3EC}
.dsk-ttl .w{display:inline-block;white-space:nowrap}
.dsk-ttl .c{display:inline-block;opacity:0;filter:blur(10px);transform:translateY(.35em) scale(1.08);animation:dsk-inr .9s cubic-bezier(.2,.8,.2,1) forwards;animation-delay:calc(var(--i)*70ms)}
@keyframes dsk-inr{to{opacity:1;filter:blur(0);transform:none}}
.dsk-ttl .l1::after{content:"";display:block;height:1px;width:calc(100% - .16em);margin-top:10px;background:linear-gradient(90deg,transparent 0%,rgba(230,235,241,.2) 50%,transparent 100%) -50% 0/26% 100% no-repeat,linear-gradient(90deg,#1E3557 0%,#2C4C79 22%,#C3CCD8 50%,#E6EBF1 58%,#2C4C79 82%,#1E3557 100%);box-shadow:0 0 8px rgba(44,76,121,.45);transform:scaleX(0);transform-origin:left;animation:dsk-ul 1.1s cubic-bezier(.3,.7,.2,1) 1.2s forwards,dsk-linerun 4.2s linear 2.4s infinite}
@keyframes dsk-linerun{from{background-position:-50% 0,0 0}to{background-position:150% 0,0 0}}
@keyframes dsk-ul{to{transform:scaleX(1)}}
.dsk-ttl .l1::before{content:"";position:absolute;left:12%;right:calc(12% + .16em);bottom:-22px;height:26px;pointer-events:none;border-radius:50%;filter:blur(15px);opacity:0;background:radial-gradient(closest-side,#C3CCD8 0%,#2C4C79 55%,transparent 100%);animation:dsk-lightsin 1.2s ease 1.6s forwards,dsk-lightbreath 5s ease-in-out 2.8s infinite alternate}
@keyframes dsk-lightsin{to{opacity:.2}}
@keyframes dsk-lightbreath{from{opacity:.2}to{opacity:.3}}
.dsk-halo{position:absolute;left:-6%;top:-40%;width:70%;height:220%;z-index:-1;background:radial-gradient(closest-side,rgba(111,166,242,.22),transparent 70%);animation:dsk-halo 7s ease-in-out infinite alternate;pointer-events:none}
@keyframes dsk-halo{from{opacity:.55;transform:translateX(-3%)}to{opacity:1;transform:translateX(6%)}}
.dsk-sp{position:absolute;inset:-20px -10px;width:calc(100% + 20px);height:calc(100% + 40px);z-index:-1;pointer-events:none}
.dsk-sub{display:flex;align-items:center;gap:12px;margin-top:10px;font-size:clamp(16px,2vw,20px);font-weight:500;color:#C3CCD8;opacity:0;animation:dsk-up .8s ease 1.4s forwards}
.dsk-sub .rule{display:inline-block;height:1px;width:clamp(36px,8vw,90px);background:linear-gradient(90deg,transparent,#6FA6F2)}
.dsk-sub::after{content:"";display:inline-block;height:1px;width:clamp(36px,8vw,90px);background:linear-gradient(270deg,transparent,#6FA6F2)}
@keyframes dsk-up{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
@media(prefers-reduced-motion:reduce){.dsk-ttl .c{animation:none;opacity:1;filter:none;transform:none}.dsk-ttl .l1::after{animation:none;transform:none}.dsk-ttl .l1::before{animation:none;opacity:.2}.dsk-halo{animation:none}.dsk-sub{animation:none;opacity:1}}
`;

/** Words of a title line as {word, first letter index}, so each letter gets its own reveal delay (pure, tested). */
export function titleLetters(lines: string[]): { word: string; i: number }[][] {
  let i = 0;
  return lines.map((ln) => ln.split(" ").map((word) => { const o = { word, i }; i += word.length; return o; }));
}

/** Letter-spacing (px) that makes the small line span exactly the width of the big line (pure, tested). */
export function fitSpacing(bigWidth: number, bigSpacing: number, smallWidthAtZero: number, smallChars: number): number {
  if (smallChars < 2) return 2;
  return Math.max(2, (bigWidth - bigSpacing - smallWidthAtZero) / (smallChars - 1));
}

export function DeskTitle() {
  const h = useRef<HTMLHeadingElement>(null);
  const cv = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    const fit = () => {
      const a = h.current?.querySelector<HTMLElement>(".l1"), b = h.current?.querySelector<HTMLElement>(".l2");
      if (!a || !b) return;
      b.style.letterSpacing = "0px";
      const ls = parseFloat(getComputedStyle(a).letterSpacing) || 0;
      const sp = fitSpacing(a.getBoundingClientRect().width, ls, b.getBoundingClientRect().width, (b.textContent ?? "").length);
      b.style.letterSpacing = `${sp}px`; b.style.marginRight = `${-sp}px`;
    };
    fit(); addEventListener("resize", fit);
    void document.fonts?.ready.then(fit);
    return () => removeEventListener("resize", fit);
  }, []);
  useEffect(() => {
    const c = cv.current; const x = c?.getContext("2d");
    if (!c || !x || matchMedia("(prefers-reduced-motion:reduce)").matches) return;
    let W = 0, H = 0, raf = 0;
    const size = () => { const r = c.getBoundingClientRect(); W = c.width = r.width; H = c.height = r.height; };
    size(); addEventListener("resize", size);
    const P = Array.from({ length: 34 }, () => ({ x: Math.random(), y: Math.random(), v: 0.0004 + Math.random() * 0.0012, s: 0.5 + Math.random() * 1.4, p: Math.random() * 6 }));
    const f = () => {
      x.clearRect(0, 0, W, H);
      for (const p of P) { p.y -= p.v; p.p += 0.03; if (p.y < 0) { p.y = 1; p.x = Math.random(); } x.globalAlpha = 0.25 + 0.45 * Math.abs(Math.sin(p.p)); x.fillStyle = "#bfd6ff"; x.beginPath(); x.arc(p.x * W, p.y * H, p.s, 0, 6.3); x.fill(); }
      raf = requestAnimationFrame(f);
    };
    f();
    return () => { cancelAnimationFrame(raf); removeEventListener("resize", size); };
  }, []);
  const L = titleLetters(["ANEXOMAIL", "COMMAND CENTER OS"]);
  const line = (k: string, words: { word: string; i: number }[]) => (
    <span className={k} aria-hidden="true">{words.map((w, q) => <span key={q}><span className="w">{[...w.word].map((ch, j) => <span key={j} className="c" style={{ ["--i" as string]: w.i + j }}>{ch}</span>)}</span>{q < words.length - 1 ? " " : ""}</span>)}</span>
  );
  return (
    <div className="dsk-hero">
      <canvas ref={cv} className="dsk-sp" aria-hidden="true" />
      <div className="dsk-halo" aria-hidden="true" />
      <h1 ref={h} className="dsk-ttl" aria-label="ANEXOMAIL COMMAND CENTER OS">{line("l1", L[0])}{line("l2", L[1])}</h1>
      <div className="dsk-sub"><span className="rule" />Senior Executive</div>
    </div>
  );
}
