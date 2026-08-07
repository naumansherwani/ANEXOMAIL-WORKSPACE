/**
 * Dashboard Command Center — Phase 6.
 *
 * NO DUPLICATE rule: zero numbers are computed here. Every widget, counter,
 * activity row, credit balance and event comes from the backend
 * (Bun/Rust on Hetzner -> Supabase). If an endpoint is not wired yet the UI
 * shows an honest "not wired" surface — never a fake number.
 */

import { useQuery } from "@tanstack/react-query";

import { api, ApiError } from "@/lib/api";

/** GET /api/dashboard/summary */
export type DashboardSummary = {
  unread: number;
  assigned_to_me: number;
  waiting: number;
  done_today: number;
  storage_used_bytes: number;
  storage_limit_bytes: number;
  domain_verified: boolean;
};

/** GET /api/dashboard/activity */
export type ActivityKind =
  | "message_received"
  | "message_sent"
  | "thread_assigned"
  | "thread_done"
  | "member_joined"
  | "domain_verified"
  | "login"
  | "admin_change";

export type ActivityItem = {
  id: string;
  kind: ActivityKind;
  actor: string | null;
  subject: string;
  detail: string | null;
  created_at: string;
};

/** GET /api/dashboard/ai-usage */
export type AiUsage = {
  enabled: boolean;
  plan: string | null;
  credits_total: number;
  credits_used: number;
  period_end: string | null;
};

/** GET /api/dashboard/analytics */
export type Analytics = {
  range_days: number;
  received: number;
  sent: number;
  avg_first_reply_seconds: number | null;
  delivery_rate: number | null;
  series: { date: string; received: number; sent: number }[];
};

/** GET /api/dashboard/calendar */
export type CalendarEvent = {
  id: string;
  title: string;
  starts_at: string;
  ends_at: string | null;
  location: string | null;
  all_day: boolean;
};

function useDashboardQuery<T>(key: string, path: string, enabled: boolean) {
  return useQuery<T, ApiError>({
    queryKey: ["dashboard", key],
    queryFn: () => api<T>(path),
    enabled,
    retry: false,
    staleTime: 30_000,
  });
}

export const useSummary = (enabled: boolean) =>
  useDashboardQuery<DashboardSummary>("summary", "/api/dashboard/summary", enabled);

export const useActivity = (enabled: boolean) =>
  useDashboardQuery<{ items: ActivityItem[] }>(
    "activity",
    "/api/dashboard/activity",
    enabled,
  );

export const useAiUsage = (enabled: boolean) =>
  useDashboardQuery<AiUsage>("ai-usage", "/api/dashboard/ai-usage", enabled);

export const useAnalytics = (enabled: boolean) =>
  useDashboardQuery<Analytics>("analytics", "/api/dashboard/analytics", enabled);

export const useUpcoming = (enabled: boolean) =>
  useDashboardQuery<{ events: CalendarEvent[] }>(
    "calendar",
    "/api/dashboard/calendar",
    enabled,
  );

export function formatBytes(bytes: number): string {
  if (!Number.isFinite(bytes) || bytes <= 0) return "0 GB";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.min(units.length - 1, Math.floor(Math.log(bytes) / Math.log(1024)));
  const value = bytes / 1024 ** i;
  return `${value >= 10 || i === 0 ? Math.round(value) : value.toFixed(1)} ${units[i]}`;
}

export function formatDuration(seconds: number | null): string {
  if (seconds === null || !Number.isFinite(seconds)) return "—";
  if (seconds < 60) return `${Math.round(seconds)}s`;
  if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
  return `${(seconds / 3600).toFixed(1)}h`;
}

export function formatClock(iso: string, allDay = false): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  if (allDay) return "All day";
  return date.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
}

export function formatRelative(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "—";
  const diff = Date.now() - date.getTime();
  const mins = Math.round(diff / 60_000);
  if (mins < 1) return "just now";
  if (mins < 60) return `${mins}m ago`;
  const hours = Math.round(mins / 60);
  if (hours < 24) return `${hours}h ago`;
  const days = Math.round(hours / 24);
  if (days < 7) return `${days}d ago`;
  return date.toLocaleDateString(undefined, { day: "numeric", month: "short" });
}