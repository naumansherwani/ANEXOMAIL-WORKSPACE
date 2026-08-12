import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { AlertTriangle, CheckCircle2, Database, RefreshCw } from "lucide-react";

import { api } from "@/lib/api";
import { relativeTime } from "@/lib/mail";

export const Route = createFileRoute("/app/billing/state")({
  component: BillingStatePage,
});

type Intent = {
  id: string;
  kind: string;
  plan: string | null;
  band: string | null;
  seats: number;
  state: "open" | "paid" | "entitled" | "stuck" | "abandoned";
  amount_expected: number | null;
  amount_paid: number | null;
  currency: string;
  paid_at: string | null;
  created_at: string;
  last_error: string | null;
};

type StatePayload = {
  source_of_truth: string;
  entitlement: {
    plan: string | null;
    seats: number;
    movein_band: string | null;
    support_active: boolean;
    active_until: string | null;
    revision: number;
  };
  intents: Intent[];
  log: { to_state: string; reason: string | null; source: string | null; created_at: string }[];
};

type HealthPayload = {
  health: Record<string, number | string | null> | null;
  gaps: { gap: string; ref: string; state: string; at: string | null; detail: string | null }[];
  alerts: { id: string; severity: string; kind: string; message: string; created_at: string }[];
};

const STATE_TONE: Record<string, string> = {
  entitled: "text-green-600 bg-green-500/10 border-green-500/20",
  paid: "text-blue-600 bg-blue-500/10 border-blue-500/20",
  open: "text-amber-600 bg-amber-500/10 border-amber-500/20",
  stuck: "text-red-600 bg-red-500/10 border-red-500/20",
  abandoned: "text-muted-foreground bg-muted border-border",
};

/**
 * Phase 36 — State Sync truth panel.
 * Supabase authority hai; Polar sirf messenger. Yahan sirf Supabase ka sach
 * dikhta hai — koi payment kabhi "gum" nahi hoti.
 */
function BillingStatePage() {
  const state = useQuery({
    queryKey: ["billing-state"],
    queryFn: () => api<StatePayload>("/api/billing/state"),
    refetchInterval: 15000,
  });
  const health = useQuery({
    queryKey: ["billing-state-health"],
    queryFn: () => api<HealthPayload>("/api/billing/state-health"),
    refetchInterval: 30000,
    retry: false,
  });

  const ent = state.data?.entitlement;

  return (
    <div className="space-y-8">
      <header className="space-y-2">
        <div className="inline-flex items-center gap-2 rounded-full border px-3 py-1 text-xs text-muted-foreground">
          <Database className="h-3.5 w-3.5" /> Source of truth: Supabase — Polar sirf messenger
        </div>
        <h2 className="text-xl font-semibold tracking-tight">Payment state sync</h2>
        <p className="text-sm text-muted-foreground">
          Har purchase pehle Supabase mein intent banti hai, phir checkout. Webhook aaye ya na aaye,
          sync loop payment ka sach kheench kar entitlement laga deta hai.
        </p>
      </header>

      <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <Stat label="Plan" value={ent?.plan ? ent.plan.toUpperCase() : "—"} />
        <Stat label="Seats" value={ent ? String(ent.seats) : "—"} />
        <Stat label="Move-in band" value={ent?.movein_band ?? "—"} />
        <Stat label="Priority Support" value={ent?.support_active ? "Active" : "Off"} />
      </section>

      <section className="space-y-3">
        <h3 className="text-sm font-medium">Purchase intents</h3>
        {state.isLoading && <p className="text-sm text-muted-foreground">Loading truth…</p>}
        {state.isError && (
          <p className="text-sm text-muted-foreground">
            State sync backend abhi reachable nahi — dobara koshish jari hai.
          </p>
        )}
        {state.data?.intents.length === 0 && (
          <p className="text-sm text-muted-foreground">Ab tak koi purchase intent nahi.</p>
        )}
        <ul className="space-y-2">
          {(state.data?.intents ?? []).map((i) => (
            <li key={i.id} className="rounded-xl border p-4 text-sm">
              <div className="flex flex-wrap items-center justify-between gap-2">
                <span className="font-medium">
                  {i.kind === "plan"
                    ? `Plan · ${i.plan ?? "—"} · ${i.seats} seat${i.seats > 1 ? "s" : ""}`
                    : i.kind === "movein"
                      ? `Managed Move-In · ${i.band ?? "—"}`
                      : "Priority Support"}
                </span>
                <span
                  className={`rounded-full border px-2 py-0.5 text-xs ${STATE_TONE[i.state] ?? STATE_TONE['open']}`}
                >
                  {i.state}
                </span>
              </div>
              <div className="mt-1 text-xs text-muted-foreground">
                Opened {relativeTime(i.created_at)}
                {i.paid_at ? ` · paid ${relativeTime(i.paid_at)}` : ""}
                {i.amount_paid != null ? ` · £${i.amount_paid}` : ""}
              </div>
              {i.last_error && (
                <div className="mt-2 flex items-start gap-2 text-xs text-amber-600">
                  <RefreshCw className="mt-0.5 h-3.5 w-3.5" />
                  <span>Retrying: {i.last_error}</span>
                </div>
              )}
            </li>
          ))}
        </ul>
      </section>

      {health.data?.health && (
        <section className="space-y-3">
          <h3 className="text-sm font-medium">Sync health</h3>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <Stat label="Open intents" value={String(health.data.health['open_intents'] ?? 0)} />
            <Stat label="Paid pending" value={String(health.data.health['paid_pending'] ?? 0)} />
            <Stat label="Stuck" value={String(health.data.health['stuck_intents'] ?? 0)} />
            <Stat label="Open gaps" value={String(health.data.health['open_gaps'] ?? 0)} />
          </div>
          {health.data.gaps.length === 0 ? (
            <p className="inline-flex items-center gap-2 text-sm text-green-600">
              <CheckCircle2 className="h-4 w-4" /> Koi truth gap nahi — har paid payment entitled hai.
            </p>
          ) : (
            <ul className="space-y-2">
              {health.data.gaps.map((g) => (
                <li
                  key={`${g.gap}-${g.ref}`}
                  className="flex items-start gap-2 rounded-xl border border-red-500/20 bg-red-500/5 p-3 text-sm"
                >
                  <AlertTriangle className="mt-0.5 h-4 w-4 text-red-500" />
                  <span>
                    <span className="font-medium">{g.gap}</span> · {g.ref}
                    {g.detail ? ` — ${g.detail}` : ""}
                  </span>
                </li>
              ))}
            </ul>
          )}
        </section>
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
