/**
 * Mail Core — Phase 7 / F3.
 *
 * PRIMARY : Rust :3200 — `/rpc/mail.threads` + WebTransport `/wt/mail`
 * FALLBACK: Bun  :3100 — `/api/mail/*` sirf jab Rust 404/502/503
 * TRUTH   : Supabase `mail_threads` — browser threading nahi.
 */

import { useEffect, useRef, useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, ApiError, sessionToken } from "@/lib/api";
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
    refetchInterval: searching ? false : 15_000,
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
    queryFn: () =>
      rpcOrRest<{ labels: MailLabel[] }>(
        "mail.labels",
        { path: "/api/mail/labels" },
        {},
      ),
    retry: false,
    staleTime: 60_000,
  });
}

export function useAccounts() {
  return useQuery<{ accounts: MailAccount[] }, ApiError>({
    queryKey: ["mail", "accounts"],
    queryFn: () =>
      rpcOrRest<{ accounts: MailAccount[] }>(
        "mail.accounts",
        { path: "/api/mail/accounts" },
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
    refetchInterval: 15_000,
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
  | { kind: "star"; starred: boolean }
  | { kind: "move"; folder: MailFolder };

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

type WebTransportLike = {
  ready: Promise<void>;
  close: () => void;
  createBidirectionalStream: () => Promise<{
    readable: ReadableStream<Uint8Array>;
    writable: WritableStream<Uint8Array>;
  }>;
};

function mailWtUrl(): string {
  const env = (import.meta.env["VITE_ANEXOCHAT_WT_URL"] as string | undefined)?.replace(/\/$/, "");
  if (env) return env;
  if (typeof window === "undefined") return "";
  return `https://${window.location.hostname}:3443`;
}

/** F3.3 — Rust WebTransport mail stamp. Fail = honest RPC poll, fake live nahi. */
export function useMailLive(): { transport: "webtransport" | "poll"; detail: string } {
  const queryClient = useQueryClient();
  const [live, setLive] = useState(false);
  const [detail, setDetail] = useState("HTTP poll (WebTransport unavailable)");
  const closer = useRef<(() => void) | null>(null);

  useEffect(() => {
    closer.current?.();
    closer.current = null;
    setLive(false);

    const url = mailWtUrl();
    const token = sessionToken.get();
    if (!token || typeof window === "undefined" || !("WebTransport" in window) || !url) {
      return;
    }

    let stopped = false;
    let transport: { close: () => void } | null = null;

    void (async () => {
      try {
        const WT = (window as unknown as { WebTransport: new (u: string) => WebTransportLike })
          .WebTransport;
        const wt = new WT(`${url}/wt/mail`);
        transport = wt;
        await wt.ready;
        const stream = await wt.createBidirectionalStream();
        const writer = stream.writable.getWriter();
        await writer.write(new TextEncoder().encode(JSON.stringify({ token, mode: "mail" })));
        writer.releaseLock();

        const reader = stream.readable.getReader();
        const decoder = new TextDecoder();
        let buffer = "";
        setLive(true);
        setDetail("Live over WebTransport / QUIC (Rust engine)");

        while (!stopped) {
          const { value, done } = await reader.read();
          if (done) break;
          buffer += decoder.decode(value, { stream: true });
          const lines = buffer.split("\n");
          buffer = lines.pop() ?? "";
          for (const line of lines) {
            if (!line.trim()) continue;
            let frame: { type?: string } = {};
            try {
              frame = JSON.parse(line) as { type?: string };
            } catch {
              continue;
            }
            if (frame.type === "mail") {
              await queryClient.invalidateQueries({ queryKey: ["mail"] });
            }
            if (frame.type === "error") {
              setLive(false);
              setDetail("HTTP poll (WebTransport refused this session)");
            }
          }
        }
      } catch {
        setLive(false);
        setDetail("HTTP poll (WebTransport unavailable)");
      }
    })();

    closer.current = () => {
      stopped = true;
      try {
        transport?.close();
      } catch {
        /* already closed */
      }
    };
    return () => closer.current?.();
  }, [queryClient]);

  return { transport: live ? "webtransport" : "poll", detail };
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
