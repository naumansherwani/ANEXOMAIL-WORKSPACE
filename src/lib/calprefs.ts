/**
 * Calendar personal settings — calendars (name + colour), working hours, out-of-office.
 * They live in the ACCOUNT (Rust /rpc/locale.uipref `extra`, SQL E57/E58), so every device sees the same.
 * Signed out, SQL not installed or offline: the defaults below are used and nothing breaks.
 *
 * Universal UI (Rule 37): nothing here knows about plans.
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import type { CalendarEvent } from "@/lib/calendar";
import { rpcOrRest } from "@/lib/rpc";

export type CalendarDef = { id: string; name: string; color: string };
export type WorkDay = { on: boolean; start: string; end: string };
export type WorkHours = { days: WorkDay[]; tz?: string };
export type OooPeriod = { from: string; to: string; note: string };

export const PALETTE = [
  "#3b82f6", // blue
  "#22c55e", // green
  "#f59e0b", // amber
  "#ef4444", // red
  "#a855f7", // violet
  "#14b8a6", // teal
  "#ec4899", // pink
  "#64748b", // slate
] as const;

export const DEFAULT_CALENDARS: CalendarDef[] = [
  { id: "main", name: "My calendar", color: PALETTE[0] },
];

export const DEFAULT_HOURS: WorkHours = {
  days: Array.from({ length: 7 }, (_, i) => ({ on: i < 5, start: "09:00", end: "17:00" })),
};

/** Reminder choices, in minutes before the start. */
export const REMINDER_CHOICES: { min: number; label: string }[] = [
  { min: 0, label: "At the start" },
  { min: 5, label: "5 minutes before" },
  { min: 10, label: "10 minutes before" },
  { min: 15, label: "15 minutes before" },
  { min: 30, label: "30 minutes before" },
  { min: 60, label: "1 hour before" },
  { min: 1440, label: "1 day before" },
];

export function reminderText(min: number): string {
  if (min === 0) return "now";
  if (min < 60) return `${min} minute${min === 1 ? "" : "s"}`;
  if (min < 1440) return `${Math.round(min / 60)} hour${min === 60 ? "" : "s"}`;
  return `${Math.round(min / 1440)} day${min === 1440 ? "" : "s"}`;
}

type Extra = {
  calendars?: CalendarDef[];
  work_hours?: WorkHours;
  ooo?: OooPeriod[];
  clocks?: string[];
};

export type CalPrefs = {
  calendars: CalendarDef[];
  workHours: WorkHours;
  /** false until the person has saved their own hours — the grid then shows no shading at all. */
  hoursSet: boolean;
  ooo: OooPeriod[];
  /** World-clock pins (IANA zone names, max 6) — the toolbar shows them next to the live clock. */
  clocks: string[];
  loaded: boolean;
};

const KEY = ["calprefs"] as const;

export function useCalPrefs(): CalPrefs {
  const q = useQuery<Extra, ApiError>({
    queryKey: KEY,
    queryFn: async () => {
      const res = await rpcOrRest<{ extra?: Extra }>("locale.uipref", {
        path: "/api/locale/uipref",
      });
      return res.extra ?? {};
    },
    retry: false,
    staleTime: 60_000,
  });
  const x = q.data ?? {};
  return {
    calendars: x.calendars && x.calendars.length > 0 ? x.calendars : DEFAULT_CALENDARS,
    workHours: x.work_hours && x.work_hours.days?.length === 7 ? x.work_hours : DEFAULT_HOURS,
    hoursSet: Boolean(x.work_hours),
    ooo: x.ooo ?? [],
    clocks: Array.isArray(x.clocks) ? x.clocks.filter((z) => typeof z === "string") : [],
    loaded: q.isSuccess || q.isError,
  };
}

export function useSaveCalPrefs() {
  const qc = useQueryClient();
  return useMutation<Extra, ApiError, Extra>({
    mutationFn: async (extra) => {
      const res = await rpcOrRest<{ extra?: Extra }>(
        "locale.uipref.set",
        { path: "/api/locale/uipref", method: "PUT", body: { extra } },
        { extra },
      );
      return res.extra ?? extra;
    },
    onSuccess: (saved) => qc.setQueryData(KEY, saved),
  });
}

export function useSetEventMeta() {
  const qc = useQueryClient();
  return useMutation<
    unknown,
    ApiError,
    { id: string; calendar_key?: string | null; remind_min?: number[] | null }
  >({
    mutationFn: (p) =>
      rpcOrRest(
        "calendar.meta.set",
        { path: `/api/calendar/events/${p.id}/meta`, method: "PUT", body: p },
        p,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["calendar"] }),
  });
}

/** The colour an event is drawn in, or undefined = the default look. */
export function eventColor(
  ev: Pick<CalendarEvent, "calendar_key" | "color">,
  calendars: CalendarDef[],
): string | undefined {
  if (ev.color) return ev.color;
  if (!ev.calendar_key) return undefined;
  return calendars.find((c) => c.id === ev.calendar_key)?.color;
}

const pad = (n: number) => (n < 10 ? `0${n}` : String(n));

/** "2026-10-30" for a local date. */
export function dayKey(d: Date): string {
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
}

export function oooOn(d: Date, ooo: OooPeriod[]): OooPeriod | undefined {
  const k = dayKey(d);
  return ooo.find((p) => p.from <= k && k <= p.to);
}

const toMin = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));

/** Working window of a local date in minutes-of-day, or null when that day is off. (Monday-first week.) */
export function workWindow(d: Date, wh: WorkHours): { start: number; end: number } | null {
  const day = wh.days[(d.getDay() + 6) % 7];
  if (!day || !day.on) return null;
  return { start: toMin(day.start), end: toMin(day.end) };
}

/** true when a start time falls outside the person's saved working hours or inside an out-of-office period. */
export function outsideHours(d: Date, prefs: CalPrefs): "ooo" | "hours" | null {
  if (oooOn(d, prefs.ooo)) return "ooo";
  if (!prefs.hoursSet) return null;
  const w = workWindow(d, prefs.workHours);
  const m = d.getHours() * 60 + d.getMinutes();
  if (!w || m < w.start || m >= w.end) return "hours";
  return null;
}
