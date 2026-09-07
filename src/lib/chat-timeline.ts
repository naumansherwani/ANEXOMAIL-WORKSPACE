/**
 * PHASE 25/26/27 — CONVERSATION → OUTCOME TIMELINE · CONVERSATION HEALTH +
 * COMMITMENT COLLISION · MESSAGE PROVENANCE (client transport only).
 *
 * PRIMARY = Rust /rpc/chat.timeline.* | chat.health.* | chat.provenance.* |
 * chat.collision.* ; Bun /api/chat/* sirf fallback.
 *
 * LOCKED TRUTH:
 *  - Timeline kuch INVENT nahi karti. Har event ka asli record hai (message ·
 *    file evidence · work item · decision version) aur communication ka lane
 *    business outcome se alag rehta hai.
 *  - Health sirf sabit cheez se banti hai: khula kaam · overdue deadline ·
 *    blocked dependency · jawab ka intezar — har status ke saath reasons[].
 *  - Collision engine dependency KABHI invent nahi karti; sirf woh rishta jo
 *    insaan ne likha. Har amal insaan ka, 8+ char wajah ke saath.
 *  - Provenance = sealed hash chain. "Integrity Verified" ka matlab sealed
 *    hash aaj ke body se match karta hai; edit hone par UI sach bolta hai.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

/* ── timeline ───────────────────────────────────────────────────────── */

export type TimelineLane = "communication" | "outcome";

export type TimelineLens =
  | "all"
  | "messages"
  | "files"
  | "tasks"
  | "promises"
  | "decisions"
  | "important"
  | "outcome";

export type TimelineEvent = {
  at: string;
  lane: TimelineLane;
  kind: string;
  label: string;
  detail: string | null;
  actor: string | null;
  object_id: string;
  object_type: string;
  important: boolean;
  evidence: Record<string, unknown>;
};

export type ConversationTimeline = {
  conversation_id?: string;
  title?: string;
  lens?: TimelineLens;
  events: TimelineEvent[];
  lanes?: { communication: string; outcome: string };
  engine_invents_nothing?: boolean;
  error?: string;
};

export const LENS_LABEL: Record<TimelineLens, string> = {
  all: "Everything",
  messages: "Messages",
  files: "Files",
  tasks: "Tasks",
  promises: "Promises",
  decisions: "Decisions",
  important: "Important",
  outcome: "Outcomes only",
};

export function useConversationTimeline(conversationId: string | null, lens: TimelineLens = "all") {
  return useQuery<ConversationTimeline, ApiError>({
    queryKey: ["chat", "timeline", conversationId, lens],
    queryFn: () =>
      chatCall(
        "chat.timeline.get",
        { conversation_id: conversationId, lens },
        { path: `/api/chat/timeline/${conversationId}?lens=${encodeURIComponent(lens)}` },
      ),
    enabled: !!conversationId,
    retry: false,
  });
}

/** Ek message ko "Important" nishan lagana / hatana — dono record hote hain. */
export function useMarkImportant() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; important?: boolean; error?: string },
    ApiError,
    { message_id: string; important?: boolean; reason?: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.timeline.important", input, {
        path: "/api/chat/timeline/important",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "timeline"] }),
  });
}

/* ── health ─────────────────────────────────────────────────────────── */

export type HealthState = "healthy" | "waiting" | "blocked" | "completed";

export type ConversationHealth = {
  conversation_id: string;
  title: string;
  state: HealthState;
  owner: string | null;
  due_at: string | null;
  open_items: number;
  blocked_items: number;
  overdue_items: number;
  total_items: number;
  last_message_at: string | null;
  reasons: { reason: string; evidence: string }[];
  chain: ChainAudit | null;
  error?: string;
};

export type HealthBoard = {
  plan: boolean;
  timeline: boolean;
  collision: boolean;
  conversations: ConversationHealth[];
};

export const HEALTH_LABEL: Record<HealthState, string> = {
  healthy: "On track",
  waiting: "Waiting",
  blocked: "Blocked",
  completed: "Completed",
};

export const HEALTH_TONE: Record<HealthState, string> = {
  healthy: "text-emerald-400",
  waiting: "text-amber-400",
  blocked: "text-red-400",
  completed: "text-steel",
};

export function useHealthBoard(enabled = true) {
  return useQuery<HealthBoard, ApiError>({
    queryKey: ["chat", "health", "board"],
    queryFn: () => chatCall("chat.health.board", {}, { path: "/api/chat/health/board" }),
    enabled,
    retry: false,
  });
}

export function useConversationHealth(conversationId: string | null) {
  return useQuery<ConversationHealth, ApiError>({
    queryKey: ["chat", "health", conversationId],
    queryFn: () =>
      chatCall(
        "chat.health.conversation",
        { conversation_id: conversationId },
        { path: `/api/chat/health/${conversationId}` },
      ),
    enabled: !!conversationId,
    retry: false,
  });
}

/* ── provenance ─────────────────────────────────────────────────────── */

export type MessageProvenance = {
  message_id: string;
  conversation_id: string;
  seq: number;
  sent_by: string | null;
  workspace: string | null;
  sent_at_utc: string;
  sent_at: string;
  transport: string;
  transport_label: string;
  device_label: string | null;
  recipients: number;
  delivery_confirmed: boolean;
  delivery_count: number;
  read_count: number;
  receipts: { user_id: string; state: "delivered" | "read"; at: string }[];
  sealed: boolean;
  seal_hash: string | null;
  chain_hash: string | null;
  prev_hash: string | null;
  sealed_at: string | null;
  current_hash: string;
  integrity_verified: boolean;
  edited: boolean;
  edited_at: string | null;
  visible: boolean;
  integrity_note: string;
  important: boolean;
  error?: string;
};

export type ChainAudit = {
  conversation_id?: string;
  sealed_messages: number;
  unsealed_messages: number;
  edited_after_sealing: number;
  chain_intact: boolean;
  first_break: { message_id: string; seq: number; expected: string; sealed: string } | null;
  head_hash: string | null;
  error?: string;
};

export function useMessageProvenance(messageId: string | null) {
  return useQuery<MessageProvenance, ApiError>({
    queryKey: ["chat", "provenance", "message", messageId],
    queryFn: () =>
      chatCall(
        "chat.provenance.message",
        { message_id: messageId },
        { path: `/api/chat/provenance/message/${messageId}` },
      ),
    enabled: !!messageId,
    retry: false,
  });
}

export function useConversationChain(conversationId: string | null, enabled = true) {
  return useQuery<ChainAudit, ApiError>({
    queryKey: ["chat", "provenance", "chain", conversationId],
    queryFn: () =>
      chatCall(
        "chat.provenance.chain",
        { conversation_id: conversationId },
        { path: `/api/chat/provenance/chain/${conversationId}` },
      ),
    enabled: enabled && !!conversationId,
    retry: false,
  });
}

/* ── commitment collisions ──────────────────────────────────────────── */

export type CollisionAction =
  | "resolve_dependency"
  | "change_deadline"
  | "reassign"
  | "dismiss"
  | "viewed_source";

export type Collision = {
  id: string;
  state: "open" | "resolved" | "dismissed";
  severity: "warning" | "critical";
  relation: "depends_on" | "decision_link";
  downstream: string | null;
  detected_at: string;
  item_id: string;
  blocker_id: string;
  conversation_id: string | null;
  source_message: string | null;
  evidence: {
    link?: string;
    why?: string;
    item?: { id: string; title: string; due_at: string | null; owner: string | null };
    blocker?: {
      id: string;
      title: string;
      kind: string;
      state: string;
      due_at: string | null;
      original_due_at: string | null;
      owner: string | null;
    };
  };
  log: { action: string; reason: string | null; at: string }[];
};

export type CollisionScan = {
  plan: boolean;
  /** Server ka saaf iqrar: engine khud koi dependency nahi banati. */
  engine_invents_dependencies?: boolean;
  scanned?: number;
  collisions: Collision[];
};

export function useCollisionScan(conversationId?: string | null, enabled = true) {
  return useQuery<CollisionScan, ApiError>({
    queryKey: ["chat", "collisions", conversationId ?? "all"],
    queryFn: () =>
      chatCall(
        "chat.collision.scan",
        { conversation_id: conversationId ?? null },
        {
          path: "/api/chat/collisions/scan",
          method: "POST",
          body: { conversation_id: conversationId ?? null },
        },
      ),
    enabled,
    retry: false,
  });
}

export function useCollisionAct() {
  const qc = useQueryClient();
  return useMutation<
    { ok: boolean; error?: string; message?: string; message_id?: string },
    ApiError,
    {
      collision_id: string;
      action: CollisionAction;
      reason?: string;
      new_due?: string;
      new_owner?: string;
    }
  >({
    mutationFn: (input) =>
      chatCall("chat.collision.act", input, {
        path: `/api/chat/collisions/${input.collision_id}/act`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["chat", "collisions"] });
      void qc.invalidateQueries({ queryKey: ["chat", "health"] });
      void qc.invalidateQueries({ queryKey: ["chat", "promises"] });
    },
  });
}
