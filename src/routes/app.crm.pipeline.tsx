import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowRight, Mail, Plus } from "lucide-react";
import { useState } from "react";

import { OpenDealForm } from "@/components/app/crm/CrmCapture";
import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from "@/components/ui/sheet";
import { notify } from "@/lib/notify";
import { useLocale } from "@/lib/i18n";
import {
  STAGE_LABEL,
  STAGE_ORDER,
  money,
  probabilityPercent,
  useCrmDeals,
  useDealToWork,
  useMoveDeal,
  useAttachDealThread,
  type Deal,
  type DealStage,
} from "@/lib/crm";

export const Route = createFileRoute("/app/crm/pipeline")({
  head: () => ({
    meta: [
      { title: "Pipeline — ANEXOMAIL CRM" },
      {
        name: "description",
        content:
          "A stage board where every deal keeps its email thread. Move a deal and the server rewrites its probability and writes the audit line.",
      },
      { property: "og:title", content: "Pipeline — ANEXOMAIL CRM" },
      { property: "og:description", content: "Deal stages that never lose the email thread." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: PipelinePage,
});

function PipelinePage() {
  const { t } = useLocale();
  const deals = useCrmDeals();
  const move = useMoveDeal();
  const toWork = useDealToWork();
  const attach = useAttachDealThread();
  const [drawer, setDrawer] = useState(false);

  const advance = (deal: Deal) => {
    const next = STAGE_ORDER[Math.min(STAGE_ORDER.indexOf(deal.stage) + 1, STAGE_ORDER.length - 1)];
    if (!next || next === deal.stage) return;
    move.mutate(
      { id: deal.id, stage: next },
      {
        onSuccess: () => notify.done("Deal moved", `${deal.title} → ${STAGE_LABEL[next]}`),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Stage move not wired yet" : "Could not move deal", {
            description: e.message,
          }),
      },
    );
  };

  return (
    <div className="w-full px-ax-5 py-ax-6">
      <div className="flex items-start justify-between gap-3">
        <SectionTitle
          title={t("Pipeline")}
          hint={t("Thread stays attached when a deal has mail. Columns stay empty until a real deal lands.")}
        />
        <Button onClick={() => setDrawer(true)} className="ax-press shrink-0">
          <Plus className="size-4" aria-hidden="true" /> {t("New deal")}
        </Button>
      </div>

      <Sheet open={drawer} onOpenChange={setDrawer}>
        <SheetContent side="right" className="w-full sm:max-w-md">
          <SheetHeader>
            <SheetTitle>{t("Open a deal")}</SheetTitle>
            <SheetDescription>
              {t("Name it. Attach the mail thread later — the board fills from real deals only.")}
            </SheetDescription>
          </SheetHeader>
          <div className="mt-6">
            <OpenDealForm onDone={() => setDrawer(false)} />
          </div>
        </SheetContent>
      </Sheet>

      <CardBody
        query={{
          data: deals.data,
          isPending: deals.isPending,
          error: deals.error ?? null,
          refetch: () => void deals.refetch(),
        }}
        endpoint="/api/crm/deals"
        skeleton={<StatSkeleton rows={6} />}
      >
        {(data) => (
          <div className="flex gap-ax-3 overflow-x-auto pb-ax-4">
            {STAGE_ORDER.map((stage) => {
              const items = data.deals.filter((d) => d.stage === stage);
              const total = items.reduce((s, d) => s + d.value, 0);
              const currency = items[0]?.currency ?? "GBP";
              return (
                <Column
                  key={stage}
                  stage={stage}
                  count={items.length}
                  total={money(total, currency)}
                >
                  {items.length === 0 ? (
                    stage === "new" ? (
                      <button
                        type="button"
                        onClick={() => setDrawer(true)}
                        className="ax-press flex w-full flex-col items-start gap-1 rounded-lg border border-dashed border-border px-2.5 py-3 text-start transition-colors hover:border-foreground/30"
                      >
                        <span className="text-[12px] font-semibold text-foreground">
                          {t("No deals yet")}
                        </span>
                        <span className="ax-caption text-muted-foreground">
                          {t("Capture one from mail or open a deal here.")}
                        </span>
                      </button>
                    ) : (
                      <p className="ax-caption text-muted-foreground">{t("No deals in this stage")}</p>
                    )
                  ) : (
                    items.map((d) => (
                      <article
                        key={d.id}
                        className="rounded-xl border border-border bg-card p-ax-3"
                      >
                        <p className="text-[13px] font-semibold text-foreground">{d.title}</p>
                        <p className="ax-caption mt-0.5 text-muted-foreground">
                          {d.company ?? d.contact_email ?? t("No company yet")}
                        </p>
                        <div className="mt-1.5 flex flex-wrap items-center gap-2">
                          <span className="text-[13px] font-semibold text-foreground">
                            {money(d.value, d.currency)}
                          </span>
                          {probabilityPercent(d.probability) !== null && (
                            <Chip>{probabilityPercent(d.probability)}% {t("likely")}</Chip>
                          )}
                          {d.stale_days !== null && d.stale_days > 7 && (
                            <Chip tone="warn">{d.stale_days}d {t("quiet")}</Chip>
                          )}
                        </div>
                        {d.next_step && (
                          <p className="ax-caption mt-1.5 text-muted-foreground">
                            {t("Next")}: {d.next_step}
                            {d.next_step_due ? ` · ${d.next_step_due}` : ""}
                          </p>
                        )}
                        <div className="mt-ax-2 flex items-center gap-2">
                          {d.thread_id && (
                            <Link
                              to="/app/mail/$folder/$threadId"
                              params={{ folder: "inbox", threadId: d.thread_id }}
                              className="ax-press ax-caption inline-flex items-center gap-1 rounded-full border border-border px-2 py-0.5 font-semibold text-foreground"
                            >
                              <Mail className="size-3" aria-hidden="true" /> {t("Thread")}
                            </Link>
                          )}
                          {!d.thread_id && d.contact_email ? (
                            <button
                              type="button"
                              onClick={() =>
                                attach.mutate(
                                  { id: d.id },
                                  {
                                    onSuccess: () => notify.done(t("Mail attached from this address"), d.contact_email || ""),
                                    onError: (e) =>
                                      notify.failed(
                                        e.status === 404 ? t("No mail thread on this address yet") : t("Could not attach mail"),
                                        { description: e.message },
                                      ),
                                  },
                                )
                              }
                              disabled={attach.isPending}
                              className="ax-press ax-caption rounded-full border border-border px-2 py-0.5 font-semibold text-foreground"
                            >
                              {t("Attach mail")}
                            </button>
                          ) : null}
                          {stage !== "won" && stage !== "lost" && (
                            <button
                              type="button"
                              onClick={() => advance(d)}
                              disabled={move.isPending}
                              className="ax-press ax-caption inline-flex items-center gap-1 rounded-full border border-cyan-accent/50 px-2 py-0.5 font-semibold text-foreground"
                            >
                              {t("Advance")} <ArrowRight className="size-3" aria-hidden="true" />
                            </button>
                          )}
                          <button
                            type="button"
                            onClick={() =>
                              toWork.mutate(
                                { id: d.id },
                                {
                                  onSuccess: () => notify.done("Work opened", "The deal is a task on Work."),
                                  onError: (e) =>
                                    notify.failed(e.isNotImplemented ? "Work link not wired yet" : "Could not open work", {
                                      description: e.message,
                                    }),
                                },
                              )
                            }
                            disabled={toWork.isPending}
                            className="ax-press ax-caption rounded-full border border-border px-2 py-0.5 font-semibold text-foreground"
                          >
                            {t("Work")}
                          </button>
                        </div>
                      </article>
                    ))
                  )}
                </Column>
              );
            })}
          </div>
        )}
      </CardBody>
    </div>
  );
}

function Column({
  stage,
  count,
  total,
  children,
}: {
  stage: DealStage;
  count: number;
  total: string;
  children: React.ReactNode;
}) {
  const { t } = useLocale();
  return (
    <section className="ax-plane flex w-72 shrink-0 flex-col rounded-2xl p-ax-3">
      <header className="mb-ax-3">
        <p className="text-[13px] font-bold text-foreground">{t(STAGE_LABEL[stage])}</p>
        <p className="ax-caption text-muted-foreground">
          {count} · {total}
        </p>
      </header>
      <div className="space-y-ax-2">{children}</div>
    </section>
  );
}
