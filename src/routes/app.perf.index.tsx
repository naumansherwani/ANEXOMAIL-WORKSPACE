import { createFileRoute } from "@tanstack/react-router";
import { Gauge } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { ms, usePerfDashboard } from "@/lib/perf";

export const Route = createFileRoute("/app/perf/")({ component: PerfOverviewPage });

/** Speed as a feature: score asli samples se banta hai, koi vanity graph nahi. */
function PerfOverviewPage() {
  const q = usePerfDashboard();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Gauge className="size-3.5" aria-hidden="true" /> Speed</>}
        title="Speed you can audit, not feel"
        blurb="Every action carries a budget in milliseconds. Real samples decide the score — and name the surface that broke it."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/perf/dashboard"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                <Stat label="Speed score" value={`${d.score}/100`} hint="from real samples" />
                <Stat label="p95 everywhere" value={ms(d.p95_ms)} />
                <Stat label="Budgets passing" value={`${d.budgets_passing}/${d.budgets_total}`} />
                <Stat label="Open regressions" value={String(d.open_regressions)} />
              </div>

              <div className="mt-ax-4 grid gap-ax-3 sm:grid-cols-3">
                <Stat
                  label="Prefetch hit rate"
                  value={d.prefetch_hit_rate == null ? "—" : `${Math.round(d.prefetch_hit_rate * 100)}%`}
                />
                <Stat label="Time saved" value={d.ms_saved_24h == null ? "—" : `${Math.round(d.ms_saved_24h / 1000)}s`} hint="last 24h" />
                <Stat label="Cold starts" value={d.cold_starts_24h == null ? "—" : String(d.cold_starts_24h)} hint="last 24h" />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Slowest right now</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.slowest.map((s) => (
                  <Row key={s.action}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{s.action}</span>
                    <span className="text-muted-foreground">p95 {ms(s.p95_ms)}</span>
                    <span className="ml-auto text-steel">budget {ms(s.budget_ms)}</span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">Fix this next</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.advice.map((a, i) => (
                  <Row key={i}>
                    <span className="min-w-0 flex-1 font-semibold text-foreground">{a.title}</span>
                    <span className="min-w-0 flex-1 text-muted-foreground">{a.detail}</span>
                    <span
                      className={
                        a.severity === "high"
                          ? "ml-auto text-red-400"
                          : a.severity === "medium"
                            ? "ml-auto text-amber-400"
                            : "ml-auto text-steel"
                      }
                    >
                      {a.severity}
                    </span>
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