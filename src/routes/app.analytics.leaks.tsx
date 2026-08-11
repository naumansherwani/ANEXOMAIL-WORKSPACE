import { createFileRoute } from "@tanstack/react-router";
import { Waves } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useAttentionLeaks } from "@/lib/analytics";

export const Route = createFileRoute("/app/analytics/leaks")({ component: LeaksPage });

/** Feature 4 — Attention leaks: kaun/kya tumhara waqt kha raha hai, aur fix. */
function LeaksPage() {
  const q = useAttentionLeaks();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><Waves className="size-3.5" aria-hidden="true" /> Attention leaks</>}
          title="What keeps interrupting you"
          blurb="Ranked by minutes stolen this week, with the one change that stops it."
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/analytics/attention-leaks"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) =>
              d.leaks.length === 0 ? (
                <p className="ax-caption text-muted-foreground">No leak big enough to report this week.</p>
              ) : (
                <ul className="space-y-1.5">
                  {d.leaks.map((l) => (
                    <Row key={l.source}>
                      <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{l.source}</span>
                      <span className="text-steel">{l.kind}</span>
                      <span className="text-muted-foreground">{l.interruptions_7d} interruptions</span>
                      <span className="ml-auto text-foreground">{l.minutes_7d}m</span>
                      {l.fix && <span className="w-full text-steel">Fix: {l.fix}</span>}
                    </Row>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </Section>
      </div>
    </div>
  );
}
