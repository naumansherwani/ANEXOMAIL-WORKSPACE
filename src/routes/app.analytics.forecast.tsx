import { createFileRoute } from "@tanstack/react-router";
import { TrendingUp } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { hours, useForecast } from "@/lib/analytics";

export const Route = createFileRoute("/app/analytics/forecast")({ component: ForecastPage });

/** Feature 6 — Forecast: agla hafta kitna load aayega, kis wajah se. */
function ForecastPage() {
  const q = useForecast();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <Section
          eyebrow={<><TrendingUp className="size-3.5" aria-hidden="true" /> Next week</>}
          title="What is coming at you"
          blurb="Volume and hours predicted from your own history — with the reasons, not a mystery number."
        >
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/analytics/forecast"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(d) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-3">
                  <Stat label="Threads" value={String(d.next_week_threads)} />
                  <Stat label="Hours" value={hours(d.next_week_hours)} />
                  <Stat label="Confidence" value={`${Math.round(d.confidence)}%`} />
                </div>
                <h3 className="ax-heading mt-ax-6 text-foreground">Why</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {d.drivers.map((x) => (
                    <Row key={x.label}>
                      <span className="font-semibold text-foreground">{x.label}</span>
                      <span className="ml-auto text-steel">
                        {x.delta > 0 ? "+" : ""}
                        {x.delta}
                      </span>
                    </Row>
                  ))}
                </ul>
                {d.advice && <p className="ax-caption mt-ax-4 text-muted-foreground">{d.advice}</p>}
              </>
            )}
          </CardBody>
        </Section>
      </div>
    </div>
  );
}
