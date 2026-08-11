import type { ReactNode } from "react";

/** Phase 29 — shared premium-experience primitives. Presentation only. */

export function Toggle({
  label,
  hint,
  checked,
  onChange,
  disabled,
  disabledNote,
}: {
  label: string;
  hint: string;
  checked: boolean;
  onChange: (next: boolean) => void;
  disabled?: boolean;
  disabledNote?: string;
}) {
  return (
    <div className="flex items-start gap-3 rounded-xl border border-border bg-card px-3 py-3">
      <span className="min-w-0 flex-1">
        <span className="block text-sm font-semibold text-foreground">{label}</span>
        <span className="mt-0.5 block text-[12px] leading-relaxed text-muted-foreground">
          {disabled && disabledNote ? disabledNote : hint}
        </span>
      </span>
      <button
        type="button"
        role="switch"
        aria-checked={checked}
        aria-label={label}
        disabled={disabled}
        onClick={() => onChange(!checked)}
        className={
          "ax-press ax-tap mt-0.5 inline-flex h-6 w-11 shrink-0 items-center rounded-full border transition-colors " +
          (checked ? "border-ring/60 bg-secondary" : "border-border bg-background") +
          (disabled ? " opacity-50" : "")
        }
      >
        <span
          aria-hidden="true"
          className={
            "mx-0.5 block size-4 rounded-full transition-transform " +
            (checked ? "translate-x-5 bg-success" : "translate-x-0 bg-steel")
          }
        />
      </button>
    </div>
  );
}

const VERDICT: Record<string, string> = {
  green: "border-success/40 bg-success/10 text-success",
  watch: "border-warning/40 bg-warning/10 text-warning",
  fail: "border-danger/40 bg-danger/10 text-danger",
};

export function Verdict({ verdict, children }: { verdict: "green" | "watch" | "fail"; children: ReactNode }) {
  return (
    <span className={"rounded-md border px-1.5 py-0.5 text-[11px] font-semibold " + VERDICT[verdict]}>
      {children}
    </span>
  );
}
