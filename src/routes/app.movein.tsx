import { createFileRoute } from "@tanstack/react-router";
import { CheckCircle2, Clock, Database } from "lucide-react";

import { gbp, stateLabel, useMyMoveIn, RESULT_TONE } from "@/lib/movein";

export const Route = createFileRoute("/app/movein")({
  component: MyMoveIn,
  head: () => ({
    meta: [
      { title: "My move-in · ANEXOMAIL" },
      { name: "description", content: "Track your managed move-in: progress, proof and payments." },
      { property: "og:title", content: "My move-in · ANEXOMAIL" },
      { property: "og:description", content: "Live progress, verified mailboxes and delivery proof for your move." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
});

function MyMoveIn() {
  const q = useMyMoveIn();
  const d = q.data?.deal;

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <div className="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs text-muted-foreground">
          <Database className="h-3.5 w-3.5" /> Live status, straight from our records
        </div>
        <h2 className="text-xl font-semibold tracking-tight">Your move-in</h2>
        <p className="text-sm text-muted-foreground">
          Every mailbox we verify and every delivery record we prove shows up here — nothing hidden.
        </p>
      </header>

      {q.isLoading && <p className="text-sm text-muted-foreground">Loading your move…</p>}
      {q.isError && (
        <p className="text-sm text-muted-foreground">
          We could not reach the move-in service just now. It will appear here as soon as it responds.
        </p>
      )}
      {q.data && !d && (
        <p className="text-sm text-muted-foreground">
          No move-in is running on your account yet. Ask us about a managed move-in and it will appear here.
        </p>
      )}

      {d && (
        <>
          <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Stat label="Reference" value={d.reference} />
            <Stat label="Stage" value={stateLabel(d.state)} />
            <Stat label="Progress" value={`${d.progress ?? 0}%`} />
            <Stat label="Mailboxes verified" value={`${d.mailboxes_verified}/${d.mailboxes_total}`} />
          </section>

          <section className="space-y-2">
            <h3 className="text-sm font-medium">Cut-over</h3>
            <p className="inline-flex items-center gap-2 text-sm text-muted-foreground">
              <Clock className="h-4 w-4" />
              {d.cutover_window.start
                ? `Scheduled ${new Date(d.cutover_window.start).toLocaleString("en-GB")}`
                : "Cut-over not scheduled yet"}
            </p>
            <p className="text-xs text-muted-foreground">{d.cutover_note}</p>
          </section>

          <section className="space-y-2">
            <h3 className="text-sm font-medium">Payments</h3>
            <ul className="space-y-1 text-sm">
              {d.payments.map((p) => (
                <li key={p.leg} className="flex items-center justify-between rounded-lg border px-3 py-2">
                  <span>{p.leg === "deposit" ? "Deposit 50%" : "Final 50%"}</span>
                  <span className={p.state === "paid" ? "text-emerald-500" : "text-muted-foreground"}>
                    {gbp(p.amount_gbp)} · {p.state}
                  </span>
                </li>
              ))}
            </ul>
          </section>

          <section className="space-y-2">
            <h3 className="text-sm font-medium">Delivery proof</h3>
            {d.dns_proof.length === 0 ? (
              <p className="text-sm text-muted-foreground">Proof records appear as soon as checks run.</p>
            ) : (
              <ul className="space-y-1 text-sm">
                {d.dns_proof.map((p) => (
                  <li key={`${p.phase}-${p.record}`} className="flex items-center justify-between rounded-lg border px-3 py-2">
                    <span>
                      {p.phase === "POST" ? "After cut-over" : "Before cut-over"} · {p.record}
                    </span>
                    <span className={RESULT_TONE[p.result] ?? ""}>{p.result}</span>
                  </li>
                ))}
              </ul>
            )}
          </section>

          {d.customer_action.length > 0 ? (
            <section className="space-y-2">
              <h3 className="text-sm font-medium">We need one thing from you</h3>
              <ul className="space-y-2">
                {d.customer_action.map((a, i) => (
                  <li key={i} className="rounded-xl border border-amber-500/20 bg-amber-500/5 p-3 text-sm">
                    {a.reason}
                    {a.required_action ? ` — ${a.required_action}` : ""}
                  </li>
                ))}
              </ul>
            </section>
          ) : (
            <p className="inline-flex items-center gap-2 text-sm text-emerald-600">
              <CheckCircle2 className="h-4 w-4" /> Nothing is waiting on you right now.
            </p>
          )}
        </>
      )}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl border p-4">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="mt-1 text-lg font-semibold tracking-tight">{value}</div>
    </div>
  );
}
