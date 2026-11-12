import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";
import { Popover, PopoverAnchor, PopoverContent } from "@/components/ui/popover";
import { laneIdle, laneKey, laneTip, type LaneKey, type LaneTimes, type Tip } from "./bridgelane_pure";
import "./orbwhy.css";
import "./bridgelanes.css";

type L = { label: string; n: number | null };

/** LA-2 + LA-6 + LA-7 (Bridge, additive). Wraps the existing <BridgeMap> from OUTSIDE (Scene3D.tsx is not edited; the wrapper is `display: contents`, so layout is unchanged).
 *  It finds the six lane rows by their text, and: (LA-2) hover / tap / keyboard focus opens a small card (count, newest, oldest waiting; times only when the server sent them),
 *  (LA-6) click or Enter/Space picks the lane and the ledger below filters to it, (LA-7) a quiet lane's row is dimmed (data-idle, CSS only; the map drawing is not touched). */
export function BridgeLanes({ inbound, outbound, times, active, onPick, children }: { inbound: L[]; outbound: L[]; times: LaneTimes; active: LaneKey | null; onPick: (k: LaneKey | null) => void; children: ReactNode }) {
  const root = useRef<HTMLDivElement>(null), anchor = useRef<HTMLElement | null>(null), timer = useRef(0), card = useRef<HTMLDivElement>(null);
  const [open, setOpen] = useState(false), [tip, setTip] = useState<Tip | null>(null);
  const all = [...inbound, ...outbound];
  const byLabel = useCallback((label: string) => all.find((l) => l.label === label), [all]);

  // mark rows: keyboard reachable, pressed state, idle dim. Attributes only (the rows belong to BridgeMap; React never removes attributes it did not set).
  useEffect(() => {
    root.current?.querySelectorAll<HTMLElement>(".bmap li").forEach((li) => {
      const label = li.querySelector("span")?.textContent ?? "", k = laneKey(label), l = byLabel(label);
      if (!k || !l) return;
      li.tabIndex = 0; li.setAttribute("role", "button"); li.dataset.lane = k;
      li.setAttribute("aria-pressed", String(active === k));
      li.setAttribute("aria-label", laneTip(label, l.n, times).sr + (active === k ? " Showing its rows below. Press to show everything." : " Press to show its rows below."));
      if (laneIdle(label, l.n, times)) li.dataset.idle = "1"; else delete li.dataset.idle;
    });
  });

  const show = (li: HTMLElement | null, on: boolean) => {
    window.clearTimeout(timer.current);
    timer.current = window.setTimeout(() => {
      if (!on || !li) { setOpen(false); return; }
      const label = li.querySelector("span")?.textContent ?? "", l = byLabel(label); if (!laneKey(label) || !l) return;
      anchor.current = li; setTip(laneTip(label, l.n, times)); setOpen(true);
    }, on ? 60 : 160);
  };
  const rowOf = (t: EventTarget | null) => (t as HTMLElement | null)?.closest?.<HTMLElement>(".bmap li") ?? null;
  const pick = (li: HTMLElement | null) => { const k = li?.dataset.lane as LaneKey | undefined; if (k) onPick(active === k ? null : k); };
  useEffect(() => () => window.clearTimeout(timer.current), []);
  useEffect(() => {   // GSAP (lazy, shared chunk): short rise-and-fade; reduced motion = none
    if (!open || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return; let dead = false;
    void import("gsap").then(({ gsap }) => { const el = card.current; if (!dead && el) gsap.fromTo(el, { y: 6, opacity: 0 }, { y: 0, opacity: 1, duration: 0.18, ease: "power2.out", clearProps: "transform,opacity" }); });
    return () => { dead = true; };
  }, [open, tip]);

  return (
    <div ref={root} className="blanes"
      onPointerOver={(e) => { if (e.pointerType === "mouse") { const li = rowOf(e.target); if (li) show(li, true); } }}
      onPointerOut={(e) => { if (e.pointerType === "mouse" && rowOf(e.target)) show(null, false); }}
      onClick={(e) => { const li = rowOf(e.target); if (li) { pick(li); if (e.nativeEvent instanceof PointerEvent && e.nativeEvent.pointerType !== "mouse") show(li, true); } }}
      onFocus={(e) => { const li = rowOf(e.target); if (li && li.matches(":focus-visible")) show(li, true); }}
      onBlur={(e) => { if (rowOf(e.target)) show(null, false); }}
      onKeyDown={(e) => { const li = rowOf(e.target); if (!li) return; if (e.key === "Enter" || e.key === " ") { e.preventDefault(); pick(li); } else if (e.key === "Escape") setOpen(false); }}>
      <Popover open={open} onOpenChange={setOpen}>
        <PopoverAnchor virtualRef={anchor as React.RefObject<HTMLElement>} />
        <PopoverContent ref={card} side="top" onOpenAutoFocus={(e) => e.preventDefault()} onCloseAutoFocus={(e) => e.preventDefault()} onPointerEnter={() => { window.clearTimeout(timer.current); }} onPointerLeave={() => show(null, false)}>
          {tip && <><p className="owhy-h">{tip.headline}</p><ul className="owhy-ul">{tip.lines.map((x) => <li key={x} className="owhy-li ok"><span className="owhy-n">{x}</span></li>)}</ul></>}
        </PopoverContent>
      </Popover>
      {children}
    </div>
  );
}
