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

export type IntegrityState =
  | "clean"
  | "suspicious"
  | "warned"
  | "blocked"
  | "released"
  | "purged";

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
