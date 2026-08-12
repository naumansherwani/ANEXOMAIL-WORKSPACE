import { createFileRoute, Link } from "@tanstack/react-router";
import { TrendingUp } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Bar, Note } from "@/components/app/release/ReleaseBits";
import { gbp, useRevenuePipeline } from "@/lib/release";

export const Route = createFileRoute("/app/founder_/revenue_/pipeline")({
  head: () => ({
    meta: [
      { title: "Revenue pipeline truth — ANEXOMAIL" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: PipelinePage,
});

/**
 * Feature 6 — Revenue Pipeline Truth Board.
 * MRR TRUTH RULE: migration/setup cash one-off hai, MRR mein kabhi nahi ginta.
 */
function PipelinePage() {
  const q = useRevenuePipeline();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><TrendingUp className="size-3.5" aria-hidden="true" /> Pipeline truth</>}
        title="Committed MRR vs pipeline vs the gap"
        blurb="Recurring money is subscriptions, partner commission and the SLA retainer. Migration cash is counted separately — it never inflates MRR."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/founder/revenue/pipeline"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                <Stat label="Committed MRR" value={gbp(d.committed_mrr_gbp)} hint="signed and recurring" />
                <Stat label="Pipeline MRR" value={gbp(d.pipeline_mrr_gbp)} hint="weighted by stage" />
                <Stat label="One-off cash" value={gbp(d.one_off_cash_gbp)} hint="not MRR" />
                <Stat label={`Gap to ${gbp(d.target_gbp)}`} value={gbp(d.gap_gbp)} hint={d.gap_gbp <= 0 ? "target met" : "still to win"} />
              </div>

              <div className="mt-ax-5">
                <Bar
                  label={`${gbp(d.committed_mrr_gbp)} of ${gbp(d.target_gbp)} committed`}
                  value={d.committed_mrr_gbp}
                  max={d.target_gbp}
                  tone="bg-success"
                />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Committed streams</h3>
              {d.committed.length === 0 ? (
                <Note>No recurring revenue booked yet — the first £20 subscription starts this board.</Note>
              ) : (
                <ul className="mt-ax-3 space-y-1.5">
                  {d.committed.map((s) => (
                    <Row key={s.stream}>
                      <span className="min-w-0 flex-1 font-semibold text-foreground">{s.stream}</span>
                      <span className="text-steel">{s.accounts} accounts</span>
                      <span className="ml-auto font-bold text-foreground">{gbp(s.mrr_gbp)}/mo</span>
                    </Row>
                  ))}
                </ul>
              )}

              <h3 className="ax-heading mt-ax-6 text-foreground">Open leads by offer</h3>
              <p className="mt-1 text-xs text-steel">
                Managed Move-In is one-off cash · Priority Support is a £700/mo retainer · Workspace
                subscription is the recurring plan. Three different offers, never mixed.
              </p>
              {d.pipeline.length === 0 ? (
                <Note>
                  No open leads. New requests arrive from{" "}
                  <Link to="/migration" className="underline">
                    /migration
                  </Link>
                  ,{" "}
                  <Link to="/partners" className="underline">
                    /partners
                  </Link>{" "}
                  and{" "}
                  <Link to="/enterprise" className="underline">
                    /enterprise
                  </Link>
                  .
                </Note>
              ) : (
                <ul className="mt-ax-3 space-y-1.5">
                  {d.pipeline.map((p) => (
                    <Row key={p.id}>
                      <span className="font-mono text-steel">{p.reference}</span>
                      <span className="min-w-0 flex-1">
                        <span className="block font-semibold text-foreground">{p.company}</span>
                        <span className="block truncate text-steel">
                          {p.offer ?? "Workspace subscription"} · {p.stage} ·{" "}
                          {Math.round(p.weight * 100)}% · {p.plan_seats} seats
                          {p.one_off_gbp ? ` · ${gbp(p.one_off_gbp)} one-off` : ""}
                        </span>
                      </span>
                      <span className="ml-auto font-bold text-foreground">{gbp(p.expected_mrr_gbp)}/mo</span>
                    </Row>
                  ))}
                </ul>
              )}
            </>
          )}
        </CardBody>
      </Section>
    </div>
  );
}
