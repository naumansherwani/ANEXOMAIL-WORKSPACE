/**
 * ANEXOChat — transport layer (Phase 1 slice).
 *
 * FOUNDER LOCK:
 *   - PRIMARY transport = Rust engine (`/rpc/chat.*`) + WebTransport/QUIC push.
 *     Bun (`/api/chat/*`, port 3300) sirf fallback hai — kabhi primary nahi.
 *   - Sach DB mein. Yeh file kabhi state invent nahi karti.
 *   - Optimistic bubble sirf "Sending" hota hai; "Sent" tab jab server row de.
 *   - Offline pe "Waiting to send" — kabhi fake Sent nahi.
 *   - client_msg_id se idempotent send: retry duplicate message nahi banata.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useState } from "react";

import { type ApiError } from "@/lib/api";
import { chatCall } from "@/lib/chat-transport";

export type ChatBootstrap = {
  user_id: string;
  email: string;
  workspace_id: string;
  members: { user_id: string; display_name: string | null; role: string }[];
  /** Kis engine ne jawab diya — jhoot nahi. */
  transport: "rust" | "bun";
};

export type ChatConversation = {
  conversation_id: string;
  kind: "direct" | "group";
  subject: string | null;
  other_user_id: string | null;
  other_name: string | null;
  last_body: string | null;
  last_seq: number | null;
  last_at: string | null;
  last_mine: boolean | null;
  unread: number;
  other_read_seq: number | null;
  health: "green" | "amber" | "red";
  health_reason: string;
};

export type ChatMessage = {
  id: string;
  seq: number;
  body: string;
  sender_user_id: string;
  sender_name: string;
  mine: boolean;
  device_label: string | null;
  transport: string;
  created_at: string;
  edited_at: string | null;
  delivered_at: string | null;
  read_at: string | null;
};

/** Truthful ladder. `waiting` = offline queue, never shown as Sent. */
export type MessageState = "sending" | "waiting" | "sent" | "delivered" | "read" | "failed";

export function messageState(m: ChatMessage): MessageState {
  if (m.read_at) return "read";
  if (m.delivered_at) return "delivered";
  return "sent";
}

export const STATE_LABEL: Record<MessageState, string> = {
  sending: "Sending",
  waiting: "Waiting to send",
  sent: "Sent",
  delivered: "Delivered",
  read: "Read",
  failed: "Not sent",
};

export function deviceLabel(): string {
  if (typeof navigator === "undefined") return "unknown device";
  const ua = navigator.userAgent;
  if (/iPhone|Android/i.test(ua)) return "Phone";
  if (/iPad|Tablet/i.test(ua)) return "Tablet";
  return "Desktop";
}

// ── queries ─────────────────────────────────────────────────────
export function useChatBootstrap() {
  return useQuery<ChatBootstrap, ApiError>({
    queryKey: ["chat", "bootstrap"],
    queryFn: () =>
      chatCall<ChatBootstrap>("chat.bootstrap", undefined, { path: "/api/chat/bootstrap" }),
    retry: false,
    staleTime: 60_000,
  });
}

export function useConversations(enabled: boolean) {
  return useQuery<{ conversations: ChatConversation[] }, ApiError>({
    queryKey: ["chat", "conversations"],
    queryFn: () =>
      chatCall<{ conversations: ChatConversation[] }>("chat.conversations", undefined, {
        path: "/api/chat/conversations",
      }),
    enabled,
    retry: false,
    refetchInterval: 5_000,
  });
}

export function useMessages(conversationId: string | null) {
  return useQuery<{ messages: ChatMessage[] }, ApiError>({
    queryKey: ["chat", "messages", conversationId],
    queryFn: () =>
      chatCall<{ messages: ChatMessage[] }>(
        "chat.messages",
        { conversation_id: conversationId, limit: 200 },
        { path: `/api/chat/messages?c=${encodeURIComponent(conversationId!)}&limit=200` },
      ),
    enabled: Boolean(conversationId),
    retry: false,
    refetchInterval: 3_000,
  });
}

export function usePresence(conversationId: string | null, enabled: boolean) {
  return useQuery<
    {
      presence: { user_id: string; device_label: string | null; last_seen_at: string }[];
      typing: { user_id: string }[];
    },
    ApiError
  >({
    queryKey: ["chat", "presence", conversationId],
    queryFn: () =>
      chatCall(
        "chat.presence",
        { conversation_id: conversationId ?? "" },
        {
          path: `/api/chat/presence${
            conversationId ? `?c=${encodeURIComponent(conversationId)}` : ""
          }`,
        },
      ),
    enabled,
    retry: false,
    refetchInterval: 4_000,
  });
}

// ── offline outbox: honest "Waiting to send" ─────────────────────
export type OutboxItem = {
  client_msg_id: string;
  conversation_id: string;
  body: string;
  queued_at: string;
  attempts: number;
  last_error: string | null;
};

const OUTBOX_KEY = "ax.chat.outbox";

function readOutbox(): OutboxItem[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(OUTBOX_KEY);
    return raw ? (JSON.parse(raw) as OutboxItem[]) : [];
  } catch {
    return [];
  }
}

function writeOutbox(items: OutboxItem[]) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(OUTBOX_KEY, JSON.stringify(items));
}

export function newClientMsgId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) return crypto.randomUUID();
  return `c-${Date.now()}-${Math.floor(Math.random() * 1e6)}`;
}

/**
 * Send engine. Online = server row -> "Sent". Offline/failed = outbox row
 * -> "Waiting to send". Retry uses the same client_msg_id (idempotent).
 */
export function useChatSend(conversationId: string | null) {
  const queryClient = useQueryClient();
  const [outbox, setOutbox] = useState<OutboxItem[]>([]);

  useEffect(() => setOutbox(readOutbox()), []);

  const persist = useCallback((items: OutboxItem[]) => {
    writeOutbox(items);
    setOutbox(items);
  }, []);

  const post = useCallback(
    (item: OutboxItem) =>
      chatCall<{ id: string; seq: number; duplicate: boolean }>(
        "chat.send",
        {
          conversation_id: item.conversation_id,
          client_msg_id: item.client_msg_id,
          body: item.body,
          device: deviceLabel(),
        },
        {
          path: "/api/chat/messages",
          method: "POST",
          body: {
            conversation_id: item.conversation_id,
            client_msg_id: item.client_msg_id,
            body: item.body,
            device: deviceLabel(),
          },
        },
      ),
    [],
  );

  const flush = useCallback(async () => {
    let items = readOutbox();
    if (!items.length) return;
    if (typeof navigator !== "undefined" && navigator.onLine === false) return;
    for (const item of [...items]) {
      try {
        await post(item);
        items = readOutbox().filter((i) => i.client_msg_id !== item.client_msg_id);
        persist(items);
      } catch (error) {
        items = readOutbox().map((i) =>
          i.client_msg_id === item.client_msg_id
            ? { ...i, attempts: i.attempts + 1, last_error: (error as Error).message }
            : i,
        );
        persist(items);
        break;
      }
    }
    await queryClient.invalidateQueries({ queryKey: ["chat", "messages"] });
    await queryClient.invalidateQueries({ queryKey: ["chat", "conversations"] });
  }, [persist, post, queryClient]);

  useEffect(() => {
    if (typeof window === "undefined") return;
    const onOnline = () => void flush();
    window.addEventListener("online", onOnline);
    const timer = window.setInterval(() => void flush(), 15_000);
    return () => {
      window.removeEventListener("online", onOnline);
      window.clearInterval(timer);
    };
  }, [flush]);

  const send = useMutation({
    mutationFn: async (body: string) => {
      if (!conversationId) throw new Error("No conversation open.");
      const item: OutboxItem = {
        client_msg_id: newClientMsgId(),
        conversation_id: conversationId,
        body,
        queued_at: new Date().toISOString(),
        attempts: 0,
        last_error: null,
      };
      const offline = typeof navigator !== "undefined" && navigator.onLine === false;
      if (offline) {
        persist([...readOutbox(), item]);
        return { queued: true as const };
      }
      try {
        const row = await post(item);
        return { queued: false as const, ...row };
      } catch (error) {
        persist([...readOutbox(), { ...item, attempts: 1, last_error: (error as Error).message }]);
        return { queued: true as const };
      }
    },
    onSuccess: async () => {
      await queryClient.invalidateQueries({ queryKey: ["chat", "messages", conversationId] });
      await queryClient.invalidateQueries({ queryKey: ["chat", "conversations"] });
    },
  });

  const pending = conversationId
    ? outbox.filter((i) => i.conversation_id === conversationId)
    : outbox;

  return { send, pending, flush };
}

export function useMarkRead(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: async (uptoSeq: number) => {
      if (!conversationId) return null;
      const payload = {
        conversation_id: conversationId,
        state: "read" as const,
        upto_seq: uptoSeq,
      };
      return chatCall<{ marked: number }>("chat.receipts", payload, {
        path: "/api/chat/receipts",
        method: "POST",
        body: payload,
      });
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["chat", "conversations"] }),
  });
}

export function useTypingPing(conversationId: string | null) {
  return useCallback(
    (typing: boolean) => {
      if (!conversationId) return;
      const payload = { conversation_id: conversationId, typing };
      void chatCall<{ ok: boolean }>("chat.typing", payload, {
        path: "/api/chat/typing",
        method: "POST",
        body: payload,
      }).catch(() => {
        /* typing is best-effort; never surfaced as a claim */
      });
    },
    [conversationId],
  );
}

export function useStartDirect() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (otherUserId: string) =>
      chatCall<{ conversation_id: string }>(
        "chat.conversations.direct",
        { other_user_id: otherUserId },
        {
          path: "/api/chat/conversations/direct",
          method: "POST",
          body: { other_user_id: otherUserId },
        },
      ),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["chat", "conversations"] }),
  });
}