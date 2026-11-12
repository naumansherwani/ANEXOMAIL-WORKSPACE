import { useEffect, useId, useRef, useState } from "react";
import { Popover, PopoverContent, PopoverTrigger } from "@/components/ui/popover";
import { orbWhy, type OrbTone, type WhyItem } from "./orbwhy_pure";
import "./orbwhy.css";

/** LA-1 + LA-5 (Look, additive). A transparent hit area laid OVER the orb (the orb's own pixels and code are untouched): mouse hover, tap, or keyboard focus opens a small card that
 *  names why the orb has its colour; a visually hidden sentence says the same to screen readers; forced-colors gets system colours (orbwhy.css). GSAP loads lazily for the entrance only. */
export function OrbWhy({ tone, ks, items, endpointsOk, endpointsAll }: { tone: OrbTone; ks: string; items: WhyItem[] | null; endpointsOk: number | null; endpointsAll: number | null }) {
  const [open, setOpen] = useState(false), id = useId(), card = useRef<HTMLDivElement>(null), timer = useRef(0), btn = useRef<HTMLButtonElement>(null);
  const why = orbWhy({ tone, ks, items, endpointsOk, endpointsAll });
  const hover = (on: boolean) => (e: React.PointerEvent) => { if (e.pointerType !== "mouse") return; window.clearTimeout(timer.current); timer.current = window.setTimeout(() => setOpen(on), on ? 60 : 160); };
  useEffect(() => () => window.clearTimeout(timer.current), []);
  useEffect(() => {   // GSAP (lazy chunk, never first paint): a short rise-and-fade; reduced motion = none
    if (!open || window.matchMedia("(prefers-reduced-motion: reduce)").matches) return; let dead = false;
    void import("gsap").then(({ gsap }) => { const el = card.current; if (!dead && el) gsap.fromTo(el, { y: 6, opacity: 0 }, { y: 0, opacity: 1, duration: 0.18, ease: "power2.out", clearProps: "transform,opacity" }); }).catch(() => {});
    return () => { dead = true; };
  }, [open]);
  return (
    <Popover open={open} onOpenChange={setOpen}>
      <PopoverTrigger asChild>
        <button ref={btn} type="button" className="owhy-hit" onKeyDown={(e) => { if (e.key === "Tab" || e.key === "Enter" || e.key === " ") e.currentTarget.dataset.kb = "1"; }} onFocus={(e) => { if (e.currentTarget.matches(":focus-visible")) e.currentTarget.dataset.kb = "1"; }} onPointerDown={(e) => { delete e.currentTarget.dataset.kb; }} onBlur={(e) => { delete e.currentTarget.dataset.kb; }} aria-label="Why is the orb this colour?" aria-describedby={`${id}-sr`} onPointerEnter={hover(true)} onPointerLeave={hover(false)} />
      </PopoverTrigger>
      <span id={`${id}-sr`} className="owhy-sr" role="status">{why.sr}</span>
      <PopoverContent ref={card} onPointerEnter={hover(true)} onPointerLeave={hover(false)} onOpenAutoFocus={(e) => e.preventDefault()} onCloseAutoFocus={(e) => { if (btn.current?.dataset.kb !== "1") e.preventDefault(); }}>
        <p className="owhy-h">{why.headline}</p>
        {why.lines.length > 0 && <ul className="owhy-ul">{why.lines.map((l) => <li key={l.name} className={`owhy-li ${l.state}`}><i className="owhy-dot" /><span className="owhy-n">{l.name}</span>{l.detail && <span className="owhy-d">{l.detail}</span>}</li>)}</ul>}
        <p className="owhy-p">{why.summary}</p>
      </PopoverContent>
    </Popover>
  );
}
