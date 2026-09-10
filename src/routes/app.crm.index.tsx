import { createFileRoute } from "@tanstack/react-router";
import { Activity, AlertTriangle, GitBranch } from "lucide-react";

import { CardBody, DashboardCard, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CrmGraph } from "@/components/app/crm/CrmGraph";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { money, STAGE_LABEL, useCrmLive, useCrmOverview } from "@/lib/crm";

export const Route = createFileRoute("/app/crm/")({
  head: () => ({
    meta: [
      { title: "CRM — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CrmDashboard,
});

function Kpi({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="ax-plane ax-lift rounded-[18px] p-5" style={{ minHeight: 118 }}>
      <p className="text-[11px] font-semibold uppercase tracking-[0.12em] text-steel">{label}</p>
      <p className="mt-2.5 text-[28px] font-bold leading-none tabular-nums tracking-tight text-foreground">
        {value}
      </p>
      {hint ? <p className="ax-caption mt-2 text-muted-foreground">{hint}</p> : null}
    </div>
  );
}

function CrmDashboard() {
  const { t } = useLocale();
  const overview = useCrmOverview();
  const live = useCrmLive();
  const o = overview.data;
  const board = live.data;

  const won = o?.stage_counts.find((s) => s.stage === "won")?.count ?? 0;
  const lost = o?.stage_counts.find((s) => s.stage === "lost")?.count ?? 0;
  const conversion = won + lost > 0 ? Math.round((won / (won + lost)) * 100) : null;
  const maxStage = Math.max(1, ...(o?.stage_counts.map((s) => s.value) ?? [1]));

  return (
    <div className="relative mx-auto w-full max-w-[1400px] px-6 py-8 lg:px-8">
      {/* Cinematic depth — subtle, static, never distracting */}
      <div className="pointer-events-none absolute inset-x-0 top-0 h-72 bg-[radial-gradient(60%_90%_at_85%_-20%,oklch(0.455_0.093_258_/_12%),transparent_65%)]" />
      <div className="pointer-events-none absolute inset-x-0 bottom-0 h-72 bg-[radial-gradient(50%_80%_at_8%_110%,oklch(0.5_0.07_300_/_8%),transparent_65%)]" />

      <div className="relative">
        <p className="ax-eyebrow">{t("CRM")}</p>
        <h1 className="mt-1 text-[32px] font-bold leading-tight tracking-tight text-foreground">
          {t("Relationship intelligence")}
        </h1>
        <p className="mt-1.5 max-w-xl text-[14px] text-muted-foreground">
          {t("Every relationship leaves a trail. Turn the trail into action.")}
        </p>

        {/* KPI row — 6 cards, real rows only */}
        <div className="mt-6 grid grid-cols-2 gap-4 md:grid-cols-3 xl:grid-cols-6">
          <Kpi
            label={t("Revenue")}
            value={o ? money(o.won_this_month, o.currency) : "—"}
            hint={t("Won this month")}
          />
          <Kpi
            label={t("Pipeline")}
            value={o ? money(o.pipeline_value, o.currency) : "—"}
            hint={t("Open deal value")}
          />
          <Kpi
            label={t("Open deals")}
            value={o ? String(o.open_deals) : "—"}
            hint={t("Not won, not lost")}
          />
          <Kpi
            label={t("At risk")}
            value={board ? String(board.radar.length) : "—"}
            hint={t("Recorded reasons only")}
          />
          <Kpi
            label={t("Promises due")}
            value={board ? String(board.counts.promises) : "—"}
            hint={t("Open commitments")}
          />
          <Kpi
            label={t("Conversion")}
            value={conversion != null ? `${conversion}%` : "—"}
            hint={t("Won vs lost deals")}
          />
        </div>

        {/* Main cinematic area — 65 / 35 */}
        <div className="mt-6 grid gap-6 lg:grid-cols-[65fr_35fr]">
          <DashboardCard
            title={t("Relationship flow")}
            hint={t("Deal value by stage — the pipeline as a current, not a list.")}
            icon={<Activity className="size-4" />}
          >
            <CardBody
              query={{
                data: overview.data,
                isPending: overview.isPending,
                error: overview.error ?? null,
                refetch: () => void overview.refetch(),
              }}
              endpoint="/api/crm/overview"
              skeleton={<StatSkeleton rows={5} />}
            >
              {(data) => (
                <div className="flex flex-col gap-3 py-2">
                  {data.stage_counts.map((s) => (
                    <div key={s.stage} className="flex items-center gap-3">
                      <span className="w-24 shrink-0 text-[12px] font-semibold text-muted-foreground">
                        {t(STAGE_LABEL[s.stage])}
                      </span>
                      <div className="h-7 min-w-0 flex-1 overflow-hidden rounded-lg bg-secondary/60">
                        <div
                          className="flex h-full items-center rounded-lg bg-cyan-accent/25 ps-2 transition-[width] duration-700"
                          style={{ width: `${Math.max(s.value > 0 ? 8 : 0, (s.value / maxStage) * 100)}%` }}
                        >
                          {s.value > 0 ? (
                            <span className="text-[11px] font-bold tabular-nums text-foreground">
                              {money(s.value, data.currency)}
                            </span>
                          ) : null}
                        </div>
                      </div>
                      <span className="w-6 shrink-0 text-end text-[12px] font-bold tabular-nums text-foreground">
                        {s.count}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </CardBody>
          </DashboardCard>

          {/* Next actions — the panel that tells you what to do */}
          <DashboardCard
            title={t("Next")}
            hint={t("One step per rule — each carries its why.")}
            icon={<AlertTriangle className="size-4" />}
          >
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
                  <p className="ax-caption text-muted-foreground">
                    {t("No rule fired. Capture a lead or wait for mail.")}
                  </p>
                ) : (
                  <ul className="space-y-2">
                    {data.next_actions.slice(0, 6).map((a, i) => (
                      <li
                        key={`${a.kind}-${i}`}
                        className="rounded-xl border border-border/80 bg-background/40 p-3"
                      >
                        <p className="text-[13px] font-semibold text-foreground">{t(a.action)}</p>
                        <p className="ax-caption mt-0.5 text-muted-foreground">
                          {a.title} · {a.why}
                        </p>
                        <a
                          href={a.href}
                          className="ax-caption mt-1 inline-block font-semibold text-foreground underline underline-offset-4"
                        >
                          {t("Open")}
                        </a>
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </DashboardCard>
        </div>

        {/* Risk + timeline */}
        <div className="mt-6 grid gap-6 lg:grid-cols-2">
          <DashboardCard
            title={t("Risk radar")}
            hint={t("Every risk carries reason, source and time.")}
            icon={<AlertTriangle className="size-4" />}
          >
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
                  <p className="ax-caption text-muted-foreground">
                    {t("No risk rows. Health uses last touch, overdue work and silent deals.")}
                  </p>
                ) : (
                  <ul className="space-y-2">
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

          <DashboardCard
            title={t("Timeline")}
            hint={t("Mail, meetings, deals — one record, UTC.")}
            icon={<Activity className="size-4" />}
          >
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
                  <p className="ax-caption text-muted-foreground">
                    {t("No mail, meetings or deal events yet.")}
                  </p>
                ) : (
                  <ol className="relative space-y-3 ps-4 before:absolute before:inset-y-1 before:start-1 before:w-px before:bg-border">
                    {data.timeline.map((e, i) => (
                      <li key={`${e.at}-${i}`} className="relative flex flex-wrap items-center gap-2">
                        <span className="absolute -start-3.5 top-1.5 size-2 rounded-full bg-foreground" />
                        <Chip>{t(e.kind.replace("_", " "))}</Chip>
                        <a
                          href={e.href}
                          className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground"
                        >
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
        </div>

        {/* Graph — full width cinematic canvas */}
        <div className="mt-6">
          <DashboardCard
            title={t("Graph")}
            hint={t("Person ↔ company ↔ deal ↔ mail — recorded links only.")}
            icon={<GitBranch className="size-4" />}
          >
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

        <div className="mt-6">
          <SectionTitle
            title={t("Empty stays empty")}
            hint={t("Every figure on this page is computed from rows you can open. No estimate is invented.")}
          />
        </div>
      </div>
    </div>
  );
}
