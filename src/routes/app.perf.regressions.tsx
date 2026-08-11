import { createFileRoute } from "@tanstack/react-router";
import { Activity } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { ms, useRegressions } from "@/lib/perf";

export const Route = createFileRoute("/app/perf/regressions")({ component: RegressionsPage });

/** Feature 6 — Regression sentinel: har release ka latency diff + rollback advice. */
function RegressionsPage() {
  const q = useRegressions();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Activity className="size-3.5" aria-hidden="true" /> Regression sentinel</>}
        title="A release that slows you down gets caught"
        blurb="Every release is compared to the one before it, action by action. If something got slower, it is named here with the advice to roll it back."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/perf/regressions"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) =>
            d.regressions.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No regressions detected — every release held its budget.</p>
            ) : (
              <ul className="space-y-ax-3">
                {d.regressions.map((r) => (
                  <li key={r.id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                      <span className="font-semibold text-foreground">{r.action}</span>
                      <span className="text-muted-foreground">
                        {r.previous_release ?? "—"} → {r.release}
                      </span>
                      <span
                        className={
                          r.state === "open" ? "text-red-400" : r.state === "acknowledged" ? "text-amber-400" : "text-emerald-400"
                        }
                      >
                        {r.state}
                      </span>
                      <span className="ml-auto text-steel">{new Date(r.detected_at).toLocaleString("en-GB")}</span>
                    </div>
                    <ul className="mt-ax-3 space-y-1.5">
                      <Row>
                        <span className="min-w-0 flex-1 text-muted-foreground">p95 before → after</span>
                        <span className="text-foreground">
                          {ms(r.before_p95_ms)} → {ms(r.after_p95_ms)}
                        </span>
                        <span className="ml-auto text-red-400">
                          {r.delta_pct == null ? "—" : `${r.delta_pct > 0 ? "+" : ""}${Math.round(r.delta_pct)}%`}
                        </span>
                      </Row>
                      {r.advice && (
                        <Row>
                          <span className="min-w-0 flex-1 text-muted-foreground">{r.advice}</span>
                        </Row>
                      )}
                    </ul>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </Section>
    </div>
  );
}