import { createFileRoute } from "@tanstack/react-router";
import { Gauge } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { ms, useFounderPerf } from "@/lib/perf";

export const Route = createFileRoute("/app/founder_/perf")({
  head: () => ({
    meta: [
      { title: "Founder speed founder view — ANEXOMAIL" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderPerfPage,
});

/** Founder-only surface (founderworkspace.anexomail.com, IP allowlisted at Caddy). */
function FounderPerfPage() {
  const q = useFounderPerf();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Gauge className="size-3.5" aria-hidden="true" /> Founder founder view</>}
        title="Speed across every tenant"
        blurb="One screen: who is slow, which release broke it, and how much time the prefetch brain gave back — real rows only."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/founder/perf/overview"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-3">
                <Stat label="Tenants" value={String(d.tenants)} />
                <Stat label="p95 platform-wide" value={ms(d.p95_ms)} />
                <Stat label="Budgets failing" value={String(d.budgets_failing)} />
                <Stat label="Open regressions" value={String(d.open_regressions)} />
                <Stat label="Cold starts" value={d.cold_starts_24h == null ? "—" : String(d.cold_starts_24h)} hint="last 24h" />
                <Stat
                  label="Time saved"
                  value={d.ms_saved_24h == null ? "—" : `${Math.round(d.ms_saved_24h / 1000)}s`}
                  hint="prefetch, last 24h"
                />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Slowest tenants</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.worst_tenants.map((t) => (
                  <Row key={t.tenant}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{t.tenant}</span>
                    <span className="text-muted-foreground">p95 {ms(t.p95_ms)}</span>
                    <span className="ml-auto text-steel">{t.failing} budgets failing</span>
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