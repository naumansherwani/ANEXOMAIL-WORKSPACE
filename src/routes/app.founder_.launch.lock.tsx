import { createFileRoute } from "@tanstack/react-router";
import { Lock } from "lucide-react";
import { useState } from "react";

import { Row, Section } from "@/components/app/analytics/AnalyticsBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { GateBadge, Note } from "@/components/app/release/ReleaseBits";
import { notify } from "@/lib/notify";
import { gateFrom, useLocks, useReleaseOverview, useSignLock } from "@/lib/release";

export const Route = createFileRoute("/app/founder_/launch/lock")({ component: LockPage });

/** Feature 3 — append-only version lock ledger. Red gate = button disabled. */
function LockPage() {
  const overview = useReleaseOverview();
  const locks = useLocks();
  const sign = useSignLock();
  const gate = gateFrom(overview.data);
  const [version, setVersion] = useState("1.0");
  const [notes, setNotes] = useState("");

  const canSign = gate === "ready";

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Lock className="size-3.5" aria-hidden="true" /> Version lock</>}
        title="Sign v1.0, freeze the product"
        blurb="Signing writes an append-only ledger row with the verdict it was signed against — who, when, and a signature hash that cannot be edited or deleted."
      >
        <GateBadge gate={gate} />

        <div className="mt-ax-4 grid gap-ax-3 sm:grid-cols-[8rem_1fr]">
          <label className="ax-plane rounded-xl px-ax-4 py-ax-3">
            <span className="ax-caption block text-muted-foreground">Version</span>
            <input
              value={version}
              onChange={(e) => setVersion(e.target.value)}
              className="mt-1 w-full bg-transparent text-[15px] font-bold text-foreground outline-none"
            />
          </label>
          <label className="ax-plane rounded-xl px-ax-4 py-ax-3">
            <span className="ax-caption block text-muted-foreground">Sign-off note</span>
            <input
              value={notes}
              onChange={(e) => setNotes(e.target.value)}
              placeholder="What this release covers"
              className="mt-1 w-full bg-transparent text-[13px] text-foreground outline-none placeholder:text-muted-foreground"
            />
          </label>
        </div>

        <button
          type="button"
          disabled={!canSign || sign.isPending}
          onClick={() =>
            sign.mutate(
              { version, ...(notes ? { notes } : {}) },
              {
                onSuccess: (l) => notify.done(`v${l.version} locked`, `Signature ${l.signature_hash.slice(0, 12)}…`),
                onError: (e) =>
                  notify.failed(e.status === 409 ? "This version is already locked" : "Lock failed", {
                    description: e.isNotImplemented ? "Waiting on POST /api/founder/release/lock." : e.message,
                  }),
              },
            )
          }
          className="ax-press mt-ax-4 rounded-lg bg-foreground px-3 py-2 text-[12px] font-semibold text-background disabled:opacity-40"
        >
          {sign.isPending ? "Signing…" : `Sign and freeze v${version}`}
        </button>
        {!canSign && (
          <Note>
            {gate === "locked"
              ? "Already frozen — a second lock on the same version is refused by the server."
              : "Signing is disabled until the QA suite is green and no blocker is open. Nothing here can override that from the browser."}
          </Note>
        )}

        <div className="mt-ax-6">
          <h3 className="ax-heading text-foreground">Lock ledger</h3>
          <div className="mt-ax-3">
            <CardBody
              query={{ data: locks.data, isPending: locks.isPending, error: locks.error ?? null, refetch: () => void locks.refetch() }}
              endpoint="/api/founder/release/lock"
              skeleton={<StatSkeleton rows={3} />}
            >
              {(d) =>
                d.locks.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">No version has been frozen yet.</p>
                ) : (
                  <ul className="space-y-1.5">
                    {d.locks.map((l) => (
                      <Row key={l.id}>
                        <span className="font-bold text-foreground">v{l.version}</span>
                        <span className="min-w-0 flex-1">
                          <span className="block text-foreground">{l.signed_by}</span>
                          <span className="block truncate font-mono text-steel">{l.signature_hash}</span>
                        </span>
                        <span className="text-steel">{l.verdict}</span>
                        <span className="ml-auto text-muted-foreground">
                          {new Date(l.frozen_at).toLocaleString("en-GB")}
                        </span>
                      </Row>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </div>
      </Section>
    </div>
  );
}
