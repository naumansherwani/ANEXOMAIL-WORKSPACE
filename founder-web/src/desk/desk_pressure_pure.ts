// ADMIN DESK 1m (cards B1 Queue pressure + B2 SLA at risk), 23 Nov 2026. Pure parsing of the two read-only doors (/desk/v1/queues/pressure and /risk). Fail-closed: anything that is not exactly the agreed shape is null,
// and the screen then says "Data unavailable". Words never promise: the 15 minutes are a warning window, not a promise. Metadata only, no money.
export const QUEUE_NAMES = ["general", "support", "movein", "billing"] as const;
export type QueueName = (typeof QUEUE_NAMES)[number];
export const QUEUE_WORDS: Record<QueueName, string> = { general: "General", support: "Support", movein: "Move-in", billing: "Billing" };
export type QueueRow = { queue: QueueName; new: number; open: number; waiting: number; atRisk: number; oldestMinutes: number | null };
export type RiskRow = { ref: string; queue: QueueName; minutesLeft: number; overdue: boolean };
const nat = (x: unknown): x is number => typeof x === "number" && Number.isInteger(x) && x >= 0;
export function parsePressure(j: unknown): QueueRow[] | null {
  const o = j as { queues?: unknown; risk_window_minutes?: unknown } | null;
  if (!o || o.risk_window_minutes !== 15 || !Array.isArray(o.queues) || o.queues.length !== 4) return null;
  const out: QueueRow[] = [];
  for (let i = 0; i < 4; i++) {
    const r = o.queues[i] as Record<string, unknown> | null;
    if (!r || r.queue !== QUEUE_NAMES[i] || !nat(r.new) || !nat(r.open) || !nat(r.waiting) || !nat(r.at_risk)) return null;
    if (!(r.oldest_minutes === null || nat(r.oldest_minutes))) return null;
    out.push({ queue: QUEUE_NAMES[i], new: r.new, open: r.open, waiting: r.waiting, atRisk: r.at_risk, oldestMinutes: r.oldest_minutes as number | null });
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
