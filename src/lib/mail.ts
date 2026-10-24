/**
 * Mail Core — Phase 7 / F3.
 *
 * PRIMARY : Rust :3200 — `/rpc/mail.threads` + WebTransport `/wt/mail`
 * FALLBACK: Bun  :3100 — `/api/mail/*` sirf jab Rust 404/502/503
 * TRUTH   : Supabase `mail_threads` — browser threading nahi.
 */

import { liveRefetch, useLiveState } from "@/lib/live";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, ApiError } from "@/lib/api";
import type { MailFolder, ThreadStatus } from "@/lib/ia";
import { get as offlineGet, put as offlinePut } from "@/lib/offline";
import { rpcOrRest } from "@/lib/rpc";

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
  /** G38: server par asli bytes hain (download ho sakti hai) */
  stored?: boolean;
  /** G38b: the virus scanner flagged this incoming file; its bytes were not kept. */
  blocked?: boolean;
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

function threadInput(query: ThreadQuery) {
  return {
    folder: query.folder,
    ...(query.label ? { label: query.label } : {}),
    ...(query.account ? { account: query.account } : {}),
    ...(query.category ? { category: query.category } : {}),
    ...(query.q?.trim() ? { q: query.q.trim() } : {}),
  };
}

export function useThreads(query: ThreadQuery, enabled = true) {
  const searching = Boolean(query.q?.trim());
  const cacheKey = `list:${toSearch(query)}`;
  return useQuery<{ threads: ThreadListItem[] }, ApiError>({
    queryKey: ["mail", "threads", query],
    queryFn: async () => {
      try {
        const data = await rpcOrRest<{ threads: ThreadListItem[] }>(
          searching ? "mail.search" : "mail.threads",
          {
            path: `${searching ? "/api/mail/search" : "/api/mail/threads"}?${toSearch(query)}`,
          },
          threadInput(query),
        );
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
    refetchInterval: searching ? false : liveRefetch(15_000),
  });
}

/**
 * Server se aane wale thread ko UI ke liye mehfooz banata hai: koi bhi list-field null/gayab ho (purani mail, Rust ne field na bheja,
 * offline cache ki purani shakal) to page crash nahi karta — khali list maani jati hai.
 */
export function normalizeThread(raw: unknown): MailThread {
  const t = (raw ?? {}) as Partial<MailThread>;
  const list = <T>(v: unknown): T[] => (Array.isArray(v) ? (v as T[]) : []);
  return {
    id: String(t.id ?? ""),
    subject: typeof t.subject === "string" ? t.subject : "",
    status: (t.status ?? "open") as ThreadStatus,
    assignee: t.assignee ?? null,
    labels: list<string>(t.labels),
    snoozed_until: t.snoozed_until ?? null,
    account_address: t.account_address ?? null,
    messages: list<Partial<MailMessage> | null>(t.messages)
      .filter((m): m is Partial<MailMessage> => !!m && typeof m === "object")
      .map((m) => ({
        id: String(m.id ?? ""),
        direction: m.direction === "out" ? "out" : "in",
        from_name: m.from_name ?? null,
        from_address: typeof m.from_address === "string" ? m.from_address : "",
        to: list<string>(m.to),
        cc: list<string>(m.cc),
        subject: m.subject ?? null,
        body_text: m.body_text ?? null,
        body_html: m.body_html ?? null,
        sent_at: typeof m.sent_at === "string" ? m.sent_at : "",
        scheduled_at: m.scheduled_at ?? null,
        attachments: list<MailAttachment>(m.attachments),
      })),
  };
}

export function useThread(threadId: string | undefined) {
  return useQuery<MailThread, ApiError>({
    queryKey: ["mail", "thread", threadId],
    queryFn: async () => {
      try {
        // Rust PRIMARY (`/rpc/mail.thread`, TECH-MAP 0); Bun sirf fallback (Rust 404/501/502/503).
        // 20 Oct 2026 live: Bun `/api/mail/thread/:id` har thread par `messages: []` deta tha — mail khulti thi magar khaali.
        const data = await rpcOrRest<MailThread>(
          "mail.thread",
          { path: `/api/mail/thread/${threadId}` },
          { id: threadId },
        );
        void offlinePut("thread", String(threadId), data);
        return normalizeThread(data);
      } catch (error) {
        if (error instanceof ApiError && error.status === 0) {
          const cached = await offlineGet<MailThread>("thread", String(threadId));
          if (cached) return normalizeThread(cached.value);
        }
        throw error;
      }
    },
    enabled: Boolean(threadId),
    // Ek bar khud dobara koshish (refresh karne par khulti thi): sirf network / server-side / session-refresh jaisi waqti ghaltiyan.
    retry: (count, error) =>
      count < 2 && (error.status === 0 || error.status === 401 || error.status >= 500),
    retryDelay: (n) => 400 * (n + 1),
  });
}

export function useLabels() {
  return useQuery<{ labels: MailLabel[] }, ApiError>({
    queryKey: ["mail", "labels"],
    queryFn: () =>
      rpcOrRest<{ labels: MailLabel[] }>("mail.labels", { path: "/api/mail/labels" }, {}),
    retry: false,
    staleTime: 60_000,
  });
}

export function useAccounts() {
  return useQuery<{ accounts: MailAccount[] }, ApiError>({
    queryKey: ["mail", "accounts"],
    queryFn: () =>
      rpcOrRest<{ accounts: MailAccount[] }>("mail.accounts", { path: "/api/mail/accounts" }, {}),
    retry: false,
    staleTime: 60_000,
  });
}

export type SendIdentity = { address: string; kind: "login" | "mailbox" | "shared" };

/** #7 — Compose "Send from": server (Rust mail.identities) ke jaiz From addresses. */
export function useIdentities(enabled = true) {
  return useQuery<{ identities: SendIdentity[]; default: string | null }, ApiError>({
    queryKey: ["mail", "identities"],
    enabled,
    queryFn: () =>
      rpcOrRest<{ identities: SendIdentity[]; default: string | null }>(
        "mail.identities",
        { path: "/api/mail/identities" },
        {},
      ),
    retry: false,
    staleTime: 60_000,
  });
}

export type FolderCounts = Record<string, { total: number; unread: number }>;

export function useFolderCounts() {
  return useQuery<{ folders: FolderCounts }, ApiError>({
    queryKey: ["mail", "counts"],
    queryFn: () =>
      rpcOrRest<{ folders: FolderCounts }>("mail.counts", { path: "/api/mail/counts" }, {}),
    retry: false,
    staleTime: 15_000,
    refetchInterval: liveRefetch(15_000),
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
  /** G38: Rust upload se mile attachment ids */
  attachment_ids?: string[];
};

export function useSendMail() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, SendPayload>({
    // B3: Rust PRIMARY (mail.send), Bun /api/mail/send fallback. Rust smtp_failed = 424 (fallback nahi: mail dobara na jaye).
    mutationFn: (payload) =>
      rpcOrRest("mail.send", { path: "/api/mail/send", method: "POST", body: payload }, payload),
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
  | { kind: "star"; starred: boolean }
  | { kind: "move"; folder: MailFolder }
  | { kind: "assign"; assignee: string };

export function useThreadAction() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { threadId: string; action: ThreadAction }>({
    mutationFn: ({ threadId, action }) => {
      if (action.kind === "star") {
        return rpcOrRest(
          "mail.star",
          {
            path: `/api/mail/thread/${threadId}/star`,
            method: "POST",
            body: { starred: action.starred },
          },
          { thread_id: threadId, starred: action.starred },
        );
      }
      if (action.kind === "snooze") {
        // Rust PRIMARY (mail.snooze), Bun /api/mail/thread/:id/snooze fallback
        return rpcOrRest(
          "mail.snooze",
          {
            path: `/api/mail/thread/${threadId}/snooze`,
            method: "POST",
            body: { until: action.until },
          },
          { thread_id: threadId, until: action.until },
        );
      }
      const path =
        action.kind === "labels"
          ? `/api/mail/thread/${threadId}/labels`
          : action.kind === "status"
            ? `/api/mail/thread/${threadId}/status`
            : action.kind === "assign"
              ? `/api/mail/thread/${threadId}/assign`
              : `/api/mail/thread/${threadId}/move`;
      const { kind: _kind, ...body } = action;
      return api(path, { method: "POST", body: JSON.stringify(body) });
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ["mail"] }),
  });
}

/** Mail screen's view of the ONE shared live connection (opened once by AppShell via useLiveEvents; B4). */
export function useMailLive(): { transport: "webtransport" | "poll"; detail: string } {
  return useLiveState();
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
  // Future (renewals, due dates, scheduled sends): this used to fall into "now" for anything ahead of the clock, so a
  // renewal in 20 days read "Auto-renews now". Beyond a minute of clock skew we say how far ahead it is.
  if (diff < -60_000) {
    const ahead = Math.round(-diff / 60_000);
    if (ahead < 60) return `in ${ahead}m`;
    const aheadHours = Math.round(ahead / 60);
    if (aheadHours < 24) return `in ${aheadHours}h`;
    const aheadDays = Math.round(aheadHours / 24);
    if (aheadDays < 7) return `in ${aheadDays}d`;
    return new Date(iso).toLocaleDateString(undefined, { month: "short", day: "numeric" });
  }
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
