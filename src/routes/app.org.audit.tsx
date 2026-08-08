import { createFileRoute } from "@tanstack/react-router";
import { Link2, ShieldCheck } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Chip, SectionTitle } from "@/components/app/org/OrgBits";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { useOrgLedger, useVerifyLedger, type LedgerVerdict } from "@/lib/org";

export const Route = createFileRoute("/app/org/audit")({
  head: () => ({
    meta: [
      { title: "Audit ledger — ANEXOMAIL Organization Center" },
      {
        name: "description",
        content:
          "An append-only, hash-chained record of every action in your organisation — verify the chain yourself in one click.",
      },
      { property: "og:title", content: "Audit ledger — ANEXOMAIL Organization Center" },
      { property: "og:description", content: "Hash-chained, append-only audit you can verify yourself." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AuditPage,
});

function AuditPage() {
  const ledger = useOrgLedger();
  const verify = useVerifyLedger();
  const [verdict, setVerdict] = useState<LedgerVerdict | null>(null);

  const runVerify = () =>
    verify.mutate(
      {},
      {
        onSuccess: (v) => {
          setVerdict(v);
          if (v.ok) notify.done("Chain intact", `${v.checked} entries verified.`);
          else notify.failed("Chain broken", { description: `First break at entry #${v.broken_at_seq}.` });
        },
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Verify not wired yet" : "Could not verify", {
            description: e.message,
          }),
      },
    );

  return (
    <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
      <div className="flex flex-wrap items-end gap-3">
        <div className="min-w-0 flex-1">
          <SectionTitle
            title="Audit ledger"
            hint="Append-only. Each entry carries the hash of the one before it, so nobody — not even the owner — can rewrite history."
          />
        </div>
        <Button variant="secondary" disabled={verify.isPending} onClick={runVerify}>
          <ShieldCheck className="size-4" aria-hidden="true" /> Verify chain
        </Button>
      </div>

      {verdict && (
        <div
          className={`mb-ax-4 rounded-2xl border p-ax-4 ${
            verdict.ok ? "border-success/40 bg-success/5" : "border-danger/40 bg-danger/5"
          }`}
        >
          <p className="text-[13px] font-bold text-foreground">
            {verdict.ok ? "Chain intact" : `Chain broken at entry #${verdict.broken_at_seq}`}
          </p>
          <p className="ax-caption mt-1 text-muted-foreground">
            {verdict.checked} entries checked · verified {relativeTime(verdict.verified_at)}
          </p>
        </div>
      )}

      <CardBody
        query={{
          data: ledger.data,
          isPending: ledger.isPending,
          error: ledger.error ?? null,
          refetch: () => void ledger.refetch(),
        }}
        endpoint="/api/org/audit"
        skeleton={<StatSkeleton rows={8} />}
      >
        {(data) =>
          data.entries.length === 0 ? (
            <p className="ax-caption text-muted-foreground">Nothing recorded yet.</p>
          ) : (
            <ul className="space-y-1.5">
              {data.entries.map((e) => (
                <li key={e.id} className="rounded-xl border border-border px-ax-3 py-ax-2">
                  <div className="flex flex-wrap items-center gap-2">
                    <Chip>#{e.seq}</Chip>
                    <span className="text-[13px] font-semibold text-foreground">{e.action}</span>
                    <span className="ax-caption text-muted-foreground">
                      {e.actor}
                      {e.target ? ` → ${e.target}` : ""}
                      {e.ip ? ` · ${e.ip}` : ""}
                    </span>
                    <span className="ax-caption ml-auto text-muted-foreground">
                      {relativeTime(e.created_at)}
                    </span>
                  </div>
                  <p className="ax-caption mt-1 flex items-center gap-1.5 truncate font-mono text-muted-foreground">
                    <Link2 className="size-3 shrink-0" aria-hidden="true" />
                    {e.hash.slice(0, 16)}… ← {e.prev_hash ? `${e.prev_hash.slice(0, 16)}…` : "genesis"}
                  </p>
                </li>
              ))}
            </ul>
          )
        }
      </CardBody>
    </div>
  );
}