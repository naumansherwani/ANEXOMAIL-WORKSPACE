// ADMIN DESK 1m (cards B1 Queue pressure + B2 SLA at risk), 23 Nov 2026. Pure parsing of the two read-only doors (/desk/v1/queues/pressure and /risk). Fail-closed: anything that is not exactly the agreed shape is null,
// and the screen then says "Data unavailable". Words never promise: the 15 minutes are a warning window, not a promise. Metadata only, no money.
export const QUEUE_NAMES = ["general", "support", "movein", "billing"] as const;
export type QueueName = (typeof QUEUE_NAMES)[number];
export const QUEUE_WORDS: Record<QueueName, string> = { general: "General", support: "Support", movein: "Move-in", billing: "Billing" };
export const LEVELS = ["calm", "busy", "strained", "overloaded"] as const;
export type Level = (typeof LEVELS)[number] | "none";
export type Trend = "growing" | "steady" | "shrinking" | "unknown";
export type QueueRow = { queue: QueueName; readable: boolean; new: number; open: number; waiting: number; atRisk: number; oldestMinutes: number | null; arrived60: number; answered60: number;
  ages: [number, number, number, number, number]; spark: (number | null)[]; trend: Trend; clearMinutes: number | null; level: Level };
export type RiskRow = { ref: string; queue: QueueName; minutesLeft: number; overdue: boolean };
export const AGE_LABELS = ["under 15 min", "15 min to 1 h", "1 to 4 h", "4 to 24 h", "over 24 h"] as const;
const nat = (x: unknown): x is number => typeof x === "number" && Number.isInteger(x) && x >= 0;
export function parsePressure(j: unknown): QueueRow[] | null {
  const o = j as { queues?: unknown; risk_window_minutes?: unknown } | null;
  if (!o || o.risk_window_minutes !== 15 || !Array.isArray(o.queues) || o.queues.length !== 4) return null;
  const out: QueueRow[] = [];
  for (let i = 0; i < 4; i++) {
    const r = o.queues[i] as Record<string, unknown> | null;
    if (!r || r.queue !== QUEUE_NAMES[i] || typeof r.readable !== "boolean") return null;
    if (!nat(r.new) || !nat(r.open) || !nat(r.waiting) || !nat(r.at_risk) || !nat(r.arrived_60m) || !nat(r.answered_60m)) return null;
    if (!(r.oldest_minutes === null || nat(r.oldest_minutes))) return null;
    if (!Array.isArray(r.ages) || r.ages.length !== 5 || !r.ages.every(nat)) return null;
    if (!Array.isArray(r.spark) || r.spark.length !== 12 || !r.spark.every((n) => n === null || nat(n))) return null;
    if (!["growing", "steady", "shrinking", "unknown"].includes(r.trend as string)) return null;
    if (!(r.clear_minutes === null || (nat(r.clear_minutes) && r.clear_minutes > 0))) return null;
    const lv = r.level as string;
    if (r.readable ? !(LEVELS as readonly string[]).includes(lv) : lv !== "none") return null;
    out.push({ queue: QUEUE_NAMES[i], readable: r.readable, new: r.new, open: r.open, waiting: r.waiting, atRisk: r.at_risk, oldestMinutes: r.oldest_minutes as number | null, arrived60: r.arrived_60m, answered60: r.answered_60m,
      ages: r.ages as QueueRow["ages"], spark: r.spark as (number | null)[], trend: r.trend as Trend, clearMinutes: r.clear_minutes as number | null, level: lv as Level });
  }
  return out;
}
export function parseRisk(j: unknown): RiskRow[] | null {
  const o = j as { cases?: unknown; risk_window_minutes?: unknown } | null;
  if (!o || o.risk_window_minutes !== 15 || !Array.isArray(o.cases) || o.cases.length > 20) return null;
  const out: RiskRow[] = [];
  for (const c of o.cases as Record<string, unknown>[]) {
    if (!c || typeof c.ref !== "string" || !/^C-\d{6,}$/.test(c.ref) || !QUEUE_NAMES.includes(c.queue as QueueName) || !Number.isInteger(c.minutes_left) || typeof c.overdue !== "boolean") return null;
    out.push({ ref: c.ref, queue: c.queue as QueueName, minutesLeft: c.minutes_left as number, overdue: c.overdue });
  }
  return out;
}
export const totalWaiting = (rows: QueueRow[]) => rows.reduce((n, r) => n + r.new + r.open + r.waiting, 0);
export const totalAtRisk = (rows: QueueRow[]) => rows.reduce((n, r) => n + r.atRisk, 0);
export function ageWords(min: number | null): string {
  if (min === null) return "none waiting";
  if (min < 60) return `${min} min`;
  const h = Math.floor(min / 60), m = min % 60;
  return h < 48 ? `${h} h ${m} min` : `${Math.floor(h / 24)} days`;
}
export function riskWords(r: RiskRow): string {
  if (r.overdue) return `${-r.minutesLeft} min past its target`;
  return r.minutesLeft <= 0 ? "due now" : `${r.minutesLeft} min left to the target`;
}
export const WINDOW_NOTE = "At risk means the first-answer target ends in under 15 minutes or has passed. It is a warning for the team, not a promise to a customer.";
export const LEVEL_WORDS: Record<Level, string> = { calm: "Calm", busy: "Busy", strained: "Strained", overloaded: "Overloaded", none: "Not yours to see" };
export const TREND_WORDS: Record<Trend, string> = { growing: "Growing", steady: "Steady", shrinking: "Shrinking", unknown: "No history yet" };
export function clearWords(min: number | null): string {
  if (min === null) return "No estimate yet (needs at least 3 answers in the last hour)";
  return `About ${ageWords(min)} at the pace of the last hour. An estimate, not a promise.`;
}
export function paceWords(r: QueueRow): string { return `${r.arrived60} came in, ${r.answered60} answered in the last hour`; }
/** Sparkline points scaled 0..1 against the largest point (null stays a gap). */
export function sparkScale(v: (number | null)[]): (number | null)[] { const m = Math.max(1, ...v.map((n) => n ?? 0)); return v.map((n) => (n === null ? null : n / m)); }
/** The queues the person may read, busiest signal first for the one-line summary. */
export function summaryWords(rows: QueueRow[]): string {
  const rd = rows.filter((r) => r.readable); if (rd.length === 0) return "No queue is yours to see.";
  const w = totalWaiting(rd); return w === 0 ? "No cases are waiting." : `${w} case${w === 1 ? "" : "s"} waiting, ${totalAtRisk(rd)} at risk.`;
}
