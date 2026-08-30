import { createFileRoute } from "@tanstack/react-router";
import { Check, Clock3, TrendingUp } from "lucide-react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import {
  gbp,
  useFounderReplyQueue,
  useMarkFounderReplySent,
  useRevenueTruth,
} from "@/lib/billing-platform";

export const Route = createFileRoute("/app/founder_/billing")({
  component: FounderRevenue,
});

/** Phase 21 — founder view: revenue truth, no vanity numbers. */
function FounderRevenue() {
  const revenue = useRevenueTruth();
  const replyQueue = useFounderReplyQueue();
  const markReplied = useMarkFounderReplySent();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <TrendingUp className="size-3.5" aria-hidden="true" /> Revenue truth
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">What the business actually earns</h2>

        <div className="mt-ax-5">
          <CardBody
            query={{
              data: revenue.data,
              isPending: revenue.isPending,
              error: revenue.error ?? null,
              refetch: () => void revenue.refetch(),
            }}
            endpoint="/api/founder/billing/revenue"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(r) => (
              <>
                <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                  <Stat label="MRR" value={gbp(r.mrr)} />
                  <Stat label="ARR" value={gbp(r.arr)} />
                  <Stat label="Paying tenants" value={String(r.paying_tenants)} />
                  <Stat label="Unpaid" value={gbp(r.unpaid_total)} />
                  <Stat label="Trialing" value={String(r.trialing)} />
                  <Stat label="Past due" value={String(r.past_due)} />
                  <Stat label="Churn 30d" value={String(r.churn_30d)} />
                  <Stat label="Currency" value={r.currency} />
                </div>

                <h3 className="ax-heading mt-ax-6 text-foreground">By plan</h3>
                <ul className="mt-ax-3 space-y-1.5">
                  {r.by_plan.map((p) => (
                    <li
                      key={p.plan}
                      className="ax-plane flex items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                    >
                      <span className="w-24 font-semibold text-foreground">{p.plan}</span>
                      <span className="text-muted-foreground">{p.tenants} tenants</span>
                      <span className="ml-auto text-foreground">{gbp(p.mrr)}</span>
                    </li>
                  ))}
                </ul>
              </>
            )}
          </CardBody>
        </div>

        <div className="mt-ax-6">
          <p className="ax-eyebrow flex items-center gap-2">
            <Clock3 className="size-3.5" aria-hidden="true" /> Human reply clock
          </p>
          <h3 className="ax-heading mt-1 text-foreground">Who needs your reply next</h3>
          <p className="mt-1 text-[12px] text-muted-foreground">
            Basic 72 hours · Pro 48 hours · Business 24 hours
          </p>

          <div className="mt-ax-3">
            <CardBody
              query={{
                data: replyQueue.data,
                isPending: replyQueue.isPending,
                error: replyQueue.error ?? null,
                refetch: () => void replyQueue.refetch(),
              }}
              endpoint="/api/founder/support/replies"
              skeleton={<StatSkeleton rows={4} />}
            >
              {({ replies }) => {
                const awaiting = replies.filter((reply) => reply.state === "awaiting_reply");
                if (awaiting.length === 0) {
                  return (
                    <div className="ax-plane rounded-2xl p-ax-5 text-sm text-muted-foreground">
                      No customer is waiting for a human reply.
                    </div>
                  );
                }
                return (
                  <ul className="space-y-2">
                    {awaiting.map((reply) => (
                      <li
                        key={reply.id}
                        className="ax-plane flex flex-col gap-3 rounded-2xl p-ax-4 sm:flex-row sm:items-center"
                      >
                        <div className="min-w-0 flex-1">
                          <div className="flex flex-wrap items-center gap-2">
                            <span className="text-sm font-semibold text-foreground">
                              {reply.customer_email}
                            </span>
                            <span className="rounded-full bg-secondary px-2 py-0.5 text-[10px] font-semibold uppercase text-muted-foreground">
                              {reply.plan}
                            </span>
                          </div>
                          <p className="mt-1 truncate text-[12px] text-muted-foreground">
                            {reply.subject || "No subject"}
                          </p>
                        </div>
                        <div className="flex items-center gap-3">
                          <span
                            className={`text-[12px] font-semibold ${reply.overdue ? "text-destructive" : "text-foreground"}`}
                          >
                            {reply.overdue ? "Overdue" : formatRemaining(reply.remaining_minutes)}
                          </span>
                          <Button
                            type="button"
                            title="Mark reply sent"
                            aria-label={`Mark reply to ${reply.customer_email} as sent`}
                            disabled={markReplied.isPending}
                            onClick={() => markReplied.mutate(reply.id)}
                            variant="outline"
                            size="icon"
                            className="rounded-full"
                          >
                            <Check className="size-4" aria-hidden="true" />
                          </Button>
                        </div>
                      </li>
                    ))}
                  </ul>
                );
              }}
            </CardBody>
          </div>
        </div>
      </div>
    </div>
  );
}

function formatRemaining(minutes: number) {
  const hours = Math.floor(minutes / 60);
  const mins = minutes % 60;
  return hours > 0 ? `${hours}h ${mins}m left` : `${mins}m left`;
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-1 text-[19px] font-bold text-foreground">{value}</p>
    </div>
  );
}
