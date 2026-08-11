import { createFileRoute } from "@tanstack/react-router";
import { ShieldCheck } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useSecurityDashboard } from "@/lib/security-platform";

export const Route = createFileRoute("/app/security/")({ component: SecurityOverviewPage });

/** Overview — score asli checks se, ledger hash-chained, advice actionable. */
function SecurityOverviewPage() {
  const q = useSecurityDashboard();
  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><ShieldCheck className="size-3.5" aria-hidden="true" /> Security posture</>}
        title="Proof, not promises"
        blurb="One score built from real device, session, encryption and delivery checks — with a tamper-evident ledger underneath."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/security/dashboard"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                <Stat label="Security score" value={`${d.score}/100`} hint="recomputed on every check" />
                <Stat label="Trusted devices" value={String(d.devices_trusted)} hint={`${d.devices_pending} waiting`} />
                <Stat label="Live sessions" value={String(d.sessions_live)} hint="killable in one click" />
                <Stat label="Failed logins" value={String(d.failed_logins_24h)} hint="last 24h" />
              </div>

              <div className="mt-ax-4 grid gap-ax-3 sm:grid-cols-3">
                <Stat label="Open anomalies" value={String(d.open_anomalies)} hint="frozen first, asked later" />
                <Stat label="Encryption" value={d.encryption_ok ? "Verified" : "Needs attention"} />
                <Stat label="Ownership" value={d.ownership_ok ? "Signed" : "Not proven"} />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">Fix this next</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.advice.map((a, i) => (
                  <Row key={i}>
                    <span className="min-w-0 flex-1 font-semibold text-foreground">{a.title}</span>
                    <span className="min-w-0 flex-1 text-muted-foreground">{a.detail}</span>
                    <span
                      className={
                        a.severity === "high"
                          ? "ml-auto text-red-400"
                          : a.severity === "medium"
                            ? "ml-auto text-amber-400"
                            : "ml-auto text-steel"
                      }
                    >
                      {a.severity}
                    </span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">Tamper-evident ledger</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.ledger.map((e) => (
                  <Row key={e.hash}>
                    <span className="text-steel">{new Date(e.at).toLocaleString("en-GB")}</span>
                    <span className="min-w-0 flex-1 truncate text-foreground">{e.action.replace(/_/g, " ")}</span>
                    <span className="text-muted-foreground">{e.actor}</span>
                    <code className="ml-auto rounded bg-secondary px-1 py-0.5 text-[11px] text-steel">
                      {e.hash.slice(0, 12)}
                    </code>
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