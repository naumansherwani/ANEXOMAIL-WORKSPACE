import { createFileRoute } from "@tanstack/react-router";
import { ListChecks } from "lucide-react";

import { Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { CheckRow } from "@/components/app/release/ReleaseBits";
import { EmptyState } from "@/components/app/Panel";
import { ms, useReleaseChecks } from "@/lib/release";

export const Route = createFileRoute("/app/founder_/launch/qa")({ component: QaPage });

/** Feature 1 (detail) — 60+ checks, suite-wise, each with its own proof. */
function QaPage() {
  const q = useReleaseChecks();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><ListChecks className="size-3.5" aria-hidden="true" /> QA suite</>}
        title="Every check, with its receipt"
        blurb="Suite by suite: response code, latency and the reason. A failing probe is red here and the gate stays shut."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/founder/release/checks"
          skeleton={<StatSkeleton rows={6} />}
        >
          {(d) => {
            const run = d.runs[0];
            if (!run) {
              return (
                <EmptyState
                  icon={<ListChecks className="size-5" />}
                  title="No runs yet"
                  body="Run the QA suite from Release command — the first run writes the ledger."
                />
              );
            }
            const suites = [...new Set(d.checks.map((c) => c.suite))];
            return (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="Passed" value={String(run.passed)} />
                  <Stat label="Warned" value={String(run.warned)} />
                  <Stat label="Failed" value={String(run.failed)} />
                  <Stat label="Suite time" value={ms(run.ms)} hint={`${run.total} checks`} />
                </div>

                {suites.map((suite) => (
                  <section key={suite} className="mt-ax-6">
                    <h3 className="ax-heading text-foreground">{suite}</h3>
                    <ul className="mt-ax-3 space-y-1.5">
                      {d.checks
                        .filter((c) => c.suite === suite)
                        .map((c) => (
                          <CheckRow
                            key={c.id}
                            suite={c.suite}
                            name={c.name}
                            status={c.status}
                            latency={c.ms}
                            code={c.code}
                            detail={c.detail}
                          />
                        ))}
                    </ul>
                  </section>
                ))}
              </>
            );
          }}
        </CardBody>
      </Section>
    </div>
  );
}
