import { createFileRoute } from "@tanstack/react-router";
import { Brain, Gauge, Sparkles, TrendingUp } from "lucide-react";

import { CardBody, DashboardCard, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, CrmStat, SectionTitle } from "@/components/app/crm/CrmBits";
import { STAGE_LABEL, money, useCrmInsights, useCrmOverview } from "@/lib/crm";

export const Route = createFileRoute("/app/crm/")({
  head: () => ({
    meta: [
      { title: "CRM dashboard — ANEXOMAIL Workspace" },
      {
        name: "description",
        content: "Pipeline value, weighted forecast, unworked leads and Leo's live deal insights.",
      },
      { property: "og:title", content: "CRM dashboard — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Pipeline, forecast and AI deal insights in one view." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CrmDashboard,
});

function CrmDashboard() {
  const overview = useCrmOverview();
  const insights = useCrmInsights();

  const o = overview.data;

  return (
    <div className="mx-auto w-full max-w-6xl px-ax-5 py-ax-6">
      <SectionTitle
        title="Revenue at a glance"
        hint="Every figure is derived from real threads on the server. Nothing here is typed by hand."
      />

      <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
        <CrmStat
          label="Open pipeline"
          value={o ? money(o.pipeline_value, o.currency) : "—"}
          hint={o ? `${o.open_deals} open deals` : undefined}
        />
        <CrmStat
          label="Weighted forecast"
          value={o ? money(o.weighted_value, o.currency) : "—"}
          hint="Value × probability"
        />
        <CrmStat
          label="Won this month"
          value={o ? money(o.won_this_month, o.currency) : "—"}
        />
        <CrmStat
          label="Unworked leads"
          value={o ? String(o.leads_unworked) : "—"}
          hint={o ? `${o.leads_new} new` : undefined}
        />
      </div>

      <div className="mt-ax-5 grid gap-ax-3 lg:grid-cols-2">
        <DashboardCard title="Stage health" icon={<Gauge className="size-4" />}>
          <CardBody
            query={{
              data: overview.data,
              isPending: overview.isPending,
              error: overview.error ?? null,
              refetch: () => void overview.refetch(),
            }}
            endpoint="/api/crm/overview"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(data) => (
              <ul className="space-y-ax-2">
                {data.stage_counts.map((s) => (
                  <li key={s.stage} className="flex items-center gap-ax-3">
                    <span className="w-24 shrink-0 text-[13px] font-semibold text-foreground">
                      {STAGE_LABEL[s.stage]}
                    </span>
                    <span className="ax-caption text-muted-foreground">{s.count} deals</span>
                    <span className="ml-auto text-[13px] font-semibold text-foreground">
                      {money(s.value, data.currency)}
                    </span>
                  </li>
                ))}
              </ul>
            )}
          </CardBody>
        </DashboardCard>

        <DashboardCard title="Speed" icon={<TrendingUp className="size-4" />}>
          <CardBody
            query={{
              data: overview.data,
              isPending: overview.isPending,
              error: overview.error ?? null,
              refetch: () => void overview.refetch(),
            }}
            endpoint="/api/crm/overview"
            skeleton={<StatSkeleton />}
          >
            {(data) => (
              <div className="space-y-ax-2 text-[13px] text-foreground">
                <p>
                  First reply average:{" "}
                  <strong>
                    {data.avg_first_reply_minutes === null
                      ? "not enough data"
                      : `${data.avg_first_reply_minutes} min`}
                  </strong>
                </p>
                <p className="flex items-center gap-2">
                  Stale deals:{" "}
                  <Chip tone={data.stale_deals > 0 ? "warn" : "good"}>
                    {data.stale_deals} untouched
                  </Chip>
                </p>
              </div>
            )}
          </CardBody>
        </DashboardCard>
      </div>

      <div className="mt-ax-5">
        <DashboardCard
          title="Leo's deal insights"
          hint="Risk, opportunity and the single next step — written by the AI that reads the thread."
          icon={<Sparkles className="size-4" />}
        >
          <CardBody
            query={{
              data: insights.data,
              isPending: insights.isPending,
              error: insights.error ?? null,
              refetch: () => void insights.refetch(),
            }}
            endpoint="/api/crm/insights"
            skeleton={<StatSkeleton rows={3} />}
          >
            {(data) =>
              data.insights.length === 0 ? (
                <p className="ax-caption text-muted-foreground">
                  No insights yet — Leo writes one as soon as a deal thread moves.
                </p>
              ) : (
                <ul className="space-y-ax-2">
                  {data.insights.map((i) => (
                    <li key={i.id} className="rounded-xl border border-border p-ax-3">
                      <div className="flex flex-wrap items-center gap-2">
                        <Brain aria-hidden="true" className="size-3.5 text-steel" />
                        <span className="text-[13px] font-semibold text-foreground">{i.title}</span>
                        <Chip
                          tone={
                            i.kind === "risk" ? "bad" : i.kind === "opportunity" ? "good" : "quiet"
                          }
                        >
                          {i.kind.replace("_", " ")}
                        </Chip>
                        <span className="ax-caption ml-auto text-muted-foreground">
                          {i.agent}
                          {i.confidence === null ? "" : ` · ${Math.round(i.confidence * 100)}%`}
                        </span>
                      </div>
                      <p className="ax-body mt-1.5">{i.detail}</p>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </DashboardCard>
      </div>
    </div>
  );
}
