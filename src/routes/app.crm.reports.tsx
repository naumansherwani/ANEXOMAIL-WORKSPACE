import { createFileRoute } from "@tanstack/react-router";

import { SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useLocale } from "@/lib/i18n";
import { money, STAGE_LABEL, useCrmOverview } from "@/lib/crm";

export const Route = createFileRoute("/app/crm/reports")({
  head: () => ({
    meta: [
      { title: "Reports — ANEXOMAIL CRM" },
      {
        name: "description",
        content:
          "Pipeline value, stage spread and won revenue — every figure computed from real deal rows.",
      },
      { property: "og:title", content: "Reports — ANEXOMAIL CRM" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: ReportsPage,
});

function ReportsPage() {
  const { t } = useLocale();
  const overview = useCrmOverview();

  return (
    <div className="mx-auto w-full max-w-6xl px-ax-5 py-ax-6">
      <SectionTitle
        title={t("Reports")}
        hint={t("Numbers from your deal rows. If a figure is zero, the rows behind it are zero.")}
      />

      <CardBody
        query={{
          data: overview.data,
          isPending: overview.isPending,
          error: overview.error ?? null,
          refetch: () => void overview.refetch(),
        }}
        endpoint="/api/crm/overview"
        skeleton={<StatSkeleton rows={6} />}
      >
        {(data) => {
          const maxStage = Math.max(1, ...data.stage_counts.map((s) => s.value));
          return (
            <div className="flex flex-col gap-ax-5">
              <div className="grid gap-ax-4 sm:grid-cols-2 xl:grid-cols-4">
                <div className="ax-plane rounded-2xl p-ax-4">
                  <p className="ax-caption text-steel">{t("Open pipeline")}</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums text-foreground">
                    {money(data.pipeline_value, data.currency)}
                  </p>
                  <p className="ax-caption mt-1 text-muted-foreground">
                    {data.open_deals} {t("open deals")}
                  </p>
                </div>
                <div className="ax-plane rounded-2xl p-ax-4">
                  <p className="ax-caption text-steel">{t("Weighted forecast")}</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums text-foreground">
                    {money(data.weighted_value, data.currency)}
                  </p>
                  <p className="ax-caption mt-1 text-muted-foreground">{t("Value × probability")}</p>
                </div>
                <div className="ax-plane rounded-2xl p-ax-4">
                  <p className="ax-caption text-steel">{t("Won this month")}</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums text-success">
                    {money(data.won_this_month, data.currency)}
                  </p>
                  <p className="ax-caption mt-1 text-muted-foreground">{t("Closed-won, this calendar month")}</p>
                </div>
                <div className="ax-plane rounded-2xl p-ax-4">
                  <p className="ax-caption text-steel">{t("Stale deals")}</p>
                  <p className="mt-1 text-2xl font-bold tabular-nums text-foreground">
                    {data.stale_deals}
                  </p>
                  <p className="ax-caption mt-1 text-muted-foreground">
                    {t("No movement in 14+ days")}
                  </p>
                </div>
              </div>

              <div className="ax-plane rounded-2xl p-ax-5">
                <p className="ax-caption font-semibold uppercase tracking-wider text-steel">
                  {t("Stage spread")}
                </p>
                <div className="mt-ax-4 flex flex-col gap-ax-3">
                  {data.stage_counts.map((s) => (
                    <div key={s.stage} className="flex items-center gap-ax-3">
                      <span className="w-24 shrink-0 text-[12px] font-semibold text-foreground">
                        {t(STAGE_LABEL[s.stage])}
                      </span>
                      <div className="h-2 min-w-0 flex-1 overflow-hidden rounded-full bg-secondary">
                        <div
                          className="h-full rounded-full bg-cyan-accent/80"
                          style={{ width: `${Math.max(2, (s.value / maxStage) * 100)}%` }}
                        />
                      </div>
                      <span className="w-20 shrink-0 text-end text-[12px] tabular-nums text-muted-foreground">
                        {money(s.value, data.currency)}
                      </span>
                      <span className="w-8 shrink-0 text-end text-[12px] font-bold tabular-nums text-foreground">
                        {s.count}
                      </span>
                    </div>
                  ))}
                </div>
              </div>

              <div className="grid gap-ax-4 sm:grid-cols-2">
                <div className="ax-plane rounded-2xl p-ax-4">
                  <p className="ax-caption text-steel">{t("New leads")}</p>
                  <p className="mt-1 text-xl font-bold tabular-nums text-foreground">
                    {data.leads_new}
                  </p>
                  <p className="ax-caption mt-1 text-muted-foreground">
                    {data.leads_unworked} {t("never touched")}
                  </p>
                </div>
                <div className="ax-plane rounded-2xl p-ax-4">
                  <p className="ax-caption text-steel">{t("Avg first reply")}</p>
                  <p className="mt-1 text-xl font-bold tabular-nums text-foreground">
                    {data.avg_first_reply_minutes != null
                      ? `${Math.round(data.avg_first_reply_minutes)} ${t("min")}`
                      : "—"}
                  </p>
                  <p className="ax-caption mt-1 text-muted-foreground">
                    {t("Fills in when mail flows")}
                  </p>
                </div>
              </div>
            </div>
          );
        }}
      </CardBody>
    </div>
  );
}
