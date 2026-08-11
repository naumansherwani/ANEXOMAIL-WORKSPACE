import { createFileRoute } from "@tanstack/react-router";
import { KeyRound, Lock } from "lucide-react";

import { Row, Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { notify } from "@/lib/notify";
import { useEncryption, useRotateKeys } from "@/lib/security-platform";

export const Route = createFileRoute("/app/security/encryption")({ component: EncryptionPage });

/** Feature 4 — Encryption ledger: har surface aur har hop, hashed proof ke saath. */
function EncryptionPage() {
  const q = useEncryption();
  const rotate = useRotateKeys();

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Lock className="size-3.5" aria-hidden="true" /> Encryption ledger</>}
        title="Encrypted is a fact you can check"
        blurb="Every surface at rest and every hop in transit, named with its algorithm — plus a hashed entry each time a key moves."
      >
        <CardBody
          query={{ data: q.data, isPending: q.isPending, error: q.error ?? null, refetch: () => void q.refetch() }}
          endpoint="/api/security/encryption"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(d) => (
            <>
              <div className="grid gap-ax-3 sm:grid-cols-2">
                <Stat
                  label="Keys last rotated"
                  value={d.key_rotated_at ? new Date(d.key_rotated_at).toLocaleDateString("en-GB") : "Never"}
                />
                <Stat
                  label="Next rotation"
                  value={d.next_rotation_at ? new Date(d.next_rotation_at).toLocaleDateString("en-GB") : "Not scheduled"}
                />
              </div>

              <h3 className="ax-heading mt-ax-6 text-foreground">At rest</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.at_rest.map((r) => (
                  <Row key={r.surface}>
                    <span className="min-w-0 flex-1 font-semibold text-foreground">{r.surface}</span>
                    <code className="rounded bg-secondary px-1 py-0.5 text-[11px] text-steel">{r.algorithm}</code>
                    <span className="min-w-0 flex-1 truncate text-muted-foreground">{r.detail ?? ""}</span>
                    <span className={r.state === "on" ? "ml-auto text-emerald-400" : "ml-auto text-amber-400"}>
                      {r.state}
                    </span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 text-foreground">In transit</h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.in_transit.map((r) => (
                  <Row key={r.hop}>
                    <span className="min-w-0 flex-1 font-semibold text-foreground">{r.hop}</span>
                    <code className="rounded bg-secondary px-1 py-0.5 text-[11px] text-steel">{r.protocol}</code>
                    <span className="min-w-0 flex-1 truncate text-muted-foreground">{r.cipher ?? ""}</span>
                    <span className={r.state === "on" ? "ml-auto text-emerald-400" : "ml-auto text-amber-400"}>
                      {r.state}
                    </span>
                  </Row>
                ))}
              </ul>

              <h3 className="ax-heading mt-ax-6 flex items-center gap-2 text-foreground">
                <KeyRound className="size-3.5" aria-hidden="true" /> Key ledger
              </h3>
              <ul className="mt-ax-3 space-y-1.5">
                {d.ledger.map((e) => (
                  <Row key={e.hash}>
                    <span className="text-steel">{new Date(e.at).toLocaleString("en-GB")}</span>
                    <span className="min-w-0 flex-1 truncate text-foreground">{e.action.replace(/_/g, " ")}</span>
                    <span className="text-muted-foreground">{e.surface}</span>
                    <code className="ml-auto rounded bg-secondary px-1 py-0.5 text-[11px] text-steel">
                      {e.hash.slice(0, 12)}
                    </code>
                  </Row>
                ))}
              </ul>

              <Button
                className="mt-ax-5"
                variant="secondary"
                disabled={rotate.isPending}
                onClick={() =>
                  rotate.mutate(
                    {},
                    {
                      onSuccess: () => notify.done("Keys rotated", "Old keys are retired and the ledger has the proof."),
                      onError: (e) =>
                        notify.failed(e.isNotImplemented ? "Rotation not wired yet" : "Could not rotate", {
                          description: e.message,
                        }),
                    },
                  )
                }
              >
                {rotate.isPending ? "Rotating…" : "Rotate keys now"}
              </Button>
            </>
          )}
        </CardBody>
      </Section>
    </div>
  );
}