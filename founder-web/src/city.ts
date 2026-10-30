// ONE adaptive city for the whole workspace. Every clock, greeting, date and time the founder sees comes from here.
//  - Home city saved in Settings (founder setting "personal.home") wins, exactly.
//  - Otherwise the workspace follows the city of the zone the DEVICE is in right now (travel -> it adapts on the next focus / minute).
// Nothing is guessed from the network and the exact position is never stored: "Detect my city" picks the nearest bundled city on the device.
import { useSyncExternalStore } from "react";
import { isPlace, placeForZone, type Place } from "./places";
import { browserZone } from "./greeting";

export type City = { city: string; country: string; iana: string; lat: number | null; lon: number | null; source: "home" | "device"; device: string };
let home: Place | null = null, snap: City | null = null, key = "";
const subs = new Set<() => void>();
const emit = () => subs.forEach((f) => f());

function compute(): City {
  const dz = browserZone();
  const k = home ? `h:${home.city}:${home.iana}` : `d:${dz}`;
  if (snap && k === key) return snap;
  key = k;
  if (home) snap = { city: home.city, country: home.country || "", iana: home.iana, lat: home.lat, lon: home.lon, source: "home", device: dz };
  else { const p = placeForZone(dz); snap = { city: p ? p.city : (dz.split("/").pop() ?? dz).replace(/_/g, " "), country: p ? p.country : "", iana: dz, lat: p ? p.lat : null, lon: p ? p.lon : null, source: "device", device: dz }; }
  return snap;
}

/** Apply the saved home city (null / anything malformed = adapt to the device). */
export function setHome(p: unknown) { const h: Place | null = isPlace(p) ? p : null; if ((h && home && h.city === home.city && h.iana === home.iana) || (!h && !home)) return; home = h; emit(); }
export const cityNow = () => compute();
export function useCity() {
  return useSyncExternalStore((f) => { subs.add(f); return () => subs.delete(f); }, compute, compute);
}
// Travel: when the tab regains focus or the minute changes, re-read the device zone (cheap; compute() is memoised on the zone).
if (typeof window !== "undefined") { window.addEventListener("focus", emit); setInterval(emit, 60_000); }

type D = Date | string | number;
const fmt = (d: D, o: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat("en-GB", { timeZone: compute().iana, ...o }).format(d instanceof Date ? d : new Date(d));
// 12-hour clock everywhere (founder 28 Oct 13:01: "12 ghantay wala chaiye")
export const fmtTime = (d: D) => fmt(d, { hour: "numeric", minute: "2-digit", second: "2-digit", hour12: true }).toUpperCase();
export const fmtHM = (d: D) => fmt(d, { hour: "numeric", minute: "2-digit", hour12: true }).toUpperCase();
export const fmtDateTime = (d: D) => fmt(d, { day: "2-digit", month: "short", year: "numeric", hour: "numeric", minute: "2-digit", hour12: true }).toUpperCase();
export const fmtDay = (d: D) => fmt(d, { weekday: "long", day: "numeric", month: "long" });
export const coordsOf = (c: { lat: number | null; lon: number | null }) => (c.lat != null && c.lon != null && Number.isFinite(c.lat) && Number.isFinite(c.lon) ? { lat: c.lat, lon: c.lon } : undefined);
