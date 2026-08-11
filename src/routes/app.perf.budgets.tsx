import { createFileRoute } from "@tanstack/react-router";
import { Timer } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { BUDGET_TONE, ms, usePerfBudgets } from "@/lib/perf";

export const Route = createFileRoute("/app/perf/budgets")({ component: BudgetsPage });

/** Feature 1 — Speed receipts: har action ka budget aur uska asli p50/p95/p99. */
function BudgetsPage() {
  const q = usePerfBudgets();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Timer className="size-3.5" aria-hidden="true" /> Speed receipts</>}
        title="A budget per action, and the receipt to prove it"
        blurb="Opening a thread, sending, searching — each one has a millisecond budget. If it breaks, you see the number and the surface, not a spinner."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/perf/budgets"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) =>
            d.budgets.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No samples recorded yet.</p>
            ) : (
              <ul className="space-y-ax-3">
                {d.budgets.map((b) => (
                  <li key={b.action} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                      <span className="font-semibold text-foreground">{b.label}</span>
                      <code className="text-steel">{b.action}</code>
                      <span className={`ml-auto ${BUDGET_TONE[b.state]}`}>{b.state.replace("_", " ")}</span>
                    </div>
                    <ul className="mt-ax-3 space-y-1.5">
                      <Row>
                        <span className="min-w-0 flex-1 text-muted-foreground">budget</span>
                        <span className="text-foreground">{ms(b.budget_ms)}</span>
                        <span className="ml-auto text-steel">{b.samples} samples</span>
                      </Row>
                      <Row>
                        <span className="min-w-0 flex-1 text-muted-foreground">p50 · p95 · p99</span>
                        <span className="text-foreground">
                          {ms(b.p50_ms)} · {ms(b.p95_ms)} · {ms(b.p99_ms)}
                        </span>
                        {b.worst_surface && <span className="ml-auto text-amber-400">{b.worst_surface}</span>}
                      </Row>
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