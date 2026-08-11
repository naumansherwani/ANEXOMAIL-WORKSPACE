import { createFileRoute } from "@tanstack/react-router";
import { Clock } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { money, useResponseDebt } from "@/lib/analytics";

export const Route = createFileRoute("/app/analytics/")({ component: ResponseDebtPage });

/** Feature 1 — Response debt: kitne log wait kar rahe hain + £ cost of delay. */
function ResponseDebtPage() {
  const q = useResponseDebt();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><Clock className="size-3.5" aria-hidden="true" /> Response debt</>}
          title="How many people are waiting on you"
          blurb="Not opens, not clicks. Real people, real hours, and what that delay is costing."
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/analytics/response-debt"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="People waiting" value={String(d.waiting_people)} hint={`${d.waiting_threads} threads`} />
                  <Stat label="Oldest wait" value={`${Math.round(d.oldest_hours)}h`} />
                  <Stat label="Median wait" value={`${Math.round(d.median_hours)}h`} />
                  <Stat label="Cost of delay" value={money(d.cost_of_delay, d.currency)} hint="waiting hours × blended rate" />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">Worst debt right now</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {d.worst.map((w) => (
                    <Row key={w.thread_id}>
                      <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{w.subject}</span>
                      <span className="text-muted-foreground">{w.person}</span>
                      <span className="text-steel">{Math.round(w.hours)}h</span>
                      <span className="ml-auto text-foreground">{money(w.cost, d.currency)}</span>
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
