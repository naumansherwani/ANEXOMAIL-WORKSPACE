import { CalendarClock } from "lucide-react";

import { billingDeadline, describeDeadline } from "@/lib/deadline";
import { useSubscription } from "@/lib/billing-platform";
import { useAccountState } from "@/lib/trial";
import { cityOf } from "@/lib/timeFormat";
import { cn } from "@/lib/utils";

/**
 * "Plan renews Fri 6 Nov, 2:00 PM Karachi time · in 14 days" — the real date from our own billing tables, in the person's own time zone.
 * Shown only when a real future date exists. Reads only; it never changes a plan and never calls Polar.
 */
export function BillingDeadline({
  here,
  now,
  className,
}: {
  here: string;
  now: Date | null;
  className?: string;
}) {
  const sub = useSubscription();
  const acct = useAccountState();
  if (now === null) return null;
  const d = billingDeadline(sub.data, acct.data, now.getTime());
  if (!d) return null;
  return (
    <div
      className={cn("rounded-md border border-border px-2.5 py-2 text-[12px]", className)}
      aria-live="polite"
    >
      <div className="flex items-center gap-1.5">
        <CalendarClock className="size-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
        <span className="font-semibold text-foreground">Billing</span>
      </div>
      <p className="mt-1 text-foreground">
        {describeDeadline(d, here, cityOf(here), now.getTime())}
      </p>
    </div>
  );
}
