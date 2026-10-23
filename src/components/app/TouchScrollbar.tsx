import { useRouterState } from "@tanstack/react-router";
import { useEffect, useRef, useState } from "react";

import { pickScroller, scrollFromThumb, thumbMetrics, type Thumb } from "@/lib/touch-scroll";

const HIDE_MS = 1600;

/**
 * Phone/tablet: a scroll handle you can grab and drag (Android's own bar cannot be dragged).
 * Shows while scrolling and stays grabbable at the right edge; drag it to jump anywhere.
 * Touch screens only; swipes elsewhere on the page still scroll normally.
 */
export function TouchScrollbar() {
  const pathname = useRouterState({ select: (s) => s.location.pathname });
  const target = useRef<HTMLElement | null>(null);
  const [thumb, setThumb] = useState<Thumb>({ visible: false, height: 0, top: 0 });
  const [box, setBox] = useState({ top: 0, height: 0 });
  const [awake, setAwake] = useState(false);
  const [dragging, setDragging] = useState(false);
  const hide = useRef<ReturnType<typeof setTimeout> | null>(null);
  const grab = useRef<{ y: number; top: number } | null>(null);

  const sync = () => {
    const el = target.current;
    if (!el || !el.isConnected) {
      setThumb((t) => (t.visible ? { visible: false, height: 0, top: 0 } : t));
      return;
    }
    const r = el.getBoundingClientRect();
    setBox({ top: r.top, height: r.height });
    setThumb(thumbMetrics(el.scrollTop, el.scrollHeight, el.clientHeight));
  };
  const wake = () => {
    setAwake(true);
    if (hide.current) clearTimeout(hide.current);
    hide.current = setTimeout(() => setAwake(false), HIDE_MS);
  };
  const find = () => {
    const nodes = Array.from(document.querySelectorAll<HTMLElement>("main, main .overflow-y-auto"));
    target.current = pickScroller(
      nodes
        .filter((el) => {
          const oy = getComputedStyle(el).overflowY;
          return oy === "auto" || oy === "scroll";
        })
        .map((el) => {
          let depth = 0;
          for (let p: HTMLElement | null = el; p; p = p.parentElement) depth++;
          return {
            el,
            overflow: el.scrollHeight - el.clientHeight,
            depth,
            height: el.clientHeight,
          };
        }),
      window.innerHeight,
    );
    sync();
  };

  useEffect(() => {
    if (typeof window === "undefined" || !window.matchMedia("(pointer: coarse)").matches) return;
    const settle = setTimeout(() => {
      find();
      wake();
    }, 350); // let the new page lay out first
    const onScroll = (e: Event) => {
      const el = e.target;
      if (!(el instanceof HTMLElement)) return;
      if (el !== target.current) {
        const prev = target.current;
        target.current = el;
        find();
        if (target.current !== el && prev) target.current = prev;
      }
      sync();
      wake();
    };
    const onResize = () => find();
    document.addEventListener("scroll", onScroll, { capture: true, passive: true });
    window.addEventListener("resize", onResize);
    return () => {
      clearTimeout(settle);
      if (hide.current) clearTimeout(hide.current);
      document.removeEventListener("scroll", onScroll, { capture: true });
      window.removeEventListener("resize", onResize);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [pathname]);

  if (!thumb.visible) return null;
  const on = awake || dragging;
  return (
    <div
      className="pointer-events-none fixed right-0 z-[55]"
      style={{ top: box.top, height: box.height }}
      aria-hidden="true"
    >
      <div
        className="pointer-events-auto absolute right-0 w-8 touch-none select-none"
        style={{ top: thumb.top, height: thumb.height }}
        onPointerDown={(e) => {
          e.currentTarget.setPointerCapture(e.pointerId);
          grab.current = { y: e.clientY, top: thumb.top };
          setDragging(true);
          wake();
        }}
        onPointerMove={(e) => {
          const g = grab.current;
          const el = target.current;
          if (!g || !el) return;
          el.scrollTop = scrollFromThumb(
            g.top + (e.clientY - g.y),
            el.scrollHeight,
            el.clientHeight,
          );
        }}
        onPointerUp={() => {
          grab.current = null;
          setDragging(false);
          wake();
        }}
        onPointerCancel={() => {
          grab.current = null;
          setDragging(false);
        }}
      >
        <div
          className="absolute inset-y-0 right-1 rounded-full bg-muted-foreground transition-[width,opacity] duration-150 motion-reduce:transition-none"
          style={{ width: dragging ? 8 : 5, opacity: dragging ? 0.9 : on ? 0.6 : 0.28 }}
        />
      </div>
    </div>
  );
}
