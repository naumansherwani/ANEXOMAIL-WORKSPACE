import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { AlertTriangle, Banknote, CalendarClock, Database, ShieldCheck } from "lucide-react";

import {
  gbp,
  stateLabel,
  useMoveInArm,
  useMoveInCockpit,
  useMoveInDeal,
  useMoveInRollback,
  useMoveInRunbookStep,
  useMoveInTransition,
  RESULT_TONE,
} from "@/lib/movein";
import { relativeTime } from "@/lib/mail";

export const Route = createFileRoute("/app/founder_/movein")({
  component: MoveInCockpit,
  head: () => ({
    meta: [
      { title: "Move-In Cockpit · ANEXOMAIL" },
      { name: "description", content: "Managed Move-In operations, cash clock and cut-over control." },
      { property: "og:title", content: "Move-In Cockpit · ANEXOMAIL" },
      { property: "og:description", content: "Every move-in, every payment leg, every proof — one screen." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
});

function MoveInCockpit() {
  const cockpit = useMoveInCockpit();
  const [dealId, setDealId] = useState<string | null>(null);
  const deal = useMoveInDeal(dealId);
  const transition = useMoveInTransition();
  const arm = useMoveInArm();
  const step = useMoveInRunbookStep();
  const rollback = useMoveInRollback();

  const c = cockpit.data;
  const bundle = deal.data?.deal;

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <div className="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs text-muted-foreground">
          <Database className="h-3.5 w-3.5" /> Every gate lives in the database — no shortcut, no guesswork
        </div>
        <h2 className="text-xl font-semibold tracking-tight">Move-In cockpit</h2>
        <p className="text-sm text-muted-foreground">
          Managed Move-In ka poora operation: cash clock, capacity, mailbox ledger, DNS proof, cut-over
          arm/rollback. Sab kuch Supabase se, kuch bhi hard-coded nahi.
        </p>
      </header>

      {cockpit.isError && (
        <p className="text-sm text-muted-foreground">
          Move-In backend abhi reachable nahi — deploy ke baad yeh screen live ho jayegi.
        </p>
      )}

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat label="Active move-ins" value={String(c?.active_moves ?? 0)} />
        <Stat label="Slots free this month" value={String(c?.capacity?.slots_free ?? "—")} />
        <Stat label="Cash collected" value={gbp((c?.cash?.deposits_paid_gbp ?? 0) + (c?.cash?.final_paid_gbp ?? 0))} />
        {(c?.cash?.overdue_gbp ?? 0) > 0 ? (
          <Stat label="Outstanding" value={gbp(c?.cash?.outstanding_gbp)} tone="warn" />
        ) : (
          <Stat label="Outstanding" value={gbp(c?.cash?.outstanding_gbp)} />
        )}
      </section>

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat label="Booked value" value={gbp(c?.cash?.booked_gbp)} />
        <Stat label="Cut-overs next 24h" value={String(c?.cutovers_tonight ?? 0)} />
        <Stat label="Mailbox verified" value={`${c?.mailbox_verification_pct ?? 0}%`} />
        <Stat label="DNS proof green" value={`${c?.dns_proof_pct ?? 0}%`} />
      </section>

      {!!c?.attention?.length && (
        <section className="space-y-2">
          <h3 className="text-sm font-medium">Needs you now</h3>
          <ul className="space-y-2">
            {c.attention.map((a, i) => (
              <li key={`${a.deal_id}-${a.kind}-${i}`} className="flex items-start gap-2 rounded-xl border border-amber-500/20 bg-amber-500/5 p-3 text-sm">
                <AlertTriangle className="mt-0.5 h-4 w-4 text-amber-500" />
                <span>
                  <button className="font-medium underline-offset-2 hover:underline" onClick={() => setDealId(a.deal_id)}>
                    {a.reference}
                  </button>{" "}
                  · {a.message} <span className="text-muted-foreground">({stateLabel(a.state)})</span>
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="space-y-3">
        <h3 className="text-sm font-medium">Move-in board</h3>
        {c?.board?.length === 0 && <p className="text-sm text-muted-foreground">Ab tak koi move-in request nahi.</p>}
        <ul className="space-y-2">
          {(c?.board ?? []).map((d) => (
            <li key={d.id} className="rounded-xl border p-4 text-sm">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <button className="font-medium underline-offset-2 hover:underline" onClick={() => setDealId(d.id)}>
                  {d.reference} · {d.company}
                </button>
                <span className="rounded-full border px-2 py-0.5 text-xs">{stateLabel(d.state)}</span>
              </div>
              <div className="mt-1 flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted-foreground">
                <span>{d.mailboxes} mailboxes · band {d.band ?? "—"}</span>
                <span>{gbp(d.price_gbp)}</span>
                <span className={d.deposit_paid ? "text-emerald-500" : ""}>deposit {d.deposit_paid ? "paid" : "due"}</span>
                <span className={d.final_paid ? "text-emerald-500" : ""}>final {d.final_paid ? "paid" : "due"}</span>
                <span>health {d.health}%</span>
                {d.waitlisted && <span className="text-amber-500">waitlisted</span>}
                <span>updated {relativeTime(d.updated_at)}</span>
              </div>
            </li>
          ))}
        </ul>
      </section>

      {bundle && (
        <section className="space-y-4 rounded-2xl border p-5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h3 className="text-sm font-medium">
                {bundle.reference} · {bundle.company}
              </h3>
              <p className="text-xs text-muted-foreground">
                {stateLabel(bundle.state)} · {gbp(bundle.price_gbp)} · {bundle.scope.mailboxes} mailboxes
              </p>
            </div>
            <button className="text-xs text-muted-foreground underline-offset-2 hover:underline" onClick={() => setDealId(null)}>
              Close
            </button>
          </div>

          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {Object.entries(bundle.health ?? {})
              .filter(([k]) => k.endsWith("readiness") || k.endsWith("verification") || k === "overall")
              .map(([k, v]) => (
                <Stat key={k} label={stateLabel(k)} value={`${v}%`} />
              ))}
          </div>

          <div className="grid gap-4 lg:grid-cols-2">
            <div className="space-y-2">
              <h4 className="inline-flex items-center gap-2 text-xs font-medium text-muted-foreground">
                <Banknote className="h-3.5 w-3.5" /> Cash clock (50/50)
              </h4>
              <ul className="space-y-1 text-sm">
                {bundle.payments.map((p) => (
                  <li key={p.leg} className="flex items-center justify-between rounded-lg border px-3 py-2">
                    <span>{p.leg === "deposit" ? "Deposit 50%" : "Final 50%"}</span>
                    <span className={p.state === "paid" ? "text-emerald-500" : "text-muted-foreground"}>
                      {gbp(p.amount_gbp)} · {p.state}
                    </span>
                  </li>
                ))}
              </ul>
            </div>

            <div className="space-y-2">
              <h4 className="inline-flex items-center gap-2 text-xs font-medium text-muted-foreground">
                <ShieldCheck className="h-3.5 w-3.5" /> DNS proof
              </h4>
              <ul className="space-y-1 text-sm">
                {bundle.dns_proof.length === 0 && <li className="text-muted-foreground">Abhi koi check record nahi.</li>}
                {bundle.dns_proof.map((p) => (
                  <li key={`${p.phase}-${p.record}`} className="flex items-center justify-between rounded-lg border px-3 py-2">
                    <span>
                      {p.phase} · {p.record}
                    </span>
                    <span className={RESULT_TONE[p.result] ?? ""}>{p.result}</span>
                  </li>
                ))}
              </ul>
            </div>
          </div>

          <div className="space-y-2">
            <h4 className="inline-flex items-center gap-2 text-xs font-medium text-muted-foreground">
              <CalendarClock className="h-3.5 w-3.5" /> Cut-over runbook — {bundle.cutover_note}
            </h4>
            <ul className="space-y-1 text-sm">
              {bundle.runbook.map((r) => (
                <li key={r.label} className="flex flex-wrap items-center justify-between gap-2 rounded-lg border px-3 py-2">
                  <span>{r.label}</span>
                  <span className="flex items-center gap-2">
                    <span className={RESULT_TONE[r.result] ?? ""}>{r.result}</span>
                    {r.result !== "VERIFIED" && dealId && (
                      <button
                        className="rounded-md border px-2 py-0.5 text-xs hover:border-primary hover:text-primary"
                        disabled={step.isPending}
                        onClick={() =>
                          step.mutate({
                            deal_id: dealId,
                            step_key: stepKeyFor(r.label),
                            result: "VERIFIED",
                            evidence: "verified in cockpit",
                          })
                        }
                      >
                        Mark verified
                      </button>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          </div>

          <div className="flex flex-wrap gap-2">
            {dealId && (
              <>
                <button
                  className="rounded-lg border px-3 py-1.5 text-xs hover:border-primary hover:text-primary"
                  disabled={rollback.isPending}
                  onClick={() => rollback.mutate({ deal_id: dealId, label: "pre-cutover" })}
                >
                  Record rollback point
                </button>
                <button
                  className="rounded-lg border px-3 py-1.5 text-xs hover:border-primary hover:text-primary"
                  disabled={arm.isPending}
                  onClick={() => arm.mutate({ deal_id: dealId })}
                >
                  Arm cut-over
                </button>
                <button
                  className="rounded-lg border px-3 py-1.5 text-xs hover:border-primary hover:text-primary"
                  disabled={transition.isPending}
                  onClick={() => transition.mutate({ deal_id: dealId, to: "CUTOVER_EXECUTED", reason: "cut-over executed" })}
                >
                  Execute cut-over
                </button>
              </>
            )}
          </div>
          {(arm.isError || transition.isError) && (
            <p className="text-xs text-amber-600">
              Database ne roka: {(arm.error ?? transition.error)?.message}. Pehle gates clear karo.
            </p>
          )}

          <div className="space-y-1">
            <h4 className="text-xs font-medium text-muted-foreground">Audit trail</h4>
            <ul className="space-y-1 text-xs text-muted-foreground">
              {bundle.audit.slice(-12).reverse().map((a, i) => (
                <li key={i}>
                  {relativeTime(a.at)} · {a.actor} · {a.action}
                  {a.to_state ? ` → ${stateLabel(a.to_state)}` : ""}
                  {a.reason ? ` — ${a.reason}` : ""}
                </li>
              ))}
            </ul>
          </div>
        </section>
      )}
    </div>
  );
}

/** Runbook label -> step_key (labels DB se aate hain, keys deterministic). */
function stepKeyFor(label: string) {
  return label.toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "").slice(0, 40);
}

function Stat({ label, value, tone }: { label: string; value: string; tone?: "warn" }) {
  return (
    <div className={`rounded-xl border p-4 ${tone === "warn" ? "border-amber-500/30 bg-amber-500/5" : ""}`}>
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="mt-1 text-lg font-semibold tracking-tight">{value}</div>
    </div>
  );
}
