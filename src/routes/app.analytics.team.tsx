import { createFileRoute } from "@tanstack/react-router";
import { Users } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { money, useTeamAnalytics } from "@/lib/analytics";

export const Route = createFileRoute("/app/analytics/team")({ component: TeamPage });

/** Team load — surveillance nahi, balance. Kaun doob raha hai, kaun free hai. */
function TeamPage() {
  const q = useTeamAnalytics();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><Users className="size-3.5" aria-hidden="true" /> Team load</>}
          title="Who is drowning, who is free"
          blurb="Built to rebalance work, not to police people. No keystrokes, no screenshots, ever."
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/analytics/team"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) => (
              <>
                {d.unbalanced && (
                  <p className="ax-caption mb-ax-3 text-steel">
                    Load is unbalanced — some inboxes carry several times the debt of others.
                  </p>
                )}
                <ul className="space-y-1.5">
                  {d.members.map((m) => (
                    <Row key={m.email}>
                      <span className="min-w-0 flex-1 truncate font-semibold text-foreground">
                        {m.display_name ?? m.email}
                      </span>
                      <span className="text-muted-foreground">debt {money(m.response_debt)}</span>
                      <span className="text-steel">keep {Math.round(m.keep_rate)}%</span>
                      <span className="ml-auto text-foreground">{m.load}</span>
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
