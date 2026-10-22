/**
 * ACCOUNT INTEGRITY — one person, one account (client transport only).
 *
 * PRIMARY = Rust /rpc/account.integrity.* , Bun /api/chat/integrity/* fallback.
 *
 * LOCKED TRUTH:
 *  - Detection sirf device shape (sealed hash) par hoti hai. IP, network ya WiFi
 *    par kabhi block nahi — shared office/cafe machine kisi doosre ki saza na uthaye.
 *  - Engine khud kisi ko block nahi karti: suspicious sirf nishan hai. Final
 *    warning aur block insaan karta hai, likhi hui wajah ke saath.
 *  - Block hone par 72 ghante poora export khula rehta hai; usi ke baad delete.
 *  - Yeh file koi faisla nahi karti, sirf server ka sach dikhati hai.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export type IntegrityState = "clean" | "suspicious" | "warned" | "blocked" | "released" | "purged";

export const INTEGRITY_LABEL: Record<IntegrityState, string> = {
  clean: "Good standing",
  suspicious: "Flagged for review",
  warned: "Final warning issued",
  blocked: "Account blocked",
  released: "Restored after review",
  purged: "Data permanently deleted",
};

export const INTEGRITY_TONE: Record<IntegrityState, string> = {
  clean: "text-emerald-400",
  suspicious: "text-amber-400",
  warned: "text-amber-400",
  blocked: "text-red-400",
  released: "text-emerald-400",
  purged: "text-steel",
};

export type IntegrityPolicy = {
  max_accounts_per_device: number;
  signup_window_hours: number;
  max_signups_in_window: number;
  export_window_hours: number;
  ban_scope: string;
  warning_required: boolean;
};

export type IntegrityStatus = {
  policy: IntegrityPolicy;
  state: IntegrityState;
  reason: string | null;
  evidence: { signals?: string[]; device_hash_prefix?: string | null };
  accounts_on_device: number;
  signups_in_window: number;
  warned_at: string | null;
  blocked_at: string | null;
  export_until: string | null;
  export_hours_left: number | null;
  purge_after: string | null;
  purged_at: string | null;
  appeal: { id: string; state: string; created_at: string; decision_reason: string | null } | null;
  timeline: {
    event: string;
    actor: string;
    reason: string | null;
    detail: Record<string, unknown>;
    at: string;
  }[];
  append_only: boolean;
};

export type IntegrityQueue = {
  allowed: boolean;
  accounts: {
    user_id: string;
    state: IntegrityState;
    reason: string | null;
    evidence: { signals?: string[]; device_hash_prefix?: string | null };
    accounts_on_device: number;
    signups_in_window: number;
    warned_at: string | null;
    blocked_at: string | null;
    export_until: string | null;
    purge_after: string | null;
    updated_at: string;
  }[];
};

export type IntegrityResult = {
  ok: boolean;
  state?: IntegrityState;
  error?: string;
  message?: string;
  next_step?: string;
  devices_banned?: number;
  export_until?: string;
  export_hours?: number;
  appealable?: boolean;
};

/* ── reads ──────────────────────────────────────────────────────────── */

export function useIntegrityStatus(enabled = true) {
  return useQuery<IntegrityStatus, ApiError>({
    queryKey: ["account", "integrity", "state"],
    queryFn: () =>
      chatCall("account.integrity.state", undefined, { path: "/api/chat/integrity/state" }),
    enabled,
    retry: false,
  });
}

export function useIntegrityQueue(state: string = "all", enabled = true) {
  return useQuery<IntegrityQueue, ApiError>({
    queryKey: ["account", "integrity", "queue", state],
    queryFn: () =>
      chatCall(
        "account.integrity.queue",
        { state },
        { path: `/api/chat/integrity/queue?state=${encodeURIComponent(state)}` },
      ),
    enabled,
    retry: false,
  });
}

/* ── writes (har ek insaan ka amal) ─────────────────────────────────── */

/** Sign-in ke baad deterministic check. Sirf nishan lagata hai, block kabhi nahi. */
export function useIntegrityEvaluate() {
  const qc = useQueryClient();
  return useMutation<IntegrityResult, ApiError, { device_hash?: string | null }>({
    mutationFn: (input) =>
      chatCall("account.integrity.evaluate", input, {
        path: "/api/chat/integrity/evaluate",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["account", "integrity"] }),
  });
}

function reviewerAction(kind: "warn" | "block" | "release") {
  return function useAction() {
    const qc = useQueryClient();
    return useMutation<IntegrityResult, ApiError, { user_id: string; reason: string }>({
      mutationFn: (input) =>
        chatCall(`account.integrity.${kind}`, input, {
          path: `/api/chat/integrity/${kind}`,
          method: "POST",
          body: input,
        }),
      onSuccess: () => void qc.invalidateQueries({ queryKey: ["account", "integrity"] }),
    });
  };
}

/** Ek hi final warning — dobara warning nahi, agla qadam block. */
export const useIntegrityWarn = reviewerAction("warn");
/** Warning ke baad hi block; 72h export window khud khul jati hai. */
export const useIntegrityBlock = reviewerAction("block");
/** Ghalat block ya appeal granted — device ban bhi uthta hai. */
export const useIntegrityRelease = reviewerAction("release");

/** Blocked account ka export: window band ho gayi to server saaf mana karta hai. */
export function useIntegrityExport() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; blocked: boolean; export_open: boolean; hours_left?: number; error?: string },
    ApiError,
    void
  >({
    mutationFn: () =>
      chatCall("account.integrity.export", undefined, {
        path: "/api/chat/integrity/export",
        method: "POST",
        body: {},
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["account", "integrity"] }),
  });
}

/* ── Identity vault (E68): founder ka ek-nazar hisaab + logged-out appeals ── */
export type IdentityOverview = {
  allowed: boolean;
  bans_active?: number;
  bans_permanent?: number;
  bans_expiring_30d?: number;
  bans_by_reason?: Record<string, number>;
  signups_denied_30d?: number;
  signups_review_30d?: number;
  appeals_open?: number;
  health_alert?: boolean;
  health?: { source: string; age_s: number; outbox_pending: number; check_failures_1h: number; mirror_size: number; mirror_age_s: number; mode: string }[];
  appeals?: { id: string; created_at: string; contact: string; statement: string }[];
  /** E70 hardening */
  gate?: { mode: SignupGate; changed_at: string | null; disposable_block: boolean; probation_days: number; hold_expire_days: number; fp_match_min: number; evasion?: EvasionMode; fp_min_usable?: number };
  holds_pending?: number;
  holds_30d?: number;
  holds?: { account_id: string; email: string | null; kind: "match" | "gate" | "manual" | "evasion" | null; reason: string | null; held_at: string; expires_at: string }[];
  disposable_domains?: number;
};

/** open = no extra step; hold_matches = a sign-up that matches a blocked person's browser waits for you; approval_all = every new sign-up waits for you. */
export type SignupGate = "open" | "hold_matches" | "approval_all";
/** What to do with a sign-up whose browser hid its fingerprint (privacy browsers, noise, scripts that skip it). */
export type EvasionMode = "allow" | "review" | "hold";

export function useIdentityOverview(enabled = true) {
  return useQuery<IdentityOverview, ApiError>({
    queryKey: ["account", "integrity", "identity"],
    queryFn: () => chatCall("account.integrity.identity", undefined, { path: "/api/chat/integrity/identity" }),
    enabled,
    retry: false,
  });
}

export function useIdentityDecide() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; error?: string; lifted?: number },
    ApiError,
    { appeal_id: string; decision: "granted" | "denied"; reason: string }
  >({
    mutationFn: (input) =>
      chatCall("account.integrity.identity.decide", input, {
        path: "/api/chat/integrity/identity/decide",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["account", "integrity"] }),
  });
}

/* ── Identity hardening (E70): hold queue, sign-up gate, disposable-email list ── */
type Done = { allowed?: boolean; ok?: boolean; error?: string; state?: string; gate?: SignupGate; evasion?: EvasionMode; banned?: boolean };

export function useIdentityHold() {
  const qc = useQueryClient();
  return useMutation<Done, ApiError, { account_id: string; decision: "approve" | "reject"; ban?: boolean; note?: string }>({
    mutationFn: (input) =>
      chatCall("account.integrity.identity.hold", input, { path: "/api/chat/integrity/identity/hold", method: "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["account", "integrity"] }),
  });
}

export function useIdentityGate() {
  const qc = useQueryClient();
  return useMutation<Done, ApiError, { mode: SignupGate }>({
    mutationFn: (input) =>
      chatCall("account.integrity.identity.gate", input, { path: "/api/chat/integrity/identity/gate", method: "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["account", "integrity"] }),
  });
}

export function useIdentityEvasion() {
  const qc = useQueryClient();
  return useMutation<Done, ApiError, { mode: EvasionMode }>({
    mutationFn: (input) =>
      chatCall("account.integrity.identity.evasion", input, { path: "/api/chat/integrity/identity/evasion", method: "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["account", "integrity"] }),
  });
}

export function useIdentityDomain() {
  const qc = useQueryClient();
  return useMutation<Done, ApiError, { domain: string; on?: boolean }>({
    mutationFn: (input) =>
      chatCall("account.integrity.identity.domain", input, { path: "/api/chat/integrity/identity/domain", method: "POST", body: input }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["account", "integrity"] }),
  });
}
