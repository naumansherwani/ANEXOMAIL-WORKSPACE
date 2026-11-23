// ADMIN DESK 1m-6 (card B10 Reports, BL-04), 23 Nov 2026. Pure parsing of the one read-only door /desk/v1/reports/summary. Fail-closed: anything that is not exactly the agreed shape, or whose numbers do not add up, is null ("Data unavailable").
// Counts and minutes only (never a case reference, subject, company or person). Zero is data, always a number; a median with nothing measured is words, never a guess.
export const QUEUES = ["general", "support", "movein", "billing"] as const;
export type Pair = { median: number | null; p90: number | null };
export type Report = {
  generated_at: string; counted: number; hidden: number; backlog: { new: number; open: number; waiting: number };
  daily: { created: number[]; solved: number[]; backlog: number[] };
  first_reply: Pair & { cases: number; replied: number; unanswered: number }; resolution: Pair & { solved: number };
  reopened_30d: number; priority: { total: number; in_time: number; late: number; waiting: number }; queues: { queue: string; created: number; solved: number; backlog: number }[];
};
const nat = (x: unknown): x is number => typeof x === "number" && Number.isInteger(x) && x >= 0;
const rec = (x: unknown): Record<string, unknown> | null => (x && typeof x === "object" && !Array.isArray(x) ? (x as Record<string, unknown>) : null);
function group(x: unknown, keys: readonly string[]): Record<string, number> | null {
  const o = rec(x); if (!o || Object.keys(o).length !== keys.length) return null;
  const r: Record<string, number> = {}; for (const k of keys) { const v = o[k]; if (!nat(v)) return null; r[k] = v; } return r;
}
function line(x: unknown): number[] | null { return Array.isArray(x) && x.length === 14 && x.every(nat) ? (x as number[]) : null; }
function pair(o: Record<string, unknown>, n: number): Pair | null {
  const m = o.median_min, p = o.p90_min;
  if (n === 0) return m === null && p === null ? { median: null, p90: null } : null;
  return nat(m) && nat(p) && p >= m ? { median: m, p90: p } : null;
}
export function parseReport(j: unknown): Report | null {
  const o = rec(j); if (!o || Object.keys(o).length !== 10) return null;
  if (typeof o.generated_at !== "string" || !o.generated_at || !nat(o.queues_counted) || !nat(o.queues_hidden) || !nat(o.reopened_30d)) return null;
  if (o.queues_counted < 1 || o.queues_counted + o.queues_hidden !== 4) return null;
  const bk = group(o.backlog, ["new", "open", "waiting"]); if (!bk) return null; const total = bk.new + bk.open + bk.waiting;
  const d = rec(o.daily); if (!d || Object.keys(d).length !== 3) return null;
  const cr = line(d.created), so = line(d.solved), db = line(d.backlog); if (!cr || !so || !db || db[13] !== total) return null;
  const f = rec(o.first_reply); if (!f || Object.keys(f).length !== 5) return null;
  const fg = group({ cases: f.cases, replied: f.replied, unanswered: f.unanswered }, ["cases", "replied", "unanswered"]); if (!fg || fg.replied + fg.unanswered !== fg.cases) return null;
  const fp = pair(f, fg.replied); if (!fp) return null;
  const r = rec(o.resolution); if (!r || Object.keys(r).length !== 3 || !nat(r.solved)) return null;
  const rp = pair(r, r.solved); if (!rp) return null;
  const pr = group(o.priority, ["total", "in_time", "late", "waiting"]); if (!pr || pr.total !== pr.in_time + pr.late + pr.waiting) return null;
  if (!Array.isArray(o.queues) || o.queues.length !== o.queues_counted) return null;
  const queues: Report["queues"] = []; let last = -1, sum = 0;
  for (const q of o.queues) {
    const g = rec(q); if (!g || Object.keys(g).length !== 4 || typeof g.queue !== "string") return null;
    const pos = (QUEUES as readonly string[]).indexOf(g.queue); if (pos <= last || !nat(g.created) || !nat(g.solved) || !nat(g.backlog)) return null;
    last = pos; sum += g.backlog; queues.push({ queue: g.queue, created: g.created, solved: g.solved, backlog: g.backlog });
  }
  if (sum !== total) return null;
  return { generated_at: o.generated_at, counted: o.queues_counted, hidden: o.queues_hidden, backlog: { new: bk.new, open: bk.open, waiting: bk.waiting }, daily: { created: cr, solved: so, backlog: db }, first_reply: { ...fg, ...fp } as Report["first_reply"], resolution: { solved: r.solved, ...rp }, reopened_30d: o.reopened_30d, priority: pr as Report["priority"], queues };
}
export const NOT_YOURS = "This is for people who may read a support queue.";
export const NOTE = "Counts and minutes only. No case, person or company is shown here. Only the queues you may read are counted.";
export const QUEUE_WORDS: Record<string, string> = { general: "General", support: "Support", movein: "Move-in", billing: "Billing" };
/** Minutes as words: 45 min, 3 h 20 min, 2 d 4 h. Nothing measured = words, never a made-up number. */
export function minutes(m: number | null): string {
  if (m === null) return "No cases yet";
  if (m < 60) return `${m} min`; if (m < 1440) { const h = Math.floor(m / 60), r = m % 60; return r ? `${h} h ${r} min` : `${h} h`; }
  const d = Math.floor(m / 1440), h = Math.floor((m % 1440) / 60); return h ? `${d} d ${h} h` : `${d} d`;
}
export function hiddenWords(r: Report): string { return r.hidden === 0 ? "All four queues are counted." : `${r.counted} of 4 queues counted; ${r.hidden} you may not read ${r.hidden === 1 ? "is" : "are"} left out.`; }
export function slaWords(p: Report["priority"]): string { return p.total === 0 ? "No case with a deadline yet." : `${p.in_time} in time, ${p.late} late, ${p.waiting} still waiting out of ${p.total}.`; }
export function sum(v: number[]): number { return v.reduce((a, b) => a + b, 0); }
