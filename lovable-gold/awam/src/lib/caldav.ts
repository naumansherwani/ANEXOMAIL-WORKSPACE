/**
 * Phone / desktop calendar apps (CalDAV, calendar #6 C1) — client side of the Rust `caldav.apppw.*` procs (SQL E80).
 * Read-only for now: your phone shows your ANEXOMAIL events; nothing is written back. The key is shown ONCE (only its hash is stored).
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type AppKey = { id: string; label: string; created_at: string; last_used_at: string | null };
export type NewKey = { key: string; id: string | null; username: string };

export const MAX_APP_KEYS = 10;
export const DAV_SERVER = "anexomail.com";
/** Full address for apps that ask for a URL (DAVx5, Thunderbird). */
export const DAV_URL = "https://anexomail.com/dav/";

const KEY = ["caldav", "keys"] as const;
const FEED_KEY = ["caldav", "feeds"] as const;

/* ── Calendar link (no app): a secret read-only .ics address for Google Calendar "From URL" (SQL E81, Rust /dav/feed). ── */
export type NewFeed = { path: string; id: string | null };
export const MAX_FEED_LINKS = 5;
export const DAV_ORIGIN = "https://anexomail.com";

const FEED_PATH = /^\/dav\/feed\/[a-z2-7]{30}\.ics$/;

/** Full https link from the server's path. Anything that is not exactly our feed shape gives "" (never show or open an odd link). */
export function feedUrl(path: string): string {
  return FEED_PATH.test(path) ? `${DAV_ORIGIN}${path}` : "";
}

/** One tap on a phone: Google Calendar's own "Add calendar?" screen for this link (webcal:// is what it expects). */
export function googleAddUrl(url: string): string {
  if (!url.startsWith("https://")) return "";
  return `https://calendar.google.com/calendar/r?cid=${encodeURIComponent(`webcal://${url.slice("https://".length)}`)}`;
}

export function useAppKeys() {
  return useQuery<{ keys: AppKey[] }, ApiError>({
    queryKey: KEY,
    queryFn: () => rpc<{ keys: AppKey[] }>("caldav.apppw.list", {}),
    retry: false,
    staleTime: 30_000,
  });
}

export function useCreateAppKey() {
  const qc = useQueryClient();
  return useMutation<NewKey, ApiError, { label: string }>({
    mutationFn: (p) => rpc<NewKey>("caldav.apppw.create", p),
    onSuccess: () => void qc.invalidateQueries({ queryKey: KEY }),
  });
}

export function useRevokeAppKey() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { id: string }>({
    mutationFn: (p) => rpc("caldav.apppw.revoke", p),
    onSuccess: () => void qc.invalidateQueries({ queryKey: KEY }),
  });
}

export function keyAge(iso: string | null, now = Date.now()): string {
  if (!iso) return "Never used";
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return "Never used";
  const m = Math.max(0, Math.round((now - t) / 60000));
  if (m < 2) return "Used just now";
  if (m < 120) return `Used ${m} min ago`;
  if (m < 2880) return `Used ${Math.round(m / 60)} h ago`;
  return `Used ${Math.round(m / 1440)} d ago`;
}

export function useFeedLinks() {
  return useQuery<{ keys: AppKey[] }, ApiError>({
    queryKey: FEED_KEY,
    queryFn: () => rpc<{ keys: AppKey[] }>("caldav.feed.list", {}),
    retry: false,
    staleTime: 30_000,
  });
}

export function useCreateFeedLink() {
  const qc = useQueryClient();
  return useMutation<NewFeed, ApiError, { label: string }>({
    mutationFn: (p) => rpc<NewFeed>("caldav.feed.create", p),
    onSuccess: () => void qc.invalidateQueries({ queryKey: FEED_KEY }),
  });
}

export function useRevokeFeedLink() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { id: string }>({
    mutationFn: (p) => rpc("caldav.feed.revoke", p),
    onSuccess: () => void qc.invalidateQueries({ queryKey: FEED_KEY }),
  });
}
