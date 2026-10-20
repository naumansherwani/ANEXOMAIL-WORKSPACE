import { useCallback, useRef } from "react";

/**
 * Mouse se pakad kar left/right ghumao (touch par browser khud swipe deta hai).
 * Kyun: mail ke address chips aur category tabs (All / Primary / Updates / People / Promotions ...) ek line mein
 * scroll hote hain; desktop par sirf patli scrollbar thi, baqi icons nazar nahi aate the (20 Oct 2026 founder).
 *
 * - 5px se kam hilna = click (button chalta hai). Us se zyada = drag (click nigal liya jata hai).
 * - Mouse wheel (upar/neeche) bhi us row ko side mein ghumata hai jab wo row overflow ho.
 * - Overflow na ho to kuch nahi badalta.
 */
export function useDragScroll<T extends HTMLElement = HTMLDivElement>() {
  const cleanup = useRef<(() => void) | null>(null);

  // callback ref: row baad mein (jab data aaye) bane tab bhi judta hai, hatne par saaf ho jata hai
  return useCallback((el: T | null) => {
    cleanup.current?.();
    cleanup.current = null;
    if (!el) return;
    let down = false;
    let moved = false;
    let startX = 0;
    let startLeft = 0;
    let pid = -1;

    const onDown = (e: PointerEvent) => {
      if (e.pointerType !== "mouse" || e.button !== 0) return;
      if (el.scrollWidth <= el.clientWidth) return;
      down = true;
      moved = false;
      startX = e.clientX;
      startLeft = el.scrollLeft;
      pid = e.pointerId;
    };
    const onMove = (e: PointerEvent) => {
      if (!down) return;
      const dx = e.clientX - startX;
      if (!moved && Math.abs(dx) < 5) return;
      if (!moved) {
        moved = true;
        try {
          el.setPointerCapture(pid);
        } catch {
          /* koi baat nahi */
        }
        el.style.cursor = "grabbing";
        el.style.userSelect = "none";
      }
      el.scrollLeft = startLeft - dx;
    };
    const end = () => {
      if (!down) return;
      down = false;
      el.style.cursor = "";
      el.style.userSelect = "";
      try {
        el.releasePointerCapture(pid);
      } catch {
        /* koi baat nahi */
      }
    };
    const onClick = (e: MouseEvent) => {
      if (moved) {
        e.preventDefault();
        e.stopPropagation();
        moved = false;
      }
    };
    const onWheel = (e: WheelEvent) => {
      if (el.scrollWidth <= el.clientWidth) return;
      if (Math.abs(e.deltaY) <= Math.abs(e.deltaX)) return;
      const max = el.scrollWidth - el.clientWidth;
      const next = Math.max(0, Math.min(max, el.scrollLeft + e.deltaY));
      if (next === el.scrollLeft) return; // kinare par — page ko apna scroll karne do
      e.preventDefault();
      el.scrollLeft = next;
    };

    el.addEventListener("pointerdown", onDown);
    el.addEventListener("pointermove", onMove);
    el.addEventListener("pointerup", end);
    el.addEventListener("pointercancel", end);
    el.addEventListener("click", onClick, true);
    el.addEventListener("wheel", onWheel, { passive: false });
    cleanup.current = () => {
      el.removeEventListener("pointerdown", onDown);
      el.removeEventListener("pointermove", onMove);
      el.removeEventListener("pointerup", end);
      el.removeEventListener("pointercancel", end);
      el.removeEventListener("click", onClick, true);
      el.removeEventListener("wheel", onWheel);
    };
  }, []);
}
