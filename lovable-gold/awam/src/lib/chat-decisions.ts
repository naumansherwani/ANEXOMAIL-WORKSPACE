/**
 * PHASE 24 — DECISION LEDGER + DECISION IMPACT MAP (client transport only).
 *
 * PRIMARY = Rust /rpc/chat.decision.* , Bun /api/chat/decisions/* fallback.
 *
 * LOCKED TRUTH:
 *  - Ek decision hamesha ek ASLI message se banti hai: maker, UTC timestamp,
 *    source conversation aur body_hash provenance. Bina message koi decision nahi.
 *  - History KABHI overwrite nahi hoti. Tabdeeli naya version row banati hai;
 *    purana version hamesha padha ja sakta hai.
 *  - Impact map sirf insaani link se banta hai. "Potentially affected" alag
 *    khaana hai — woh sirf ishaara hai, link nahi, aur engine kabhi khud
 *    dependency invent nahi karti.
 *  - Yeh file koi faisla nahi karti, sirf server ka sach dikhati hai.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export type DecisionState = "active" | "superseded" | "reversed";
export type DecisionObjectType =
  "task" | "promise" | "decision" | "conversation" | "file" | "message";

export const DECISION_LABEL: Record<DecisionState, string> = {
  active: "Standing decision",
  superseded: "Replaced by a later decision",
  reversed: "Reversed",
};

export const DECISION_TONE: Record<DecisionState, string> = {
  active: "text-emerald-400",
  superseded: "text-amber-400",
  reversed: "text-red-400",
};

export type DecisionRow = {
  id: string;
  title: string;
  detail: string | null;
  state: DecisionState;
  version: number;
  decided_at: string;
  made_by: string;
  made_by_email: string | null;
  recorded_at: string;
  source: string;
  conversation_id: string;
  message_id: string;
  body_hash: string;
  affects_count: number;
  open_affected: number;
};

export type DecisionBoard = {
  plan: boolean;
  impact: boolean;
  summary: {
    total?: number;
    active?: number;
    superseded?: number;
    reversed?: number;
    amended?: number;
  };
  decisions: DecisionRow[];
};

export type DecisionAffected = {
  link_id: string;
  object_type: DecisionObjectType;
  object_id: string;
  relation: string;
  note: string | null;
  link_reason: string;
  linked_at: string;
  label: string | null;
  object_state: string | null;
  due_at: string | null;
};

export type DecisionImpact = {
  decision_id?: string;
  title?: string;
  state?: DecisionState;
  version?: number;
  decided_at?: string;
  impact_allowed: boolean;
  /** Server ka saaf iqrar: engine khud koi dependency nahi banati. */
  engine_invents_links: boolean;
  affects: DecisionAffected[];
  potentially_affected: {
    object_type: "task" | "promise";
    object_id: string;
    label: string;
    object_state: string;
    due_at: string | null;
    derived_from: string;
    linked: boolean;
  }[];
  removed_links: {
    object_type: DecisionObjectType;
    object_id: string;
    remove_reason: string | null;
    removed_at: string;
  }[];
  error?: string;
};

export type DecisionDetail = {
  decision: {
    id: string;
    title: string;
    detail: string | null;
    state: DecisionState;
    version: number;
    decided_at: string;
    made_by: string;
    made_by_email: string | null;
    recorded_by: string;
    recorded_at: string;
    source: string;
    conversation_id: string;
    message_id: string;
    work_item_id: string | null;
    body_hash: string;
    /** Message chhup jaye to bhi decision aur uska hash zinda rehta hai. */
    message_visible: boolean;
    superseded_by: string | null;
  };
  history: {
    version: number;
    title: string;
    detail: string | null;
    decided_at: string;
    state: DecisionState;
    change: "recorded" | "amended" | "superseded" | "reversed";
    reason: string | null;
    changed_by: string | null;
    at: string;
  }[];
  impact: DecisionImpact;
  ledger: {
    event: string;
    reason: string | null;
    prev: Record<string, unknown>;
    next: Record<string, unknown>;
    actor_id: string | null;
    at: string;
  }[];
  error?: string;
};

export type DecisionResult = {
  ok: boolean;
  decision_id?: string;
  work_item_id?: string | null;
  link_id?: string;
  version?: number;
  previous_version?: number;
  state?: DecisionState;
  title?: string;
  decided_at?: string;
  made_by?: string;
  body_hash?: string;
  error?: string;
  message?: string;
};

/* ── reads ──────────────────────────────────────────────────────────── */

export function useDecisionBoard(conversationId?: string | null, enabled = true) {
  return useQuery<DecisionBoard, ApiError>({
    queryKey: ["chat", "decisions", "board", conversationId ?? "all"],
    queryFn: () =>
      chatCall(
        "chat.decision.board",
        { conversation_id: conversationId ?? null },
        {
          path: conversationId
            ? `/api/chat/decisions/board?conversation_id=${encodeURIComponent(conversationId)}`
            : "/api/chat/decisions/board",
        },
      ),
    enabled,
    retry: false,
  });
}

export function useDecision(decisionId: string | null) {
  return useQuery<DecisionDetail, ApiError>({
    queryKey: ["chat", "decisions", "one", decisionId],
    queryFn: () =>
      chatCall(
        "chat.decision.state",
        { decision_id: decisionId },
        { path: `/api/chat/decisions/${decisionId}` },
      ),
    enabled: !!decisionId,
    retry: false,
  });
}

export function useDecisionImpact(decisionId: string | null) {
  return useQuery<DecisionImpact, ApiError>({
    queryKey: ["chat", "decisions", "impact", decisionId],
    queryFn: () =>
      chatCall(
        "chat.decision.impact",
        { decision_id: decisionId },
        { path: `/api/chat/decisions/${decisionId}/impact` },
      ),
    enabled: !!decisionId,
    retry: false,
  });
}

/* ── writes (har ek insaan ka amal) ─────────────────────────────────── */

/** "Mark as Decision" — sirf ek asli message par. */
export function useDecisionMark() {
  const qc = useQueryClient();
  return useMutation<
    DecisionResult,
    ApiError,
    { message_id: string; title?: string; detail?: string; decided_at?: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.decision.mark", input, {
        path: "/api/chat/decisions/mark",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "decisions"] }),
  });
}

/**
 * Amend / supersede / reverse — 12+ char wajah lazmi. Purani decision mitti
 * nahi: ledger mein naya version row banta hai.
 */
export function useDecisionAmend() {
  const qc = useQueryClient();
  return useMutation<
    DecisionResult,
    ApiError,
    {
      decision_id: string;
      reason: string;
      change?: "amended" | "superseded" | "reversed";
      title?: string;
      detail?: string;
      decided_at?: string;
      superseded_by?: string;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.decision.amend", input, {
        path: `/api/chat/decisions/${input.decision_id}/amend`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "decisions"] }),
  });
}

/** Impact link — 8+ char wajah ke saath, aur object asli hona chahiye. */
export function useDecisionLink() {
  const qc = useQueryClient();
  return useMutation<
    DecisionResult,
    ApiError,
    {
      decision_id: string;
      object_type: DecisionObjectType;
      object_id: string;
      reason: string;
      relation?: string;
      note?: string;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.decision.link", input, {
        path: `/api/chat/decisions/${input.decision_id}/link`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "decisions"] }),
  });
}

/** Link hatana bhi record hota hai — row delete nahi hoti, sirf removed. */
export function useDecisionUnlink() {
  const qc = useQueryClient();
  return useMutation<DecisionResult, ApiError, { link_id: string; reason: string }>({
    mutationFn: (input) =>
      chatCall("chat.decision.unlink", input, {
        path: `/api/chat/decisions/link/${input.link_id}/remove`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "decisions"] }),
  });
}
