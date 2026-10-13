import type { ReactNode } from "react";

import { cn } from "@/lib/utils";

/** One rhythm for every CRM number so the surface reads as one product. */
export function CrmStat({
  label,
  value,
  hint,
}: {
  label: string;
  value: string;
  hint?: string | undefined;
}) {
  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-2 text-3xl font-extrabold tracking-tight text-foreground">{value}</p>
      {hint && <p className="ax-caption mt-1 text-muted-foreground">{hint}</p>}
    </div>
  );
}

export function Chip({
  children,
  tone = "quiet",
}: {
  children: ReactNode;
  tone?: "quiet" | "good" | "warn" | "bad";
}) {
  return (
    <span
      className={cn(
        "ax-caption rounded-full border px-2 py-0.5 font-semibold",
        tone === "good" && "border-success/40 bg-success/10 text-success",
        tone === "warn" && "border-warning/40 bg-warning/10 text-warning",
        tone === "bad" && "border-danger/40 bg-danger/10 text-danger",
        tone === "quiet" && "border-border text-muted-foreground",
      )}
    >
      {children}
    </span>
  );
}

/** Score / probability bar — number always shown next to it, colour never alone. */
export function ScoreBar({ value }: { value: number }) {
  const clamped = Math.max(0, Math.min(100, Math.round(value)));
  return (
    <span className="flex items-center gap-2">
      <span className="h-1.5 w-16 overflow-hidden rounded-full bg-secondary">
        <span
          className="block h-full rounded-full bg-foreground/70"
          style={{ width: `${clamped}%` }}
        />
      </span>
      <span className="ax-caption font-semibold text-foreground">{clamped}</span>
    </span>
  );
}

export function HealthRing({ value }: { value: number | null }) {
  if (value == null) return null;
  const clamped = Math.max(0, Math.min(100, Math.round(value)));
  const r = 15;
  const c = 2 * Math.PI * r;
  const offset = c - (clamped / 100) * c;
  return (
    <svg viewBox="0 0 40 40" className="size-10 shrink-0" aria-hidden="true">
      <circle cx="20" cy="20" r={r} fill="none" className="stroke-border" strokeWidth="3" />
      <circle
        cx="20"
        cy="20"
        r={r}
        fill="none"
        className="stroke-foreground"
        strokeWidth="3"
        strokeLinecap="round"
        strokeDasharray={c}
        strokeDashoffset={offset}
        transform="rotate(-90 20 20)"
      />
      <text
        x="20"
        y="24"
        textAnchor="middle"
        className="fill-foreground"
        style={{ fontSize: "9px", fontWeight: 700 }}
      >
        {clamped}
      </text>
    </svg>
  );
}

export function SectionTitle({ title, hint }: { title: string; hint?: string }) {
  return (
    <div className="mb-ax-3">
      <h2 className="ax-heading text-foreground">{title}</h2>
      {hint && <p className="ax-caption mt-1 text-muted-foreground">{hint}</p>}
    </div>
  );
}
