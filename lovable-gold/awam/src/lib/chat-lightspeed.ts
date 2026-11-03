/**
 * ANEXOVIDEOCALL · PHASE 31A — LIGHT-SPEED CLIENT (Rust primary, Bun fallback)
 *
 * FOUNDER LOCK:
 *   - Har arm pehle Rust `/rpc/call.*` par jati hai; sirf 404/502/offline par
 *     Bun `/api/chat/call/*` fallback.
 *   - Ring truth: rang -> answered | declined | no_answer (45s/60s plan window).
 *     Jhoota "missed" kabhi nahi — 45s guzarne par hi no_answer.
 *   - Connect marks asli browser events se: prewarm, ICE gather, signal RTT,
 *     answer, ICE connected, pehli remote frame. Na mile to null jata hai.
 *   - SFU sirf apna engine (3+ log). TURN ko SFU kehna mamnu.
 *   - Survival: video gire to audio-only, reason ke saath — call zinda.
 */

import { chatCall } from "./chat-transport";

export type ConnectMark =
  | "prewarm_started"
  | "prewarm_ready"
  | "ice_gather_first"
  | "signal_sent"
  | "signal_rtt"
  | "answer_received"
  | "ice_connected"
  | "first_remote_frame";

export type RingState = {
  ok?: boolean;
  reason?: string;
  ring_id?: string | null;
  tone?: string | null;
  state?: string | null;
  calm_mode?: boolean;
  trigger_path?: string | null;
  window_seconds?: number | null;
  rang_at_ms?: number | null;
};

export type ConnectReport = {
  ok?: boolean;
  reason?: string;
  marks?: Array<{ mark: string; value_ms: number | null; transport: string | null }>;
  ring_to_frame_ms?: number | null;
  signal_rtt_ms?: number | null;
  ice_connected_ms?: number | null;
  first_frame_ms?: number | null;
  transport?: string | null;
};

export type SurvivalState = "video_dropped" | "audio_only" | "video_restored" | "audio_lost";

const now = () => Date.now();

export function ringStart(input: {
  session_id: string;
  to_user: string;
  tone: "ringtone" | "ringback";
  calm_mode: boolean;
  trigger_path: "quic" | "realtime" | "rows";
}) {
  return chatCall<RingState>(
    "call.ring.start",
    { ...input, at_ms: now() },
    {
      path: "/api/chat/call/ring/start",
      method: "POST",
      body: { ...input, at_ms: now() },
    },
  );
}

export function ringSettle(input: {
  ring_id: string;
  action: "answered" | "declined" | "no_answer" | "calm_mode";
}) {
  return chatCall<RingState>(
    "call.ring.settle",
    { ...input, at_ms: now() },
    { path: "/api/chat/call/ring/settle", method: "POST", body: { ...input, at_ms: now() } },
  );
}

export function ringState(sessionId: string) {
  return chatCall<RingState>(
    "call.ring.state",
    { session_id: sessionId },
    { path: `/api/chat/call/ring/${encodeURIComponent(sessionId)}` },
  );
}

/** Asli reading ya null — engine kabhi andaza nahi likhti. */
export function connectMark(input: {
  session_id: string;
  mark: ConnectMark;
  value_ms?: number | null;
  transport?: string;
}) {
  const body = { ...input, value_ms: input.value_ms ?? null, at_ms: now() };
  return chatCall<{ ok?: boolean }>("call.connect.mark", body, {
    path: "/api/chat/call/connect/mark",
    method: "POST",
    body,
  });
}

export function connectReport(sessionId: string) {
  return chatCall<ConnectReport>(
    "call.connect.report",
    { session_id: sessionId },
    { path: `/api/chat/call/connect/report/${encodeURIComponent(sessionId)}` },
  );
}

export function connectHealth(days = 7) {
  return chatCall<Record<string, unknown>>(
    "call.connect.health",
    { days },
    { path: `/api/chat/call/connect/health?days=${days}` },
  );
}

export function sfuEnsure(conversationId: string, participants: number) {
  const body = { conversation_id: conversationId, participants };
  return chatCall<{
    ok?: boolean;
    reason?: string;
    room_id?: string;
    topology?: "mesh" | "sfu";
    media_forwarding?: boolean;
    max_participants?: number;
  }>("call.sfu.ensure", body, { path: "/api/chat/call/sfu/ensure", method: "POST", body });
}

export function sfuJoin(roomId: string, layers: number, codec: string) {
  const body = { room_id: roomId, layers, codec };
  return chatCall<{ ok?: boolean; reason?: string }>("call.sfu.join", body, {
    path: "/api/chat/call/sfu/join",
    method: "POST",
    body,
  });
}

export function sfuLeave(roomId: string) {
  const body = { room_id: roomId };
  return chatCall<{ ok?: boolean }>("call.sfu.leave", body, {
    path: "/api/chat/call/sfu/leave",
    method: "POST",
    body,
  });
}

export function sfuState(conversationId: string) {
  return chatCall<Record<string, unknown>>(
    "call.sfu.state",
    { conversation_id: conversationId },
    { path: `/api/chat/call/sfu/${encodeURIComponent(conversationId)}` },
  );
}

/** Reason lazmi (3+ char) — record kabhi khali wajah nahi leta. */
export function survivalRecord(input: {
  session_id: string;
  state: SurvivalState;
  reason: string;
  rtt_ms?: number | null;
  loss_pct?: number | null;
}) {
  const body = {
    ...input,
    rtt_ms: input.rtt_ms ?? null,
    loss_pct: input.loss_pct ?? null,
    at_ms: now(),
  };
  return chatCall<{ ok?: boolean }>("call.survival", body, {
    path: "/api/chat/call/survival",
    method: "POST",
    body,
  });
}
