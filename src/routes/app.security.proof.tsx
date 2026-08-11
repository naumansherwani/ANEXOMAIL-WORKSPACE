import { createFileRoute } from "@tanstack/react-router";
import { Stamp } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { notify } from "@/lib/notify";
import { useOwnershipProofs, useRunOwnershipProof } from "@/lib/security-platform";

export const Route = createFileRoute("/app/security/proof")({ component: ProofPage });

/** Feature 3 — Ownership proof: DKIM/SPF/DMARC/TLS live probe, hashed, exportable. */
function ProofPage() {
  const q = useOwnershipProofs();
  const run = useRunOwnershipProof();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Stamp className="size-3.5" aria-hidden="true" /> Ownership proof</>}
        title="Prove the domain is yours, on paper"
        blurb="A live probe of DKIM, SPF, DMARC and TLS, hashed into one signed pack you can hand to a client, an auditor or a bank."
      >
        <Button
          variant="secondary"
          disabled={run.isPending}
          onClick={() =>
            run.mutate(
              {},
              {
                onSuccess: () => notify.done("Proof generated", "Hash recorded — the pack is ready to export."),
                onError: (e) =>
                  notify.failed(e.isNotImplemented ? "Proof not wired yet" : "Could not run proof", {
                    description: e.message,
                  }),
              },
            )
          }
        >
          {run.isPending ? "Probing…" : "Run ownership proof"}
        </Button>

        <div className="mt-ax-5">
          <CardBody
            query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
            endpoint="/api/security/proof"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(d) =>
              d.proofs.length === 0 ? (
                <p className="ax-caption text-muted-foreground">No proof pack generated yet.</p>
              ) : (
                <ul className="space-y-ax-4">
                  {d.proofs.map((p) => (
                    <li key={p.id} className="ax-plane rounded-2xl p-ax-4">
                      <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                        <span className="font-semibold text-foreground">{p.domain}</span>
                        <span className="text-steel">{new Date(p.ran_at).toLocaleString("en-GB")}</span>
                        <span className="text-emerald-400">{p.passed} passed</span>
                        {p.failed > 0 && <span className="text-red-400">{p.failed} failed</span>}
                        {p.proof_hash && (
                          <code className="ml-auto rounded bg-secondary px-1 py-0.5 text-[11px] text-steel">
                            {p.proof_hash.slice(0, 16)}
                          </code>
                        )}
                      </div>
                      <ul className="mt-ax-3 space-y-1.5">
                        {p.checks.map((c) => (
                          <Row key={c.check}>
                            <span className="min-w-0 flex-1 font-semibold text-foreground">{c.check}</span>
                            <span className="min-w-0 flex-1 truncate text-muted-foreground">{c.observed ?? "—"}</span>
                            {c.fix && <span className="text-amber-400">{c.fix}</span>}
                            <span
                              className={
                                c.result === "pass" ? "ml-auto text-emerald-400" : c.result === "fail" ? "ml-auto text-red-400" : "ml-auto text-steel"
                              }
                            >
                              {c.result}
                            </span>
                          </Row>
                        ))}
                      </ul>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </div>
      </Section>
    </div>
  );
}