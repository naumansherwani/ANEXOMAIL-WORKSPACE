/**
 * BootSplash — the ANEXOMAIL "A" shows the instant the page opens (B6 batch, 21 Oct 2026).
 *
 * WHY: /app is client-rendered (`ssr: false`), so the server HTML body is EMPTY — on a phone with a slow network the
 * user stared at a blank dark screen until the JS bundle arrived. This overlay lives in the HTML shell itself
 * (plain markup + inline CSS, zero JS needed to paint), uses the REAL BrandMark (no second copy of the logo), and fades
 * out the moment React mounts (RootComponent sets `data-ax-ready`) so WorkspaceLoader takes over seamlessly.
 *
 * Only on /app* (client-rendered area). Public pages are server-rendered with real content — an overlay there would
 * HIDE content and slow what people see, so an inline script marks them ready before first paint (landing untouched).
 * Failsafe: 15 s after load the overlay lets go no matter what, so it can never trap a user. Reduced motion respected.
 */
import { useEffect } from "react";

import { BrandMark } from "@/components/site/BrandMark";

export const BOOT_CSS = `
#ax-boot{position:fixed;inset:0;z-index:2147483000;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:20px;
background:radial-gradient(60% 45% at 50% 42%,#14203a 0%,#0b0b0c 70%);
padding:env(safe-area-inset-top) env(safe-area-inset-right) env(safe-area-inset-bottom) env(safe-area-inset-left);opacity:1;visibility:visible}
#ax-boot svg{width:88px;height:88px;filter:drop-shadow(0 0 30px rgba(86,120,210,.38));animation:axBootIn .75s cubic-bezier(.2,.7,.2,1) both,axBootFloat 3.4s ease-in-out .75s infinite}
#ax-boot .w{font:800 14px/1 Inter,system-ui,-apple-system,sans-serif;letter-spacing:.34em;text-indent:.34em;color:#c9ced8;animation:axBootFade .7s .3s both}
#ax-boot .b{width:104px;height:2px;border-radius:2px;background:rgba(255,255,255,.08);overflow:hidden;animation:axBootFade .7s .45s both}
#ax-boot .b i{display:block;height:100%;width:42%;border-radius:2px;background:linear-gradient(90deg,transparent,#8fa6e6,transparent);animation:axBootSweep 1.15s ease-in-out infinite}
html[data-ax-ready] #ax-boot{opacity:0;visibility:hidden;pointer-events:none;transition:opacity .45s ease,visibility 0s .45s}
@keyframes axBootIn{from{opacity:0;transform:scale(.82) translateY(8px)}to{opacity:1;transform:none}}
@keyframes axBootFloat{0%,100%{transform:translateY(0)}50%{transform:translateY(-5px)}}
@keyframes axBootFade{from{opacity:0}to{opacity:1}}
@keyframes axBootSweep{from{transform:translateX(-120%)}to{transform:translateX(260%)}}
@media (prefers-reduced-motion:reduce){#ax-boot svg,#ax-boot .w,#ax-boot .b,#ax-boot .b i{animation:none!important}}
`;

/** Runs in <head> before first paint. Non-/app paths: overlay off at once. /app: off after 15 s at the latest. */
export const BOOT_SCRIPT = `(function(){var d=document.documentElement;if(!/^\\/app(\\/|$)/.test(location.pathname)){d.setAttribute("data-ax-ready","");return}setTimeout(function(){d.setAttribute("data-ax-ready","")},15000)})();`;

export function BootSplash() {
  return (
    <div id="ax-boot" aria-hidden="true">
      <BrandMark compact home={false} />
      <div className="w">ANEXOMAIL</div>
      <div className="b">
        <i />
      </div>
    </div>
  );
}

/**
 * Let go of the boot "A" only once something real is on screen (a page, WorkspaceLoader, an error…): React mounting is NOT
 * enough — /app routes are lazy chunks, and on a slow phone the gap between "React is alive" and "page is painted" would be
 * a blank screen again. Watches the DOM until a visible element other than the overlay appears (then fades the A out).
 * Worst case the inline 15 s failsafe in BOOT_SCRIPT releases it.
 */
export function useBootRelease() {
  useEffect(() => {
    const root = document.documentElement;
    if (root.hasAttribute("data-ax-ready")) return;
    const contentVisible = () =>
      Array.from(document.body.children).some((el) => {
        if (el.id === "ax-boot" || el.tagName === "SCRIPT" || el.tagName === "SECTION") return false;
        const r = (el as HTMLElement).getBoundingClientRect();
        return r.width > 0 && r.height > 0;
      });
    const release = () => {
      requestAnimationFrame(() => root.setAttribute("data-ax-ready", ""));
    };
    if (contentVisible()) {
      release();
      return;
    }
    const mo = new MutationObserver(() => {
      if (contentVisible()) {
        mo.disconnect();
        release();
      }
    });
    mo.observe(document.body, { childList: true, subtree: true });
    return () => mo.disconnect();
  }, []);
}
