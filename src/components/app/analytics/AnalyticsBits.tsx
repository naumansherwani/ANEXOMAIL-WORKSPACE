import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

/** Phase 24 — no vanity charts. Bars sirf tab jab woh faisla badle. */
export function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-1 text-[19px] font-bold text-foreground">{value}</p>
      {hint && <p className="ax-caption mt-0.5 text-steel">{hint}</p>}
    </div>
  );
}

export function Section({ title, eyebrow, blurb, children }: { title: string; eyebrow: ReactNode; blurb?: string; children: ReactNode }) {
  return (
    <section>
      <p className="ax-eyebrow flex items-center gap-2">{eyebrow}</p>
      <h2 className="ax-h2 mt-1 text-foreground">{title}</h2>
      {blurb && <p className="ax-caption mt-1 text-muted-foreground">{blurb}</p>}
      <div className="mt-ax-4">{children}</div>
    </section>
  );
}

/** Ek honest stacked bar — CSS only, koi chart library nahi (speed as feature). */
export function StackBar({
  rows,
  keys,
}: {
  rows: { label: string; values: number[] }[];
  keys: { label: string; className: string }[];
}) {
  const max = Math.max(1, ...rows.map((r) => r.values.reduce((a, b) => a + b, 0)));
  return (
    <div>
      <div className="flex flex-wrap gap-ax-3">
        {keys.map((k) => (
          <span key={k.label} className="ax-caption flex items-center gap-1.5 text-muted-foreground">
            <span className={cn("size-2.5 rounded-sm", k.className)} aria-hidden="true" /> {k.label}
          </span>
        ))}
      </div>
      <ul className="mt-ax-3 space-y-1.5">
        {rows.map((r) => (
          <li key={r.label} className="flex items-center gap-ax-3">
            <span className="ax-caption w-12 shrink-0 text-muted-foreground">{r.label}</span>
            <span className="flex h-3 flex-1 overflow-hidden rounded-full bg-secondary">
              {r.values.map((v, i) => (
                <span
                  key={i}
                  className={keys[i]?.className}
                  style={{ width: `${(v / max) * 100}%` }}
                  aria-hidden="true"
                />
              ))}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}

export function Row({ children }: { children: ReactNode }) {
  return (
    <li className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]">{children}</li>
  );
}
