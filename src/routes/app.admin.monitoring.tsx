import { createFileRoute } from "@tanstack/react-router";
import { Radar } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useWatchtower } from "@/lib/admin-center";

export const Route = createFileRoute("/app/admin/monitoring")({ component: MonitoringPage });

/** Feature 4 — Delivery watchtower: queue/defer/bounce reasons plain English mein, live. */
function MonitoringPage() {
  const q = useWatchtower();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Radar className="size-3.5" aria-hidden="true" /> Delivery watchtower</>}
        title="Is your mail actually landing?"
        blurb="Every deferral and bounce translated into one plain sentence, with the ones you can fix marked."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/admin/monitoring"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                <Stat label="Delivered" value={String(d.sent)} hint={`${d.delivery_rate}% of attempts`} />
                <Stat label="In queue" value={String(d.queued)} hint={`last ${d.window_hours}h`} />
                <Stat label="Deferred" value={String(d.deferred)} hint="will retry" />
                <Stat label="Bounced / rejected" value={String(d.bounced + d.rejected)} hint="needs a decision" />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Why mail was held</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.reasons.map((r) => (
                  <Row key={r.reason_code}>
                    <span className="min-w-0 flex-1 font-semibold text-foreground">{r.human_reason}</span>
                    <code className="rounded bg-secondary px-1 py-0.5 text-[11px] text-steel">{r.reason_code}</code>
                    {r.fixable && <span className="text-amber-400">you can fix this</span>}
                    <span className="ml-auto text-muted-foreground">{r.count}</span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">Live stream</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.recent.map((e) => (
                  <Row key={e.id}>
                    <span className="text-steel">{new Date(e.at).toLocaleTimeString("en-GB")}</span>
                    <span className="min-w-0 flex-1 truncate text-foreground">{e.address ?? e.remote ?? "—"}</span>
                    <span className="text-muted-foreground">{e.state}</span>
                    <span className="ml-auto min-w-0 truncate text-steel">{e.human_reason ?? ""}</span>
                  </Row>
                ))}
              </ul>
            </>
          )}
        </CardBody>
      </Section>
    </div>
  );
}
