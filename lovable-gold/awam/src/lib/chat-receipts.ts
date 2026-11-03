/**
 * PHASE 28 — BUSINESS CONVERSATION RECEIPTS + ZERO-LOSS HANDOVER PACK
 * (client transport only; truth Supabase #4 mein).
 *
 * PRIMARY = Rust /rpc/chat.receipt.* | chat.handover.* (:3200 + QUIC/WT);
 * Bun /api/chat/* sirf fallback.
 *
 * LOCKED TRUTH:
 *  - Har step ka asli record. Jo record nahi hua woh "Not recorded".
 *  - NEGATIVE RECEIPTS: jo nahi hua woh bhi dikhta hai (not delivered window,
 *    read-without-response) — measured silence, ilzaam nahi.
 *  - Per-device receipt sirf platform class + timezone bucket. Fingerprinting
 *    kabhi nahi.
 *  - Certificate mein message body kabhi nahi jati; sirf hashes + counts.
 *  - Handover pack missing context FABRICATE nahi karta.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export type ReceiptStep = {
  step: string;
  recorded: boolean;
  at: string | null;
  people?: number;
  of?: number;
  evidence: string | null;
};

export type NegativeReceipt = {
  user_id: string;
  person: string;
  state: "not_delivered" | "read_without_response";
  window_from?: string;
  window_to?: string;
  last_seen_at?: string | null;
  read_at?: string;
  hours_since?: number;
  note: string;
  evidence: string;
};

export type AttachmentReceipt = {
  version_id: string;
  filename: string;
  bytes: number;
  version_state: string;
  steps: ReceiptStep[] | null;
};

export type ReceiptPack = {
  message_id?: string;
  conversation_id?: string;
  recipients?: number;
  steps?: ReceiptStep[];
  negative_receipts?: NegativeReceipt[];
  attachments?: AttachmentReceipt[];
  engine_invents_nothing?: boolean;
  note?: string;
  error?: string;
};

export function useReceiptPack(messageId: string | null) {
  return useQuery<ReceiptPack, ApiError>({
    queryKey: ["chat", "receipts", "message", messageId],
    queryFn: () =>
      chatCall(
        "chat.receipt.pack",
        { message_id: messageId },
        { path: `/api/chat/receipts/message/${messageId}` },
      ),
    enabled: !!messageId,
    retry: false,
  });
}

export type SilentBoard = {
  hours?: number;
  items?: {
    message_id: string;
    conversation_id: string;
    title: string;
    reader: string;
    reader_id: string;
    read_at: string;
    hours_since: number;
    evidence: string;
  }[];
  note?: string;
  error?: string;
};

export function useReadWithoutResponse(hours = 24) {
  return useQuery<SilentBoard, ApiError>({
    queryKey: ["chat", "receipts", "silent", hours],
    queryFn: () =>
      chatCall(
        "chat.receipt.silent",
        { hours },
        { path: `/api/chat/receipts/silent?hours=${hours}` },
      ),
    retry: false,
  });
}

export type ReplayFrame = {
  at: string;
  kind: "sent" | "delivered" | "read";
  message_id: string;
  seq: number;
  actor: string;
  device?: { platform_class: string | null; timezone_bucket: string | null };
  evidence: string;
};

export type ReceiptReplay = {
  conversation_id?: string;
  frames?: ReplayFrame[];
  error?: string;
};

export function useReceiptReplay(conversationId: string | null) {
  return useQuery<ReceiptReplay, ApiError>({
    queryKey: ["chat", "receipts", "replay", conversationId],
    queryFn: () =>
      chatCall(
        "chat.receipt.replay",
        { conversation_id: conversationId },
        { path: `/api/chat/receipts/replay/${conversationId}` },
      ),
    enabled: !!conversationId,
    retry: false,
  });
}

export type CertificateResult = {
  ok?: boolean;
  certificate_id?: string;
  verify_token?: string;
  certificate_hash?: string;
  head_hash?: string;
  messages?: number;
  delivered?: number;
  read?: number;
  contains_message_bodies?: boolean;
  note?: string;
  error?: string;
};

export function useIssueCertificate() {
  return useMutation<CertificateResult, ApiError, { conversation_id: string }>({
    mutationFn: (input) =>
      chatCall("chat.receipt.certificate", input, {
        path: "/api/chat/receipts/certificate",
        method: "POST",
        body: input,
      }),
  });
}

/* ── zero-loss handover pack ─────────────────────────────────────────── */

export type HandoverStatus =
  "confirmed_fact" | "pending" | "overdue" | "historical_decision" | "open_dependency";

export const HANDOVER_STATUS_LABEL: Record<HandoverStatus, string> = {
  confirmed_fact: "Confirmed fact",
  pending: "Pending",
  overdue: "Overdue",
  historical_decision: "Historical decision",
  open_dependency: "Open dependency",
};

export type HandoverItem = {
  id: string;
  category: string;
  status: HandoverStatus;
  object_type: string;
  object_id: string;
  title: string;
  detail: string | null;
  source: string;
  evidence: Record<string, unknown>;
  due_at: string | null;
  assigned_to: string | null;
  accepted_at: string | null;
};

export type HandoverPack = {
  pack_id?: string;
  state?: string;
  scope?: string;
  outgoing_user?: string;
  incoming_user?: string | null;
  built_at?: string;
  completed_at?: string | null;
  items?: HandoverItem[];
  log?: { action: string; at: string; reason: string | null }[];
  error?: string;
};

export type HandoverBoard = {
  packs?: {
    pack_id: string;
    state: string;
    scope: string;
    outgoing: string;
    incoming: string | null;
    built_at: string;
    items: number;
    overdue: number;
  }[];
  allowed?: boolean;
  error?: string;
};

export function useHandoverBoard() {
  return useQuery<HandoverBoard, ApiError>({
    queryKey: ["chat", "handover", "board"],
    queryFn: () => chatCall("chat.handover.board", {}, { path: "/api/chat/handover/board" }),
    retry: false,
  });
}

export function useHandoverPack(packId: string | null) {
  return useQuery<HandoverPack, ApiError>({
    queryKey: ["chat", "handover", packId],
    queryFn: () =>
      chatCall("chat.handover.get", { pack_id: packId }, { path: `/api/chat/handover/${packId}` }),
    enabled: !!packId,
    retry: false,
  });
}

export function useBuildHandover() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; pack_id?: string; items?: number; error?: string },
    ApiError,
    { outgoing_user: string; scope?: string; scope_ref?: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.handover.build", input, {
        path: "/api/chat/handover/build",
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "handover"] }),
  });
}

export function useAssignHandover() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; error?: string },
    ApiError,
    { pack_id: string; incoming_user: string; reason: string; item_id?: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.handover.assign", input, {
        path: `/api/chat/handover/${input.pack_id}/assign`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "handover"] }),
  });
}

export function useCompleteHandover() {
  const qc = useQueryClient();
  return useMutation<
    { ok?: boolean; error?: string; count?: number },
    ApiError,
    { pack_id: string; reason: string }
  >({
    mutationFn: (input) =>
      chatCall("chat.handover.complete", input, {
        path: `/api/chat/handover/${input.pack_id}/complete`,
        method: "POST",
        body: input,
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["chat", "handover"] }),
  });
}
