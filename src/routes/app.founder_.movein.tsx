import { createFileRoute } from "@tanstack/react-router";
import { useRef, useState } from "react";
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
import { ConfirmButton } from "@/components/app/ConfirmButton";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/movein")({
  component: MoveInCockpit,
  head: () => ({
    meta: [
      { title: "Move-In Cockpit · ANEXOMAIL" },
      {
        name: "description",
        content: "Managed Move-In operations, cash clock and cut-over control.",
      },
      { property: "og:title", content: "Move-In Cockpit · ANEXOMAIL" },
      {
        property: "og:description",
        content: "Every move-in, every payment leg, every proof — one screen.",
      },
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
  const loading = cockpit.isPending;
  /** A number is shown only once the server has answered — never a fake 0 while loading. */
  const n = (v: string | number | null | undefined) => (loading || v == null ? "—" : String(v));
  const detailRef = useRef<HTMLElement | null>(null);
  const openDeal = (id: string) => {
    setDealId(id);
    // On a phone the detail panel sits far below the board — bring it into view.
    requestAnimationFrame(() => detailRef.current?.scrollIntoView({ behavior: "smooth", block: "start" }));
  };
  const done = (what: string) => ({
    onSuccess: () => notify.done(what),
    onError: (e: Error) => notify.failed(`${what} failed`, { description: e.message }),
  });

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <div className="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs text-muted-foreground">
          <Database className="h-3.5 w-3.5" /> Every gate lives in the database — no shortcut, no
          guesswork
        </div>
        <h2 className="text-xl font-semibold tracking-tight">Move-In cockpit</h2>
        <p className="text-sm text-muted-foreground">
          Managed Move-In ka poora operation: cash clock, capacity, mailbox ledger, DNS proof,
          cut-over arm/rollback. Sab kuch Supabase se, kuch bhi hard-coded nahi.
        </p>
      </header>

      {cockpit.isError && (
        <div role="alert" className="flex flex-wrap items-center gap-3 rounded-xl border border-danger/40 bg-danger/10 p-3 text-sm text-danger">
          <span className="min-w-0 flex-1">The cockpit could not be loaded: {cockpit.error?.message ?? "server unreachable"}.</span>
          <button type="button" onClick={() => void cockpit.refetch()} className="ax-press ax-tap rounded-lg border border-danger/50 px-3 py-2 text-xs font-semibold">
            Try again
          </button>
        </div>
      )}

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat label="Active move-ins" value={n(c?.active_moves ?? 0)} />
        <Stat label="Slots free this month" value={n(c?.capacity?.slots_free)} />
        <Stat
          label="Cash collected"
          value={loading ? "—" : gbp((c?.cash?.deposits_paid_gbp ?? 0) + (c?.cash?.final_paid_gbp ?? 0))}
        />
        {(c?.cash?.overdue_gbp ?? 0) > 0 ? (
          <Stat label="Outstanding" value={loading ? "—" : gbp(c?.cash?.outstanding_gbp)} tone="warn" />
        ) : (
          <Stat label="Outstanding" value={loading ? "—" : gbp(c?.cash?.outstanding_gbp)} />
        )}
      </section>

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat label="Booked value" value={loading ? "—" : gbp(c?.cash?.booked_gbp)} />
        <Stat label="Cut-overs next 24h" value={n(c?.cutovers_tonight ?? 0)} />
        <Stat label="Mailbox verified" value={loading ? "—" : `${c?.mailbox_verification_pct ?? 0}%`} />
        <Stat label="DNS proof green" value={loading ? "—" : `${c?.dns_proof_pct ?? 0}%`} />
      </section>

      {!!c?.attention?.length && (
        <section className="space-y-2">
          <h3 className="text-sm font-medium">Needs you now</h3>
          <ul className="space-y-2">
            {c.attention.map((a, i) => (
              <li
                key={`${a.deal_id}-${a.kind}-${i}`}
                className="flex items-start gap-2 rounded-xl border border-warning/30 bg-warning/5 p-3 text-sm"
              >
                <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-warning" aria-hidden="true" />
                <span>
                  <button
                    type="button"
                    className="ax-tap font-medium underline underline-offset-2"
                    onClick={() => openDeal(a.deal_id)}
                  >
                    {a.reference}
                  </button>{" "}
                  · {a.message}{" "}
                  <span className="text-muted-foreground">({stateLabel(a.state)})</span>
                </span>
              </li>
            ))}
          </ul>
        </section>
      )}

      <section className="space-y-3">
        <h3 className="text-sm font-medium">Move-in board</h3>
        {!loading && c?.board?.length === 0 && (
          <p className="text-sm text-muted-foreground">No move-in requests yet.</p>
        )}
        <ul className="space-y-2">
          {(c?.board ?? []).map((d) => (
            <li key={d.id} className="rounded-xl border p-4 text-sm">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <button
                  type="button"
                  className="ax-tap min-w-0 text-left font-medium underline-offset-2 hover:underline"
                  onClick={() => openDeal(d.id)}
                >
                  {d.reference} · {d.company}
                </button>
                <span className="rounded-full border px-2 py-0.5 text-xs">
                  {stateLabel(d.state)}
                </span>
              </div>
              <div className="mt-1 flex flex-wrap gap-x-3 gap-y-1 text-xs text-muted-foreground">
                <span>
                  {d.mailboxes} mailboxes · band {d.band ?? "—"}
                </span>
                <span>{gbp(d.price_gbp)}</span>
                <span className={d.deposit_paid ? "text-success" : ""}>
                  deposit {d.deposit_paid ? "paid" : "due"}
                </span>
                <span className={d.final_paid ? "text-success" : ""}>
                  final {d.final_paid ? "paid" : "due"}
                </span>
                <span>health {d.health}%</span>
                {d.waitlisted && <span className="text-warning">waitlisted</span>}
                <span>updated {relativeTime(d.updated_at)}</span>
              </div>
            </li>
          ))}
        </ul>
      </section>

      {dealId && deal.isPending && (
        <p className="text-sm text-muted-foreground" role="status">Loading the move-in record…</p>
      )}
      {dealId && deal.isError && (
        <p role="alert" className="text-sm text-danger">Could not load this move-in: {deal.error?.message}</p>
      )}
      {bundle && (
        <section ref={detailRef} className="scroll-mt-4 space-y-4 rounded-2xl border p-4 sm:p-5">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h3 className="text-sm font-medium">
                {bundle.reference} · {bundle.company}
              </h3>
              <p className="text-xs text-muted-foreground">
                {stateLabel(bundle.state)} · {gbp(bundle.price_gbp)} · {bundle.scope.mailboxes}{" "}
                mailboxes
              </p>
            </div>
            <button
              type="button"
              className="ax-press ax-tap rounded-lg border border-border px-3 py-2 text-xs text-muted-foreground hover:text-foreground"
              onClick={() => setDealId(null)}
            >
              Close
            </button>
          </div>

          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {Object.entries(bundle.health ?? {})
              .filter(
                ([k]) => k.endsWith("readiness") || k.endsWith("verification") || k === "overall",
              )
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
                  <li
                    key={p.leg}
                    className="flex items-center justify-between gap-3 rounded-lg border px-3 py-2"
                  >
                    <span>{p.leg === "deposit" ? "Deposit 50%" : "Final 50%"}</span>
                    <span
                      className={p.state === "paid" ? "text-success" : "text-muted-foreground"}
                    >
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
                {bundle.dns_proof.length === 0 && (
                  <li className="text-muted-foreground">No check records yet.</li>
                )}
                {bundle.dns_proof.map((p) => (
                  <li
                    key={`${p.phase}-${p.record}`}
                    className="flex items-center justify-between gap-3 rounded-lg border px-3 py-2"
                  >
                    <span className="min-w-0 break-all">
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
                <li
                  key={r.label}
                  className="flex flex-wrap items-center justify-between gap-2 rounded-lg border px-3 py-2"
                >
                  <span>{r.label}</span>
                  <span className="flex items-center gap-2">
                    <span className={RESULT_TONE[r.result] ?? ""}>{r.result}</span>
                    {r.result !== "VERIFIED" && dealId && (
                      <ConfirmButton
                        pending={step.isPending}
                        confirmLabel="Tap again: mark verified"
                        onConfirm={() =>
                          step.mutate(
                            {
                              deal_id: dealId,
                              step_key: stepKeyFor(r.label),
                              result: "VERIFIED",
                              evidence: "verified in cockpit",
                            },
                            done("Step verified"),
                          )
                        }
                      >
                        Mark verified
                      </ConfirmButton>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          </div>

          <div className="flex flex-wrap gap-2">
            {dealId && (
              <>
                <ConfirmButton
                  pending={rollback.isPending}
                  onConfirm={() => rollback.mutate({ deal_id: dealId, label: "pre-cutover" }, done("Rollback point recorded"))}
                >
                  Record rollback point
                </ConfirmButton>
                <ConfirmButton
                  pending={arm.isPending}
                  confirmLabel="Tap again: arm cut-over"
                  onConfirm={() => arm.mutate({ deal_id: dealId }, done("Cut-over armed"))}
                >
                  Arm cut-over
                </ConfirmButton>
                <ConfirmButton
                  tone="danger"
                  pending={transition.isPending}
                  confirmLabel="Tap again: EXECUTE cut-over"
                  onConfirm={() =>
                    transition.mutate(
                      { deal_id: dealId, to: "CUTOVER_EXECUTED", reason: "cut-over executed" },
                      done("Cut-over executed"),
                    )
                  }
                >
                  Execute cut-over
                </ConfirmButton>
              </>
            )}
          </div>
          {(arm.isError || transition.isError) && (
            <p role="alert" className="text-xs text-warning">
              The database refused this: {(arm.error ?? transition.error)?.message}. Clear the open gates first.
            </p>
          )}

          <div className="space-y-1">
            <h4 className="text-xs font-medium text-muted-foreground">Audit trail</h4>
            <ul className="space-y-1 text-xs text-muted-foreground">
              {bundle.audit
                .slice(-12)
                .reverse()
                .map((a, i) => (
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
  return label
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_|_$/g, "")
    .slice(0, 40);
}

function Stat({ label, value, tone }: { label: string; value: string; tone?: "warn" }) {
  return (
    <div
      className={`rounded-xl border p-4 ${tone === "warn" ? "border-warning/30 bg-warning/5" : ""}`}
    >
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="mt-1 text-lg font-semibold tracking-tight">{value}</div>
    </div>
  );
}
