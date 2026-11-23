// ADMIN DESK 1m-2 (card B3 Security health of the Desk itself), 23 Nov 2026. Pure parsing of the one read-only door /desk/v1/security/health. Fail-closed: anything that is not exactly the agreed shape is null and the screen says "Data unavailable".
// AGGREGATE ONLY (a score, eight named checks with have / of, a 24-hour series, a trend): no name, e-mail or key material ever reaches this file. No money, no promises.
export const CHECK_KEYS = ["every_staff_has_key", "two_keys_each", "keys_device_bound", "keys_allowed_model", "no_open_recovery", "no_stale_grants", "no_breakglass_active", "no_open_high_alert"] as const;
export const CHECK_WEIGHTS = [20, 20, 15, 10, 10, 10, 10, 5] as const;
export type CheckStatus = "ok" | "fail" | "na";
export type SecCheck = { key: (typeof CHECK_KEYS)[number]; label: string; weight: number; status: CheckStatus; have: number; of: number };
export type SecTrend = "up" | "steady" | "down" | "unknown";
export type SecHealth = { score: number | null; ok: number; fail: number; na: number; staff: number; checks: SecCheck[]; spark: (number | null)[]; trend: SecTrend };
const nat = (x: unknown): x is number => typeof x === "number" && Number.isInteger(x) && x >= 0;
const pct = (x: unknown): x is number => nat(x) && x <= 100;
export function parseHealth(j: unknown): SecHealth | null {
  const o = j as Record<string, unknown> | null;
  if (!o || !Array.isArray(o.checks) || o.checks.length !== 8) return null;
  const checks: SecCheck[] = [];
  for (let i = 0; i < 8; i++) {
    const c = o.checks[i] as Record<string, unknown> | null;
    if (!c || c.key !== CHECK_KEYS[i] || c.weight !== CHECK_WEIGHTS[i] || typeof c.label !== "string" || c.label.length === 0 || c.label.length > 120) return null;
    if (!["ok", "fail", "na"].includes(c.status as string) || !nat(c.have) || !nat(c.of) || c.have > c.of) return null;
    if (c.status === "na" && c.of !== 0) return null;
    if (c.status === "ok" && !(c.of > 0 && c.have === c.of)) return null;
    checks.push({ key: CHECK_KEYS[i], label: c.label, weight: c.weight as number, status: c.status as CheckStatus, have: c.have, of: c.of });
  }
  if (!(o.score === null || pct(o.score)) || !nat(o.ok) || !nat(o.fail) || !nat(o.na) || o.ok + o.fail + o.na !== 8 || !nat(o.staff)) return null;
  if ((o.score === null) !== (o.ok + o.fail === 0)) return null;
  if (!Array.isArray(o.spark) || o.spark.length !== 24 || !o.spark.every((n) => n === null || pct(n))) return null;
  if (!["up", "steady", "down", "unknown"].includes(o.trend as string)) return null;
  return { score: o.score as number | null, ok: o.ok, fail: o.fail, na: o.na, staff: o.staff, checks, spark: o.spark as (number | null)[], trend: o.trend as SecTrend };
}
export const TREND_WORDS: Record<SecTrend, string> = { up: "Better than 24 hours ago", steady: "Steady over 24 hours", down: "Worse than 24 hours ago", unknown: "No 24-hour history yet" };
export const SCORE_NOTE = "The score is the weight of the checks that pass out of the checks that apply. A check with nobody to check is left out. It counts what the Desk can measure; it is not a certificate.";
export const NOT_YOURS = "This is for people who manage staff.";
export function scoreWords(s: SecHealth): string {
  if (s.score === null) return "Nothing to score yet.";
  return s.fail === 0 ? `${s.score} out of 100. Every check that applies passes.` : `${s.score} out of 100. ${s.fail} check${s.fail === 1 ? "" : "s"} to fix.`;
}
export function checkWords(c: SecCheck): string {
  if (c.status === "na") return "Nobody to check yet";
  return c.of === 1 && c.key.startsWith("no_") ? (c.status === "ok" ? "Clear" : "Needs attention") : `${c.have} of ${c.of}`;
}
/** Failing checks first (heaviest first), then the passing ones, then the ones that do not apply; the original order breaks ties. */
export function sortedChecks(cs: SecCheck[]): SecCheck[] {
  const rank = (c: SecCheck) => (c.status === "fail" ? 0 : c.status === "ok" ? 1 : 2);
  return cs.map((c, i) => ({ c, i })).sort((a, b) => rank(a.c) - rank(b.c) || (a.c.status === "fail" ? b.c.weight - a.c.weight : 0) || a.i - b.i).map((x) => x.c);
}
