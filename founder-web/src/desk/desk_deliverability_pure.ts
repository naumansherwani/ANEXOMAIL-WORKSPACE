// ADMIN DESK 1m-5 (card B6 Deliverability), 23 Nov 2026. Pure parsing of the one read-only door /desk/v1/deliverability/board. Fail-closed: anything that is not exactly the agreed shape (or whose numbers do not add up) is null and the screen says "Data unavailable".
// Counts only (never a domain name, company, e-mail or person). No money. Zero is data, always shown as a number.
import type { Signal, Trend } from "./desk_customers_pure";
export type { Signal, Trend };
export const SIGNAL_KEYS = ["spf_missing", "dkim_missing", "dmarc_missing", "mx_missing", "stale_check", "pending_7d"] as const;
export const POSTURE_KEYS = ["spf", "dkim", "dmarc", "mx", "all_ok"] as const;
export type Deliverability = { generated_at: string; domains: number; companies: number; pending: number; verified: number; posture: Record<string, number>; never_checked: number; stale_24h: number; pending_7d: number; companies_failing: number; signals: Signal[] };
export type Board = { d: Deliverability; spark: (number | null)[]; trend: Trend };
const nat = (x: unknown): x is number => typeof x === "number" && Number.isInteger(x) && x >= 0;
const rec = (x: unknown): Record<string, unknown> | null => (x && typeof x === "object" && !Array.isArray(x) ? (x as Record<string, unknown>) : null);
function group(x: unknown, keys: readonly string[]): Record<string, number> | null {
  const o = rec(x); if (!o || Object.keys(o).length !== keys.length) return null;
  const r: Record<string, number> = {}; for (const k of keys) { const v = o[k]; if (!nat(v)) return null; r[k] = v; } return r;
}
export function parseBoard(j: unknown): Board | null {
  const o = rec(j), c = rec(o?.deliverability), s = rec(o?.series);
  if (!o || !c || !s || Object.keys(c).length !== 10) return null;
  if (!nat(c.domains) || !nat(c.companies) || !nat(c.never_checked) || !nat(c.stale_24h) || !nat(c.pending_7d) || !nat(c.companies_failing) || typeof c.generated_at !== "string" || !c.generated_at) return null;
  const st = group(c.status, ["pending", "verified"]), po = group(c.posture, POSTURE_KEYS);
  if (!st || !po) return null;
  const { pending, verified } = st;
  if (pending + verified !== c.domains || c.companies > c.domains || c.never_checked > c.domains || c.stale_24h > verified || c.pending_7d > pending || c.companies_failing > c.companies) return null;
  if (POSTURE_KEYS.some((k) => po[k] > verified) || po.all_ok > Math.min(po.spf, po.dkim, po.dmarc, po.mx)) return null;
  if (!Array.isArray(c.signals) || c.signals.length !== SIGNAL_KEYS.length) return null;
  const want = [verified - po.spf, verified - po.dkim, verified - po.dmarc, verified - po.mx, c.stale_24h, c.pending_7d];
  const signals: Signal[] = [];
  for (let i = 0; i < SIGNAL_KEYS.length; i++) {
    const g = rec(c.signals[i]);
    if (!g || Object.keys(g).length !== 4 || g.key !== SIGNAL_KEYS[i] || typeof g.label !== "string" || !g.label || g.label.length > 80 || !(g.runbook === null || (typeof g.runbook === "string" && g.runbook.length > 0 && g.runbook.length <= 80)) || g.count !== want[i]) return null;
    signals.push({ key: g.key as string, label: g.label, runbook: g.runbook as string | null, count: g.count as number });
  }
  if (!Array.isArray(s.spark) || s.spark.length !== 24 || !s.spark.every((x) => x === null || nat(x)) || !["up", "steady", "down", "unknown"].includes(s.trend as string)) return null;
  return { d: { generated_at: c.generated_at, domains: c.domains, companies: c.companies, pending, verified, posture: po, never_checked: c.never_checked, stale_24h: c.stale_24h, pending_7d: c.pending_7d, companies_failing: c.companies_failing, signals }, spark: s.spark as (number | null)[], trend: s.trend as Trend };
}
export const POSTURE_WORDS: Record<string, string> = { spf: "SPF published", dkim: "DKIM published", dmarc: "DMARC published", mx: "MX points to Anexomail", all_ok: "Fully authenticated" };
export const TREND_WORDS: Record<Trend, string> = { up: "More fully authenticated domains than 24 hours ago", steady: "Same as 24 hours ago", down: "Fewer fully authenticated domains than 24 hours ago", unknown: "No 24-hour history yet" };
export const NOT_YOURS = "This is for people who may open a customer.";
export const NOTE = "Counts only. No domain name or company is shown here. These are the checks Anexomail already runs on each company domain; bounce and complaint rates are measured separately.";
export function headline(d: Deliverability): string {
  if (d.domains === 0) return "No company domain has been added yet.";
  if (d.verified === 0) return `${d.domains} ${d.domains === 1 ? "domain" : "domains"} added, none verified yet.`;
  return `${d.posture.all_ok} of ${d.verified} verified ${d.verified === 1 ? "domain is" : "domains are"} fully authenticated.`;
}
export function attentionWords(d: Deliverability): string {
  if (d.companies_failing === 0) return "No company has a verified domain that fails a check.";
  return `${d.companies_failing} ${d.companies_failing === 1 ? "company has" : "companies have"} a verified domain that fails a check.`;
}
export function share(part: number, whole: number): number { return whole <= 0 ? 0 : Math.round((part / whole) * 100); }
/** Signals with a count first (largest first), then the quiet ones; the fixed order breaks ties. */
export function sortedSignals(s: Signal[]): Signal[] { return s.map((x, i) => ({ x, i })).sort((a, b) => (b.x.count > 0 ? 1 : 0) - (a.x.count > 0 ? 1 : 0) || b.x.count - a.x.count || a.i - b.i).map((r) => r.x); }
