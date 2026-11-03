/**
 * Repeating meetings (B7b) — every package, no plan gate.
 *
 * The browser only picks a pattern and builds an RFC 5545 rule string; the Rust calendar engine validates it,
 * expands it (time zone + DST aware) and mails real invitations. Nothing here needs a library.
 */

export type RepeatKind =
  | "none"
  | "daily"
  | "weekdays"
  | "weekly"
  | "biweekly"
  | "monthly_day"
  | "monthly_nth"
  | "yearly";

export type RepeatEnd =
  | { kind: "never" }
  | { kind: "count"; count: number }
  | { kind: "until"; date: string }; // yyyy-mm-dd, the last day a meeting may START (organiser's local date)

export type RepeatSpec = {
  kind: RepeatKind;
  /** 0 = Sunday … 6 = Saturday; used by weekly / biweekly. Empty = the start day. */
  days: number[];
  end: RepeatEnd;
};

export const NO_REPEAT: RepeatSpec = { kind: "none", days: [], end: { kind: "never" } };

const CODES = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"] as const;
const LONG = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"] as const;
const ORD = ["", "first", "second", "third", "fourth", "fifth"] as const;
export const MAX_REPEAT_COUNT = 500;

/** Which occurrence of its weekday in the month a date is (1..5), and whether it is the last one. */
export function nthOfMonth(d: Date): { nth: number; last: boolean } {
  const nth = Math.floor((d.getDate() - 1) / 7) + 1;
  const last = d.getDate() + 7 > new Date(d.getFullYear(), d.getMonth() + 1, 0).getDate();
  return { nth, last };
}

function untilStamp(date: string): string | null {
  const m = /^(\d{4})-(\d{2})-(\d{2})$/.exec(date);
  if (!m) return null;
  const end = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), 23, 59, 59);
  if (Number.isNaN(end.getTime())) return null;
  return end.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "");
}

/** RFC 5545 rule for a pattern starting on `start` (local time of the organiser), or undefined for "does not repeat". */
export function buildRrule(spec: RepeatSpec, start: Date): string | undefined {
  if (spec.kind === "none" || Number.isNaN(start.getTime())) return undefined;
  const wd = start.getDay();
  let rule: string;
  switch (spec.kind) {
    case "daily":
      rule = "FREQ=DAILY";
      break;
    case "weekdays":
      rule = "FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR";
      break;
    case "weekly":
    case "biweekly": {
      const days = (spec.days.length ? [...new Set(spec.days)] : [wd]).sort((a, b) => a - b);
      rule = `FREQ=WEEKLY${spec.kind === "biweekly" ? ";INTERVAL=2" : ""};BYDAY=${days.map((d) => CODES[d]).join(",")}`;
      break;
    }
    case "monthly_day":
      rule = `FREQ=MONTHLY;BYMONTHDAY=${start.getDate()}`;
      break;
    case "monthly_nth": {
      const { nth, last } = nthOfMonth(start);
      rule = `FREQ=MONTHLY;BYDAY=${last && nth >= 4 ? -1 : nth}${CODES[wd]}`;
      break;
    }
    case "yearly":
      rule = "FREQ=YEARLY";
      break;
  }
  if (spec.end.kind === "count") {
    const c = Math.min(MAX_REPEAT_COUNT, Math.max(1, Math.floor(spec.end.count || 1)));
    rule += `;COUNT=${c}`;
  } else if (spec.end.kind === "until") {
    const u = untilStamp(spec.end.date);
    if (u) rule += `;UNTIL=${u}`;
  }
  return rule;
}

/** Plain-English label for the picker ("Every week on Monday, Wednesday"). */
export function describeRepeat(spec: RepeatSpec, start: Date): string {
  const wd = start.getDay();
  switch (spec.kind) {
    case "none":
      return "Does not repeat";
    case "daily":
      return "Every day";
    case "weekdays":
      return "Every weekday (Mon–Fri)";
    case "weekly":
    case "biweekly": {
      const days = (spec.days.length ? [...spec.days] : [wd]).sort((a, b) => a - b);
      return `${spec.kind === "weekly" ? "Every week" : "Every 2 weeks"} on ${days.map((d) => LONG[d]).join(", ")}`;
    }
    case "monthly_day":
      return `Every month on day ${start.getDate()}`;
    case "monthly_nth": {
      const { nth, last } = nthOfMonth(start);
      return `Every month on the ${last && nth >= 4 ? "last" : ORD[nth]} ${LONG[wd]}`;
    }
    case "yearly":
      return `Every year on ${start.toLocaleDateString(undefined, { day: "numeric", month: "long" })}`;
  }
}

/** Short human text for an RRULE string we got back from the server (list/detail badges). */
export function humanRrule(rule: string | null | undefined): string {
  if (!rule) return "";
  const p = new Map<string, string>();
  for (const part of rule.replace(/^RRULE:/i, "").split(";")) {
    const [k, v] = part.split("=");
    if (k && v) p.set(k.toUpperCase(), v.toUpperCase());
  }
  const interval = Number(p.get("INTERVAL") ?? "1") || 1;
  const unit = { DAILY: "day", WEEKLY: "week", MONTHLY: "month", YEARLY: "year" }[p.get("FREQ") ?? ""] ?? "";
  if (!unit) return "Repeats";
  let s = interval === 1 ? `Every ${unit}` : `Every ${interval} ${unit}s`;
  const by = p.get("BYDAY");
  if (by) {
    const names = by.split(",").map((d) => {
      const code = d.slice(-2);
      const n = d.slice(0, -2);
      const i = CODES.indexOf(code as (typeof CODES)[number]);
      const name = i >= 0 ? LONG[i]!.slice(0, 3) : code;
      if (!n) return name;
      return n === "-1" ? `last ${name}` : `${ORD[Number(n)] ?? n} ${name}`;
    });
    s += ` on ${names.join(", ")}`;
  }
  const count = p.get("COUNT");
  if (count) s += `, ${count} times`;
  const until = p.get("UNTIL");
  if (until && /^\d{8}/.test(until)) s += ` until ${until.slice(6, 8)}/${until.slice(4, 6)}/${until.slice(0, 4)}`;
  return s;
}
