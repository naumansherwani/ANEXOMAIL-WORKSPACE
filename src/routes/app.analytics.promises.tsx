import { createFileRoute } from "@tanstack/react-router";
import { Handshake } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { usePromiseSla } from "@/lib/analytics";

export const Route = createFileRoute("/app/analytics/promises")({ component: PromisesPage });

/** Feature 5 — Promise SLA: jo waada kiya woh poora hua ya nahi. */
function PromisesPage() {
  const q = usePromiseSla();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><Handshake className="size-3.5" aria-hidden="true" /> Promise SLA</>}
          title="Did you do what you said you would"
          blurb="Every commitment made in a thread, tracked to the day it was due."
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/analytics/promise-sla"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Promises 30d" value={String(d.made_30d)} />
                  <Stat label="Keep rate" value={`${Math.round(d.keep_rate)}%`} hint={`${d.kept} kept`} />
                  <Stat label="Late" value={String(d.late)} hint={`avg ${Math.round(d.avg_late_hours)}h late`} />
                  <Stat label="Broken" value={String(d.broken)} />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">At risk today</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {d.at_risk.map((r) => (
                    <Row key={r.thread_id}>
                      <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{r.subject}</span>
                      <span className="text-muted-foreground">{r.person}</span>
                      <span className="ml-auto text-steel">due {new Date(r.due_at).toLocaleString("en-GB")}</span>
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
