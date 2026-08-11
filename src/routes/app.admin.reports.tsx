import { createFileRoute } from "@tanstack/react-router";
import { FileBarChart } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useGenerateReport, useReports } from "@/lib/admin-center";

export const Route = createFileRoute("/app/admin/reports")({ component: ReportsPage });

const thisPeriod = () => new Date().toISOString().slice(0, 7);

/** Organization Reports — board-ready, sirf asli numbers, one click export. */
function ReportsPage() {
  const q = useReports();
  const gen = useGenerateReport();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><FileBarChart className="size-3.5" aria-hidden="true" /> Organisation reports</>}
        title="A report you can hand to the board"
        blurb="Built from real mail, real hours and real spend — never estimated, never rounded up."
      >
        <button
          type="button"
          onClick={() => gen.mutate({ period: thisPeriod() })}
          disabled={gen.isPending}
          className="ax-press rounded-lg bg-foreground px-3 py-2 text-[12px] font-semibold text-background disabled:opacity-50"
        >
          {gen.isPending ? "Building…" : `Build report for ${thisPeriod()}`}
        </button>

        <div className="mt-ax-5">
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/admin/reports"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(d) => (
              <ul className="space-y-ax-4">
                {d.reports.map((r) => (
                  <li key={r.id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                      <span className="font-semibold text-foreground">{r.title}</span>
                      <span className="text-steel">{r.period}</span>
                      <span className="ml-auto text-muted-foreground">{r.status}</span>
                    </div>
                    <ul className="mt-ax-3 grid gap-1.5 sm:grid-cols-2">
                      {Object.entries(r.numbers).map(([k, v]) => (
                        <Row key={k}>
                          <span className="min-w-0 flex-1 truncate text-muted-foreground">{k.replace(/_/g, " ")}</span>
                          <span className="ml-auto font-semibold text-foreground">{String(v)}</span>
                        </Row>
                      ))}
                    </ul>
                    {r.highlights.length > 0 && (
                      <ul className="ax-caption mt-ax-3 list-disc space-y-1 pl-4 text-muted-foreground">
                        {r.highlights.map((h, i) => (
                          <li key={i}>{h}</li>
                        ))}
                      </ul>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </CardBody>
        </div>
      </Section>
    </div>
  );
}
