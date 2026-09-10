import { createFileRoute } from "@tanstack/react-router";
import { Activity, AlertTriangle, GitBranch, ListChecks } from "lucide-react";

import { CardBody, DashboardCard, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, CrmStat, SectionTitle } from "@/components/app/crm/CrmBits";
import { CrmGraph } from "@/components/app/crm/CrmGraph";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { money, useCrmLive, useCrmOverview } from "@/lib/crm";

export const Route = createFileRoute("/app/crm/")({
  head: () => ({
    meta: [
      { title: "CRM — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CrmDashboard,
});

function CrmDashboard() {
  const { t } = useLocale();
  const overview = useCrmOverview();
  const live = useCrmLive();
  const o = overview.data;
  const board = live.data;

  return (
    <div className="mx-auto w-full max-w-6xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Live relationship")}
        hint={t("Mail, people, calendar, work and deals on one board. Empty stays empty until those records exist.")}
      />

      <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
        <CrmStat
          label={t("Open pipeline")}
          value={o ? money(o.pipeline_value, o.currency) : "—"}
          hint={o ? `${o.open_deals} ${t("open deals")}` : undefined}
        />
        <CrmStat
          label={t("Weighted forecast")}
          value={o ? money(o.weighted_value, o.currency) : "—"}
          hint={t("Value × probability")}
        />
        <CrmStat
          label={t("At risk")}
          value={board ? String(board.radar.length) : "—"}
          hint={t("From recorded dates and mail, not a guess")}
        />
        <CrmStat
          label={t("Overdue work")}
          value={board ? String(board.counts.overdue_tasks) : "—"}
          hint={t("Promises and tasks past due")}
        />
      </div>

      <div className="mt-ax-5 grid gap-ax-3 lg:grid-cols-2">
        <DashboardCard title={t("Next action")} icon={<ListChecks className="size-4" />}>
          <CardBody
            query={{
              data: live.data,
              isPending: live.isPending,
              error: live.error ?? null,
              refetch: () => void live.refetch(),
            }}
            endpoint="/api/crm/live"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(data) =>
              data.next_actions.length === 0 ? (
                <p className="ax-caption text-muted-foreground">{t("No rule fired. Capture a lead or wait for mail.")}</p>
              ) : (
                <ul className="space-y-ax-2">
                  {data.next_actions.map((a, i) => (
                    <li key={`${a.kind}-${i}`} className="rounded-xl border border-border/80 bg-background/40 p-ax-3">
                      <p className="text-[13px] font-semibold text-foreground">{t(a.action)}</p>
                      <p className="ax-caption mt-0.5 text-muted-foreground">
                        {a.title} · {a.why}
                      </p>
                      <a href={a.href} className="ax-caption mt-1 inline-block font-semibold text-foreground underline">
                        {t("Open")}
                      </a>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </DashboardCard>

        <DashboardCard title={t("Revenue risk")} icon={<AlertTriangle className="size-4" />}>
          <CardBody
            query={{
              data: live.data,
              isPending: live.isPending,
              error: live.error ?? null,
              refetch: () => void live.refetch(),
            }}
            endpoint="/api/crm/live"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(data) =>
              data.radar.length === 0 ? (
                <p className="ax-caption text-muted-foreground">{t("No risk rows. Health uses last touch, overdue work and silent deals.")}</p>
              ) : (
                <ul className="space-y-ax-2">
                  {data.radar.map((r, i) => (
                    <li key={`${r.source}-${i}`} className="flex items-start gap-2">
                      <Chip tone="warn">{t(r.kind.replace("_", " "))}</Chip>
                      <div className="min-w-0">
                        <p className="truncate text-[13px] font-semibold text-foreground">{r.title}</p>
                        <p className="ax-caption text-muted-foreground">{r.why}</p>
                        <p className="ax-caption text-steel">{r.source}</p>
                      </div>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </DashboardCard>
      </div>

      <div className="mt-ax-5 grid gap-ax-3 lg:grid-cols-2">
        <DashboardCard title={t("Timeline")} icon={<Activity className="size-4" />}>
          <CardBody
            query={{
              data: live.data,
              isPending: live.isPending,
              error: live.error ?? null,
              refetch: () => void live.refetch(),
            }}
            endpoint="/api/crm/live"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(data) =>
              data.timeline.length === 0 ? (
                <p className="ax-caption text-muted-foreground">{t("No mail, meetings or deal events yet.")}</p>
              ) : (
                <ol className="relative space-y-ax-3 ps-4 before:absolute before:inset-y-1 before:start-1 before:w-px before:bg-border">
                  {data.timeline.map((e, i) => (
                    <li key={`${e.at}-${i}`} className="relative flex flex-wrap items-center gap-2">
                      <span className="absolute -start-3.5 top-1.5 size-2 rounded-full bg-foreground" />
                      <Chip>{t(e.kind.replace("_", " "))}</Chip>
                      <a href={e.href} className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                        {e.title}
                      </a>
                      <span className="ax-caption text-muted-foreground">{relativeTime(e.at)}</span>
                    </li>
                  ))}
                </ol>
              )
            }
          </CardBody>
        </DashboardCard>

        <DashboardCard title={t("Graph")} icon={<GitBranch className="size-4" />}>
          <CardBody
            query={{
              data: live.data,
              isPending: live.isPending,
              error: live.error ?? null,
              refetch: () => void live.refetch(),
            }}
            endpoint="/api/crm/live"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(data) => <CrmGraph graph={data.graph} />}
          </CardBody>
        </DashboardCard>
      </div>
    </div>
  );
}
