import { createFileRoute } from "@tanstack/react-router";
import { Receipt } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { money, useThreadEconomics } from "@/lib/analytics";

export const Route = createFileRoute("/app/analytics/threads")({
  head: () => ({
    meta: [
      { title: "Analytics · Threads — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Analytics · Threads in ANEXOMAIL Workspace — real readings from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Analytics · Threads — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Analytics · Threads in ANEXOMAIL Workspace." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: ThreadEconomicsPage,
});

/** Feature 2 — Thread economics: har thread pe kitne minutes aur kitne logon ka waqt. */
function ThreadEconomicsPage() {
  const q = useThreadEconomics();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={
            <>
              <Receipt className="size-3.5" aria-hidden="true" /> Thread economics
            </>
          }
          title="What each conversation actually cost"
          blurb="A thread is a unit of work. This is the bill for it — minutes, people, money."
        >
          <CardBody
            query={{
              data: q.data,
              isPending: q.isPending,
              error: q.error ?? null,
              refetch: () => void q.refetch(),
            }}
            endpoint="/api/analytics/thread-economics"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Threads 30d" value={String(d.threads_30d)} />
                  <Stat
                    label="Time spent"
                    value={spanLabel(d.minutes_total)}
                    hint={`${d.avg_minutes}m average`}
                  />
                  <Stat label="People-hours" value={spanLabel(d.people_hours * 60)} />
                  <Stat label="Total cost" value={money(d.cost_total, d.currency)} />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">Most expensive threads</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {d.worst.map((t) => (
                    <Row key={t.thread_id}>
                      <span className="min-w-0 flex-1 truncate font-semibold text-foreground">
                        {t.subject}
                      </span>
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

/** 1 ghante se kam ho to minutes dikhao (pehle "0h" dikhta tha jab 23 minute the). */
function spanLabel(minutes: number): string {
  const m = Math.max(0, Math.round(minutes));
  if (m < 60) return `${m}m`;
  const h = m / 60;
  return `${h >= 10 ? Math.round(h) : Math.round(h * 10) / 10}h`;
}
