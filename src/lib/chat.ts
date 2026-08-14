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
  reply_to_id?: string | null;
  reply_to_body?: string | null;
  reply_to_sender?: string | null;
  pinned_at?: string | null;
  reactions?: ChatReaction[];
};

/** Founder lock: edit 5 minute, delete-for-everyone 1 ghanta — DB bhi yehi enforce karta hai. */
export const EDIT_WINDOW_MS = 5 * 60 * 1000;
export const DELETE_WINDOW_MS = 60 * 60 * 1000;

export function withinWindow(createdAt: string, windowMs: number): boolean {
  return Date.now() - new Date(createdAt).getTime() <= windowMs;
}

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
  reply_to_id?: string | null;
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
          reply_to_id: item.reply_to_id ?? null,
        },
        {
          path: "/api/chat/messages",
          method: "POST",
          body: {
            conversation_id: item.conversation_id,
            client_msg_id: item.client_msg_id,
            body: item.body,
            device: deviceLabel(),
            reply_to_id: item.reply_to_id ?? null,
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
    mutationFn: async (vars: string | { body: string; reply_to_id?: string | null }) => {
      if (!conversationId) throw new Error("No conversation open.");
      const body = typeof vars === "string" ? vars : vars.body;
      const replyTo = typeof vars === "string" ? null : vars.reply_to_id ?? null;
      const item: OutboxItem = {
        client_msg_id: newClientMsgId(),
        conversation_id: conversationId,
        body,
        reply_to_id: replyTo,
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
// ── PHASE 3: message engine (reactions / edit / delete) ──────────
export type ChatReaction = { emoji: string; count: number; mine: boolean };

export function useReact(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (vars: { message_id: string; emoji: string }) =>
      chatCall<{ reactions: ChatReaction[] }>("chat.react", vars, {
        path: "/api/chat/react",
        method: "POST",
        body: vars,
      }),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["chat", "messages", conversationId] }),
  });
}

export function useEditMessage(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (vars: { message_id: string; body: string }) =>
      chatCall<{ id: string; body: string; edited_at: string }>("chat.message.edit", vars, {
        path: "/api/chat/messages/edit",
        method: "POST",
        body: vars,
      }),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["chat", "messages", conversationId] }),
  });
}

export function useDeleteMessage(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (messageId: string) =>
      chatCall<{ id: string; deleted_at: string }>(
        "chat.message.delete",
        { message_id: messageId },
        {
          path: "/api/chat/messages/delete",
          method: "POST",
          body: { message_id: messageId },
        },
      ),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["chat", "messages", conversationId] }),
  });
}

// ── PHASE 3: work objects (task / promise / decision) ────────────
export type ChatWorkItem = {
  id: string;
  kind: "task" | "promise" | "decision";
  title: string;
  state: "open" | "done" | "cancelled";
  due_at: string | null;
  owner_user_id: string | null;
  message_id: string | null;
  created_at: string;
};

export function useWorkItems(conversationId: string | null) {
  return useQuery<{ items: ChatWorkItem[] }, ApiError>({
    queryKey: ["chat", "work", conversationId],
    queryFn: () =>
      chatCall<{ items: ChatWorkItem[] }>(
        "chat.work.list",
        { conversation_id: conversationId },
        { path: `/api/chat/work?c=${encodeURIComponent(conversationId!)}` },
      ),
    enabled: Boolean(conversationId),
    retry: false,
  });
}

export function useCreateWorkItem(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (vars: {
      kind: ChatWorkItem["kind"];
      title: string;
      message_id?: string | null;
      due_at?: string | null;
    }) => {
      const payload = { conversation_id: conversationId, ...vars };
      return chatCall<{ id: string }>("chat.work.create", payload, {
        path: "/api/chat/work",
        method: "POST",
        body: payload,
      });
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["chat", "work", conversationId] }),
  });
}

export function useSetWorkState(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (vars: { item_id: string; state: ChatWorkItem["state"] }) =>
      chatCall<{ ok: boolean }>("chat.work.state", vars, {
        path: "/api/chat/work/state",
        method: "POST",
        body: vars,
      }),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["chat", "work", conversationId] }),
  });
}

export type ConversationState = "active" | "waiting" | "blocked" | "closed";

export function useSetConversationState(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (vars: { state: ConversationState; note?: string | null }) => {
      const payload = { conversation_id: conversationId, ...vars };
      return chatCall<{ state: ConversationState; note: string | null; updated_at: string }>(
        "chat.conversation.state",
        payload,
        { path: "/api/chat/conversations/state", method: "POST", body: payload },
      );
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["chat", "conversations"] }),
  });
}

// ── PHASE 6: ANEXOMAIL sidebar unread truth ─────────────────────
export function useChatUnread() {
  return useQuery<{ unread: number; conversations: number }, ApiError>({
    queryKey: ["chat", "unread"],
    queryFn: () =>
      chatCall<{ unread: number; conversations: number }>("chat.unread", undefined, {
        path: "/api/chat/unread",
      }),
    retry: false,
    refetchInterval: 20_000,
  });
}

// ── PHASE 8-10: messenger parity (reply / hide / pin / prefs / search) ──
export function useHideMessage(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (messageId: string) =>
      chatCall<{ hidden: boolean }>(
        "chat.message.hide",
        { message_id: messageId },
        { path: "/api/chat/messages/hide", method: "POST", body: { message_id: messageId } },
      ),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["chat", "messages", conversationId] }),
  });
}

export function usePinMessage(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (vars: { message_id: string; pin: boolean }) =>
      chatCall<{ id: string; pinned_at: string | null }>("chat.message.pin", vars, {
        path: "/api/chat/messages/pin",
        method: "POST",
        body: vars,
      }),
    onSuccess: () =>
      queryClient.invalidateQueries({ queryKey: ["chat", "messages", conversationId] }),
  });
}

export function useConversationPrefs(conversationId: string | null) {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (vars: { mute_minutes?: number | null; archived?: boolean | null }) => {
      const payload = { conversation_id: conversationId, ...vars };
      return chatCall<{ muted_until: string | null; archived: boolean }>(
        "chat.conversation.prefs",
        payload,
        { path: "/api/chat/conversations/prefs", method: "POST", body: payload },
      );
    },
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["chat", "conversations"] }),
  });
}

export type ChatSearchHit = {
  id: string;
  conversation_id: string;
  seq: number;
  body: string;
  sender_name: string;
  created_at: string;
};

export function useChatSearch(q: string) {
  const term = q.trim();
  return useQuery<{ results: ChatSearchHit[] }, ApiError>({
    queryKey: ["chat", "search", term],
    queryFn: () =>
      chatCall<{ results: ChatSearchHit[] }>(
        "chat.search",
        { q: term },
        { path: `/api/chat/search?q=${encodeURIComponent(term)}` },
      ),
    enabled: term.length >= 2,
    retry: false,
    staleTime: 15_000,
  });
}
