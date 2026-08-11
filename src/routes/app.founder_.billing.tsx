import { createFileRoute } from "@tanstack/react-router";
import { TrendingUp } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { gbp, useRevenueTruth } from "@/lib/billing-platform";

export const Route = createFileRoute("/app/founder_/billing")({
  component: FounderRevenue,
});

/** Phase 21 — founder god-view: revenue truth, no vanity numbers. */
function FounderRevenue() {
  const revenue = useRevenueTruth();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <TrendingUp className="size-3.5" aria-hidden="true" /> Revenue truth
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">What the business actually earns</h2>

        <div className="mt-ax-5">
          <CardBody
            query={{
              data: revenue.data,
              isPending: revenue.isPending,
              error: revenue.error ?? null,
              refetch: () => void revenue.refetch(),
            }}
            endpoint="/api/founder/billing/revenue"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(r) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="MRR" value={gbp(r.mrr)} />
                  <Stat label="ARR" value={gbp(r.arr)} />
                  <Stat label="Paying tenants" value={String(r.paying_tenants)} />
                  <Stat label="Unpaid" value={gbp(r.unpaid_total)} />
                  <Stat label="Trialing" value={String(r.trialing)} />
                  <Stat label="Past due" value={String(r.past_due)} />
                  <Stat label="Churn 30d" value={String(r.churn_30d)} />
                  <Stat label="Currency" value={r.currency} />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">By plan</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {r.by_plan.map((p) => (
                    <li
                      key={p.plan}
                      className="ax-plane flex items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                    >
                      <span className="w-24 font-semibold text-foreground">{p.plan}</span>
                      <span className="text-muted-foreground">{p.tenants} tenants</span>
                      <span className="ml-auto text-foreground">{gbp(p.mrr)}</span>
                    </li>
                  ))}
                </ul>
              </>
            )}
          </CardBody>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-1 text-[19px] font-bold text-foreground">{value}</p>
    </div>
  );
}
