import { createFileRoute } from "@tanstack/react-router";
import { Rocket } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { ms, usePrefetch } from "@/lib/perf";

export const Route = createFileRoute("/app/perf/prefetch")({ component: PrefetchPage });

/**
 * Feature 2 + 3 — Prefetch brain aur cold-start killer ek screen par:
 * kitni baar humne aapka next click pehle hi load kar liya, aur kaun surface thanda hai.
 */
function PrefetchPage() {
  const q = usePrefetch();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Rocket className="size-3.5" aria-hidden="true" /> Prefetch brain</>}
        title="The next screen is already loaded"
        blurb="We predict the thread you are about to open and fetch it early. Here is the hit rate, the time it saved you, and every surface still starting cold."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/perf/prefetch"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                <Stat
                  label="Hit rate"
                  value={d.hit_rate == null ? "—" : `${Math.round(d.hit_rate * 100)}%`}
                  hint={`${d.hits} hits · ${d.misses} misses`}
                />
                <Stat label="Time saved" value={`${Math.round(d.ms_saved / 1000)}s`} />
                <Stat label="Hits" value={String(d.hits)} />
                <Stat label="Misses" value={String(d.misses)} hint="wasted work, we tune it down" />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Predictions by surface</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.predictions.map((p) => (
                  <Row key={p.surface}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{p.surface}</span>
                    <span className="text-muted-foreground">
                      {p.opened}/{p.predicted} opened
                    </span>
                    <span className="text-steel">{Math.round(p.accuracy * 100)}% accurate</span>
                    <span className="ml-auto text-emerald-400">saves {ms(p.avg_saved_ms)}</span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">Still cold</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.cold_surfaces.map((c) => (
                  <Row key={c.surface}>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{c.surface}</span>
                    <span className="text-muted-foreground">first paint {ms(c.first_paint_ms)}</span>
                    <span className="text-steel">warm {ms(c.warm_ms)}</span>
                    <span className="ml-auto text-amber-400">{c.cold_starts} cold starts</span>
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