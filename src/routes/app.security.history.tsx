import { createFileRoute } from "@tanstack/react-router";
import { History, Plane } from "lucide-react";
import { useState } from "react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { notify } from "@/lib/notify";
import { useDisownLogin, useLoginHistory } from "@/lib/security-platform";

export const Route = createFileRoute("/app/security/history")({ component: HistoryPage });

const FILTERS = ["all", "success", "failed", "blocked", "challenged"] as const;

/**
 * Feature 5 — Login replay: har login ka insaani risk story.
 * Feature 2 — Impossible travel: server pehle freeze karta hai, poochta baad mein.
 */
function HistoryPage() {
  const [outcome, setOutcome] = useState<string>("all");
  const q = useLoginHistory(outcome);
  const disown = useDisownLogin();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><History className="size-3.5" aria-hidden="true" /> Login replay</>}
        title="Every sign-in, told as a story"
        blurb="Not a raw log. Each attempt explains where it came from, why it looked safe or not, and lets you say “this wasn’t me” in one click."
      >
        <div className="mb-ax-4 flex flex-wrap gap-1.5">
          {FILTERS.map((f) => (
            <button
              key={f}
              type="button"
              onClick={() => setOutcome(f)}
              className={
                f === outcome
                  ? "ax-press rounded-lg bg-foreground px-2.5 py-1.5 text-[12px] font-semibold text-background"
                  : "ax-press rounded-lg bg-secondary px-2.5 py-1.5 text-[12px] font-semibold text-muted-foreground"
              }
            >
              {f}
            </button>
          ))}
        </div>

        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/security/history"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <ul className="space-y-1.5">
                {d.events.map((e) => (
                  <Row key={e.id}>
                    <span className="text-steel">{new Date(e.at).toLocaleString("en-GB")}</span>
                    <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{e.email}</span>
                    <span className="text-muted-foreground">{e.method}</span>
                    <span
                      className={
                        e.outcome === "success"
                          ? "text-emerald-400"
                          : e.outcome === "failed" || e.outcome === "blocked"
                            ? "text-red-400"
                            : "text-amber-400"
                      }
                    >
                      {e.outcome}
                    </span>
                    <span className="min-w-0 flex-1 truncate text-muted-foreground">
                      {e.story ??
                        [[e.city, e.country].filter(Boolean).join(", "), e.device_label, e.ip]
                          .filter(Boolean)
                          .join(" · ")}
                    </span>
                    <span className="text-steel">risk {e.risk_score}</span>
                    {e.disowned ? (
                      <span className="ml-auto text-red-400">disowned</span>
                    ) : (
                      <Button
                        size="sm"
                        variant="secondary"
                        className="ml-auto"
                        disabled={disown.isPending}
                        onClick={() =>
                          disown.mutate(
                            { event_id: e.id },
                            {
                              onSuccess: (r) =>
                                notify.done("Reported", `${r.sessions_killed} sessions ended and the device was blocked.`),
                              onError: (err) =>
                                notify.failed(err.isNotImplemented ? "Not wired yet" : "Could not report", {
                                  description: err.message,
                                }),
                            },
                          )
                        }
                      >
                        Wasn’t me
                      </Button>
                    )}
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 flex items-center gap-2 text-foreground">
                <Plane className="size-3.5" aria-hidden="true" /> Impossible travel and anomalies
              </h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.anomalies.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">Nothing suspicious recorded.</p>
                ) : (
                  d.anomalies.map((a) => (
                    <Row key={a.id}>
                      <span className="text-steel">{new Date(a.created_at).toLocaleString("en-GB")}</span>
                      <span className="font-semibold text-foreground">{a.kind.replace(/_/g, " ")}</span>
                      <span className="min-w-0 flex-1 truncate text-muted-foreground">{a.detail}</span>
                      {a.km !== null && a.minutes !== null && (
                        <span className="text-muted-foreground">
                          {Math.round(a.km)} km in {a.minutes} min
                        </span>
                      )}
                      <span className={a.state === "frozen" ? "ml-auto text-red-400" : "ml-auto text-amber-400"}>
                        {a.state}
                      </span>
                    </Row>
                  ))
                )}
              </ul>
            </>
          )}
        </CardBody>
      </Section>
    </div>
  );
}