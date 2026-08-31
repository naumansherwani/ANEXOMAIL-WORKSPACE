/**
 * ANEXOChat · PHASE 12 — CROSS-DEVICE CONTINUITY (Resume Anywhere)
 *
 * TRANSPORT LOCK: PRIMARY = Rust engine `/rpc/chat.*` (tRPC-style, HTTP/3) +
 * WebTransport/QUIC live frames. Bun `/api/chat/*` sirf FALLBACK.
 * TRUTH: canonical state Supabase #4 mein — device sirf uske saath reconcile
 * karta hai, apni parallel reality kabhi nahi banata.
 */
import { useCallback, useEffect, useRef, useState } from "react";

import { chatCall } from "./chat-transport";

export type ChatDevice = {
  device_id: string;
  label: string | null;
  kind: string;
  platform: string | null;
  installed: boolean;
  last_seen_at: string;
};

export type ServerDraft = {
  conversation_id: string;
  body: string;
  reply_to_id: string | null;
  caret: number;
  attachment_ids: string[];
  rev: number;
  device_label: string | null;
  updated_at: string;
};

export type ServerPosition = {
  conversation_id: string;
  anchor_seq: number;
  at_bottom: boolean;
  rev: number;
  device_label: string | null;
  updated_at: string;
};

export type Continuity = {
  devices: ChatDevice[];
  drafts: ServerDraft[];
  positions: ServerPosition[];
};

const DEVICE_KEY = "ax.chat.device";

/** Stable per-browser device identity — server par sirf yeh id + label jaati hai. */
export function deviceIdentity(): { device_id: string; label: string; kind: string; platform: string; installed: boolean } {
  if (typeof window === "undefined") {
    return { device_id: "ssr", label: "Server", kind: "unknown", platform: "ssr", installed: false };
  }
  let id = window.localStorage.getItem(DEVICE_KEY);
  if (!id) {
    id = (window.crypto?.randomUUID?.() ?? `dev-${Date.now()}-${Math.random().toString(36).slice(2)}`);
    window.localStorage.setItem(DEVICE_KEY, id);
  }
  const ua = window.navigator.userAgent;
  const installed = window.matchMedia?.("(display-mode: standalone)")?.matches === true;
  const touch = window.navigator.maxTouchPoints > 1;
  const w = window.screen?.width ?? window.innerWidth;
  const kind = installed ? "pwa" : touch ? (w >= 820 ? "tablet" : "mobile") : w >= 1600 ? "desktop" : "laptop";
  const platform = /Mac/i.test(ua) ? "macOS" : /Win/i.test(ua) ? "Windows" : /Android/i.test(ua) ? "Android" : /iPhone|iPad/i.test(ua) ? "iOS" : "Linux";
  return { device_id: id, label: `${platform} · ${kind}`, kind, platform, installed };
}

/** Har session par device register — presence truth, guess nahi. */
export async function markDeviceSeen(): Promise<void> {
  const d = deviceIdentity();
  await chatCall<{ ok: boolean }>("chat.device.seen", d, {
    path: "/api/chat/device/seen",
    method: "POST",
    body: d,
  });
}

/** Canonical continuity snapshot (devices + drafts + positions). */
export async function fetchContinuity(): Promise<Continuity> {
  const d = deviceIdentity();
  const data = await chatCall<Continuity>(
    "chat.continuity",
    { device_id: d.device_id },
    { path: `/api/chat/continuity?device=${encodeURIComponent(d.device_id)}`, method: "GET" },
  );
  return { devices: data?.devices ?? [], drafts: data?.drafts ?? [], positions: data?.positions ?? [] };
}

async function saveDraftRemote(input: {
  conversation_id: string;
  body: string;
  reply_to_id: string | null;
  caret: number;
  attachment_ids: string[];
  rev: number;
}): Promise<ServerDraft | null> {
  const d = deviceIdentity();
  const body = { ...input, device_id: d.device_id, device_label: d.label };
  return chatCall<ServerDraft | null>("chat.draft.save", body, {
    path: "/api/chat/draft",
    method: "POST",
    body,
  });
}

async function savePositionRemote(input: {
  conversation_id: string;
  anchor_seq: number;
  at_bottom: boolean;
  rev: number;
}): Promise<ServerPosition | null> {
  const d = deviceIdentity();
  const body = { ...input, device_id: d.device_id, device_label: d.label };
  return chatCall<ServerPosition | null>("chat.position.save", body, {
    path: "/api/chat/position",
    method: "POST",
    body,
  });
}

/**
 * Server-authoritative draft. Local typing turant dikhta hai, magar rev
 * server ka hota hai: doosre device ka naya rev jeet jata hai (no conflict fork).
 */
export function useSyncedDraft(conversationId: string | null) {
  const [body, setBody] = useState("");
  const [replyToId, setReplyToId] = useState<string | null>(null);
  const [rev, setRev] = useState(0);
  const [fromDevice, setFromDevice] = useState<string | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    let alive = true;
    setBody("");
    setReplyToId(null);
    setRev(0);
    setFromDevice(null);
    if (!conversationId) return;
    (async () => {
      try {
        const snap = await fetchContinuity();
        if (!alive) return;
        const draft = snap.drafts.find((x) => x.conversation_id === conversationId);
        if (draft) {
          setBody(draft.body ?? "");
          setReplyToId(draft.reply_to_id ?? null);
          setRev(draft.rev ?? 0);
          setFromDevice(draft.device_label ?? null);
        }
      } catch {
        /* offline: local typing chalta rahega, jhooti "synced" state nahi */
      }
    })();
    return () => {
      alive = false;
    };
  }, [conversationId]);

  const save = useCallback(
    (next: string, reply: string | null, caret = next.length) => {
      setBody(next);
      setReplyToId(reply);
      if (!conversationId) return;
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(async () => {
        try {
          const saved = await saveDraftRemote({
            conversation_id: conversationId,
            body: next,
            reply_to_id: reply,
            caret,
            attachment_ids: [],
            rev,
          });
          if (saved?.rev) setRev(saved.rev);
        } catch {
          /* server na mile to draft local rehta hai; retry next keystroke */
        }
      }, 600);
    },
    [conversationId, rev],
  );

  const clear = useCallback(() => {
    setBody("");
    setReplyToId(null);
    if (!conversationId) return;
    void saveDraftRemote({
      conversation_id: conversationId,
      body: "",
      reply_to_id: null,
      caret: 0,
      attachment_ids: [],
      rev,
    }).catch(() => undefined);
  }, [conversationId, rev]);

  return { body, replyToId, rev, fromDevice, save, clear };
}

/** Relevant position (anchor message seq) — device change par wahi jagah. */
export function useResumePosition(conversationId: string | null) {
  const [anchorSeq, setAnchorSeq] = useState<number | null>(null);
  const [atBottom, setAtBottom] = useState(true);
  const revRef = useRef(0);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    let alive = true;
    setAnchorSeq(null);
    setAtBottom(true);
    revRef.current = 0;
    if (!conversationId) return;
    (async () => {
      try {
        const snap = await fetchContinuity();
        if (!alive) return;
        const pos = snap.positions.find((x) => x.conversation_id === conversationId);
        if (pos) {
          setAnchorSeq(pos.anchor_seq);
          setAtBottom(pos.at_bottom);
          revRef.current = pos.rev ?? 0;
        }
      } catch {
        /* resume point na mile to bottom — sach bolna, guess nahi */
      }
    })();
    return () => {
      alive = false;
    };
  }, [conversationId]);

  const report = useCallback(
    (seq: number, bottom: boolean) => {
      if (!conversationId) return;
      if (timer.current) clearTimeout(timer.current);
      timer.current = setTimeout(async () => {
        try {
          const saved = await savePositionRemote({
            conversation_id: conversationId,
            anchor_seq: seq,
            at_bottom: bottom,
            rev: revRef.current,
          });
          if (saved?.rev) revRef.current = saved.rev;
        } catch {
          /* silent: position sync best-effort hai */
        }
      }, 900);
    },
    [conversationId],
  );

  return { anchorSeq, atBottom, report };
}

export type DeepHit = {
  message_id: string;
  conversation_id: string;
  conversation_title: string | null;
  sender_id: string;
  seq: number;
  body: string;
  created_at: string;
};

/** Lambi chats mein deep search — jitni purani ho, hamesha available. */
export async function deepSearch(input: {
  q: string;
  conversationId?: string | null;
  sender?: string | null;
  before?: string | null;
  limit?: number;
}): Promise<DeepHit[]> {
  if (!input.q.trim()) return [];
  const qs = new URLSearchParams({ q: input.q });
  if (input.conversationId) qs.set("c", input.conversationId);
  if (input.sender) qs.set("sender", input.sender);
  if (input.before) qs.set("before", input.before);
  if (input.limit) qs.set("limit", String(input.limit));
  const data = await chatCall<{ results: DeepHit[] }>(
    "chat.search.deep",
    {
      q: input.q,
      conversation_id: input.conversationId ?? null,
      sender: input.sender ?? null,
      before: input.before ?? null,
      limit: input.limit ?? 40,
    },
    { path: `/api/chat/search/deep?${qs.toString()}`, method: "GET" },
  );
  return data?.results ?? [];
}
