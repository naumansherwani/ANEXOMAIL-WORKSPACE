/**
 * Outside calendars (calendar #4c) — client side of the Rust `calendar.sub.*` procs (SQL E73).
 *
 * Split of work:
 *   - ENGINE (Rust): fetches the feed itself (https only, public addresses only, 5 MB, 10 s), parses it, keeps the events and expands
 *     repeating ones for the range asked. The link is a secret: it is never sent back to the browser, only the website name.
 *   - BROWSER: asks, draws the events in the calendar's own colour and marks them read-only.
 *
 * Read-only on purpose: these events never turn into invites, bookings or mail.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { CalendarEvent } from "@/lib/calendar";
import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type CalendarSub = {
  id: string;
  name: string;
  host: string;
  color: string;
  enabled: boolean;
  refresh_minutes: number;
  last_ok_at: string | null;
  last_fetch_at: string | null;
  last_error: string | null;
  fail_count: number;
  event_count: number;
};

export type SubEvent = {
  sub_id: string;
  sub_name: string;
  color: string;
  uid: string;
  title: string;
  location: string;
  description: string;
  start: string;
  end: string;
  all_day: boolean;
  date?: string;
  end_date?: string;
};

export const MAX_SUBS = 10;
export const EXT_PREFIX = "ext~";

/** Ids of outside events start with "ext~" — they have no server record to open. */
export function isExternalId(id: string): boolean {
  return id.startsWith(EXT_PREFIX);
}

export function externalId(e: Pick<SubEvent, "sub_id" | "uid" | "start">): string {
  return `${EXT_PREFIX}${e.sub_id}~${e.uid.replace(/~/g, "-")}~${Date.parse(e.start) || 0}`;
}

/** "2026-10-20" -> that day's local midnight as an ISO string (a holiday belongs to the viewer's calendar day, not to UTC's). */
export function localMidnightIso(date: string): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!m) return null;
  return new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3])).toISOString();
}

/** All-day end dates are exclusive (the day AFTER the last day). Returns the last day, never before the first. */
export function lastDay(date: string, endDate?: string): string {
  if (!endDate || endDate <= date) return date;
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(endDate);
  if (!m) return date;
  const d = new Date(Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3])) - 86_400_000);
  const last = d.toISOString().slice(0, 10);
  return last < date ? date : last;
}

/** An outside event drawn as a normal (read-only) calendar row. */
export function toCalendarEvent(e: SubEvent): CalendarEvent {
  const startIso = e.all_day && e.date ? (localMidnightIso(e.date) ?? e.start) : e.start;
  const endIso = e.all_day && e.end_date ? (localMidnightIso(e.end_date) ?? e.end) : e.end;
  return {
    id: externalId(e),
    title: e.title || "(no title)",
    starts_at: startIso,
    ends_at: endIso,
    all_day: e.all_day,
    location: e.location || null,
    agenda: e.description || null,
    organiser: e.sub_name || null,
    attendees: [],
    thread_id: null,
    thread_subject: null,
    kind: "personal",
    status: "confirmed",
    cost: null,
    conflict: false,
    shield_conflict: false,
    calendar_key: `ext:${e.sub_id}`,
    color: /^#[0-9a-fA-F]{6}$/.test(e.color) ? e.color : "#64748b",
  };
}

/** Our events plus the outside ones, in time order; outside events never replace ours. */
export function mergeEvents(own: CalendarEvent[], outside: SubEvent[]): CalendarEvent[] {
  if (outside.length === 0) return own;
  return [...own, ...outside.map(toCalendarEvent)].sort((a, b) =>
    a.starts_at.localeCompare(b.starts_at),
  );
}

export function lookup(events: SubEvent[], id: string): SubEvent | undefined {
  return events.find((e) => externalId(e) === id);
}

/** "Updated 5 min ago" / "Never updated" / the engine's error in plain words. */
export function subStatus(s: CalendarSub, now = Date.now()): string {
  if (!s.enabled)
    return s.last_error === "disabled_too_many_failures"
      ? "Paused — the link kept failing. Turn on to retry."
      : "Paused";
  if (s.last_error) return "Last update failed — will retry";
  if (!s.last_ok_at) return "Waiting for the first update";
  const mins = Math.max(0, Math.round((now - Date.parse(s.last_ok_at)) / 60_000));
  if (mins < 1) return "Updated just now";
  if (mins < 60) return `Updated ${mins} min ago`;
  if (mins < 1440) return `Updated ${Math.round(mins / 60)} h ago`;
  return `Updated ${Math.round(mins / 1440)} d ago`;
}

export const REFRESH_CHOICES: { minutes: number; label: string }[] = [
  { minutes: 15, label: "Every 15 minutes" },
  { minutes: 60, label: "Every hour" },
  { minutes: 360, label: "Every 6 hours" },
  { minutes: 1440, label: "Once a day" },
];

const KEY = ["calendar", "subs"] as const;

export function useCalendarSubs() {
  return useQuery<{ subs: CalendarSub[] }, ApiError>({
    queryKey: KEY,
    queryFn: () => rpc<{ subs: CalendarSub[] }>("calendar.sub.list", {}),
    retry: false,
    staleTime: 30_000,
  });
}

/** Events of every followed calendar for a range. Fails soft: the calendar still shows our own events. */
export function useSubEvents(range: { from: string; to: string }, enabled = true) {
  return useQuery<
    { subs: { id: string; name: string; color: string }[]; events: SubEvent[] },
    ApiError
  >({
    queryKey: ["calendar", "sub-events", range],
    queryFn: () => rpc("calendar.sub.events", range),
    enabled,
    retry: false,
    staleTime: 60_000,
  });
}

function useInvalidate() {
  const qc = useQueryClient();
  return () => {
    void qc.invalidateQueries({ queryKey: KEY });
    void qc.invalidateQueries({ queryKey: ["calendar", "sub-events"] });
  };
}

export function useAddSub() {
  const done = useInvalidate();
  return useMutation<
    { id: string; name: string; event_count: number },
    ApiError,
    { url: string; name?: string; color?: string; refresh_minutes?: number }
  >({
    mutationFn: (p) => rpc("calendar.sub.add", p),
    onSuccess: done,
  });
}

export function useUpdateSub() {
  const done = useInvalidate();
  return useMutation<
    unknown,
    ApiError,
    { id: string; name?: string; color?: string; enabled?: boolean; refresh_minutes?: number }
  >({
    mutationFn: (p) => rpc("calendar.sub.update", p),
    onSuccess: done,
  });
}

export function useRemoveSub() {
  const done = useInvalidate();
  return useMutation<unknown, ApiError, { id: string }>({
    mutationFn: (p) => rpc("calendar.sub.remove", p),
    onSuccess: done,
  });
}

export function useRefreshSub() {
  const done = useInvalidate();
  return useMutation<{ event_count: number }, ApiError, { id: string }>({
    mutationFn: (p) => rpc("calendar.sub.refresh", p),
    onSuccess: done,
    onError: done,
  });
}
