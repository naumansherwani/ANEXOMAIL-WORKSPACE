import { createFileRoute } from "@tanstack/react-router";
import { Stethoscope } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useDiagnostics, useRunDiagnostics } from "@/lib/admin-center";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/admin/diagnostics")({ component: DiagnosticsPage });

/** Feature 6 — Diagnostics proof pack: DNS/DKIM/SPF/DMARC/TLS/SMTP/IMAP + hash proof. */
function DiagnosticsPage() {
  const q = useDiagnostics();
  const run = useRunDiagnostics();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Stethoscope className="size-3.5" aria-hidden="true" /> Diagnostics proof pack</>}
        title="One click, whole stack, signed evidence"
        blurb="DNS, DKIM, SPF, DMARC, TLS, SMTP and IMAP checked end to end — each run hashed so the result can be proven later."
      >
        <button
          type="button"
          onClick={() => run.mutate({ scope: "all" })}
          disabled={run.isPending}
          className="ax-press rounded-lg bg-foreground px-3 py-2 text-[12px] font-semibold text-background disabled:opacity-50"
        >
          {run.isPending ? "Running probes…" : "Run full diagnostics"}
        </button>

        <div className="mt-ax-5">
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/admin/diagnostics"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) => (
              <ul className="space-y-ax-4">
                {d.runs.map((r) => (
                  <li key={r.id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="grid gap-ax-3 sm:grid-cols-3">
                      <Stat label="Passed" value={String(r.passed)} />
                      <Stat label="Failed" value={String(r.failed)} />
                      <Stat
                        label="Proof"
                        value={r.proof_hash ? `${r.proof_hash.slice(0, 10)}…` : "—"}
                        hint={r.export_ready ? "exportable" : "in progress"}
                      />
                    </div>
                    <ul className="mt-ax-3 space-y-1.5">
                      {r.probes.map((p, i) => (
                        <Row key={`${p.probe}-${i}`}>
                          <span
                            className={cn(
                              "font-bold",
                              p.result === "pass" ? "text-emerald-400" : p.result === "fail" ? "text-red-400" : "text-steel",
                            )}
                          >
                            {p.result}
                          </span>
                          <span className="min-w-0 flex-1">
                            <span className="block font-semibold text-foreground">
                              {p.probe} {p.target ? `· ${p.target}` : ""}
                            </span>
                            <span className="block truncate text-steel">
                              {p.result === "fail" ? (p.fix ?? p.expected ?? "") : (p.observed ?? "")}
                            </span>
                          </span>
                          <span className="ml-auto text-muted-foreground">{p.ms}ms</span>
                        </Row>
                      ))}
                    </ul>
                  </li>
                ))}
              </ul>
            )}
          </CardBody>
        </div>
      </Section>
    </div>
  );
}
