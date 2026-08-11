/**
 * Mail Core — Phase 7.
 *
 * Locked source of truth: Supabase 4 `mail_threads` + `mail_messages`,
 * exposed ONLY through the backend (/api/mail/*). Postfix delivery hook
 * syncs incoming mail into those tables; IMAP/Dovecot is backup access only.
 *
 * NO DUPLICATE rule: no threading, no dedupe, no counting, no search ranking
 * happens in the browser. This file speaks HTTP and nothing else.
 * NO MOCK rule: a missing endpoint surfaces as an honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, ApiError } from "@/lib/api";
import type { MailFolder, ThreadStatus } from "@/lib/ia";
import { get as offlineGet, put as offlinePut } from "@/lib/offline";

export type MailLabel = {
  id: string;
  name: string;
  colour: string | null;
  thread_count?: number;
};

export type MailAccount = {
  id: string;
  address: string;
  kind: "personal" | "shared";
  unread?: number;
};

export type ThreadCategory = "primary" | "updates" | "people" | "promotions";

export const THREAD_CATEGORIES: { id: ThreadCategory; label: string }[] = [
  { id: "primary", label: "Primary" },
  { id: "updates", label: "Updates" },
  { id: "people", label: "People" },
  { id: "promotions", label: "Promotions" },
];

export type ThreadListItem = {
  id: string;
  subject: string;
  snippet: string | null;
  from_name: string | null;
  from_address: string;
  account_id: string | null;
  account_address: string | null;
  message_count: number;
  unread: boolean;
  starred: boolean;
  has_attachments: boolean;
  status: ThreadStatus;
  assignee: string | null;
  labels: string[];
  category: ThreadCategory | null;
  snoozed_until: string | null;
  last_message_at: string;
};

export type MailAttachment = {
  id: string;
  filename: string;
  mime_type: string | null;
  size_bytes: number;
  url: string | null;
};

export type MailMessage = {
  id: string;
  direction: "in" | "out";
  from_name: string | null;
  from_address: string;
  to: string[];
  cc: string[];
  subject: string | null;
  body_text: string | null;
  body_html: string | null;
  sent_at: string;
  scheduled_at: string | null;
  attachments: MailAttachment[];
};

export type MailThread = {
  id: string;
  subject: string;
  status: ThreadStatus;
  assignee: string | null;
  labels: string[];
  snoozed_until: string | null;
  account_address: string | null;
  messages: MailMessage[];
};

export type ThreadQuery = {
  folder: MailFolder;
  label?: string | null;
  account?: string | null;
  category?: ThreadCategory | null;
  q?: string;
};

function toSearch(query: ThreadQuery) {
  const params = new URLSearchParams({ folder: query.folder });
  if (query.label) params.set("label", query.label);
  if (query.account) params.set("account", query.account);
  if (query.category) params.set("category", query.category);
  if (query.q?.trim()) params.set("q", query.q.trim());
  return params.toString();
}

export function useThreads(query: ThreadQuery, enabled = true) {
  const searching = Boolean(query.q?.trim());
  const cacheKey = `list:${toSearch(query)}`;
  return useQuery<{ threads: ThreadListItem[] }, ApiError>({
    queryKey: ["mail", "threads", query],
    queryFn: async () => {
      try {
        const data = await api<{ threads: ThreadListItem[] }>(
          `${searching ? "/api/mail/search" : "/api/mail/threads"}?${toSearch(query)}`,
        );
        // Phase 28: cache real rows for offline reading. Never faked.
        if (!searching) void offlinePut("threads", cacheKey, data.threads);
        return data;
      } catch (error) {
        if (error instanceof ApiError && error.status === 0 && !searching) {
          const cached = await offlineGet<ThreadListItem[]>("threads", cacheKey);
          if (cached) return { threads: cached.value };
        }
        throw error;
      }
    },
    enabled,
    retry: false,
    staleTime: 15_000,
  });
}

export function useThread(threadId: string | undefined) {
  return useQuery<MailThread, ApiError>({
    queryKey: ["mail", "thread", threadId],
    queryFn: async () => {
      try {
        const data = await api<MailThread>(`/api/mail/thread/${threadId}`);
        void offlinePut("thread", String(threadId), data);
        return data;
      } catch (error) {
        if (error instanceof ApiError && error.status === 0) {
          const cached = await offlineGet<MailThread>("thread", String(threadId));
          if (cached) return cached.value;
        }
        throw error;
      }
    },
    enabled: Boolean(threadId),
    retry: false,
  });
}

export function useLabels() {
  return useQuery<{ labels: MailLabel[] }, ApiError>({
    queryKey: ["mail", "labels"],
    queryFn: () => api<{ labels: MailLabel[] }>("/api/mail/labels"),
    retry: false,
    staleTime: 60_000,
  });
}

export function useAccounts() {
  return useQuery<{ accounts: MailAccount[] }, ApiError>({
    queryKey: ["mail", "accounts"],
    queryFn: () => api<{ accounts: MailAccount[] }>("/api/mail/accounts"),
    retry: false,
    staleTime: 60_000,
  });
}

export type SendPayload = {
  to: string;
  cc?: string;
  bcc?: string;
  subject: string;
  body: string;
  thread_id?: string;
  in_reply_to?: string;
  /** ISO timestamp — schedule send. Omitted means send now. */
  send_at?: string;
};

export function useSendMail() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, SendPayload>({
    mutationFn: (payload) =>
      api("/api/mail/send", { method: "POST", body: JSON.stringify(payload) }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["mail"] });
      void qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}

type ThreadAction =
  | { kind: "labels"; add?: string[]; remove?: string[] }
  | { kind: "status"; status: ThreadStatus }
  | { kind: "snooze"; until: string | null }
  | { kind: "move"; folder: MailFolder };

export function useThreadAction() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { threadId: string; action: ThreadAction }>({
    mutationFn: ({ threadId, action }) => {
      const path =
        action.kind === "labels"
          ? `/api/mail/thread/${threadId}/labels`
          : action.kind === "status"
            ? `/api/mail/thread/${threadId}/status`
            : action.kind === "snooze"
              ? `/api/mail/thread/${threadId}/snooze`
              : `/api/mail/thread/${threadId}/move`;
      const { kind: _kind, ...body } = action;
      return api(path, { method: "POST", body: JSON.stringify(body) });
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["mail"] }),
  });
}

/** Snooze presets — resolved in the browser only as timestamps, never as state. */
export function snoozePresets(now = new Date()) {
  const at = (d: Date, h: number, m = 0) => {
    const copy = new Date(d);
    copy.setHours(h, m, 0, 0);
    return copy;
  };
  const tomorrow = new Date(now);
  tomorrow.setDate(now.getDate() + 1);
  const nextWeek = new Date(now);
  nextWeek.setDate(now.getDate() + 7);
  return [
    { label: "Later today", at: at(now, Math.min(now.getHours() + 3, 21)) },
    { label: "Tomorrow, 8am", at: at(tomorrow, 8) },
    { label: "Next week", at: at(nextWeek, 8) },
  ];
}

export function relativeTime(iso: string) {
  const then = new Date(iso).getTime();
  if (Number.isNaN(then)) return "";
  const diff = Date.now() - then;
  const minutes = Math.round(diff / 60_000);
  if (minutes < 1) return "now";
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.round(hours / 24);
  if (days < 7) return `${days}d`;
  return new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });
}

export function formatBytes(bytes: number) {
  if (!bytes) return "0 B";
  const units = ["B", "KB", "MB", "GB"];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  return `${(bytes / 1024 ** i).toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
}
