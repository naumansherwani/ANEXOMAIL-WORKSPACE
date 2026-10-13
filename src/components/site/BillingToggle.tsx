import type { BillingCycle } from "@/lib/plans";

type Props = {
  value: BillingCycle;
  onChange: (v: BillingCycle) => void;
  /** Small line rendered inside the pill next to "Yearly". */
  yearlyNote?: string;
  className?: string;
};

/**
 * Monthly / Yearly pill. Single control, no default blue card — the active
 * segment is a quiet raised chip, exactly like the reference.
 */
export function BillingToggle({ value, onChange, yearlyNote = "2 months free", className }: Props) {
  return (
    <div
      role="group"
      aria-label="Billing period"
      className={`inline-flex items-center gap-1 rounded-full border border-border bg-secondary/40 p-1 ${className ?? ""}`}
    >
      <button
        type="button"
        aria-pressed={value === "monthly"}
        onClick={() => onChange("monthly")}
        className={`ax-press rounded-full px-4 py-2 text-[13px] font-semibold transition-colors ${
          value === "monthly"
            ? "border border-border bg-card text-foreground"
            : "border border-transparent text-muted-foreground hover:text-foreground"
        }`}
      >
        Monthly
      </button>
      <button
        type="button"
        aria-pressed={value === "yearly"}
        onClick={() => onChange("yearly")}
        className={`ax-press flex items-center gap-2 rounded-full px-4 py-2 text-[13px] font-semibold transition-colors ${
          value === "yearly"
            ? "border border-border bg-card text-foreground"
            : "border border-transparent text-muted-foreground hover:text-foreground"
        }`}
      >
        Yearly
        <span className="text-[12px] font-semibold text-primary">{yearlyNote}</span>
      </button>
    </div>
  );
}
