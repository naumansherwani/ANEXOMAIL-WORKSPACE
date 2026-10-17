/**
 * ICS (iCalendar) reader for "switch to ANEXOMAIL": turns the .ics file a person exports from Google Calendar, Zoho, Outlook or
 * Apple into meetings ANEXOMAIL can create. Pure functions, no network, no dependency — the file is read in the browser and only
 * the events the person confirms are sent (through the same calendar.create route a hand-made meeting uses).
 *
 * Honest limits (reported back as counts, never hidden):
 *  - all-day events are skipped (calendar_events.all_day is not writable through calendar.create)
 *  - recurring series: DAILY / WEEKLY(BYDAY) / MONTHLY(same day of month) / YEARLY with INTERVAL, COUNT, UNTIL and EXDATE are
 *    expanded over the import window; anything fancier (BYSETPOS, "2nd Tuesday"…) imports its first occurrence only
 *  - a time zone we cannot read (not IANA, not a common Windows name) is placed in the device's own time zone
 */

export type IcsEvent = {
  uid: string;
  title: string;
  starts_at: string; // ISO UTC
  duration_minutes: number;
  agenda: string;
  location?: string;
  attendees: string[];
  timezone?: string;
};

export type IcsStats = {
  found: number;
  willImport: number;
  allDaySkipped: number;
  cancelledSkipped: number;
  outsideWindow: number;
  seriesExpanded: number;
  seriesFirstOnly: number;
  unknownZone: number;
  capped: boolean;
};

export type IcsPlan = { events: IcsEvent[]; stats: IcsStats };

export const IMPORT_BACK_DAYS = 30;
export const IMPORT_FORWARD_DAYS = 180;
export const IMPORT_MAX_EVENTS = 500;
const MAX_PER_SERIES = 120;
const DAY = 86_400_000;

const WINDOWS_ZONES: Record<string, string> = {
  "GMT Standard Time": "Europe/London",
  "Greenwich Standard Time": "Atlantic/Reykjavik",
  "W. Europe Standard Time": "Europe/Berlin",
  "Central Europe Standard Time": "Europe/Budapest",
  "Central European Standard Time": "Europe/Warsaw",
  "Romance Standard Time": "Europe/Paris",
  "GTB Standard Time": "Europe/Athens",
  "E. Europe Standard Time": "Europe/Chisinau",
  "FLE Standard Time": "Europe/Kiev",
  "Russian Standard Time": "Europe/Moscow",
  "Turkey Standard Time": "Europe/Istanbul",
  "Israel Standard Time": "Asia/Jerusalem",
  "Arab Standard Time": "Asia/Riyadh",
  "Arabian Standard Time": "Asia/Dubai",
  "Pakistan Standard Time": "Asia/Karachi",
  "India Standard Time": "Asia/Kolkata",
  "Bangladesh Standard Time": "Asia/Dhaka",
  "SE Asia Standard Time": "Asia/Bangkok",
  "China Standard Time": "Asia/Shanghai",
  "Singapore Standard Time": "Asia/Singapore",
  "Tokyo Standard Time": "Asia/Tokyo",
  "Korea Standard Time": "Asia/Seoul",
  "AUS Eastern Standard Time": "Australia/Sydney",
  "E. Australia Standard Time": "Australia/Brisbane",
  "New Zealand Standard Time": "Pacific/Auckland",
  "South Africa Standard Time": "Africa/Johannesburg",
  "Egypt Standard Time": "Africa/Cairo",
  "W. Central Africa Standard Time": "Africa/Lagos",
  "E. Africa Standard Time": "Africa/Nairobi",
  "Eastern Standard Time": "America/New_York",
  "Central Standard Time": "America/Chicago",
  "Mountain Standard Time": "America/Denver",
  "US Mountain Standard Time": "America/Phoenix",
  "Pacific Standard Time": "America/Los_Angeles",
  "Alaskan Standard Time": "America/Anchorage",
  "Hawaiian Standard Time": "Pacific/Honolulu",
  "Canada Central Standard Time": "America/Regina",
  "Atlantic Standard Time": "America/Halifax",
  "E. South America Standard Time": "America/Sao_Paulo",
  "Argentina Standard Time": "America/Argentina/Buenos_Aires",
  "Mexico Standard Time": "America/Mexico_City",
  UTC: "UTC",
};

type Prop = { name: string; params: Record<string, string>; value: string };
type Wall = { y: number; m: number; d: number; hh: number; mm: number; ss: number };

const unescapeText = (s: string) =>
  s.replace(/\\n/gi, "\n").replace(/\\,/g, ",").replace(/\\;/g, ";").replace(/\\\\/g, "\\");

function parseLine(line: string): Prop | null {
  // NAME;PARAM=v;PARAM="v:with:colon":value  — the first colon outside quotes ends the name+params
  let inQ = false;
  let idx = -1;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') inQ = !inQ;
    else if (ch === ":" && !inQ) {
      idx = i;
      break;
    }
  }
  if (idx < 1) return null;
  const head = line.slice(0, idx);
  const value = line.slice(idx + 1);
  const parts = head.split(";");
  const name = (parts.shift() || "").toUpperCase();
  const params: Record<string, string> = {};
  for (const p of parts) {
    const eq = p.indexOf("=");
    if (eq > 0) params[p.slice(0, eq).toUpperCase()] = p.slice(eq + 1).replace(/^"|"$/g, "");
  }
  return { name, params, value };
}

type DateVal = { wall: Wall; allDay: boolean; utc: boolean; tz: string | null };

function parseDate(p: Prop): DateVal | null {
  const v = p.value.trim();
  const m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/i.exec(v);
  if (!m) return null;
  const allDay = p.params["VALUE"] === "DATE" || m[4] === undefined;
  return {
    wall: { y: +m[1]!, m: +m[2]!, d: +m[3]!, hh: +(m[4] ?? 0), mm: +(m[5] ?? 0), ss: +(m[6] ?? 0) },
    allDay,
    utc: Boolean(m[7]),
    tz: p.params["TZID"] ?? null,
  };
}

function resolveZone(tzid: string | null): { zone: string | null; unknown: boolean } {
  if (!tzid) return { zone: null, unknown: false };
  const candidate = WINDOWS_ZONES[tzid] ?? tzid.replace(/^\//, "");
  try {
    new Intl.DateTimeFormat("en-US", { timeZone: candidate });
    return { zone: candidate, unknown: false };
  } catch {
    return { zone: null, unknown: true };
  }
}

function tzOffsetMinutes(utcMs: number, zone: string): number {
  const dtf = new Intl.DateTimeFormat("en-US", {
    timeZone: zone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const q: Record<string, number> = {};
  for (const part of dtf.formatToParts(new Date(utcMs))) if (part.type !== "literal") q[part.type] = +part.value;
  const asUtc = Date.UTC(q["year"]!, q["month"]! - 1, q["day"]!, q["hour"]!, q["minute"]!, q["second"]!);
  return (asUtc - utcMs) / 60000;
}

/** Wall-clock time in `zone` (or the device zone when null) -> absolute ms. */
export function wallToMs(w: Wall, zone: string | null, utc: boolean): number {
  if (utc) return Date.UTC(w.y, w.m - 1, w.d, w.hh, w.mm, w.ss);
  if (!zone) return new Date(w.y, w.m - 1, w.d, w.hh, w.mm, w.ss).getTime();
  const guess = Date.UTC(w.y, w.m - 1, w.d, w.hh, w.mm, w.ss);
  const off = tzOffsetMinutes(guess, zone);
  let ms = guess - off * 60000;
  const off2 = tzOffsetMinutes(ms, zone);
  if (off2 !== off) ms = guess - off2 * 60000;
  return ms;
}

function parseDuration(v: string): number | null {
  const m = /^([+-])?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$/i.exec(v.trim());
  if (!m) return null;
  const mins =
    +(m[2] ?? 0) * 7 * 1440 + +(m[3] ?? 0) * 1440 + +(m[4] ?? 0) * 60 + +(m[5] ?? 0) + Math.round(+(m[6] ?? 0) / 60);
  return m[1] === "-" ? -mins : mins;
}

const BYDAY: Record<string, number> = { MO: 1, TU: 2, WE: 3, TH: 4, FR: 5, SA: 6, SU: 0 };

type Rule = {
  freq: string;
  interval: number;
  count: number | null;
  until: number | null;
  byday: number[] | null;
  supported: boolean;
};

function parseRule(raw: string, start: DateVal, zone: string | null): Rule {
  const kv: Record<string, string> = {};
  for (const part of raw.split(";")) {
    const eq = part.indexOf("=");
    if (eq > 0) kv[part.slice(0, eq).toUpperCase()] = part.slice(eq + 1);
  }
  const freq = (kv["FREQ"] ?? "").toUpperCase();
  let supported = ["DAILY", "WEEKLY", "MONTHLY", "YEARLY"].includes(freq);
  if (kv["BYSETPOS"] || kv["BYWEEKNO"] || kv["BYYEARDAY"] || kv["BYHOUR"] || kv["BYMINUTE"]) supported = false;
  let byday: number[] | null = null;
  if (kv["BYDAY"]) {
    const toks = kv["BYDAY"].split(",");
    if (freq === "WEEKLY" && toks.every((t) => /^[+-]?\d*(MO|TU|WE|TH|FR|SA|SU)$/.test(t) && !/^[+-]?\d+/.test(t))) {
      byday = toks.map((t) => BYDAY[t.slice(-2)]!);
    } else supported = false; // "2nd Tuesday", BYDAY on daily/monthly/yearly
  }
  if (kv["BYMONTHDAY"] && (freq !== "MONTHLY" || +kv["BYMONTHDAY"] !== start.wall.d)) supported = false;
  if (kv["BYMONTH"] && freq !== "YEARLY") supported = false;
  let until: number | null = null;
  if (kv["UNTIL"]) {
    const u = parseDate({ name: "UNTIL", params: {}, value: kv["UNTIL"] });
    if (u) until = u.allDay ? Date.UTC(u.wall.y, u.wall.m - 1, u.wall.d, 23, 59, 59) : wallToMs(u.wall, u.utc ? null : zone, u.utc);
  }
  return {
    freq,
    interval: Math.max(1, +(kv["INTERVAL"] ?? 1) || 1),
    count: kv["COUNT"] ? Math.max(1, +kv["COUNT"] || 1) : null,
    until,
    byday,
    supported,
  };
}

/** Wall-clock occurrences of a rule, from the series start up to `endMs` (absolute), at most MAX_PER_SERIES in range. */
function expand(rule: Rule, start: DateVal, zone: string | null, fromMs: number, endMs: number): Wall[] {
  const out: Wall[] = [];
  const s = start.wall;
  const startDay = Date.UTC(s.y, s.m - 1, s.d);
  const startDow = new Date(startDay).getUTCDay();
  const weekStart = (t: number) => t - ((new Date(t).getUTCDay() + 6) % 7) * DAY; // Monday 00:00
  const baseWeek = weekStart(startDay);
  let counted = 0;
  const limitDays = Math.ceil((endMs - startDay) / DAY) + 2;
  for (let i = 0; i <= Math.min(limitDays, 4000); i++) {
    const dayMs = startDay + i * DAY;
    const dt = new Date(dayMs);
    const y = dt.getUTCFullYear(), m = dt.getUTCMonth() + 1, d = dt.getUTCDate();
    let hit = false;
    if (rule.freq === "DAILY") hit = i % rule.interval === 0;
    else if (rule.freq === "WEEKLY") {
      const weeks = Math.round((weekStart(dayMs) - baseWeek) / (7 * DAY));
      const days = rule.byday ?? [startDow];
      hit = weeks % rule.interval === 0 && days.includes(dt.getUTCDay());
    } else if (rule.freq === "MONTHLY") {
      const months = (y - s.y) * 12 + (m - s.m);
      hit = d === s.d && months >= 0 && months % rule.interval === 0;
    } else if (rule.freq === "YEARLY") {
      hit = m === s.m && d === s.d && (y - s.y) % rule.interval === 0;
    }
    if (!hit) continue;
    const w: Wall = { y, m, d, hh: s.hh, mm: s.mm, ss: s.ss };
    const ms = wallToMs(w, zone, start.utc);
    if (rule.until !== null && ms > rule.until) break;
    counted++;
    if (rule.count !== null && counted > rule.count) break;
    if (ms > endMs) break;
    if (ms >= fromMs) out.push(w);
    if (out.length >= MAX_PER_SERIES) break;
  }
  return out;
}

function unfold(text: string): string[] {
  return text.replace(/\r\n/g, "\n").replace(/\r/g, "\n").replace(/\n[ \t]/g, "").split("\n");
}

export function parseIcs(text: string, now: Date = new Date()): IcsPlan {
  const stats: IcsStats = {
    found: 0, willImport: 0, allDaySkipped: 0, cancelledSkipped: 0, outsideWindow: 0,
    seriesExpanded: 0, seriesFirstOnly: 0, unknownZone: 0, capped: false,
  };
  const fromMs = now.getTime() - IMPORT_BACK_DAYS * DAY;
  const endMs = now.getTime() + IMPORT_FORWARD_DAYS * DAY;
  const lines = unfold(text);

  const blocks: Prop[][] = [];
  let cur: Prop[] | null = null;
  let depth = 0; // VALARM etc. nested inside VEVENT are ignored
  for (const line of lines) {
    if (!line) continue;
    const up = line.toUpperCase();
    if (up === "BEGIN:VEVENT") {
      cur = [];
      depth = 0;
      continue;
    }
    if (up === "END:VEVENT") {
      if (cur) blocks.push(cur);
      cur = null;
      continue;
    }
    if (!cur) continue;
    if (up.startsWith("BEGIN:")) {
      depth++;
      continue;
    }
    if (up.startsWith("END:")) {
      depth = Math.max(0, depth - 1);
      continue;
    }
    if (depth > 0) continue;
    const p = parseLine(line);
    if (p) cur.push(p);
  }

  // overrides: a RECURRENCE-ID instance replaces one generated occurrence of its series
  const overridden = new Set<string>();
  for (const b of blocks) {
    const rid = b.find((p) => p.name === "RECURRENCE-ID");
    const uid = b.find((p) => p.name === "UID")?.value;
    const dv = rid ? parseDate(rid) : null;
    if (dv && uid) {
      const { zone } = resolveZone(dv.tz);
      overridden.add(`${uid}|${wallToMs(dv.wall, zone, dv.utc)}`);
    }
  }

  const events: IcsEvent[] = [];
  const seen = new Set<string>();
  const push = (e: IcsEvent) => {
    const k = `${e.uid}|${e.starts_at}`;
    if (seen.has(k)) return;
    seen.add(k);
    events.push(e);
  };

  for (const b of blocks) {
    stats.found++;
    const get = (n: string) => b.find((p) => p.name === n);
    if ((get("STATUS")?.value ?? "").toUpperCase() === "CANCELLED") {
      stats.cancelledSkipped++;
      continue;
    }
    const ds = get("DTSTART");
    const start = ds ? parseDate(ds) : null;
    if (!start) continue;
    if (start.allDay) {
      stats.allDaySkipped++;
      continue;
    }
    const { zone, unknown } = start.utc ? { zone: null, unknown: false } : resolveZone(start.tz);
    if (unknown) stats.unknownZone++;
    const startMs = wallToMs(start.wall, zone, start.utc);

    let duration = 60;
    const de = get("DTEND");
    const dd = get("DURATION");
    if (de) {
      const e = parseDate(de);
      if (e && !e.allDay) {
        const z2 = e.utc ? null : resolveZone(e.tz ?? start.tz).zone;
        duration = Math.max(5, Math.round((wallToMs(e.wall, z2, e.utc) - startMs) / 60000));
      }
    } else if (dd) {
      const m = parseDuration(dd.value);
      if (m && m > 0) duration = m;
    }
    duration = Math.min(duration, 24 * 60);

    const title = unescapeText(get("SUMMARY")?.value ?? "").trim().slice(0, 200);
    const desc = unescapeText(get("DESCRIPTION")?.value ?? "").trim();
    const location = unescapeText(get("LOCATION")?.value ?? "").trim().slice(0, 300);
    const uid = get("UID")?.value ?? `noid-${startMs}`;
    const attendees = [
      ...new Set(
        b
          .filter((p) => p.name === "ATTENDEE")
          .map((p) => p.value.replace(/^mailto:/i, "").trim().toLowerCase())
          .filter((a) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(a) && !a.includes("calendar.google.com")),
      ),
    ];
    const base = {
      uid,
      title: title.length >= 2 ? title : "Untitled event",
      duration_minutes: duration,
      agenda: desc.length >= 5 ? desc.slice(0, 600) : "Imported from your calendar file",
      ...(location ? { location } : {}),
      attendees,
      ...(zone ? { timezone: zone } : {}),
    };

    const rr = get("RRULE");
    if (!rr) {
      if (startMs < fromMs || startMs > endMs) {
        stats.outsideWindow++;
        continue;
      }
      push({ ...base, starts_at: new Date(startMs).toISOString() });
      continue;
    }

    const rule = parseRule(rr.value, start, zone);
    if (!rule.supported) {
      stats.seriesFirstOnly++;
      if (startMs >= fromMs && startMs <= endMs) push({ ...base, starts_at: new Date(startMs).toISOString() });
      else stats.outsideWindow++;
      continue;
    }
    const exdates = new Set<number>();
    for (const x of b.filter((p) => p.name === "EXDATE"))
      for (const v of x.value.split(",")) {
        const dv = parseDate({ name: "EXDATE", params: x.params, value: v });
        if (dv) exdates.add(wallToMs(dv.wall, dv.utc ? null : resolveZone(dv.tz ?? start.tz).zone, dv.utc));
      }
    const occ = expand(rule, start, zone, fromMs, endMs);
    stats.seriesExpanded++;
    let added = 0;
    for (const w of occ) {
      const ms = wallToMs(w, zone, start.utc);
      if (exdates.has(ms) || overridden.has(`${uid}|${ms}`)) continue;
      push({ ...base, starts_at: new Date(ms).toISOString() });
      added++;
    }
    if (added === 0) stats.outsideWindow++;
  }

  events.sort((a, b) => a.starts_at.localeCompare(b.starts_at));
  if (events.length > IMPORT_MAX_EVENTS) {
    stats.capped = true;
    events.length = IMPORT_MAX_EVENTS;
  }
  stats.willImport = events.length;
  return { events, stats };
}

/** Same event imported twice from the same file in this browser is skipped — key stored by the panel. */
export const importKey = (e: Pick<IcsEvent, "uid" | "starts_at">) => `${e.uid}|${e.starts_at}`;
