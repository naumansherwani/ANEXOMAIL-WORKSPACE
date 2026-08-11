import { createFileRoute } from "@tanstack/react-router";
import { History } from "lucide-react";

import { Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { ReceiptCard } from "@/components/app/release/ReleaseBits";
import { useDeployments } from "@/lib/release";

export const Route = createFileRoute("/app/founder_/launch/deployments")({ component: DeploymentsPage });

/** Feature 2 — deploy receipt + rollback trail. */
function DeploymentsPage() {
  const q = useDeployments();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><History className="size-3.5" aria-hidden="true" /> Deploy receipts</>}
        title="Which commit is live, and what changed"
        blurb="Every deploy keeps its commit, actor, duration and the diff since the last green release — including rollbacks."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/founder/release/deployments"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) =>
            d.deployments.length === 0 ? (
              <EmptyState
                icon={<History className="size-5" />}
                title="No deploy receipts yet"
                body="The next production deploy writes the first receipt automatically."
              />
            ) : (
              <ul className="space-y-ax-3">
                {d.deployments.map((dep) => (
                  <ReceiptCard key={dep.id} deployment={dep} />
                ))}
              </ul>
            )
          }
        </CardBody>
      </Section>
    </div>
  );
}
