// ADMIN DESK 1m-4 (card B9 Customers and Plans), 23 Nov 2026. Pure parsing of the one read-only door /desk/v1/customers/census. Fail-closed: anything that is not exactly the agreed shape is null and the screen says "Data unavailable".
// Counts only (never a company name, e-mail, domain or person). No money. Zero is data, always shown as a number.
export const PKGS = ["basic", "pro", "business", "business_pro", "business_premium", "business_max"] as const;
export const PKG_ALL = [...PKGS, "none", "unknown"] as const;
export const STATES = ["active", "trialing", "grace_period", "not_active_yet", "ended"] as const;
export const SIGNAL_KEYS = ["grace_period", "not_active_yet", "ended", "payment_received_not_active", "seats_90", "seats_95", "storage_90", "storage_95"] as const;
export type Signal = { key: string; label: string; runbook: string | null; count: number };
export type PlanDetail = { companies: number; seats_in_use: number; states: Record<string, number>; intervals: Record<string, number>; size_bands: Record<string, number>; storage_90: number };
export type Census = { generated_at: string; companies: number; seats_in_use: number; packages: Record<string, number>; states: Record<string, number>; intervals: Record<string, number>; size_bands: Record<string, number>; growth_12m: number[]; ended_30d: number; renewals_7d: number; over_limit: Record<string, number>; by_package: Record<string, PlanDetail>; signals: Signal[] };
export type Trend = "up" | "steady" | "down" | "unknown";
export type Customers = { census: Census; spark: (number | null)[]; trend: Trend };
const nat = (x: unknown): x is number => typeof x === "number" && Number.isInteger(x) && x >= 0;
const rec = (x: unknown): Record<string, unknown> | null => (x && typeof x === "object" && !Array.isArray(x) ? (x as Record<string, unknown>) : null);
function group(x: unknown, keys: readonly string[]): Record<string, number> | null {
  const o = rec(x); if (!o || Object.keys(o).length !== keys.length) return null;
  const r: Record<string, number> = {}; for (const k of keys) { const v = o[k]; if (!nat(v)) return null; r[k] = v; } return r;
}
const total = (g: Record<string, number>) => Object.values(g).reduce((a, b) => a + b, 0);
export function parseCustomers(j: unknown): Customers | null {
  const o = rec(j), c = rec(o?.census), s = rec(o?.series);
  if (!o || !c || !s || Object.keys(c).length !== 13) return null;
  if (!nat(c.companies) || !nat(c.seats_in_use) || !nat(c.ended_30d) || !nat(c.renewals_7d) || typeof c.generated_at !== "string" || !c.generated_at) return null;
  const n = c.companies;
  const packages = group(c.packages, PKG_ALL), states = group(c.states, STATES), intervals = group(c.intervals, ["month", "year", "none"]), bands = group(c.size_bands, ["1", "2-5", "6-20", "21-100", "101+"]);
  if (!packages || !states || !intervals || !bands) return null;
  if (total(packages) !== n || total(states) !== n || total(intervals) > n || total(bands) > n) return null;
  const bpr = rec(c.by_package); if (!bpr || Object.keys(bpr).length !== PKG_ALL.length) return null;
  const by: Record<string, PlanDetail> = {}; let seatSum = 0;
  for (const k of PKG_ALL) {
    const g = rec(bpr[k]); if (!g || Object.keys(g).length !== 6 || !nat(g.companies) || !nat(g.seats_in_use) || !nat(g.storage_90) || g.companies !== packages[k] || g.storage_90 > g.companies) return null;
    const st = group(g.states, STATES), iv = group(g.intervals, ["month", "year", "none"]), bd = group(g.size_bands, ["1", "2-5", "6-20", "21-100", "101+"]);
    if (!st || !iv || !bd || total(st) !== g.companies || total(iv) > g.companies || total(bd) > g.companies) return null;
    seatSum += g.seats_in_use; by[k] = { companies: g.companies, seats_in_use: g.seats_in_use, states: st, intervals: iv, size_bands: bd, storage_90: g.storage_90 };
  }
  if (seatSum !== c.seats_in_use) return null;
  if (!Array.isArray(c.growth_12m) || c.growth_12m.length !== 12 || !c.growth_12m.every(nat)) return null;
  const ol = rec(c.over_limit); if (!ol) return null; const over: Record<string, number> = {};
  for (const [k, v] of Object.entries(ol)) { if (!(PKGS as readonly string[]).includes(k) || !nat(v) || v > n) return null; over[k] = v; }
  if (!Array.isArray(c.signals) || c.signals.length !== SIGNAL_KEYS.length) return null;
  const signals: Signal[] = [];
  for (let i = 0; i < SIGNAL_KEYS.length; i++) {
    const g = rec(c.signals[i]);
    if (!g || Object.keys(g).length !== 4 || g.key !== SIGNAL_KEYS[i] || typeof g.label !== "string" || !g.label || g.label.length > 80 || !(g.runbook === null || (typeof g.runbook === "string" && g.runbook.length > 0 && g.runbook.length <= 80)) || !nat(g.count) || g.count > n) return null;
    signals.push({ key: g.key as string, label: g.label, runbook: g.runbook as string | null, count: g.count });
  }
  if (!Array.isArray(s.spark) || s.spark.length !== 24 || !s.spark.every((x) => x === null || nat(x)) || !["up", "steady", "down", "unknown"].includes(s.trend as string)) return null;
  return { census: { generated_at: c.generated_at, companies: n, seats_in_use: c.seats_in_use, packages, states, intervals, size_bands: bands, growth_12m: c.growth_12m as number[], ended_30d: c.ended_30d, renewals_7d: c.renewals_7d, over_limit: over, by_package: by, signals }, spark: s.spark as (number | null)[], trend: s.trend as Trend };
}
export const PKG_WORDS: Record<string, string> = { basic: "Basic", pro: "Pro", business: "Business", business_pro: "Business Pro", business_premium: "Business Premium", business_max: "Business Max", none: "No plan yet", unknown: "Plan not recognised" };
export const STATE_WORDS: Record<string, string> = { active: "Active", trialing: "Trial", grace_period: "Grace period", not_active_yet: "Not active yet", ended: "Ended" };
export const TREND_WORDS: Record<Trend, string> = { up: "More companies than 24 hours ago", steady: "Same as 24 hours ago", down: "Fewer companies than 24 hours ago", unknown: "No 24-hour history yet" };
export const NOT_YOURS = "This is for people who may open a customer.";
export const NOTE = "Counts only. No company name, address or person is shown here. Open one company from Plans and prices.";
export const SMALL = "Small group";
export function headline(c: Census): string {
  if (c.companies === 0) return "No company has an account yet.";
  return `${c.companies} ${c.companies === 1 ? "company" : "companies"}, ${c.seats_in_use} ${c.seats_in_use === 1 ? "seat" : "seats"} in use. ${c.states.active} active.`;
}
/** A group under five companies is called "Small group" so one company cannot be picked out of a split. */
export function isSmall(n: number): boolean { return n > 0 && n < 5; }
export function share(part: number, whole: number): number { return whole <= 0 ? 0 : Math.round((part / whole) * 100); }
export function growthWords(g: number[]): string {
  const last = g[g.length - 1], first = g[0], d = last - first;
  if (last === 0 && first === 0) return "No companies were added in the last 12 months.";
  return d === 0 ? `${last} companies, the same as 12 months ago.` : d > 0 ? `${last} companies, ${d} more than 12 months ago.` : `${last} companies, ${-d} fewer than 12 months ago.`;
}
/** Signals with a count first (largest first), then the quiet ones; order of the fixed list breaks ties. */
export function sortedSignals(s: Signal[]): Signal[] { return s.map((x, i) => ({ x, i })).sort((a, b) => (b.x.count > 0 ? 1 : 0) - (a.x.count > 0 ? 1 : 0) || b.x.count - a.x.count || a.i - b.i).map((r) => r.x); }
export function overLimitWords(o: Record<string, number>): string[] {
  return PKGS.filter((k) => (o[k] ?? 0) > 0).map((k) => `${o[k]} on ${PKG_WORDS[k]} ${o[k] === 1 ? "is" : "are"} above the seat promise`);
}
