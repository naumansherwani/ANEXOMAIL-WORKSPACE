/**
 * Calendar display preferences — per viewer, per device (localStorage, always wrapped in try/catch).
 *
 *  • Clock format: "auto" follows the viewer's own country/language habit, or force 12h / 24h.
 *  • Calendar layout: "classic" (list rail + week grid, two scrollbars) or "expanded" (one toolbar, full width).
 *
 * Universal UI (Rule 37): nothing here knows about plans.
 */
import { useSyncExternalStore } from "react";

import { rpcOrRest } from "@/lib/rpc";

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

function write(key: string, value: string, remote = true) {
  memory[key] = value;
  try {
    window.localStorage.setItem(key, value);
  } catch {
    /* private window / blocked storage: the in-memory value still works for this visit */
  }
  listeners.forEach((fn) => fn());
  if (remote) void pushRemote();
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

/**
 * Account sync (E58 + Rust /rpc/locale.uipref*): the choice follows the user to every device.
 * Best-effort and silent — signed out, SQL not run yet, or offline: the device value still works.
 */
async function pushRemote() {
  try {
    await rpcOrRest(
      "locale.uipref.set",
      { path: "/api/locale/uipref", method: "PUT", body: { clock: readClockPref(), layout: readLayoutPref() } },
      { clock: readClockPref(), layout: readLayoutPref() },
    );
  } catch {
    /* keep the local value */
  }
}

let hydrated = false;

/** Once per page load: the account's saved choice wins; if the account has none yet, upload this device's. */
export async function hydrateUiPref(): Promise<void> {
  if (hydrated || typeof window === "undefined") return;
  hydrated = true;
  try {
    const res = await rpcOrRest<{ clock: string | null; layout: string | null }>("locale.uipref", {
      path: "/api/locale/uipref",
    });
    const clock = res.clock === "12" || res.clock === "24" || res.clock === "auto" ? res.clock : null;
    const layout = res.layout === "classic" || res.layout === "expanded" ? res.layout : null;
    if (clock) write(CLOCK_KEY, clock, false);
    if (layout) write(LAYOUT_KEY, layout, false);
    if (!clock && !layout && (read(CLOCK_KEY) || read(LAYOUT_KEY))) void pushRemote();
  } catch {
    /* signed out / not installed yet */
  }
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

/** "14:30" or "2:30 PM" from minutes since midnight (availability slots). */
export function fmtMinutes(m: number): string {
  const h = Math.floor(m / 60) % 24;
  const mi = m % 60;
  if (use12h()) return `${h % 12 || 12}:${two(mi)} ${h < 12 ? "AM" : "PM"}`;
  return `${two(h)}:${two(mi)}`;
}

/** A clock time in any IANA zone, following the clock preference (used where the zone is not the viewer's). */
export function fmtTimeIn(d: Date, timeZone?: string): string {
  try {
    return new Intl.DateTimeFormat(use12h() ? "en-US" : "en-GB", {
      hour: use12h() ? "numeric" : "2-digit",
      minute: "2-digit",
      hour12: use12h(),
      ...(timeZone ? { timeZone } : {}),
    }).format(d);
  } catch {
    return fmtTime(d);
  }
}

/** "Asia/Karachi" -> "Karachi". */
export function cityOf(iana?: string): string {
  const last = (iana ?? zoneCity().iana).split("/").pop() ?? "";
  return last.replace(/_/g, " ");
}
