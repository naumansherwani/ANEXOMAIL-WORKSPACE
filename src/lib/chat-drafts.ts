/**
 * ANEXOChat · PHASE 11 — DRAFT PER CONVERSATION
 *
 * Conversation switch karne par draft zinda rehta hai (panel chhode bina).
 * Storage local hai — draft kabhi server par nahi bhejta, aur "Sent" jaisa
 * kabhi nahi dikhta. Sirf woh cheez sach hai jo user ne likhi.
 */
import { useCallback, useEffect, useState } from "react";

const KEY = "ax.chat.drafts";

type DraftMap = Record<string, { body: string; reply_to_id: string | null; at: string }>;

function read(): DraftMap {
  if (typeof window === "undefined") return {};
  try {
    return JSON.parse(window.localStorage.getItem(KEY) || "{}") as DraftMap;
  } catch {
    return {};
  }
}

function write(map: DraftMap) {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(KEY, JSON.stringify(map));
}

export function useDraft(conversationId: string | null) {
  const [body, setBody] = useState("");
  const [replyToId, setReplyToId] = useState<string | null>(null);

  useEffect(() => {
    if (!conversationId) {
      setBody("");
      setReplyToId(null);
      return;
    }
    const saved = read()[conversationId];
    setBody(saved?.body ?? "");
    setReplyToId(saved?.reply_to_id ?? null);
  }, [conversationId]);

  const save = useCallback(
    (next: string, reply: string | null) => {
      setBody(next);
      setReplyToId(reply);
      if (!conversationId) return;
      const map = read();
      if (next.trim()) {
        map[conversationId] = { body: next, reply_to_id: reply, at: new Date().toISOString() };
      } else {
        delete map[conversationId];
      }
      write(map);
    },
    [conversationId],
  );

  const clear = useCallback(() => {
    setBody("");
    setReplyToId(null);
    if (!conversationId) return;
    const map = read();
    delete map[conversationId];
    write(map);
  }, [conversationId]);

  return { body, replyToId, save, clear };
}

/** List panel par "Draft" chip — sirf jahan asli draft hai. */
export function draftIds(): string[] {
  return Object.keys(read());
}
