import { createFileRoute } from "@tanstack/react-router";
import { BarChart3 } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { money, useFounderAnalytics } from "@/lib/analytics";

export const Route = createFileRoute("/app/founder_/analytics")({ component: FounderAnalytics });

/** Phase 24 — founder view: platform-wide debt aur keep rate. */
function FounderAnalytics() {
  const q = useFounderAnalytics();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><BarChart3 className="size-3.5" aria-hidden="true" /> Analytics founder view</>}
          title="Platform-wide truth"
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/founder/analytics/overview"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(o) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Tenants" value={String(o.tenants)} />
                  <Stat label="Total debt" value={money(o.total_debt_cost, o.currency)} />
                  <Stat label="Keep rate" value={`${Math.round(o.platform_keep_rate)}%`} />
                  <Stat label="Threads 30d" value={o.threads_30d.toLocaleString()} />
                </div>
                <h3 className="ax-heading mt-ax-6 text-foreground">Worst tenants</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {o.worst_tenants.map((t) => (
                    <Row key={t.tenant}>
                      <span className="font-semibold text-foreground">{t.tenant}</span>
                      <span className="text-steel">{t.waiting} people waiting</span>
                      <span className="ml-auto text-foreground">{money(t.debt, o.currency)}</span>
                    </Row>
                  ))}
                </ul>
              </>
            )}
          </CardBody>
        </Section>
      </div>
    </div>
  );
}
