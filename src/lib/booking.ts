import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

/**
 * Booking page (B7c) — client for the Rust `book` module (SQL E59).
 * Public calls (visitor) need no login; host calls use the normal session.
 * All times travel as RFC 3339 UTC strings; the screen formats them in the viewer's zone.
 */

export type PublicPage = {
  handle: string;
  host_name: string | null;
  title: string;
  description: string | null;
  durations: number[];
  timezone: string;
  location: string | null;
  min_notice_min: number;
  max_days: number;
};

export type SlotsResult = { slots: string[]; minutes: number; timezone: string; now: string; from: string; to: string };

export type Booked = {
  booked: true;
  token: string;
  starts_at: string;
  ends_at: string;
  title: string;
  host_name: string | null;
  location: string | null;
  timezone: string;
  manage_url: string;
  mail_sent: boolean;
};

export type ManageView = {
  status: "confirmed" | "cancelled";
  starts_at: string;
  ends_at: string;
  visitor_name: string;
  visitor_tz: string | null;
  reschedules: number;
  can_change: boolean;
  handle: string;
  title: string;
  host_name: string | null;
  location: string | null;
  timezone: string;
  minutes: number;
  enabled: boolean;
};

export const pageGet = (handle: string) => rpc<PublicPage>("booking.public.page", { handle });
export const slotsGet = (handle: string, minutes: number, from: string, days = 14) =>
  rpc<SlotsResult>("booking.public.slots", { handle, minutes, from, days });
export const bookSlot = (p: {
  handle: string;
  start: string;
  minutes: number;
  name: string;
  email: string;
  tz: string;
  note: string;
  website: string;
}) => rpc<Booked>("booking.public.book", p);
export const manageLookup = (token: string) => rpc<ManageView>("booking.manage.lookup", { token });
export const manageCancel = (token: string) => rpc<{ cancelled: boolean; already: boolean }>("booking.manage.cancel", { token });
export const manageReschedule = (token: string, start: string) =>
  rpc<{ rescheduled: boolean; starts_at: string; ends_at: string; mail_sent: boolean }>("booking.manage.reschedule", { token, start });

/* ───────────────────────────── host side ───────────────────────────── */

export type HostPage = {
  id: string;
  handle: string;
  host_name: string | null;
  title: string;
  description: string | null;
  durations: number[];
  buffer_min: number;
  min_notice_min: number;
  max_days: number;
  timezone: string;
  location: string | null;
  calendar_key: string | null;
  enabled: boolean;
};

export type HostPageState = { page: HostPage | null; suggested_handle: string; host_email: string; app_url: string };

export type HostBooking = {
  id: string;
  starts_at: string;
  ends_at: string;
  visitor_name: string;
  visitor_email: string;
  visitor_tz: string | null;
  note: string | null;
  status: "confirmed" | "cancelled";
  reschedules: number;
  created_at: string;
};

export type HostPageInput = Omit<HostPage, "id" | "host_name"> & { host_name: string };

const KEY = ["booking", "page"] as const;
const LIST = ["booking", "list"] as const;

export function useBookingPage(enabled = true) {
  return useQuery<HostPageState, ApiError>({
    queryKey: KEY,
    queryFn: () => rpc<HostPageState>("booking.page.get", {}),
    enabled,
    retry: false,
    staleTime: 30_000,
  });
}

export function useSaveBookingPage() {
  const qc = useQueryClient();
  return useMutation<HostPageState, ApiError, HostPageInput>({
    mutationFn: (p) => rpc<HostPageState>("booking.page.set", p),
    onSuccess: (s) => qc.setQueryData(KEY, s),
  });
}

export function useBookingList(enabled = true) {
  return useQuery<{ bookings: HostBooking[] }, ApiError>({
    queryKey: LIST,
    queryFn: () => rpc<{ bookings: HostBooking[] }>("booking.list", {}),
    enabled,
    retry: false,
    staleTime: 15_000,
  });
}

export function useHostCancel() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, string>({
    mutationFn: (booking_id) => rpc("booking.host.cancel", { booking_id }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: LIST });
      void qc.invalidateQueries({ queryKey: ["calendar"] });
    },
  });
}

/* ───────────────────────────── shared helpers ───────────────────────────── */

/** Browser zone, with a safe fallback. */
export function localZone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
  } catch {
    return "UTC";
  }
}

const FALLBACK_ZONES = [
  "UTC", "Europe/London", "Europe/Berlin", "Europe/Paris", "Europe/Istanbul", "Asia/Dubai", "Asia/Karachi", "Asia/Kolkata",
  "Asia/Dhaka", "Asia/Bangkok", "Asia/Singapore", "Asia/Shanghai", "Asia/Tokyo", "Australia/Sydney", "Pacific/Auckland",
  "America/Sao_Paulo", "America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles",
];

/** Every IANA zone the browser knows (plus the current one), sorted. */
export function allZones(current?: string): string[] {
  let list: string[] = [];
  try {
    const f = (Intl as unknown as { supportedValuesOf?: (k: string) => string[] }).supportedValuesOf;
    list = f ? f("timeZone") : [];
  } catch {
    list = [];
  }
  if (list.length === 0) list = FALLBACK_ZONES;
  const set = new Set(list);
  set.add("UTC");
  if (current) set.add(current);
  return [...set].sort();
}

export function fmtDay(iso: string, tz: string, opts: Intl.DateTimeFormatOptions = { weekday: "long", day: "numeric", month: "long", year: "numeric" }) {
  try {
    return new Intl.DateTimeFormat(undefined, { ...opts, timeZone: tz }).format(new Date(iso));
  } catch {
    return new Date(iso).toDateString();
  }
}

export function fmtClock(iso: string, tz: string) {
  try {
    return new Intl.DateTimeFormat(undefined, { hour: "2-digit", minute: "2-digit", timeZone: tz }).format(new Date(iso));
  } catch {
    return new Date(iso).toTimeString().slice(0, 5);
  }
}

/** "YYYY-MM-DD" of an instant in zone `tz` (used to group slots by the visitor's own calendar day). */
export function dayKey(iso: string, tz: string): string {
  try {
    const p = new Intl.DateTimeFormat("en-CA", { year: "numeric", month: "2-digit", day: "2-digit", timeZone: tz }).format(new Date(iso));
    return p;
  } catch {
    return iso.slice(0, 10);
  }
}

export function zoneLabel(tz: string): string {
  return tz.replace(/_/g, " ");
}

export function minutesLabel(m: number): string {
  if (m % 60 === 0) return `${m / 60} h`;
  if (m > 60) return `${Math.floor(m / 60)} h ${m % 60} min`;
  return `${m} min`;
}
