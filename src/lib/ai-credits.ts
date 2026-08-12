/**
 * Phase 31 — AI CREDIT ENGINE (transport only).
 *
 * FOUNDER LOCK: Supabase #4 = source of truth. Ledger immutable.
 * Credits sirf backend RPC badalta hai — yeh file kabhi math nahi karti.
 * Frontend = display + approval. NO MOCK: endpoint missing = honest state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type CreditWallet = {
  workspace_id: string;
  plan_id: string | null;
  subscription_credits: number;
  topup_credits: number;
  complimentary_credits: number;
  reserved_credits: number;
  total_balance: number;
  currency: string;
  cycle_started_at: string;
  renews_at: string | null;
};

export type LedgerEntry = {
  id: string;
  credit_type: "subscription" | "topup" | "complimentary" | "reserved";
  entry_type: string;
  amount: number;
  balance_before: number;
  balance_after: number;
  reason: string | null;
  model: string | null;
  created_at: string;
};

export type CreditAction = {
  id: string;
  action_type: string;
  model: string | null;
  status: string;
  estimated_credits_min: number | null;
  estimated_credits_max: number | null;
  reserved_credits: number;
  actual_credits: number | null;
  latency_ms: number | null;
  created_at: string;
  completed_at: string | null;
};

export type CreditProducts = {
  plans: { id: string; name: string; price: number; monthly_credits: number }[];
  topups: { id: string; price: number; credits: number; price_per_credit: number }[];
  bands: { action: string; min: number; max: number }[];
  currency: string;
};

export type Estimate = {
  action_id: string;
  estimate: { min: number; max: number };
  balance: number;
  affordable: boolean;
  approval_required: boolean;
};

const get = <T,>(procedure: string, path: string) => rpcOrRest<T>(procedure, { path });
const post = <T,>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path, method: "POST" }, input);

export function useCreditProducts() {
  return useQuery<CreditProducts, ApiError>({
    queryKey: ["ai-credits", "products"],
    queryFn: () => get<CreditProducts>("aiCredits.products", "/api/ai/credits/products"),
    retry: false,
  });
}

export function useCreditWallet() {
  return useQuery<{ wallet: CreditWallet; complimentary_claimed: number[] }, ApiError>({
    queryKey: ["ai-credits", "wallet"],
    queryFn: () =>
      get<{ wallet: CreditWallet; complimentary_claimed: number[] }>(
        "aiCredits.wallet",
        "/api/ai/credits/wallet",
      ),
    retry: false,
  });
}

export function useCreditLedger(limit = 50) {
  return useQuery<{ entries: LedgerEntry[]; immutable: boolean }, ApiError>({
    queryKey: ["ai-credits", "ledger", limit],
    queryFn: () =>
      get<{ entries: LedgerEntry[]; immutable: boolean }>(
        "aiCredits.ledger",
        `/api/ai/credits/ledger?limit=${limit}`,
      ),
    retry: false,
  });
}

export function useCreditActions(limit = 50) {
  return useQuery<{ actions: CreditAction[] }, ApiError>({
    queryKey: ["ai-credits", "actions", limit],
    queryFn: () =>
      get<{ actions: CreditAction[] }>(
        "aiCredits.actions",
        `/api/ai/credits/actions?limit=${limit}`,
      ),
    retry: false,
  });
}

/** Pre-flight: har AI action se PEHLE estimate + approval. */
export function useEstimateAction() {
  return useMutation<
    Estimate,
    ApiError,
    { action_type: string; model?: string; input_tokens?: number; output_tokens?: number }
  >({
    mutationFn: (input) => post<Estimate>("aiCredits.estimate", "/api/ai/credits/estimate", input),
  });
}

export function useReserveCredits() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; balance: number },
    ApiError,
    { action_id: string; credits: number; idempotency_key: string }
  >({
    mutationFn: (input) => post("aiCredits.reserve", "/api/ai/credits/reserve", input),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai-credits"] }),
  });
}

export function useSettleCredits() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; balance: number },
    ApiError,
    {
      action_id: string;
      actual_credits: number;
      model?: string;
      provider_cost?: number;
      idempotency_key?: string;
    }
  >({
    mutationFn: (input) => post("aiCredits.settle", "/api/ai/credits/settle", input),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai-credits"] }),
  });
}

export function useReleaseCredits() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; balance: number },
    ApiError,
    { action_id: string; reason?: string }
  >({
    mutationFn: (input) => post("aiCredits.release", "/api/ai/credits/release", input),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai-credits"] }),
  });
}

export function useClaimComplimentary() {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean; balance: number }, ApiError, { day: 1 | 2 }>({
    mutationFn: (input) => post("aiCredits.complimentary", "/api/ai/credits/complimentary", input),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai-credits"] }),
  });
}

/**
 * Top-up: credits sirf verified payment ke baad milte hain.
 * Checkout (Polar) pending hai — backend 402 payment_required deta hai, aur
 * UI wahi imandar message dikhata hai. Koi fake grant nahi.
 */
export function useTopUp() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; balance: number },
    ApiError,
    { product_id: string; idempotency_key: string }
  >({
    mutationFn: (input) => post("aiCredits.topup", "/api/ai/credits/topup", input),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai-credits"] }),
  });
}
