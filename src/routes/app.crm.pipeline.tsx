import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowRight, Mail } from "lucide-react";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { notify } from "@/lib/notify";
import {
  STAGE_LABEL,
  STAGE_ORDER,
  money,
  useCrmDeals,
  useMoveDeal,
  type Deal,
  type DealStage,
} from "@/lib/crm";

export const Route = createFileRoute("/app/crm/pipeline")({
  head: () => ({
    meta: [
      { title: "Pipeline — ANEXOMAIL AI CRM" },
      {
        name: "description",
        content:
          "A stage board where every deal keeps its email thread. Move a deal and the server rewrites its probability and writes the audit line.",
      },
      { property: "og:title", content: "Pipeline — ANEXOMAIL AI CRM" },
      { property: "og:description", content: "Deal stages that never lose the email thread." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: PipelinePage,
});

function PipelinePage() {
  const deals = useCrmDeals();
  const move = useMoveDeal();

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
      <SectionTitle
        title="Pipeline"
        hint="Thread stays the unit of work — open a deal and you land in the conversation, not a form."
      />

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
                <Column key={stage} stage={stage} count={items.length} total={money(total, currency)}>
                  {items.length === 0 ? (
                    <p className="ax-caption text-muted-foreground">Nothing here.</p>
                  ) : (
                    items.map((d) => (
                      <article key={d.id} className="rounded-xl border border-border bg-card p-ax-3">
                        <p className="text-[13px] font-semibold text-foreground">{d.title}</p>
                        <p className="ax-caption mt-0.5 text-muted-foreground">
                          {d.company ?? d.contact_email ?? "No company yet"}
                        </p>
                        <div className="mt-1.5 flex flex-wrap items-center gap-2">
                          <span className="text-[13px] font-semibold text-foreground">
                            {money(d.value, d.currency)}
                          </span>
                          {d.probability !== null && (
                            <Chip>{Math.round(d.probability * 100)}% likely</Chip>
                          )}
                          {d.stale_days !== null && d.stale_days > 7 && (
                            <Chip tone="warn">{d.stale_days}d quiet</Chip>
                          )}
                        </div>
                        {d.next_step && (
                          <p className="ax-caption mt-1.5 text-muted-foreground">
                            Next: {d.next_step}
                            {d.next_step_due ? ` · due ${d.next_step_due}` : ""}
                          </p>
                        )}
                        <div className="mt-ax-2 flex items-center gap-2">
                          {d.thread_id && (
                            <Link
                              to="/app/mail/$folder/$threadId"
                              params={{ folder: "inbox", threadId: d.thread_id }}
                              className="ax-press ax-caption inline-flex items-center gap-1 rounded-full border border-border px-2 py-0.5 font-semibold text-foreground"
                            >
                              <Mail className="size-3" aria-hidden="true" /> Thread
                            </Link>
                          )}
                          {stage !== "won" && stage !== "lost" && (
                            <button
                              type="button"
                              onClick={() => advance(d)}
                              disabled={move.isPending}
                              className="ax-press ax-caption inline-flex items-center gap-1 rounded-full border border-cyan-accent/50 px-2 py-0.5 font-semibold text-foreground"
                            >
                              Advance <ArrowRight className="size-3" aria-hidden="true" />
                            </button>
                          )}
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
  return (
    <section className="ax-plane flex w-72 shrink-0 flex-col rounded-2xl p-ax-3">
      <header className="mb-ax-3">
        <p className="text-[13px] font-bold text-foreground">{STAGE_LABEL[stage]}</p>
        <p className="ax-caption text-muted-foreground">
          {count} · {total}
        </p>
      </header>
      <div className="space-y-ax-2">{children}</div>
    </section>
  );
}
