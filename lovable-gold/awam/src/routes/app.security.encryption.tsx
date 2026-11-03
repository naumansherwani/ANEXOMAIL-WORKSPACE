import { createFileRoute } from "@tanstack/react-router";
import { KeyRound, Lock } from "lucide-react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { useEncryption } from "@/lib/security-platform";

export const Route = createFileRoute("/app/security/encryption")({
  head: () => ({
    meta: [
      { title: "Security · Encryption — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Security · Encryption in ANEXOMAIL Workspace — real readings from your own workspace, with proof of where every number came from.",
      },
      { property: "og:title", content: "Security · Encryption — ANEXOMAIL Workspace" },
      { property: "og:description", content: "Security · Encryption in ANEXOMAIL Workspace." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: EncryptionPage,
});

/** Feature 4 — Encryption ledger: har surface aur har hop, hashed proof ke saath. */
function EncryptionPage() {
  const q = useEncryption();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={
          <>
            <Lock className="size-3.5" aria-hidden="true" /> Encryption ledger
          </>
        }
        title="Encrypted is a fact you can check"
        blurb="Every surface at rest and every hop in transit, named with its algorithm — each one checked live, not promised."
      >
        <CardBody
          query={{
            data: q.data,
            isPending: q.isPending,
            error: q.error ?? null,
            refetch: () => void q.refetch(),
          }}
          endpoint="/api/security/encryption"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <p className="ax-caption text-muted-foreground">
                {d.source
                  ? "Checked live: this server opens a real encrypted connection to each door and verifies the certificate against public roots (refreshed every 10 minutes)."
                  : "Readings recorded for this workspace."}
              </p>

              <h3 className="ax-heading mt-ax-6 text-foreground">At rest</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.at_rest.map((r) => (
                  <Row key={r.surface}>
                    <span className="min-w-0 flex-1 font-semibold text-foreground">
                      {r.surface}
                    </span>
                    <code className="rounded bg-secondary px-1 py-0.5 text-[11px] text-steel">
                      {r.algorithm}
                    </code>
                    <span className="min-w-0 flex-1 truncate text-muted-foreground">
                      {r.detail ?? ""}
                    </span>
                    <span
                      className={
                        r.state === "on" ? "ml-auto text-emerald-400" : "ml-auto text-amber-400"
                      }
                    >
                      {r.state}
                    </span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">In transit</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.in_transit.length === 0 && (
                  <li className="ax-caption text-muted-foreground">No live reading yet.</li>
                )}
                {d.in_transit.map((r) => (
                  <Row key={r.hop}>
                    <span className="min-w-0 flex-1 font-semibold text-foreground">{r.hop}</span>
                    <code className="rounded bg-secondary px-1 py-0.5 text-[11px] text-steel">
                      {r.protocol}
                    </code>
                    <span
                      className="min-w-0 flex-1 truncate text-muted-foreground"
                      title={r.detail ?? r.cipher ?? ""}
                    >
                      {r.state === "on" ? (r.cipher ?? r.detail ?? "") : (r.detail ?? "")}
                    </span>
                    <span
                      className={
                        r.state === "on" ? "ml-auto text-emerald-400" : "ml-auto text-amber-400"
                      }
                    >
                      {r.state}
                    </span>
                  </Row>
                ))}
              </ul>

              <p className="ax-caption mt-ax-5 flex items-start gap-2 text-muted-foreground">
                <KeyRound className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
                Storage keys are held and rotated by the database provider. We do not show a
                "rotate" button that would change nothing.
              </p>
            </>
          )}
        </CardBody>
      </Section>
    </div>
  );
}
