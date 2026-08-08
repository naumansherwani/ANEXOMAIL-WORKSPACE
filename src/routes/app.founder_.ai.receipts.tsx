import { createFileRoute } from "@tanstack/react-router";
import { Receipt } from "lucide-react";

import { Chip, CreditsMeter, GuardrailCard, ReceiptCard } from "@/components/app/ai/AiBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import {
  useAiCredits,
  useAiGuardrailEvents,
  useAiReceipts,
  useDecideGuardrail,
} from "@/lib/ai-workspace";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/ai/receipts")({
  component: Receipts,
});

/** Answer receipts + credits ledger. Founder unlimited — cost visible, charge zero. */
function Receipts() {
  const receipts = useAiReceipts();
  const credits = useAiCredits();
  const guardrail = useAiGuardrailEvents();
  const decide = useDecideGuardrail();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <Receipt className="size-3.5" aria-hidden="true" /> Receipts
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Every answer, with its bill</h2>

        <div className="mt-ax-5">
          <CardBody
            query={{
              data: credits.data,
              isPending: credits.isPending,
              error: credits.error ?? null,
              refetch: () => void credits.refetch(),
            }}
            endpoint="/api/ai/credits"
            skeleton={<StatSkeleton rows={3} />}
          >
            {(c) => <CreditsMeter credits={c} />}
          </CardBody>
        </div>

        <section className="mt-ax-6">
          <h3 className="ax-heading text-foreground">Guardrail pauses</h3>
          <div className="mt-ax-3">
            <CardBody
              query={{
                data: guardrail.data,
                isPending: guardrail.isPending,
                error: guardrail.error ?? null,
                refetch: () => void guardrail.refetch(),
              }}
              endpoint="/api/ai/guardrail"
              skeleton={<StatSkeleton rows={3} />}
            >
              {(d) =>
                d.events.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">Nothing paused right now.</p>
                ) : (
                  <ul>
                    {d.events.map((e) => (
                      <li key={e.id}>
                        <GuardrailCard
                          event={e}
                          busy={decide.isPending}
                          onDecide={(decision) =>
                            decide.mutate(
                              { id: e.id, decision },
                              {
                                onSuccess: () =>
                                  notify.done(
                                    decision === "release" ? "Released" : "Refused",
                                    "The server recorded your decision.",
                                  ),
                                onError: (err) =>
                                  notify.failed(
                                    err.isNotImplemented ? "Guardrail not wired yet" : "Failed",
                                    { description: err.message },
                                  ),
                              },
                            )
                          }
                        />
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </section>

        <section className="mt-ax-6">
          <h3 className="ax-heading text-foreground">Answer receipts</h3>
          <div className="mt-ax-3">
            <CardBody
              query={{
                data: receipts.data,
                isPending: receipts.isPending,
                error: receipts.error ?? null,
                refetch: () => void receipts.refetch(),
              }}
              endpoint="/api/ai/receipts"
              skeleton={<StatSkeleton rows={6} />}
            >
              {(d) =>
                d.receipts.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">No answers billed yet.</p>
                ) : (
                  <>
                    <Chip>
                      total {d.currency === "GBP" ? "£" : `${d.currency} `}
                      {d.total_cost.toFixed(4)}
                    </Chip>
                    <ul className="mt-ax-3 space-y-ax-3">
                      {d.receipts.map((r) => (
                        <li key={r.id} className="ax-plane rounded-2xl p-ax-4">
                          <p className="ax-caption text-muted-foreground">
                            {relativeTime(r.created_at)}
                          </p>
                          <ReceiptCard receipt={r} />
                        </li>
                      ))}
                    </ul>
                  </>
                )
              }
            </CardBody>
          </div>
        </section>
      </div>
    </div>
  );
}