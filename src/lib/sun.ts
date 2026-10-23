/**
 * Sun position, day/night — pure maths, no API, no network (World clock W3).
 *
 * Low-precision NOAA/Meeus formulas: the sub-solar point is right to about 0.01° (well under a pixel on the globe), which is
 * all a clock face needs. Nothing here is a forecast or a measurement of weather; it is astronomy for a given instant.
 */
const RAD = Math.PI / 180;
const DEG = 180 / Math.PI;

const mod = (a: number, n: number) => ((a % n) + n) % n;
/** Wrap a longitude to −180…180. */
export const wrapLon = (lon: number) => mod(lon + 180, 360) - 180;

/** The point on Earth where the Sun is straight overhead at instant `d`. */
export function subsolarPoint(d: Date): { lat: number; lon: number } {
  const n = d.getTime() / 86_400_000 + 2440587.5 - 2451545.0; // days since J2000.0
  const L = mod(280.46 + 0.9856474 * n, 360); // mean longitude
  const g = mod(357.528 + 0.9856003 * n, 360) * RAD; // mean anomaly
  const lambda = (L + 1.915 * Math.sin(g) + 0.02 * Math.sin(2 * g)) * RAD; // ecliptic longitude
  const eps = (23.439 - 0.0000004 * n) * RAD; // obliquity
  const dec = Math.asin(Math.sin(eps) * Math.sin(lambda));
  const ra = Math.atan2(Math.cos(eps) * Math.sin(lambda), Math.cos(lambda));
  const gmst = mod(280.46061837 + 360.98564736629 * n, 360); // Greenwich sidereal angle, degrees
  return { lat: dec * DEG, lon: wrapLon(ra * DEG - gmst) };
}

/** Sun height above the horizon in degrees at (lat, lon): > 0 day, < 0 night, −6…0 civil twilight. */
export function sunAltitude(lat: number, lon: number, sun: { lat: number; lon: number }): number {
  const phi = lat * RAD;
  const dec = sun.lat * RAD;
  const h = (lon - sun.lon) * RAD;
  const s = Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(h);
  return Math.asin(Math.max(-1, Math.min(1, s))) * DEG;
}

/** "day" | "twilight" | "night" for a place — the words the clock popover uses next to a city. */
export function dayPhase(lat: number, lon: number, d: Date): "day" | "twilight" | "night" {
  const alt = sunAltitude(lat, lon, subsolarPoint(d));
  return alt > 0 ? "day" : alt > -6 ? "twilight" : "night";
}
