import { useQueryClient } from "@tanstack/react-query";
import { useRouter } from "@tanstack/react-router";
import { RefreshCw } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import { canStartPull, damped, isPullGesture, PULL_THRESHOLD, pullReady } from "@/lib/pull-refresh";

/**
 * Phone: upar se neeche kheencho -> data taza (page reload NAHI, draft salamat). Browser ka apna pull-to-refresh shell mein band hai.
 * Sirf touch screen par; text likhte waqt / dialog ke andar / jab koi dabba neeche scrolled ho to kuch nahi.
 */
export function PullRefresh() {
  const qc = useQueryClient();
  const router = useRouter();
  const [shown, setShown] = useState(0);
  const [busy, setBusy] = useState(false);
  const shownRef = useRef(0);
  const busyRef = useRef(false);

  useEffect(() => {
    if (typeof window === "undefined" || !window.matchMedia("(pointer: coarse)").matches) return;
    let s: { x: number; y: number; on: boolean } | null = null;
    const set = (v: number) => {
      shownRef.current = v;
      setShown(v);
    };
    const onStart = (e: TouchEvent) => {
      if (busyRef.current || e.touches.length !== 1) {
        s = null;
        return;
      }
      const t = e.touches[0]!;
      s = {
        x: t.clientX,
        y: t.clientY,
        on: canStartPull(
          e.target as never,
          (el) => getComputedStyle(el as unknown as Element).overflowY,
        ),
      };
    };
    const onMove = (e: TouchEvent) => {
      if (!s?.on) return;
      const t = e.touches[0]!;
      const dx = t.clientX - s.x;
      const dy = t.clientY - s.y;
      if (shownRef.current === 0 && !isPullGesture(dx, dy)) {
        if (dy < -8 || Math.abs(dx) > 12) s.on = false; // upar ya side ko gaya: yeh pull nahi
        return;
      }
      set(damped(dy));
    };
    const onEnd = async () => {
      const was = s;
      s = null;
      if (!was?.on || shownRef.current === 0) {
        set(0);
        return;
      }
      if (pullReady(shownRef.current)) {
        busyRef.current = true;
        setBusy(true);
        set(PULL_THRESHOLD);
        await Promise.allSettled([qc.invalidateQueries(), router.invalidate()]);
        await new Promise((r) => setTimeout(r, 450));
        busyRef.current = false;
        setBusy(false);
      }
      set(0);
    };
    document.addEventListener("touchstart", onStart, { passive: true });
    document.addEventListener("touchmove", onMove, { passive: true });
    document.addEventListener("touchend", onEnd, { passive: true });
    document.addEventListener("touchcancel", onEnd, { passive: true });
    return () => {
      document.removeEventListener("touchstart", onStart);
      document.removeEventListener("touchmove", onMove);
      document.removeEventListener("touchend", onEnd);
      document.removeEventListener("touchcancel", onEnd);
    };
  }, [qc, router]);

  const ready = pullReady(shown);
  return (
    <div
      className="pointer-events-none fixed inset-x-0 z-[60] flex justify-center"
      style={{ top: "calc(env(safe-area-inset-top, 0px) + 3.25rem)" }}
      role="status"
      aria-live="polite"
    >
      <span className="sr-only">{busy ? "Refreshing" : ""}</span>
      <div
        aria-hidden="true"
        className="grid size-10 place-items-center rounded-full border border-border bg-card text-foreground shadow-lg motion-reduce:transition-none"
        style={{
          opacity: busy ? 1 : Math.min(1, shown / PULL_THRESHOLD),
          transform: `translateY(${shown - 44}px) scale(${busy || ready ? 1 : 0.8 + (shown / PULL_THRESHOLD) * 0.2})`,
          transition: shown === 0 ? "transform 180ms ease, opacity 180ms ease" : "none",
        }}
      >
        <RefreshCw
          className={busy ? "size-5 animate-spin" : "size-5"}
          style={busy ? undefined : { transform: `rotate(${shown * 3}deg)` }}
        />
      </div>
    </div>
  );
}
