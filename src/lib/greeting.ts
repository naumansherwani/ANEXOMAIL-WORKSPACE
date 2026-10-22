/**
 * Dashboard greeting that follows the clock AND the season.
 *
 *   05:00–11:59  morning        12:00–(evening start)  afternoon
 *   evening start–21:59  evening        22:00–04:59  night
 *
 * The evening start is not a fixed 5 pm: it follows the sunset of the user's own place, because in winter the day ends early and in
 * summer (other side of the world, or other hemisphere) it ends late. Evening starts an hour before sunset, never earlier than
 * 16:00 or later than 19:00, rounded to 5 minutes. Karachi in late October lands on 17:00.
 *
 * Place = the browser's IANA time zone (no location permission, nothing leaves the device). A zone we have no coordinates for, or a
 * place with no sunset (polar), keeps the plain 17:00. Pure functions: no network, no storage.
 */

export type DayPart = "morning" | "afternoon" | "evening" | "night";

/** [latitude, longitude] of the zone's main city. Enough to place the sunset within a few minutes — a greeting does not need more. */
const ZONES: Record<string, [number, number]> = {
  "Asia/Karachi": [24.86, 67.01],
  "Asia/Kolkata": [28.61, 77.21],
  "Asia/Calcutta": [28.61, 77.21],
  "Asia/Dhaka": [23.81, 90.41],
  "Asia/Colombo": [6.93, 79.86],
  "Asia/Kathmandu": [27.72, 85.32],
  "Asia/Kabul": [34.53, 69.17],
  "Asia/Tashkent": [41.3, 69.24],
  "Asia/Tehran": [35.69, 51.39],
  "Asia/Dubai": [25.2, 55.27],
  "Asia/Riyadh": [24.71, 46.68],
  "Asia/Baghdad": [33.31, 44.37],
  "Asia/Jerusalem": [31.77, 35.21],
  "Asia/Singapore": [1.35, 103.82],
  "Asia/Kuala_Lumpur": [3.14, 101.69],
  "Asia/Jakarta": [-6.21, 106.85],
  "Asia/Bangkok": [13.76, 100.5],
  "Asia/Manila": [14.6, 120.98],
  "Asia/Hong_Kong": [22.32, 114.17],
  "Asia/Shanghai": [31.23, 121.47],
  "Asia/Seoul": [37.57, 126.98],
  "Asia/Tokyo": [35.68, 139.69],
  "Europe/London": [51.51, -0.13],
  "Europe/Dublin": [53.35, -6.26],
  "Europe/Lisbon": [38.72, -9.14],
  "Europe/Paris": [48.86, 2.35],
  "Europe/Madrid": [40.42, -3.7],
  "Europe/Berlin": [52.52, 13.4],
  "Europe/Amsterdam": [52.37, 4.9],
  "Europe/Zurich": [47.37, 8.54],
  "Europe/Rome": [41.9, 12.5],
  "Europe/Stockholm": [59.33, 18.07],
  "Europe/Warsaw": [52.23, 21.01],
  "Europe/Athens": [37.98, 23.73],
  "Europe/Istanbul": [41.01, 28.98],
  "Europe/Moscow": [55.76, 37.62],
  "Africa/Cairo": [30.04, 31.24],
  "Africa/Lagos": [6.52, 3.38],
  "Africa/Nairobi": [-1.29, 36.82],
  "Africa/Johannesburg": [-26.2, 28.05],
  "America/New_York": [40.71, -74.01],
  "America/Toronto": [43.65, -79.38],
  "America/Chicago": [41.88, -87.63],
  "America/Denver": [39.74, -104.99],
  "America/Los_Angeles": [34.05, -118.24],
  "America/Mexico_City": [19.43, -99.13],
  "America/Sao_Paulo": [-23.55, -46.63],
  "America/Argentina/Buenos_Aires": [-34.6, -58.38],
  "Australia/Perth": [-31.95, 115.86],
  "Australia/Sydney": [-33.87, 151.21],
  "Australia/Melbourne": [-37.81, 144.96],
  "Pacific/Auckland": [-36.85, 174.76],
};

export const MIN_EVENING_START = 16 * 60;
export const MAX_EVENING_START = 19 * 60;
export const DEFAULT_EVENING_START = 17 * 60;

const rad = (d: number) => (d * Math.PI) / 180;

/** Offset of `tz` from UTC at `at`, in minutes. */
function offsetMinutes(at: Date, tz: string): number {
  const p = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hourCycle: "h23",
    year: "numeric",
    month: "numeric",
    day: "numeric",
    hour: "numeric",
    minute: "numeric",
    second: "numeric",
  }).formatToParts(at);
  const g = (t: string) => Number(p.find((x) => x.type === t)?.value);
  return Math.round(
    (Date.UTC(g("year"), g("month") - 1, g("day"), g("hour"), g("minute"), g("second")) -
      at.getTime()) /
      60_000,
  );
}

/** Local minutes after midnight of the sunset (NOAA general solar position, accurate to a couple of minutes). null = no sunset that day. */
export function sunsetMinutes(
  at: Date,
  lat: number,
  lon: number,
  offsetMin: number,
): number | null {
  const start = Date.UTC(at.getUTCFullYear(), 0, 0);
  const day = Math.floor((at.getTime() - start) / 86_400_000);
  const g = ((2 * Math.PI) / 365) * (day - 1);
  const eq =
    229.18 *
    (0.000075 +
      0.001868 * Math.cos(g) -
      0.032077 * Math.sin(g) -
      0.014615 * Math.cos(2 * g) -
      0.040849 * Math.sin(2 * g));
  const decl =
    0.006918 -
    0.399912 * Math.cos(g) +
    0.070257 * Math.sin(g) -
    0.006758 * Math.cos(2 * g) +
    0.000907 * Math.sin(2 * g) -
    0.002697 * Math.cos(3 * g) +
    0.00148 * Math.sin(3 * g);
  const c =
    Math.cos(rad(90.833)) / (Math.cos(rad(lat)) * Math.cos(decl)) -
    Math.tan(rad(lat)) * Math.tan(decl);
  if (!Number.isFinite(c) || c < -1 || c > 1) return null;
  const ha = (Math.acos(c) * 180) / Math.PI;
  const utc = 720 - 4 * (lon - ha) - eq;
  return (((utc + offsetMin) % 1440) + 1440) % 1440;
}

/** Minutes after midnight (local) when "Good evening" begins today. */
export function eveningStart(at: Date, tz: string): number {
  const place = ZONES[tz];
  if (!place) return DEFAULT_EVENING_START;
  let off: number;
  try {
    off = offsetMinutes(at, tz);
  } catch {
    return DEFAULT_EVENING_START;
  }
  const set = sunsetMinutes(at, place[0], place[1], off);
  if (set === null) return DEFAULT_EVENING_START;
  const raw = Math.round((set - 60) / 5) * 5;
  return Math.min(MAX_EVENING_START, Math.max(MIN_EVENING_START, raw));
}

/** Local minutes after midnight in `tz`. */
export function localMinutes(at: Date, tz: string): number {
  const p = new Intl.DateTimeFormat("en-US", {
    timeZone: tz,
    hourCycle: "h23",
    hour: "numeric",
    minute: "numeric",
  }).formatToParts(at);
  const g = (t: string) => Number(p.find((x) => x.type === t)?.value);
  return g("hour") * 60 + g("minute");
}

export function browserZone(): string {
  try {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
  } catch {
    return "UTC";
  }
}

/** The zone the person chose in Settings (their home city) wins over the browser's; a missing or unusable name falls back to the browser's. */
export function preferredZone(saved?: string | null): string {
  if (saved) {
    try {
      new Intl.DateTimeFormat("en-US", { timeZone: saved });
      return saved;
    } catch {
      /* not a zone name — ignore */
    }
  }
  return browserZone();
}

export function dayPart(at: Date = new Date(), zone?: string | null): DayPart {
  let tz = preferredZone(zone);
  let m: number;
  try {
    m = localMinutes(at, tz);
  } catch {
    m = at.getHours() * 60 + at.getMinutes();
    tz = "UTC";
  }
  if (m >= 22 * 60 || m < 5 * 60) return "night";
  if (m < 12 * 60) return "morning";
  return m < eveningStart(at, tz) ? "afternoon" : "evening";
}
