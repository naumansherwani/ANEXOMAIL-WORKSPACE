import { createFileRoute } from "@tanstack/react-router";
import { Gauge, ShieldCheck, Wallet } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import {
  money,
  useAiWallet,
  useCheckout,
  useCreditHistory,
  useSetSpendCap,
  useTopUpPacks,
  useUsageAnalytics,
} from "@/lib/ai-billing";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/ai/billing")({
  component: FounderAiBilling,
});

/**
 * Phase 19 — AI Credits & Billing, founder surface.
 * Tab 1 God-View (wallet, burn, runway, usage analytics, ledger)
 * Tab 2 Sandbox checkout (top-up packs; founder charge zero, cost visible).
 */
function FounderAiBilling() {
  const [tab, setTab] = useState<"god" | "checkout">("god");
  const [days, setDays] = useState(30);
  const [cap, setCap] = useState("");

  const wallet = useAiWallet();
  const history = useCreditHistory();
  const usage = useUsageAnalytics(days);
  const packs = useTopUpPacks();
  const checkout = useCheckout();
  const setSpendCap = useSetSpendCap();

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-5xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <Wallet className="size-3.5" aria-hidden="true" /> Credits &amp; billing
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Every credit, with its truth</h2>

        <nav className="mt-ax-4 flex gap-1.5">
          {(["god", "checkout"] as const).map((t) => (
            <button
              key={t}
              type="button"
              onClick={() => setTab(t)}
              data-on={tab === t ? "true" : "false"}
              className="ax-press rounded-xl border border-border px-3 py-1.5 text-[12px] font-semibold text-muted-foreground data-[on=true]:border-primary data-[on=true]:bg-primary data-[on=true]:text-primary-foreground"
            >
              {t === "god" ? "God-view" : "Sandbox checkout"}
            </button>
          ))}
        </nav>

        {tab === "god" ? (
          <>
            <section className="mt-ax-5">
              <CardBody
                query={{
                  data: wallet.data,
                  isPending: wallet.isPending,
                  error: wallet.error ?? null,
                  refetch: () => void wallet.refetch(),
                }}
                endpoint="/api/ai/billing/wallet"
                skeleton={<StatSkeleton rows={4} />}
              >
                {(w) => (
                  <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
                    <Stat
                      label="Balance"
                      value={w.unlimited ? "Founder" : `${w.balance} cr`}
                      hint={w.plan ? `plan ${w.plan}` : "founder"}
                    />
                    <Stat label="Spent today" value={money(w.spent_today, w.currency)} hint={`${w.burn_per_day.toFixed(2)}/day burn`} />
                    <Stat label="Spent this month" value={money(w.spent_month, w.currency)} hint={w.renews_at ? `renews ${relativeTime(w.renews_at)}` : "no renewal set"} />
                    <Stat
                      label="Runway"
                      value={w.unlimited ? "∞" : w.runway_days === null ? "—" : `${w.runway_days} days`}
                      hint={`monthly grant ${w.monthly_grant} · comp ${w.complimentary}`}
                    />
                  </div>
                )}
              </CardBody>
            </section>

            <section className="mt-ax-6">
              <div className="flex flex-wrap items-center gap-ax-3">
                <h3 className="ax-heading text-foreground">Usage analytics</h3>
                <div className="flex gap-1.5">
                  {[7, 30, 90].map((d) => (
                    <button
                      key={d}
                      type="button"
                      onClick={() => setDays(d)}
                      data-on={days === d ? "true" : "false"}
                      className="ax-press rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground data-[on=true]:border-primary data-[on=true]:text-primary"
                    >
                      {d}d
                    </button>
                  ))}
                </div>
              </div>
              <div className="mt-ax-3">
                <CardBody
                  query={{
                    data: usage.data,
                    isPending: usage.isPending,
                    error: usage.error ?? null,
                    refetch: () => void usage.refetch(),
                  }}
                  endpoint="/api/ai/billing/usage"
                  skeleton={<StatSkeleton rows={5} />}
                >
                  {(u) => {
                    const peak = Math.max(1, ...u.series.map((p) => p.credits));
                    return (
                      <div className="ax-plane rounded-2xl p-ax-4">
                        <p className="ax-caption text-muted-foreground">
                          {u.total_credits} credits · {money(u.total_cost, u.currency)} in {days} days
                        </p>
                        <div className="mt-ax-4 flex h-28 items-end gap-1">
                          {u.series.map((p) => (
                            <div
                              key={p.day}
                              title={`${p.day} · ${p.credits} cr · ${money(p.cost, u.currency)}`}
                              className="flex-1 rounded-t bg-primary/70"
                              style={{ height: `${(p.credits / peak) * 100}%` }}
                            />
                          ))}
                        </div>
                        <ul className="mt-ax-4 space-y-1.5">
                          {u.by_surface.map((s) => (
                            <li key={s.surface} className="flex items-center gap-ax-3 text-[12px]">
                              <span className="w-28 shrink-0 text-muted-foreground">{s.surface}</span>
                              <span className="h-1.5 flex-1 overflow-hidden rounded-full bg-secondary">
                                <span
                                  className="block h-full rounded-full bg-primary"
                                  style={{ width: `${Math.round(s.share * 100)}%` }}
                                />
                              </span>
                              <span className="w-24 shrink-0 text-right text-foreground">
                                {money(s.cost, u.currency)}
                              </span>
                            </li>
                          ))}
                        </ul>
                      </div>
                    );
                  }}
                </CardBody>
              </div>
            </section>

            <section className="mt-ax-6">
              <h3 className="ax-heading flex items-center gap-2 text-foreground">
                <ShieldCheck className="size-4" aria-hidden="true" /> Daily spend cap
              </h3>
              <form
                className="mt-ax-3 flex flex-wrap items-center gap-2"
                onSubmit={(e) => {
                  e.preventDefault();
                  const value = Number(cap);
                  if (!Number.isFinite(value) || value < 0) return;
                  setSpendCap.mutate(
                    { cap: value },
                    {
                      onSuccess: () => notify.done("Cap saved", "Server enforces it on every call."),
                      onError: (err) =>
                        notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
                          description: err.isNotImplemented ? "POST /api/ai/billing/cap pending." : err.message,
                        }),
                    },
                  );
                }}
              >
                <input
                  aria-label="Daily spend cap"
                  value={cap}
                  onChange={(e) => setCap(e.target.value)}
                  inputMode="decimal"
                  placeholder="e.g. 25"
                  className="h-9 w-32 rounded-lg border border-border bg-card px-2 text-[12px] text-foreground"
                />
                <button
                  type="submit"
                  disabled={setSpendCap.isPending}
                  className="ax-press rounded-xl bg-primary px-3 py-2 text-[12px] font-semibold text-primary-foreground disabled:opacity-50"
                >
                  Save cap
                </button>
                <span className="ax-caption text-muted-foreground">
                  Hard stop on the server — not a warning banner.
                </span>
              </form>
            </section>

            <section className="mt-ax-6">
              <h3 className="ax-heading text-foreground">Credit ledger</h3>
              <div className="mt-ax-3">
                <CardBody
                  query={{
                    data: history.data,
                    isPending: history.isPending,
                    error: history.error ?? null,
                    refetch: () => void history.refetch(),
                  }}
                  endpoint="/api/ai/billing/history"
                  skeleton={<StatSkeleton rows={6} />}
                >
                  {(d) =>
                    d.events.length === 0 ? (
                      <p className="ax-caption text-muted-foreground">Nothing recorded yet.</p>
                    ) : (
                      <ul className="space-y-1.5">
                        {d.events.map((e) => (
                          <li
                            key={e.id}
                            className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                          >
                            <span className="rounded-md bg-secondary px-1.5 py-0.5 text-[10px] font-semibold uppercase text-muted-foreground">
                              {e.kind}
                            </span>
                            <span className="text-foreground">
                              {e.credits > 0 ? "+" : ""}
                              {e.credits} cr
                            </span>
                            <span className="text-muted-foreground">{money(e.cost, e.currency)}</span>
                            {e.model && <span className="text-steel">{e.model}</span>}
                            {e.surface && <span className="text-steel">{e.surface}</span>}
                            <span className="ml-auto text-steel">{relativeTime(e.created_at)}</span>
                          </li>
                        ))}
                      </ul>
                    )
                  }
                </CardBody>
              </div>
            </section>
          </>
        ) : (
          <section className="mt-ax-5">
            <p className="ax-caption text-muted-foreground">
              Founder checkout is a sandbox: the server records the intent and grants the credits,
              the charge stays zero. Awam ke liye yeh wahi flow hai, asli payment ke saath.
            </p>
            <div className="mt-ax-4">
              <CardBody
                query={{
                  data: packs.data,
                  isPending: packs.isPending,
                  error: packs.error ?? null,
                  refetch: () => void packs.refetch(),
                }}
                endpoint="/api/ai/billing/packs"
                skeleton={<StatSkeleton rows={4} />}
              >
                {(p) => (
                  <ul className="grid gap-ax-3 sm:grid-cols-2">
                    {p.packs.map((pack) => (
                      <li
                        key={pack.id}
                        data-best={pack.best_value ? "true" : "false"}
                        className="ax-plane rounded-2xl p-ax-4 data-[best=true]:border-primary/50"
                      >
                        <p className="text-[15px] font-bold text-foreground">
                          {pack.credits.toLocaleString()} credits
                        </p>
                        <p className="ax-caption mt-1 text-muted-foreground">
                          {money(pack.price, pack.currency)}
                          {pack.bonus > 0 ? ` · +${pack.bonus} bonus` : ""}
                          {pack.best_value ? " · best value" : ""}
                        </p>
                        <button
                          type="button"
                          disabled={checkout.isPending}
                          onClick={() =>
                            checkout.mutate(
                              { pack_id: pack.id, sandbox: true },
                              {
                                onSuccess: (r) =>
                                  notify.done(
                                    "Credits granted",
                                    `${r.credits} credits · charged ${money(r.charged, r.currency)}`,
                                  ),
                                onError: (err) =>
                                  notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
                                    description: err.isNotImplemented
                                      ? "POST /api/ai/billing/checkout pending on the server."
                                      : err.message,
                                  }),
                              },
                            )
                          }
                          className="ax-press mt-ax-4 rounded-xl bg-primary px-3 py-2 text-[12px] font-semibold text-primary-foreground disabled:opacity-50"
                        >
                          Run sandbox checkout
                        </button>
                      </li>
                    ))}
                  </ul>
                )}
              </CardBody>
            </div>
          </section>
        )}
      </div>
    </div>
  );
}

function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-1 text-[19px] font-bold text-foreground">{value}</p>
      {hint && (
        <p className="ax-caption mt-1 flex items-center gap-1 text-steel">
          <Gauge className="size-3" aria-hidden="true" /> {hint}
        </p>
      )}
    </div>
  );
}
