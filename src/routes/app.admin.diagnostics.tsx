import { createFileRoute } from "@tanstack/react-router";
import { Gauge, Stethoscope } from "lucide-react";
import { useEffect, useRef } from "react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Verdict } from "@/components/app/premium/PremiumBits";
import { useDiagnostics, useRunDiagnostics } from "@/lib/admin-center";
import { celebrate, useFrameWatch, useMotionLedger } from "@/lib/experience";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/admin/diagnostics")({ component: DiagnosticsPage });

/** Feature 6 — Diagnostics proof pack: DNS/DKIM/SPF/DMARC/TLS/SMTP/IMAP + hash proof. */
function DiagnosticsPage() {
  const q = useDiagnostics();
  const run = useRunDiagnostics();
  const latest = q.data?.runs?.[0];
  const celebrated = useRef(false);

  // Ownership proven is a real finish: every probe green, nothing failing.
  useEffect(() => {
    if (!latest || celebrated.current) return;
    if (latest.failed === 0 && latest.passed > 0) {
      celebrated.current = true;
      celebrate("dns-green");
    }
  }, [latest]);

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

      <MotionMetrics />
    </div>
  );
}

const ms = (n: number) => `${Math.round(n)}ms`;

/**
 * Founder metrics — the motion contract measured on this device. Sits beside the
 * stack proof because jank is an outage you can see.
 */
function MotionMetrics() {
  const ledger = useMotionLedger();
  const frames = useFrameWatch();
  const worstRow = ledger.rows[0];

  return (
    <div className="mt-ax-6">
      <Section
        eyebrow={<><Gauge className="size-3.5" aria-hidden="true" /> Motion performance</>}
        title="Animation frame time, measured not felt"
        blurb="Real samples from this device: p95 against each named budget, plus every frame the browser blew past 50ms."
      >
        <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
          <Stat label="Samples" value={String(ledger.total)} />
          <Stat label="Over budget" value={String(ledger.failing)} hint="p95 past 1.5× budget" />
          <Stat label="Long frames" value={frames.watching ? String(frames.longFrames) : "—"} hint="stalls >50ms" />
          <Stat label="Worst stall" value={frames.worst_ms ? ms(frames.worst_ms) : "—"} />
        </div>

        {ledger.rows.length === 0 ? (
          <p className="ax-caption mt-ax-3 text-muted-foreground">
            No samples yet on this device — open a thread or switch folders, then come back.
          </p>
        ) : (
          <ul className="mt-ax-3 space-y-1.5">
            {ledger.rows.map((r) => (
              <Row key={`${r.name}-${r.budget}`}>
                <Verdict verdict={r.verdict}>{r.verdict}</Verdict>
                <span className="min-w-0 flex-1 truncate font-mono text-foreground">{r.name}</span>
                <span className="text-steel">
                  p50 {ms(r.p50)} · p95 {ms(r.p95)}
                </span>
                <span className="ml-auto text-muted-foreground">budget {ms(r.budget_ms)}</span>
              </Row>
            ))}
          </ul>
        )}

        {worstRow && worstRow.verdict !== "green" && (
          <p className="ax-caption mt-ax-3 text-muted-foreground">
            Jank detected on <span className="font-mono text-foreground">{worstRow.name}</span> — p95{" "}
            {ms(worstRow.p95)} against a {ms(worstRow.budget_ms)} budget.
          </p>
        )}
      </Section>
    </div>
  );
}
