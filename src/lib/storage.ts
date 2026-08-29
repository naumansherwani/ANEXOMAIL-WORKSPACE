/**
 * Phase 48 — Inbox Storage & Quota (transport + display only).
 *
 * LOGICAL quota: 3 numbers hi sach hain — quota_bytes · used_bytes ·
 * remaining_bytes. Frontend kabhi nahi jaanta ke mailbox kis disk/server par
 * hai (backend storage abstraction). Business Pro = pooled workspace storage.
 *
 * NO DUPLICATE: quota ka faisla sirf DB (`storage_can_accept`) karta hai.
 * NO MOCK: endpoint na ho to honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, type ApiError } from "@/lib/api";

export type StorageKind = "email" | "attachment" | "file";
export type QuotaLevel = "ok" | "warning" | "critical" | "full";

export type MailboxStorage = {
  mailbox: string;
  quota_bytes: number;
  used_bytes: number;
  remaining_bytes: number;
  percent: number | null;
  level: QuotaLevel;
  breakdown: { emails_bytes: number; attachments_bytes: number; files_bytes: number };
  reserved_bytes: number;
  updated_at: string | null;
};

export type StorageState = {
  plan: string;
  model: "pooled" | "per_mailbox";
  mailbox_limit: number | null;
  max_send_bytes: number;
  pool: {
    quota_bytes: number;
    used_bytes: number;
    remaining_bytes: number;
    percent: number | null;
  } | null;
  mailboxes: MailboxStorage[];
};

export type Preflight = {
  allowed: boolean;
  code: "ok" | "mailbox_full" | "pool_full" | "file_too_large";
  reason?: string;
  used_bytes?: number;
  quota_bytes?: number;
  remaining_bytes?: number;
  limit_bytes?: number;
};

export function useStorageState() {
  return useQuery<StorageState, ApiError>({
    queryKey: ["storage", "state"],
    queryFn: () => api<StorageState>("/api/storage/state"),
    retry: false,
    staleTime: 30_000,
  });
}

/** Upload/attachment se PEHLE — DB ka faisla, browser ka andaza nahi. */
export function useStoragePreflight() {
  return useMutation<Preflight, ApiError, { mailbox: string; bytes: number; kind: StorageKind }>({
    mutationFn: (body) =>
      api<Preflight>("/api/storage/preflight", { method: "POST", body: JSON.stringify(body) }),
  });
}

export function useStorageCommit() {
  const qc = useQueryClient();
  return useMutation<
    unknown,
    ApiError,
    { mailbox: string; bytes: number; kind: StorageKind; was_reserved?: boolean }
  >({
    mutationFn: (body) =>
      api("/api/storage/commit", { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["storage"] }),
  });
}

/** 1024-based, GB tak — "3.2 GB / 10 GB" style. */
export function gb(bytes: number): string {
  if (!bytes) return "0 GB";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), units.length - 1);
  const n = bytes / 1024 ** i;
  return `${n.toFixed(i >= 3 ? 1 : 0)} ${units[i]}`;
}

export const LEVEL_COPY: Record<QuotaLevel, string> = {
  ok: "Healthy",
  warning: "80% used — start clearing space",
  critical: "90% used — nearly full",
  full: "Mailbox full — new items are held, existing email stays readable",
};

export function levelOf(used: number, quota: number): QuotaLevel {
  if (!quota) return "ok";
  const p = used / quota;
  if (p >= 1) return "full";
  if (p >= 0.9) return "critical";
  if (p >= 0.8) return "warning";
  return "ok";
}
