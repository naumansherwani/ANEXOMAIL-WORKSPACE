/**
 * Find-a-time: the pure parts (no React, no network) so they can be tested.
 *
 * The ENGINE does the exact busy/free maths in UTC. This file only decides which hours to ask about
 * (working hours in the organiser's own zone) and how kind each answer is to every guest's local clock.
 */

import type { TimeWindow } from "@/lib/calendar";

export const ZONES = [
  "Pacific/Honolulu",
  "America/Los_Angeles",
  "America/Denver",
  "America/Chicago",
  "America/New_York",
  "America/Sao_Paulo",
  "Europe/London",
  "Europe/Paris",
  "Europe/Istanbul",
  "Africa/Cairo",
  "Africa/Lagos",
  "Africa/Johannesburg",
  "Asia/Dubai",
  "Asia/Karachi",
  "Asia/Kolkata",
  "Asia/Dhaka",
  "Asia/Bangkok",
  "Asia/Singapore",
  "Asia/Shanghai",
  "Asia/Tokyo",
  "Australia/Sydney",
  "Pacific/Auckland",
];

export const STEP_MINUTES = 30;
export const SOCIABLE_FROM = 8;
export const SOCIABLE_TO = 20;

export function zoneLabel(zone: string, at: Date = new Date()) {
  const city = zone.split("/").pop()?.replace(/_/g, " ") ?? zone;
  let offset = "";
  try {
    offset =
      new Intl.DateTimeFormat("en-GB", { timeZone: zone, timeZoneName: "short" })
        .formatToParts(at)
        .find((p) => p.type === "timeZoneName")?.value ?? "";
  } catch {
    /* unknown zone name: show the city only */
  }
  return offset ? `${city} (${offset})` : city;
}

export function hoursIn(zone: string, d: Date) {
  const parts = new Intl.DateTimeFormat("en-GB", {
    timeZone: zone,
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(d);
  const h = Number(parts.find((p) => p.type === "hour")?.value ?? 0);
  const m = Number(parts.find((p) => p.type === "minute")?.value ?? 0);
  return h + m / 60;
}

export function clockIn(zone: string, d: Date) {
  return d.toLocaleTimeString("en-GB", {
    timeZone: zone,
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

/**
 * 0 = a civilised hour (08:00–20:00) for this person. Otherwise 100 + how many hours outside that window
 * (x10), and +100 when it falls in the night (before 06:00 or after 23:00) — so "21:00" beats "06:00".
 */
export function unkindness(zone: string, start: Date, end: Date) {
  const s = hoursIn(zone, start);
  const e = hoursIn(zone, end);
  const wraps = e <= s;
  if (!wraps && s >= SOCIABLE_FROM && e <= SOCIABLE_TO) return 0;
  const early = Math.max(0, SOCIABLE_FROM - s);
  const late = wraps ? 24 - SOCIABLE_TO + e : Math.max(0, e - SOCIABLE_TO);
  const night = wraps || s < 6 || e > 23 || s >= 23;
  return 100 + Math.round((early + late) * 10) + (night ? 100 : 0);
}

export function toLocalInput(d: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** Working hours of the organiser (their own zone, because the browser is in it) -> UTC windows for the engine. */
export function buildWindows(days: number, from: number, to: number, weekdaysOnly: boolean) {
  const out: TimeWindow[] = [];
  const now = new Date();
  const floor = new Date(now);
  floor.setMinutes(Math.ceil(now.getMinutes() / 15) * 15, 0, 0);
  for (let i = 0; i < days; i++) {
    const day = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i);
    const dow = day.getDay();
    if (weekdaysOnly && (dow === 0 || dow === 6)) continue;
    let start = new Date(day.getFullYear(), day.getMonth(), day.getDate(), from, 0, 0, 0);
    const end = new Date(day.getFullYear(), day.getMonth(), day.getDate(), to, 0, 0, 0);
    if (end <= floor) continue;
    if (start < floor) start = floor;
    if (end > start) out.push({ start: start.toISOString(), end: end.toISOString() });
  }
  return out;
}

export type Ranked = {
  start: Date;
  end: Date;
  penalty: number;
  notes: { zone: string; text: string }[];
};

export function rankSlots(
  slots: TimeWindow[],
  minutes: number,
  zones: string[],
  limit = 6,
): Ranked[] {
  const rows: Ranked[] = slots.map((s) => {
    const start = new Date(s.start);
    const end = new Date(start.getTime() + minutes * 60_000);
    let penalty = 0;
    const notes: Ranked["notes"] = [];
    for (const zone of zones) {
      const p = unkindness(zone, start, end);
      penalty += p;
      if (p > 0) {
        notes.push({ zone, text: p >= 200 ? "night" : hoursIn(zone, start) < 12 ? "early" : "late" });
      }
    }
    return { start, end, penalty, notes };
  });
  rows.sort((a, b) => a.penalty - b.penalty || a.start.getTime() - b.start.getTime());
  return rows.slice(0, limit);
}
