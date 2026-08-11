import { createFileRoute } from "@tanstack/react-router";
import { Receipt } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { money, useThreadEconomics } from "@/lib/analytics";

export const Route = createFileRoute("/app/analytics/threads")({ component: ThreadEconomicsPage });

/** Feature 2 — Thread economics: har thread pe kitne minutes aur kitne logon ka waqt. */
function ThreadEconomicsPage() {
  const q = useThreadEconomics();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><Receipt className="size-3.5" aria-hidden="true" /> Thread economics</>}
          title="What each conversation actually cost"
          blurb="A thread is a unit of work. This is the bill for it — minutes, people, money."
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/analytics/thread-economics"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Threads 30d" value={String(d.threads_30d)} />
                  <Stat label="Time spent" value={`${Math.round(d.minutes_total / 60)}h`} hint={`${d.avg_minutes}m average`} />
                  <Stat label="People-hours" value={`${Math.round(d.people_hours)}h`} />
                  <Stat label="Total cost" value={money(d.cost_total, d.currency)} />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">Most expensive threads</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {d.worst.map((t) => (
                    <Row key={t.thread_id}>
                      <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{t.subject}</span>
                      <span className="text-muted-foreground">
                        {t.messages} msgs · {t.participants} people
                      </span>
                      <span className="text-steel">{t.minutes}m</span>
                      <span className="text-steel">{t.resolved ? "resolved" : "open"}</span>
                      <span className="ml-auto text-foreground">{money(t.cost, d.currency)}</span>
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
