/**
 * Calendar display preferences — per viewer, per device (localStorage, always wrapped in try/catch).
 *
 *  • Clock format: "auto" follows the viewer's own country/language habit, or force 12h / 24h.
 *  • Calendar layout: "classic" (list rail + week grid, two scrollbars) or "expanded" (one toolbar, full width).
 *
 * Universal UI (Rule 37): nothing here knows about plans.
 */
import { useSyncExternalStore } from "react";

export type ClockPref = "auto" | "12" | "24";
export type CalLayout = "classic" | "expanded";

const CLOCK_KEY = "ax.cal.clock";
const LAYOUT_KEY = "ax.cal.layout";

const listeners = new Set<() => void>();
const memory: Record<string, string> = {};

function read(key: string): string | null {
  try {
    return window.localStorage.getItem(key) ?? memory[key] ?? null;
  } catch {
    return memory[key] ?? null;
  }
}

function write(key: string, value: string) {
  memory[key] = value;
  try {
    window.localStorage.setItem(key, value);
  } catch {
    /* private window / blocked storage: the in-memory value still works for this visit */
  }
  listeners.forEach((fn) => fn());
}

function subscribe(fn: () => void) {
  listeners.add(fn);
  const onStorage = (e: StorageEvent) => {
    if (e.key === CLOCK_KEY || e.key === LAYOUT_KEY) fn();
  };
  if (typeof window !== "undefined") window.addEventListener("storage", onStorage);
  return () => {
    listeners.delete(fn);
    if (typeof window !== "undefined") window.removeEventListener("storage", onStorage);
  };
}

export function readClockPref(): ClockPref {
  if (typeof window === "undefined") return "auto";
  const v = read(CLOCK_KEY);
  return v === "12" || v === "24" ? v : "auto";
}

export function readLayoutPref(): CalLayout {
  if (typeof window === "undefined") return "classic";
  return read(LAYOUT_KEY) === "expanded" ? "expanded" : "classic";
}

export function useClockPref(): [ClockPref, (v: ClockPref) => void] {
  const v = useSyncExternalStore(subscribe, readClockPref, () => "auto" as ClockPref);
  return [v, (next) => write(CLOCK_KEY, next)];
}

export function useCalLayout(): [CalLayout, (v: CalLayout) => void] {
  const v = useSyncExternalStore(subscribe, readLayoutPref, () => "classic" as CalLayout);
  return [v, (next) => write(LAYOUT_KEY, next)];
}

/** What "auto" means here: the viewer's own locale (en-PK → 12h, en-GB → 24h, ja-JP → 24h …). */
export function localeUses12h(): boolean {
  try {
    const hc = new Intl.DateTimeFormat(undefined, { hour: "numeric" }).resolvedOptions().hourCycle;
    return hc === "h12" || hc === "h11";
  } catch {
    return false;
  }
}

export function use12h(pref: ClockPref = readClockPref()): boolean {
  return pref === "12" ? true : pref === "24" ? false : localeUses12h();
}

const two = (n: number) => (n < 10 ? `0${n}` : String(n));

/** "15:30" or "3:30 PM" in the VIEWER's own time zone, following the clock preference. */
export function fmtTime(input: string | number | Date, opts: { seconds?: boolean } = {}): string {
  const d = input instanceof Date ? input : new Date(input);
  if (Number.isNaN(d.getTime())) return "";
  const h = d.getHours();
  const tail = `${two(d.getMinutes())}${opts.seconds ? `:${two(d.getSeconds())}` : ""}`;
  if (use12h()) return `${h % 12 || 12}:${tail} ${h < 12 ? "AM" : "PM"}`;
  return `${two(h)}:${tail}`;
}

/** Hour label for a time grid row: "13:00" or "1 PM". */
export function fmtHour(h: number): string {
  if (use12h()) return `${h % 12 || 12} ${h < 12 ? "AM" : "PM"}`;
  return `${two(h)}:00`;
}

/** The viewer's own place, as a name a person recognises ("Karachi"), never "GMT+5". */
export function zoneCity(): { city: string; iana: string } {
  let iana = "";
  try {
    iana = Intl.DateTimeFormat().resolvedOptions().timeZone || "";
  } catch {
    iana = "";
  }
  const last = iana.split("/").pop() ?? "";
  return { city: last.replace(/_/g, " ") || "Local time", iana };
}
