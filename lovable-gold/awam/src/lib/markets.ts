/**
 * World clock W5 — market open/closed chip (opt-in, default OFF).
 *
 * Only the REGULAR weekday sessions of a few big exchanges, in the exchange's own time zone. Public holidays and early closes are
 * NOT checked, and the chip says so. No price, no data feed, nothing leaves the device.
 */
export type Exchange = { code: string; name: string; zone: string; sessions: [string, string][] };

export const EXCHANGES: Exchange[] = [
  {
    code: "NYSE",
    name: "New York (NYSE / Nasdaq)",
    zone: "America/New_York",
    sessions: [["09:30", "16:00"]],
  },
  { code: "LSE", name: "London (LSE)", zone: "Europe/London", sessions: [["08:00", "16:30"]] },
  {
    code: "XETRA",
    name: "Frankfurt (Xetra)",
    zone: "Europe/Berlin",
    sessions: [["09:00", "17:30"]],
  },
  { code: "NSE", name: "Mumbai (NSE)", zone: "Asia/Kolkata", sessions: [["09:15", "15:30"]] },
  {
    code: "HKEX",
    name: "Hong Kong (HKEX)",
    zone: "Asia/Hong_Kong",
    sessions: [
      ["09:30", "12:00"],
      ["13:00", "16:00"],
    ],
  },
  {
    code: "TSE",
    name: "Tokyo (TSE)",
    zone: "Asia/Tokyo",
    sessions: [
      ["09:00", "11:30"],
      ["12:30", "15:30"],
    ],
  },
];

export type MarketState = { open: boolean; weekend: boolean; minsToChange: number | null };

const mins = (hhmm: string) => Number(hhmm.slice(0, 2)) * 60 + Number(hhmm.slice(3, 5));

/** Local weekday (0=Sun) and minutes-after-midnight in `zone` at `nowMs`. */
function localParts(nowMs: number, zone: string): { wd: number; m: number } {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: zone,
    weekday: "short",
    hour: "2-digit",
    minute: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date(nowMs));
  const get = (t: string) => parts.find((p) => p.type === t)?.value ?? "";
  const wd = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].indexOf(get("weekday"));
  return { wd, m: Number(get("hour")) * 60 + Number(get("minute")) };
}

export function marketState(ex: Exchange, nowMs: number): MarketState {
  const { wd, m } = localParts(nowMs, ex.zone);
  if (wd === 0 || wd === 6) return { open: false, weekend: true, minsToChange: null };
  for (const [a, b] of ex.sessions) {
    if (m >= mins(a) && m < mins(b))
      return { open: true, weekend: false, minsToChange: mins(b) - m };
  }
  const next = ex.sessions.map(([a]) => mins(a)).find((s) => s > m);
  return { open: false, weekend: false, minsToChange: next === undefined ? null : next - m };
}

export function exchangesForZone(zone: string): Exchange[] {
  return EXCHANGES.filter((e) => e.zone === zone);
}

export function spanWord(min: number): string {
  if (min < 60) return `${min} min`;
  const h = Math.floor(min / 60);
  const r = min % 60;
  return r === 0 ? `${h} h` : `${h} h ${r} min`;
}

/** "NYSE open · closes in 2 h 5 min" / "TSE closed · opens in 3 h" / "LSE closed (weekend)". */
export function marketLine(ex: Exchange, s: MarketState): string {
  if (s.weekend) return `${ex.code} closed (weekend)`;
  if (s.open) return `${ex.code} open · closes in ${spanWord(s.minsToChange ?? 0)}`;
  return s.minsToChange === null
    ? `${ex.code} closed`
    : `${ex.code} closed · opens in ${spanWord(s.minsToChange)}`;
}
