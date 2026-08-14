/**
 * ANEXOChat · PHASE 10A — SIGNALING ADAPTER (one interface, three transports)
 *
 * PRIMARY   : WebTransport / QUIC (Rust engine) — jab `chat.signal.*` frames
 *             WT session par aayen.
 * REALTIME  : Supabase Realtime broadcast channel `call:<conversation_id>` —
 *             persistent socket, polling nahi. Sirf SIGNALING ke liye.
 * DURABLE   : `chat_signals` rows (RPC se) — sach ka ghar + late-join fallback.
 *
 * LOCK:
 *   - Data (messages, conversations, calls) hamesha RPC se aata hai.
 *     Realtime client se DIRECT DB QUERY kabhi nahi — sirf broadcast channel.
 *   - Har outgoing frame durable row bhi banata hai, is liye peer jab bhi
 *     judta hai use frame milta hai (zero missed offer).
 *   - Transport label kabhi jhoot nahi bolta.
 */
import { createClient, type RealtimeChannel, type SupabaseClient } from "@supabase/supabase-js";

import { chatCall } from "./chat-transport";

export type SignalKind = "offer" | "answer" | "ice" | "ice-end" | "restart" | "end" | "ring";

export type SignalFrame = {
  id?: string;
  from_user: string;
  kind: SignalKind;
  payload: Record<string, unknown>;
};

export type SignalTransport = "realtime" | "rows";

const RT_URL = import.meta.env['VITE_SUPABASE4_URL'] as string | undefined;
const RT_KEY = import.meta.env['VITE_SUPABASE4_PUBLISHABLE_KEY'] as string | undefined;

let client: SupabaseClient | null = null;

/** Realtime SIRF signaling ke liye. Koi `.from()` query yahan se kabhi nahi. */
function realtimeClient(): SupabaseClient | null {
  if (!RT_URL || !RT_KEY) return null;
  if (!client) {
    client = createClient(RT_URL, RT_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
      realtime: { params: { eventsPerSecond: 40 } },
    });
  }
  return client;
}

export function realtimeSignalingAvailable(): boolean {
  return Boolean(RT_URL && RT_KEY);
}

export type SignalLink = {
  /** Instant path par bhejo aur durable row bhi likho (dono, hamesha). */
  send: (to: string, kind: SignalKind, payload: unknown) => Promise<void>;
  transport: () => SignalTransport;
  close: () => void;
};

/**
 * Ek channel khol do. `onFrame` sirf peer ke frames deta hai (apne nahi),
 * aur duplicate frames (realtime + row) dedupe hote hain.
 */
export function openSignalLink(opts: {
  conversationId: string;
  selfId: string;
  onFrame: (frame: SignalFrame) => void;
  onTransport?: (t: SignalTransport) => void;
}): SignalLink {
  const { conversationId, selfId, onFrame } = opts;
  const seen = new Set<string>();
  let transport: SignalTransport = "rows";
  let channel: RealtimeChannel | null = null;
  let stopped = false;

  const key = (f: SignalFrame) =>
    f.id ?? `${f.from_user}:${f.kind}:${JSON.stringify(f.payload).slice(0, 220)}`;

  const deliver = (frame: SignalFrame) => {
    if (stopped || !frame || frame.from_user === selfId) return;
    const k = key(frame);
    if (seen.has(k)) return;
    seen.add(k);
    if (seen.size > 500) seen.clear();
    onFrame(frame);
  };

  const sb = realtimeClient();
  if (sb) {
    channel = sb.channel(`call:${conversationId}`, { config: { broadcast: { self: false } } });
    channel
      .on("broadcast", { event: "signal" }, (msg) => {
        const f = (msg as { payload?: unknown })["payload"] as SignalFrame & { to_user?: string };
        if (f?.to_user && f.to_user !== selfId) return;
        deliver(f);
      })
      .subscribe((status) => {
        const live = status === "SUBSCRIBED";
        transport = live ? "realtime" : "rows";
        opts.onTransport?.(transport);
      });
  }

  // Durable catch-up: realtime live ho to slow safety net, warna primary path.
  const tick = async () => {
    if (stopped) return;
    try {
      const res = await chatCall<{ signals: (SignalFrame & { created_at?: string })[] }>(
        "chat.signal.poll",
        { conversation_id: conversationId },
        { path: `/api/chat/video/signals?c=${encodeURIComponent(conversationId)}` },
      );
      for (const sig of res.signals ?? []) deliver(sig);
    } catch {
      /* durable catch-up best-effort — state kabhi fake nahi hota */
    }
  };
  void tick();
  // Realtime live ho to ye sirf safety net hai; warna durable primary path.
  const timer = window.setInterval(() => void tick(), sb ? 5000 : 1200);

  return {
    async send(to, kind, payload) {
      const frame = {
        conversation_id: conversationId,
        from_user: selfId,
        to_user: to,
        kind,
        payload: (payload ?? {}) as Record<string, unknown>,
      };
      // 1) instant path
      if (channel && transport === "realtime") {
        await channel.send({ type: "broadcast", event: "signal", payload: frame }).catch(() => {});
      }
      // 2) durable truth (late-join / realtime down)
      await chatCall<{ id: string }>(
        "chat.signal.send",
        { conversation_id: conversationId, to_user: to, kind, payload: frame.payload },
        {
          path: "/api/chat/video/signal",
          method: "POST",
          body: { conversation_id: conversationId, to_user: to, kind, payload: frame.payload },
        },
      ).catch(() => {});
    },
    transport: () => transport,
    close() {
      stopped = true;
      window.clearInterval(timer);
      try {
        if (channel && sb) void sb.removeChannel(channel);
      } catch {
        /* already gone */
      }
    },
  };
}
