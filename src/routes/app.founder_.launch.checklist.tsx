import { createFileRoute } from "@tanstack/react-router";
import { ClipboardCheck } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Verdict } from "@/components/app/premium/PremiumBits";
import { Bar } from "@/components/app/release/ReleaseBits";
import { notify } from "@/lib/notify";
import { useChecklist, useChecklistUpdate, type ChecklistItem } from "@/lib/release";

export const Route = createFileRoute("/app/founder_/launch/checklist")({ component: ChecklistPage });

const NEXT: Record<ChecklistItem["state"], ChecklistItem["state"]> = {
  open: "done",
  done: "blocker",
  blocker: "open",
};

/** Production checklist — a blocker here holds the gate shut, same as a red check. */
function ChecklistPage() {
  const q = useChecklist();
  const update = useChecklistUpdate();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><ClipboardCheck className="size-3.5" aria-hidden="true" /> Production checklist</>}
        title="Ticked by hand, enforced by code"
        blurb="Tap a row to cycle open → done → blocker. Anything marked blocker keeps the release gate closed."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/founder/release/checklist"
          skeleton={<StatSkeleton rows={6} />}
        >
          {(d) => {
            const done = d.items.filter((i) => i.state === "done").length;
            const areas = [...new Set(d.items.map((i) => i.area))];
            return (
              <>
                <Bar label={`${done} of ${d.items.length} complete`} value={done} max={d.items.length} tone="bg-success" />
                {areas.map((area) => (
                  <section key={area} className="mt-ax-5">
                    <h3 className="ax-heading text-foreground">{area}</h3>
                    <ul className="mt-ax-3 space-y-1.5">
                      {d.items
                        .filter((i) => i.area === area)
                        .map((i) => (
                          <Row key={i.id}>
                            <button
                              type="button"
                              onClick={() =>
                                update.mutate(
                                  { id: i.id, state: NEXT[i.state] },
                                  {
                                    onSuccess: () => notify.done(`${i.label} → ${NEXT[i.state]}`),
                                    onError: (e) =>
                                      notify.failed("Could not update", {
                                        description: e.isNotImplemented
                                          ? "Waiting on POST /api/founder/release/checklist/item."
                                          : e.message,
                                      }),
                                  },
                                )
                              }
                              className="ax-press"
                              aria-label={`Cycle ${i.label}`}
                            >
                              <Verdict verdict={i.state === "done" ? "green" : i.state === "blocker" ? "fail" : "watch"}>
                                {i.state}
                              </Verdict>
                            </button>
                            <span className="min-w-0 flex-1">
                              <span className="block font-semibold text-foreground">{i.label}</span>
                              {i.detail && <span className="block truncate text-steel">{i.detail}</span>}
                            </span>
                            <span className="ml-auto text-muted-foreground">{i.owner ?? "unassigned"}</span>
                          </Row>
                        ))}
                    </ul>
                  </section>
                ))}
              </>
            );
          }}
        </CardBody>
      </Section>
    </div>
  );
}
