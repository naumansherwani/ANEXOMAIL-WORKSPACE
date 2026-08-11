import { createFileRoute } from "@tanstack/react-router";
import { HeartPulse, Wrench } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { STATUS_TONE, useHeal, useHealth } from "@/lib/admin-center";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/admin/health")({ component: HealthPage });

/** Feature 1 — Self-healing health: check karta hai, khud theek karta hai, proof rakhta hai. */
function HealthPage() {
  const q = useHealth();
  const heal = useHeal();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><HeartPulse className="size-3.5" aria-hidden="true" /> Self-healing health</>}
        title="It fixes itself, then shows you the receipt"
        blurb="Every check knows its own remedy. Where a fix is safe, one click applies it and the proof is stored."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/admin/health"
          skeleton={<StatSkeleton rows={6} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-3">
                <Stat label="Health score" value={`${d.score}/100`} />
                <Stat label="Self-heals (24h)" value={String(d.self_heals_24h)} hint="no human needed" />
                <Stat
                  label="Last run"
                  value={d.last_run ? new Date(d.last_run).toLocaleTimeString("en-GB") : "—"}
                />
              </div>

              <ul className="mt-ax-5 space-y-1.5">
                {d.checks.map((c) => (
                  <Row key={c.key}>
                    <span className={cn("font-bold", STATUS_TONE[c.status])}>{c.status.toUpperCase()}</span>
                    <span className="min-w-0 flex-1">
                      <span className="block font-semibold text-foreground">{c.label}</span>
                      <span className="block text-steel">{c.detail ?? c.remedy ?? ""}</span>
                    </span>
                    {c.can_self_heal && c.status !== "ok" && (
                      <button
                        type="button"
                        onClick={() => heal.mutate({ key: c.key })}
                        disabled={heal.isPending}
                        className="ax-press ml-auto flex items-center gap-1.5 rounded-lg bg-secondary px-2.5 py-1.5 text-[12px] font-semibold text-foreground disabled:opacity-50"
                      >
                        <Wrench className="size-3.5" aria-hidden="true" /> Heal now
                      </button>
                    )}
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">Proof log</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.recent.map((r, i) => (
                  <Row key={`${r.key}-${i}`}>
                    <span className="text-steel">{new Date(r.created_at).toLocaleString("en-GB")}</span>
                    <span className="min-w-0 flex-1 truncate text-foreground">{r.key}</span>
                    <span className="text-muted-foreground">{r.action}</span>
                    <span className="ml-auto text-steel">{r.outcome}</span>
                  </Row>
                ))}
              </ul>
            </>
          )}
        </CardBody>
      </Section>
    </div>
  );
}
