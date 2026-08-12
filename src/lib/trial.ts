/**
 * Phase 32 — TRIAL LIFECYCLE (transport only).
 *
 * FOUNDER LOCK: sach DB mein hai. Yeh file kabhi decide nahi karti ke trial
 * bacha hai ya nahi — `public.account_state()` ka jawab jaisa aata hai waisa
 * dikhata hai. Client timer sirf display; devtools se badalne se kuch nahi hota.
 * NO MOCK: endpoint na mile to honest state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, type ApiError } from "@/lib/api";

export type AccountState = {
  state: "none" | "trial" | "active" | "expired" | "frozen" | "released";
  plan: "basic" | "pro" | "business" | null;
  hours_left: number;
  trial_ends_at: string | null;
  can_social_login: boolean;
  recovery_access: boolean;
  billing_access: boolean;
  business_data: boolean;
  /** Trial / expired / frozen = hard zero. Sirf active plan pe AI. */
  ai_enabled: boolean;
  address: string | null;
  address_reserved_days_left: number | null;
  needs_claim: boolean;
  needs_passkey: boolean;
  needs_recovery: boolean;
};

export type TrialEvent = {
  id: string;
  event_type: string;
  detail: Record<string, unknown>;
  created_at: string;
};

export type MailHold = {
  id: string;
  from_address: string | null;
  subject: string | null;
  disposition: "held" | "rejected" | "delivered";
  reason: string | null;
  received_at: string;
  released_at: string | null;
};

export function useAccountState() {
  return useQuery<AccountState, ApiError>({
    queryKey: ["trial", "state"],
    queryFn: () => api<AccountState>("/api/trial/state"),
    retry: false,
    // Server authority ko har 5 min refresh — timer chalta rehta hai display mein.
    staleTime: 60_000,
    refetchInterval: 5 * 60_000,
  });
}

export function useTrialEvents() {
  return useQuery<{ events: TrialEvent[] }, ApiError>({
    queryKey: ["trial", "events"],
    queryFn: () => api<{ events: TrialEvent[] }>("/api/trial/events"),
    retry: false,
  });
}

export function useMailHolds() {
  return useQuery<{ holds: MailHold[] }, ApiError>({
    queryKey: ["trial", "mail-holds"],
    queryFn: () => api<{ holds: MailHold[] }>("/api/trial/mail-holds"),
    retry: false,
  });
}

export function useAddressCheck(handle: string) {
  const clean = handle.trim().toLowerCase();
  return useQuery<
    { handle: string; available: boolean; reason?: string; address?: string },
    ApiError
  >({
    queryKey: ["trial", "address", clean],
    queryFn: () => api(`/api/trial/address?handle=${encodeURIComponent(clean)}`),
    enabled: clean.length >= 3,
    retry: false,
  });
}

function useInvalidateState() {
  const qc = useQueryClient();
  return () => qc.invalidateQueries({ queryKey: ["trial"] });
}

export function useStartTrial() {
  const done = useInvalidateState();
  return useMutation<AccountState, ApiError, { provider: string }>({
    mutationFn: (body) =>
      api<AccountState>("/api/trial/start", { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => void done(),
  });
}

export function useClaimAddress() {
  const done = useInvalidateState();
  return useMutation<{ ok: boolean; state: AccountState }, ApiError, { handle: string }>({
    mutationFn: (body) =>
      api("/api/trial/claim", { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => void done(),
  });
}

export function useSetSecurity() {
  const done = useInvalidateState();
  return useMutation<
    AccountState,
    ApiError,
    { passkey?: boolean; recovery_kind?: string; recovery_hint?: string }
  >({
    mutationFn: (body) =>
      api<AccountState>("/api/trial/security", { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => void done(),
  });
}

export function useSubscribe() {
  const done = useInvalidateState();
  return useMutation<
    { ok: boolean; state: AccountState },
    ApiError,
    { plan: "basic" | "pro" | "business"; payment_ref: string }
  >({
    mutationFn: (body) =>
      api("/api/trial/subscribe", { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => void done(),
  });
}

/** Sirf display formatting — koi faisla nahi. */
export function formatHoursLeft(hours: number): string {
  if (hours <= 0) return "0m";
  const h = Math.floor(hours);
  const m = Math.round((hours - h) * 60);
  if (h <= 0) return `${m}m`;
  return `${h}h ${String(m).padStart(2, "0")}m`;
}
