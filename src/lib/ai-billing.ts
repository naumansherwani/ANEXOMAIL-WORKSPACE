/**
 * Phase 19 — AI Credits & Billing (transport only).
 *
 * AI LOCK: wallet, credits, top-ups sab ai.anexomail.com ka hissa hain.
 * anexomail.com ke Basic/Pro/Business plans mein AI kabhi nahi.
 * NO DUPLICATE: pricing, blended cost, renewal aur ledger sab server par
 * (Server 2 -> Supabase 4). Founder charge zero — cost sirf dikhta hai.
 * NO MOCK: endpoint missing = honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type AiWallet = {
  plan: string | null;
  unlimited: boolean;
  founder: boolean;
  balance: number;
  monthly_grant: number;
  complimentary: number;
  spent_today: number;
  spent_month: number;
  currency: string;
  renews_at: string | null;
  burn_per_day: number;
  runway_days: number | null;
};

export type CreditEvent = {
  id: string;
  kind: "grant" | "spend" | "topup" | "refund" | "expiry";
  credits: number;
  cost: number;
  currency: string;
  model: string | null;
  surface: string | null;
  note: string | null;
  created_at: string;
};

export type UsagePoint = { day: string; credits: number; cost: number; calls: number };

export type UsageBySurface = { surface: string; credits: number; cost: number; share: number };

export type TopUpPack = {
  id: string;
  credits: number;
  price: number;
  currency: string;
  bonus: number;
  best_value: boolean;
};

export type CheckoutResult = {
  id: string;
  state: "sandbox" | "paid" | "pending";
  credits: number;
  charged: number;
  currency: string;
  note: string | null;
};

const get = <T,>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path }, input);

export function useAiWallet() {
  return useQuery<AiWallet, ApiError>({
    queryKey: ["ai-billing", "wallet"],
    queryFn: () => get<AiWallet>("aiBilling.wallet", "/api/ai/billing/wallet"),
    retry: false,
  });
}

export function useCreditHistory() {
  return useQuery<{ events: CreditEvent[] }, ApiError>({
    queryKey: ["ai-billing", "history"],
    queryFn: () => get<{ events: CreditEvent[] }>("aiBilling.history", "/api/ai/billing/history"),
    retry: false,
  });
}

export function useUsageAnalytics(days = 30) {
  return useQuery<
    { series: UsagePoint[]; by_surface: UsageBySurface[]; total_credits: number; total_cost: number; currency: string },
    ApiError
  >({
    queryKey: ["ai-billing", "usage", days],
    queryFn: () =>
      get("aiBilling.usage", `/api/ai/billing/usage?days=${days}`, { days }),
    retry: false,
  });
}

export function useTopUpPacks() {
  return useQuery<{ packs: TopUpPack[] }, ApiError>({
    queryKey: ["ai-billing", "packs"],
    queryFn: () => get<{ packs: TopUpPack[] }>("aiBilling.packs", "/api/ai/billing/packs"),
    retry: false,
  });
}

/** Founder sandbox checkout — server records the intent, charge stays zero. */
export function useCheckout() {
  const qc = useQueryClient();
  return useMutation<CheckoutResult, ApiError, { pack_id: string; sandbox?: boolean }>({
    mutationFn: (body) =>
      rpcOrRest<CheckoutResult>(
        "aiBilling.checkout",
        { path: "/api/ai/billing/checkout", method: "POST", body },
        body,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["ai-billing", "wallet"] });
      void qc.invalidateQueries({ queryKey: ["ai-billing", "history"] });
    },
  });
}

/** Founder-only: spend cap per day for a tenant (server enforces, UI only asks). */
export function useSetSpendCap() {
  const qc = useQueryClient();
  return useMutation<{ cap: number }, ApiError, { cap: number }>({
    mutationFn: (body) =>
      rpcOrRest<{ cap: number }>(
        "aiBilling.setCap",
        { path: "/api/ai/billing/cap", method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai-billing", "wallet"] }),
  });
}

export const money = (value: number, currency = "GBP") =>
  `${currency === "GBP" ? "£" : `${currency} `}${value.toFixed(value < 10 ? 4 : 2)}`;
