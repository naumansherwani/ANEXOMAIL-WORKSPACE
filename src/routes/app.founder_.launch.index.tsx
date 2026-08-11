import { createFileRoute } from "@tanstack/react-router";
import { ShieldCheck } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Verdict } from "@/components/app/premium/PremiumBits";
import { GateBadge, ReceiptCard } from "@/components/app/release/ReleaseBits";
import { notify } from "@/lib/notify";
import { gateFrom, ms, useReleaseOverview, useRunQa } from "@/lib/release";

export const Route = createFileRoute("/app/founder_/launch/")({ component: LaunchCommand });

/** Feature 1 — Release gate with proof. Red = launch blocked, in code. */
function LaunchCommand() {
  const q = useReleaseOverview();
  const run = useRunQa();
  const gate = gateFrom(q.data);

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><ShieldCheck className="size-3.5" aria-hidden="true" /> Release command</>}
        title="One screen, one verdict"
        blurb="Sixty-plus live probes decide the gate — routes, database, mail delivery, ownership proof and speed budgets. Nothing here is a guess."
      >
        <GateBadge gate={gate} />

        <button
          type="button"
          disabled={run.isPending}
          onClick={() =>
            run.mutate(
              { suite: "all" },
              {
                onSuccess: (d) =>
                  notify.done(`QA finished · ${d.run.passed} pass · ${d.run.failed} fail`, `${d.run.total} checks in ${ms(d.run.ms)}`),
                onError: (e) =>
                  notify.failed(e.status === 409 ? "A run is already in flight" : "QA run failed", {
                    description: e.isNotImplemented ? "Waiting on POST /api/founder/release/run." : e.message,
                  }),
              },
            )
          }
          className="ax-press mt-ax-4 rounded-lg bg-foreground px-3 py-2 text-[12px] font-semibold text-background disabled:opacity-50"
        >
          {run.isPending ? "Running the suite…" : "Run full QA"}
        </button>

        <div className="mt-ax-5">
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/founder/release/overview"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Checks passed" value={d.latest_run ? String(d.latest_run.passed) : "—"} />
                  <Stat label="Checks failed" value={d.latest_run ? String(d.latest_run.failed) : "—"} />
                  <Stat label="Suite time" value={ms(d.latest_run?.ms ?? null)} hint="target under 5s" />
                  <Stat
                    label="Checklist open"
                    value={`${d.checklist_open}/${d.checklist_total}`}
                    hint={d.checklist_open === 0 ? "clear" : "must reach zero"}
                  />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">What is holding the gate</h3>
                {d.blockers.length === 0 ? (
                  <p className="ax-caption mt-ax-3 text-muted-foreground">
                    Nothing is blocking. {d.locked_at ? "v1.0 is already signed." : "Sign v1.0 on the Lock tab."}
                  </p>
                ) : (
                  <ul className="mt-ax-3 space-y-1.5">
                    {d.blockers.map((b) => (
                      <Row key={b.id}>
                        <Verdict verdict="fail">blocker</Verdict>
                        <span className="min-w-0 flex-1">
                          <span className="block font-semibold text-foreground">{b.label}</span>
                          <span className="block truncate text-steel">
                            {b.suite}
                            {b.detail ? ` · ${b.detail}` : ""}
                          </span>
                        </span>
                      </Row>
                    ))}
                  </ul>
                )}

                {d.last_deployment && (
                  <>
                    <h3 className="ax-heading mt-ax-6 text-foreground">Last deployment</h3>
                    <ul className="mt-ax-3 space-y-ax-3">
                      <ReceiptCard deployment={d.last_deployment} />
                    </ul>
                  </>
                )}
              </>
            )}
          </CardBody>
        </div>
      </Section>
    </div>
  );
}
