import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { FlaskConical } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { notify } from "@/lib/notify";
import { ms, useRunQueryLab, useSearchTraces } from "@/lib/perf";

export const Route = createFileRoute("/app/perf/search")({ component: QueryLabPage });

/** Feature 4 — Query lab: asli query chalao, stage-by-stage waterfall dekho. */
function QueryLabPage() {
  const q = useSearchTraces();
  const run = useRunQueryLab();
  const [query, setQuery] = useState("");

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><FlaskConical className="size-3.5" aria-hidden="true" /> Query lab</>}
        title="See exactly where a search spends its time"
        blurb="Run a real query and get the waterfall back: parse, index, fetch, rank, render. The slowest stage is named — no guessing."
      >
        <form
          className="flex gap-2"
          onSubmit={(e) => {
            e.preventDefault();
            const value = query.trim();
            if (!value) return;
            run.mutate(
              { query: value },
              {
                onSuccess: (r) => notify.done("Trace captured", `${r.trace.total_ms}ms · ${r.trace.rows} rows`),
                onError: (err) =>
                  notify.failed(err.isNotImplemented ? "Query lab not wired yet" : "Query failed", {
                    description: err.message,
                  }),
              },
            );
          }}
        >
          <Input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="invoice from last week"
            aria-label="Query to trace"
          />
          <Button type="submit" variant="secondary" disabled={run.isPending}>
            {run.isPending ? "Tracing…" : "Trace"}
          </Button>
        </form>

        <div className="mt-ax-5">
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/perf/search"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(d) =>
              d.traces.length === 0 ? (
                <p className="ax-caption text-muted-foreground">No traces captured yet.</p>
              ) : (
                <ul className="space-y-ax-4">
                  {d.traces.map((t) => (
                    <li key={t.id} className="ax-plane rounded-2xl p-ax-4">
                      <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                        <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{t.query}</span>
                        <span className="text-muted-foreground">{ms(t.total_ms)}</span>
                        <span className="text-steel">{t.rows} rows</span>
                        {t.cached && <span className="text-emerald-400">cached</span>}
                        <span className="ml-auto text-steel">{new Date(t.at).toLocaleString("en-GB")}</span>
                      </div>
                      <ul className="mt-ax-3 space-y-1.5">
                        {t.stages.map((s) => (
                          <Row key={s.stage}>
                            <span className="min-w-0 flex-1 font-semibold text-foreground">{s.stage}</span>
                            <span
                              className={s.stage === t.slowest_stage ? "text-amber-400" : "text-muted-foreground"}
                            >
                              {ms(s.ms)}
                            </span>
                            <span className="ml-auto text-steel">
                              {t.total_ms > 0 ? `${Math.round((s.ms / t.total_ms) * 100)}%` : "—"}
                            </span>
                          </Row>
                        ))}
                      </ul>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </div>
      </Section>
    </div>
  );
}