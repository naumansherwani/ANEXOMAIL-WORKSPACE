/**
 * Overlap Matrix (calendar #4b / World Clock W1) — client side of the Rust `calendar.overlap` proc.
 *
 * Split of work (same rule as the rest of the calendar):
 *   - ENGINE (Rust + SQL E62): who may be asked about, each person's own working hours / out-of-office, free/busy, the
 *     green / amber / red call for every slot, the best times, and honest minute counts for a proposed time.
 *   - BROWSER: draws it and shows each person's local clock (Intl). It never decides who is free.
 *
 * Honest by design: no "quality" percentages. A person's day is described in real minutes; a guest whose hours are not
 * known is judged by the clock on their wall only, and is marked as such.
 */
import { keepPreviousData, useQuery } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type CellCode = "w" | "u" | "b" | "o" | "f" | "n" | "x";
export type ZoneName = "green" | "amber" | "red" | "unknown";

export type OverlapAssess = {
  zone: ZoneName;
  outside_min: number | null;
  day_len_min: number | null;
  extra_min: number | null;
  /** Focus Ring: minutes already booked (free/busy only) inside their working window that day. */
  booked_min?: number | null;
  work_min?: number | null;
};

export type OverlapMember = {
  address: string;
  name: string;
  kind: "member" | "guest";
  tz: string | null;
  known: boolean;
  you: boolean;
  row: string;
  assess?: OverlapAssess;
};

export type OverlapBest = { start: string; end: string; red: number; amber: number; all_green: boolean };

export type OverlapData = {
  now: string;
  grid: { from: string; slots: number; step_min: number };
  truncated: boolean;
  members: OverlapMember[];
  best: OverlapBest[];
};

export type OverlapParams = {
  addresses: string[];
  days?: number;
  stepMin?: 15 | 30 | 60;
  minutes?: number;
  /** ISO start of the proposed meeting (adds `assess` to every member). */
  proposalStart?: string | null;
  proposalMinutes?: number;
  from?: string;
};

export function useOverlap(params: OverlapParams, enabled = true) {
  const addresses = [...new Set(params.addresses.map((a) => a.trim().toLowerCase()).filter(Boolean))].sort();
  const proposal =
    params.proposalStart && params.proposalMinutes
      ? {
          start: params.proposalStart,
          end: new Date(new Date(params.proposalStart).getTime() + params.proposalMinutes * 60_000).toISOString(),
        }
      : null;
  return useQuery<OverlapData, ApiError>({
    queryKey: [
      "calendar",
      "overlap",
      addresses.join(","),
      params.days ?? 2,
      params.stepMin ?? 30,
      params.minutes ?? 30,
      params.from ?? "",
      proposal?.start ?? "",
      proposal?.end ?? "",
    ],
    queryFn: () =>
      rpc<OverlapData>("calendar.overlap", {
        addresses,
        days: params.days ?? 2,
        step_min: params.stepMin ?? 30,
        minutes: params.minutes ?? 30,
        ...(params.from ? { from: params.from } : {}),
        ...(proposal ? { proposal } : {}),
      }),
    enabled,
    retry: false,
    staleTime: 20_000,
    placeholderData: keepPreviousData,
  });
}

/* ------------------------------------------------------------------ words */

export const ZONE_OF: Record<CellCode, ZoneName> = {
  w: "green",
  u: "green",
  b: "amber",
  o: "amber",
  f: "amber",
  n: "red",
  x: "unknown",
};

/** Why a cell has its colour — said in plain words. */
export const CELL_WHY: Record<CellCode, string> = {
  w: "inside their working hours, free",
  u: "daytime on their clock (their hours are not shared)",
  b: "inside their working hours but busy",
  o: "out of office",
  f: "outside their working hours",
  n: "night on their clock",
  x: "time zone not known",
};

export function cellZone(c: string | undefined): ZoneName {
  return ZONE_OF[(c ?? "x") as CellCode] ?? "unknown";
}

/** Tailwind classes per zone (tokens only — works in both themes). */
export const ZONE_CLASS: Record<ZoneName, string> = {
  green: "bg-success/75",
  amber: "bg-warning/75",
  red: "bg-danger/75",
  unknown: "bg-muted",
};

/** 90 -> "1h 30m", 360 -> "6h", 45 -> "45m". Real minutes, never a made-up score. */
export function fmtMinutes(min: number): string {
  const m = Math.max(0, Math.round(min));
  const h = Math.floor(m / 60);
  const r = m % 60;
  if (h === 0) return `${r}m`;
  return r === 0 ? `${h}h` : `${h}h ${r}m`;
}

/** The sentence under a person for the proposed time. Counts only. */
export function assessLine(a: OverlapAssess | undefined, known: boolean): string {
  if (!a) return "";
  if (a.zone === "unknown") return ""; // the cell's own reason already says "time zone not known"
  if (!known || a.outside_min == null) return ""; // the cell's own reason already says "their hours are not shared"
  if (a.outside_min === 0) return ""; // the cell's own reason already says "inside their working hours"
  const out = `${fmtMinutes(a.outside_min)} outside their hours`;
  const day = a.day_len_min != null && a.extra_min ? ` · their day becomes ${fmtMinutes(a.day_len_min)} (+${fmtMinutes(a.extra_min)})` : "";
  return out + day;
}

/** Slot index of a UTC instant on the grid (clamped). */
export function slotIndex(grid: OverlapData["grid"], at: Date): number {
  const from = new Date(grid.from).getTime();
  const i = Math.floor((at.getTime() - from) / (grid.step_min * 60_000));
  return Math.min(Math.max(i, 0), grid.slots - 1);
}

export function slotStart(grid: OverlapData["grid"], i: number): Date {
  return new Date(new Date(grid.from).getTime() + i * grid.step_min * 60_000);
}

/**
 * Focus Ring: how full that person's working day is with the proposed meeting added.
 * Real minutes only: booked (free/busy) + the part of this meeting inside their hours, over their working window.
 * null = nothing honest to draw (no schedule shared, day off, unknown zone).
 */
export function focusLoad(
  a: OverlapAssess | undefined,
  meetingMin: number,
): { frac: number; booked: number; withMeeting: number; work: number; text: string } | null {
  if (!a || a.booked_min == null || a.work_min == null || a.work_min <= 0) return null;
  const inside = Math.max(0, meetingMin - (a.outside_min ?? 0));
  const withMeeting = a.booked_min + inside;
  const frac = Math.min(1, Math.max(0, withMeeting / a.work_min));
  const text = `${fmtMinutes(withMeeting)} booked of ${fmtMinutes(a.work_min)} with this meeting`;
  return { frac, booked: a.booked_min, withMeeting, work: a.work_min, text };
}
