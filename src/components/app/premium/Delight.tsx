import { useEffect, useState } from "react";
import { PartyPopper } from "lucide-react";

import { ACHIEVEMENTS, type Achievement } from "@/lib/experience";

/**
 * Phase 29 — Earned Delight.
 * Fires only for a proven finish (see celebrate()). No random confetti, no
 * fake milestones, and never when Calm Mode or the OS asks for stillness.
 * Mounted once inside the workspace shell.
 */
export function EarnedDelight() {
  const [current, setCurrent] = useState<Achievement | null>(null);

  useEffect(() => {
    const onCelebrate = (event: Event) => {
      const detail = (event as CustomEvent<Achievement>).detail;
      if (!detail || !(detail in ACHIEVEMENTS)) return;
      setCurrent(detail);
      const timer = window.setTimeout(() => setCurrent(null), 4200);
      return () => window.clearTimeout(timer);
    };
    window.addEventListener("ax:celebrate", onCelebrate);
    return () => window.removeEventListener("ax:celebrate", onCelebrate);
  }, []);

  if (!current) return null;
  const copy = ACHIEVEMENTS[current];

  return (
    <div
      role="status"
      aria-live="polite"
      className="pointer-events-none fixed inset-x-0 top-6 z-[60] flex justify-center px-4"
    >
      <div className="ax-celebrate ax-plane flex max-w-md items-start gap-3 rounded-2xl border border-success/40 bg-card/95 px-4 py-3 shadow-elev-2 backdrop-blur">
        <span
          aria-hidden="true"
          className="ax-confirm mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-xl border border-success/40 bg-success/10 text-success"
        >
          <PartyPopper className="size-4" />
        </span>
        <span className="min-w-0">
          <span className="block text-sm font-semibold text-foreground">{copy.title}</span>
          <span className="mt-0.5 block text-[12px] leading-relaxed text-muted-foreground">{copy.body}</span>
        </span>
      </div>
    </div>
  );
}
