/**
 * ANEXOVideoCall PHASE 31 — CALL BUSINESS RECORD · client transport.
 *
 * PRIMARY = Rust /rpc/call.record* (:3200 + QUIC/WT); Bun /api/chat/call/*
 * sirf fallback.
 *
 * LOCKED: duration join/leave events se measured hai (estimate nahi), "join hi
 * nahi kiya" bhi likha jata hai, in-call file wahi scanned→verified evidence
 * chain se guzarti hai, aur relay honesty apne coturn ki hai — koi Zoom/Agora/
 * Twilio nahi.
 */
import { useQuery } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export type JoinTruth = {
  user_id: string;
  event: "invited" | "ringing" | "joined" | "rejoined" | "left" | "never_joined" | "declined";
  at_ms: number;
  transport: string | null;
  path: "p2p" | "relay" | "unknown" | null;
};

export type CallRecord = {
  allowed?: boolean;
  found?: boolean;
  reason?: string;
  measured_not_estimated?: boolean;
  call?: {
    id: string;
    conversation_id: string | null;
    started_by: string | null;
    started_at: string;
    ended_at: string | null;
    setup_ms: number | null;
    signaling: string | null;
    path: string | null;
    video_codec: string | null;
    ice_restarts: number | null;
    end_reason: string | null;
  };
  duration_ms?: number | null;
  duration_source?: string;
  join_truth?: JoinTruth[];
  never_joined?: string[];
  transport_switches?: {
    path: "p2p" | "relay" | "unknown";
    relay_host: string | null;
    reason: string | null;
    at_ms: number;
  }[];
  files?: {
    version_id: string;
    shared_by: string | null;
    at_ms: number;
    sha256: string | null;
    bytes: number | null;
    name: string | null;
    evidence: { state: string; at: string }[] | null;
  }[];
  work?: {
    object_type: "work_item" | "decision";
    object_id: string;
    created_by: string | null;
    note: string | null;
    at_ms: number;
  }[];
};

export function useCallRecord(sessionId: string | null) {
  return useQuery<CallRecord, ApiError>({
    queryKey: ["chat", "call-record", sessionId],
    queryFn: () =>
      chatCall(
        "call.record",
        { session_id: sessionId },
        { path: `/api/chat/call/record/${sessionId}` },
      ),
    enabled: !!sessionId,
    retry: false,
  });
}

export type CallBoard = {
  allowed?: boolean;
  reason?: string;
  calls?: {
    id: string;
    started_at: string;
    ended_at: string | null;
    started_by: string | null;
    path: string | null;
    signaling: string | null;
    joins: number;
    never_joined: number;
    files: number;
    work: number;
  }[];
};

export function useCallBoard(conversationId: string | null = null, limit = 20) {
  return useQuery<CallBoard, ApiError>({
    queryKey: ["chat", "call-board", conversationId, limit],
    queryFn: () =>
      chatCall(
        "call.record.board",
        { conversation_id: conversationId, limit },
        {
          path: `/api/chat/call/records?limit=${limit}${
            conversationId ? `&c=${conversationId}` : ""
          }`,
        },
      ),
    retry: false,
  });
}
