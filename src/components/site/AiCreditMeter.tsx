import { Info } from "lucide-react";

/**
 * Credit wallet preview — Lovable-style meter.
 * Display only. Real numbers Supabase wallet se aate hain (signed-in surface);
 * yahan awam ko plan allocation ka honest example dikhta hai.
 */
export function AiCreditMeter({
  plan,
  monthly,
  used,
}: {
  plan: string;
  monthly: number;
  used: number;
}) {
  const remaining = Math.max(monthly - used, 0);
  const pct = Math.min(100, Math.round((used / monthly) * 100));
  const low = remaining <= monthly * 0.05;

  return (
    <div className="rounded-2xl border border-border bg-card p-5 shadow-elev-1">
      <div className="flex items-center justify-between text-sm">
        <span className="font-semibold text-foreground">AI Credits</span>
        <span className="font-semibold text-foreground">
          {remaining.toLocaleString("en-GB")} left
        </span>
      </div>

      <div className="mt-3 h-2.5 overflow-hidden rounded-full bg-surface-2">
        <div
          className="h-full rounded-full bg-primary transition-[width] duration-500"
          style={{ width: `${100 - pct}%` }}
        />
      </div>

      <div className="mt-4 space-y-2 border-t border-border pt-4 text-sm">
        <Row label={plan} value={`${monthly.toLocaleString("en-GB")} credits/month`} />
        <Row label="Used this cycle" value={`${used.toLocaleString("en-GB")} credits`} />
        <Row label="Complimentary" value="10 per cycle (5/day × 2)" />
      </div>

      <p className="mt-4 flex items-start gap-2 text-xs leading-relaxed text-muted-foreground">
        <Info className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
        {low
          ? "Running low. Top up to continue uninterrupted AI use — your workspace stays fully available either way."
          : "Every action shows a pre-flight estimate before it runs, and a receipt after it finishes."}
      </p>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4">
      <span className="text-muted-foreground">{label}</span>
      <span className="font-medium text-foreground">{value}</span>
    </div>
  );
}
