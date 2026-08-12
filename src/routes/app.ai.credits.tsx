import { createFileRoute } from "@tanstack/react-router";
import { Coins, Gift, History, Receipt, ShieldCheck, Wallet } from "lucide-react";

import { AiTopUpDialog } from "@/components/site/AiTopUpDialog";
import { StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import {
  useClaimComplimentary,
  useCreditActions,
  useCreditLedger,
  useCreditWallet,
} from "@/lib/ai-credits";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/ai/credits")({
  head: () => ({
    meta: [
      { title: "AI credit wallet — ANEXOMAIL AI" },
      {
        name: "description",
        content:
          "Your AI credit wallet: subscription, top-up and complimentary buckets, every reservation and charge in an immutable ledger.",
      },
      { property: "og:title", content: "AI credit wallet — ANEXOMAIL AI" },
      {
        property: "og:description",
        content: "Four credit buckets, pre-flight estimates and a receipt for every AI action.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CreditsPage,
});

function CreditsPage() {
  const wallet = useCreditWallet();
  const ledger = useCreditLedger(50);
  const actions = useCreditActions(50);
  const claim = useClaimComplimentary();

  if (wallet.isLoading) {
    return <StateBlock kind="loading" title="Reading your wallet…" />;
  }

  if (wallet.error) {
    return (
      <StateBlock
        kind={wallet.error.status === 401 ? "empty" : "error"}
        icon={Wallet}
        title={
          wallet.error.status === 401
            ? "Sign in to see your AI credit wallet."
            : "Wallet is not reachable right now."
        }
        body={
          wallet.error.status === 401
            ? "Credits belong to your workspace, so the wallet only opens inside a signed-in session."
            : "Balances come straight from the ledger — nothing is cached or guessed here. Try again in a moment."
        }
      />
    );
  }

  const w = wallet.data!.wallet;
  const claimed = wallet.data!.complimentary_claimed ?? [];
  const buckets = [
    { label: "Subscription", value: w.subscription_credits, note: "Resets each cycle" },
    { label: "Top-up", value: w.topup_credits, note: "Never expires" },
    { label: "Complimentary", value: w.complimentary_credits, note: "5 + 5 per cycle" },
    { label: "Reserved", value: w.reserved_credits, note: "Held for running actions" },
  ];

  return (
    <div className="space-y-8">
      <section className="rounded-2xl border border-border bg-card p-6 shadow-elev-1">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h2 className="text-lg font-semibold text-foreground">AI credit wallet</h2>
            <p className="mt-1 text-sm text-muted-foreground">
              {w.plan_id ? `Plan ${w.plan_id}` : "No AI plan on this workspace yet"} · cycle started{" "}
              {new Date(w.cycle_started_at).toLocaleDateString("en-GB")}
            </p>
          </div>
          <div className="text-right">
            <div className="text-3xl font-semibold tabular-nums text-foreground">
              {w.total_balance.toLocaleString("en-GB")}
            </div>
            <div className="text-xs text-muted-foreground">credits available</div>
          </div>
        </div>

        <div className="mt-6 grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          {buckets.map((b) => (
            <div key={b.label} className="rounded-xl border border-border bg-surface-2 p-4">
              <div className="flex items-center gap-2 text-xs font-medium text-muted-foreground">
                <Coins className="size-3.5" aria-hidden="true" />
                {b.label}
              </div>
              <div className="mt-2 text-xl font-semibold tabular-nums text-foreground">
                {b.value.toLocaleString("en-GB")}
              </div>
              <div className="mt-1 text-xs text-muted-foreground">{b.note}</div>
            </div>
          ))}
        </div>

        <div className="mt-6 flex flex-wrap items-center gap-3">
          <AiTopUpDialog />
          {([1, 2] as const).map((day) => (
            <Button
              key={day}
              variant="outline"
              disabled={claimed.includes(day) || claim.isPending}
              onClick={() =>
                claim.mutate(
                  { day },
                  {
                    onSuccess: (r) =>
                      notify.success(`5 complimentary credits added · balance ${r.balance}`),
                    onError: (e) => notify.error(e.message),
                  },
                )
              }
            >
              <Gift className="mr-2 size-4" aria-hidden="true" />
              {claimed.includes(day) ? `Day ${day} claimed` : `Claim day ${day} · 5 credits`}
            </Button>
          ))}
        </div>

        <p className="mt-4 flex items-start gap-2 text-xs leading-relaxed text-muted-foreground">
          <ShieldCheck className="mt-0.5 size-3.5 shrink-0" aria-hidden="true" />
          Every action reserves credits before it runs and settles on the real amount used. Spend
          order is complimentary first, then subscription, then top-up.
        </p>
      </section>

      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-foreground">
          <Receipt className="size-4" aria-hidden="true" /> Action receipts
        </h2>
        {actions.error ? (
          <StateBlock kind="empty" title="Receipts are not reachable yet." />
        ) : (actions.data?.actions.length ?? 0) === 0 ? (
          <StateBlock
            kind="empty"
            icon={Receipt}
            title="No AI actions yet."
            body="As soon as you run one, its estimate, the credits reserved and the final charge appear here."
          />
        ) : (
          <div className="mt-3 overflow-hidden rounded-xl border border-border">
            <table className="w-full text-sm">
              <thead className="bg-surface-2 text-xs text-muted-foreground">
                <tr>
                  <th className="p-3 text-left font-medium">Action</th>
                  <th className="p-3 text-left font-medium">Model</th>
                  <th className="p-3 text-right font-medium">Estimate</th>
                  <th className="p-3 text-right font-medium">Charged</th>
                  <th className="p-3 text-left font-medium">Status</th>
                </tr>
              </thead>
              <tbody>
                {actions.data!.actions.map((a) => (
                  <tr key={a.id} className="border-t border-border">
                    <td className="p-3 text-foreground">{a.action_type}</td>
                    <td className="p-3 text-muted-foreground">{a.model ?? "—"}</td>
                    <td className="p-3 text-right tabular-nums text-muted-foreground">
                      {a.estimated_credits_min ?? "—"}–{a.estimated_credits_max ?? "—"}
                    </td>
                    <td className="p-3 text-right tabular-nums text-foreground">
                      {a.actual_credits ?? "—"}
                    </td>
                    <td className="p-3 text-muted-foreground">{a.status}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </section>

      <section>
        <h2 className="flex items-center gap-2 text-base font-semibold text-foreground">
          <History className="size-4" aria-hidden="true" /> Immutable ledger
        </h2>
        <p className="mt-1 text-xs text-muted-foreground">
          Financial history is append-only. Nothing here can be edited or deleted — a correction is
          always a new reversal entry.
        </p>
        {ledger.error ? (
          <StateBlock kind="empty" title="Ledger is not reachable yet." />
        ) : (ledger.data?.entries.length ?? 0) === 0 ? (
          <StateBlock kind="empty" icon={History} title="Ledger is empty." body="Your first grant, reservation or charge will appear here." />
        ) : (
          <ul className="mt-3 divide-y divide-border rounded-xl border border-border">
            {ledger.data!.entries.map((e) => (
              <li key={e.id} className="flex items-center justify-between gap-4 p-3 text-sm">
                <div>
                  <div className="font-medium text-foreground">{e.entry_type.replace(/_/g, " ")}</div>
                  <div className="text-xs text-muted-foreground">
                    {e.reason ?? e.credit_type} · {new Date(e.created_at).toLocaleString("en-GB")}
                  </div>
                </div>
                <div className="text-right">
                  <div
                    className={
                      Number(e.amount) < 0 ? "tabular-nums text-foreground" : "tabular-nums text-primary"
                    }
                  >
                    {Number(e.amount) > 0 ? "+" : ""}
                    {Number(e.amount).toLocaleString("en-GB")}
                  </div>
                  <div className="text-xs text-muted-foreground tabular-nums">
                    → {Number(e.balance_after).toLocaleString("en-GB")}
                  </div>
                </div>
              </li>
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
