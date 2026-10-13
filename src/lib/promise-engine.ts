/**
 * ANEXOCHAT — PHASE 23 PROMISE RECOVERY ENGINE (client)
 *
 * Promise → deadline → reminder → deadline change (reason ke saath) →
 * reassignment → downstream impact → kept/cancelled.
 *
 * PRIMARY = Rust /rpc/chat.promise.* , Bun /api/chat/promises/* sirf fallback.
 * Engine khud kabhi deadline nahi badalti aur khud reminder nahi bhejti:
 * har action insaan karta hai, reason ke saath, aur ledger append-only hai.
 * "Kept" bina evidence namumkin — server hi mana kar deta hai.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export type PromiseState = "pending" | "due_soon" | "overdue" | "kept" | "kept_late" | "cancelled";

export const PROMISE_TONE: Record<PromiseState, string> = {
  pending: "text-muted-foreground",
  due_soon: "text-amber-400",
  overdue: "text-red-400",
  kept: "text-emerald-400",
  kept_late: "text-amber-400",
  cancelled: "text-steel",
};

export const PROMISE_LABEL: Record<PromiseState, string> = {
  pending: "Open",
  due_soon: "Due soon",
  overdue: "Overdue",
  kept: "Kept",
  kept_late: "Kept late",
  cancelled: "Cancelled",
};

export type PromiseItem = {
  id: string;
  title: string;
  state: "open" | "blocked" | "done" | "cancelled";
  promise_state: PromiseState;
  owner_user_id: string | null;
  original_owner_id: string | null;
  due_at: string | null;
  original_due_at: string | null;
  slipped_by_hours: number;
  deadline_changes: number;
  reminders_sent: number;
  reassignments: number;
  downstream_impact: string | null;
  conversation_id: string;
  message_id: string | null;
  created_at: string;
  completed_at: string | null;
  evidence_count: number;
  last_action: string | null;
};

export type PromiseBoard = {
  plan: { plan: string; allowed: boolean; note?: string | null };
  reassign: { plan: string; allowed: boolean };
  summary: {
    open?: number;
    overdue?: number;
    due_soon?: number;
    kept?: number;
    kept_late?: number;
    cancelled?: number;
    slipped?: number;
  };
  items: PromiseItem[];
};

export type PromiseHistory = {
  item: {
    id: string;
    title: string;
    state: string;
    promise_state: PromiseState;
    owner_user_id: string | null;
    original_owner_id: string | null;
    due_at: string | null;
    original_due_at: string | null;
    deadline_changes: number;
    reminders_sent: number;
    reassignments: number;
    downstream_impact: string | null;
    cancel_reason: string | null;
    completed_at: string | null;
  };
  provenance: Record<string, unknown>;
  log: {
    action: string;
    reason: string | null;
    prev: Record<string, unknown>;
    next: Record<string, unknown>;
    actor_id: string | null;
    at: string;
  }[];
  evidence: { kind: string; ref: string; sha256: string | null; at: string }[];
  append_only: boolean;
};

export type RecoveryAction = "remind" | "deadline_change" | "reassign" | "impact_set" | "cancelled";

export type RecoveryResult = {
  ok: boolean;
  action?: RecoveryAction;
  error?: string;
  message?: string;
  plan?: string;
  message_id?: string;
  body?: string;
  from?: string | null;
  to?: string | null;
};

/* ── reads ─────────────────────────────────────────────────────────── */

export function usePromiseBoard(enabled = true) {
  return useQuery<PromiseBoard, ApiError>({
    queryKey: ["chat", "promise", "board"],
    queryFn: () => chatCall("chat.promise.board", undefined, { path: "/api/chat/promises/board" }),
    enabled,
    retry: false,
    refetchInterval: 30_000,
  });
}

export function usePromiseHistory(itemId: string | null) {
  return useQuery<PromiseHistory, ApiError>({
    queryKey: ["chat", "promise", "history", itemId],
    queryFn: () =>
      chatCall(
        "chat.promise.history",
        { item_id: itemId },
        { path: `/api/chat/promises/history?item_id=${encodeURIComponent(itemId!)}` },
      ),
    enabled: Boolean(itemId),
    retry: false,
  });
}

/* ── actions (hamesha insaani) ─────────────────────────────────────── */

export function usePromiseRecover() {
  const qc = useQueryClient();
  return useMutation<
    RecoveryResult,
    ApiError,
    {
      item_id: string;
      action: RecoveryAction;
      reason?: string | undefined;
      new_due_at?: string | undefined;
      new_owner_id?: string | undefined;
      downstream_impact?: string | undefined;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.promise.recover", input, {
        path: "/api/chat/promises/recover",
        method: "POST",
        body: input,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["chat", "promise"] });
      void qc.invalidateQueries({ queryKey: ["chat", "work"] });
    },
  });
}

/** Kept sirf evidence ke saath — warna server `evidence_required` deta hai. */
export function usePromiseKeep() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; error?: string; message?: string; evidence_count?: number },
    ApiError,
    {
      item_id: string;
      evidence?: { kind: "file" | "link" | "note" | "message"; ref: string } | undefined;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.promise.keep", input, {
        path: "/api/chat/promises/keep",
        method: "POST",
        body: input,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["chat", "promise"] });
      void qc.invalidateQueries({ queryKey: ["chat", "work"] });
    },
  });
}

/* ── device ban appeal (ban device par, network par kabhi nahi) ─────── */

export type DeviceAppeal = {
  id: string;
  device_hash: string;
  user_id: string;
  statement: string;
  state: "new" | "reviewing" | "granted" | "denied";
  created_at: string;
  decision_reason: string | null;
  decided_at: string | null;
};

export function useDeviceAppealQueue(state?: DeviceAppeal["state"] | "all") {
  return useQuery<{ allowed: boolean; appeals: DeviceAppeal[] }, ApiError>({
    queryKey: ["chat", "device", "appeals", state ?? "all"],
    queryFn: () =>
      chatCall(
        "chat.device.appeal.queue",
        { state: state && state !== "all" ? state : null },
        { path: `/api/chat/devices/appeals?state=${state ?? "all"}` },
      ),
    retry: false,
  });
}

export function useOpenDeviceAppeal() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; appeal_id?: string; error?: string; message?: string },
    ApiError,
    { device_hash: string; statement: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.device.appeal", input, {
        path: "/api/chat/devices/appeal",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "device"] }),
  });
}

export function useDecideDeviceAppeal() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; error?: string; message?: string; state?: string },
    ApiError,
    { appeal_id: string; decision: "reviewing" | "granted" | "denied"; reason?: string | undefined }
  >({
    mutationFn: (input) =>
      chatCall("chat.device.appeal.decide", input, {
        path: "/api/chat/devices/appeals/decide",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "device"] }),
  });
}
