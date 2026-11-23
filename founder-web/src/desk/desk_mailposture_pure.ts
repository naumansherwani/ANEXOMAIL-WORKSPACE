// ADMIN DESK 1m-7 (card B6b Own-domain mail posture, BL-26), 23 Nov 2026. Pure parsing of the one read-only door /desk/v1/mailposture/board. Fail-closed: anything that is not exactly the agreed shape is null and the screen says "Data unavailable".
// Own domain only: no customer, company or person. Zero is data. A check is ok / missing / bogus, never a score.
export const KEYS = ["mx", "spf", "dkim", "dmarc", "mta_sts", "tls_rpt", "dane", "dnssec"] as const;
export type Key = (typeof KEYS)[number];
export type State = "ok" | "missing" | "bogus";
export type Posture = { domain: string; checks: Record<Key, State>; spark: (number | null)[]; trend: "up" | "steady" | "down" | "unknown"; worsened: Key[] };
const rec = (x: unknown): Record<string, unknown> | null => (x && typeof x === "object" && !Array.isArray(x) ? (x as Record<string, unknown>) : null);
export function parsePosture(j: unknown): Posture | null {
  const o = rec(j), c = rec(o?.checks), s = rec(o?.series);
  if (!o || !c || !s || Object.keys(o).length !== 3 || Object.keys(c).length !== KEYS.length || Object.keys(s).length !== 3) return null;
  if (typeof o.domain !== "string" || !/^[a-z0-9.-]{3,120}$/.test(o.domain)) return null;
  const checks = {} as Record<Key, State>;
  for (const k of KEYS) { const v = c[k]; if (v !== "ok" && v !== "missing" && v !== "bogus") return null; checks[k] = v; }
  if (!Array.isArray(s.spark) || s.spark.length !== 24 || !s.spark.every((x) => x === null || (typeof x === "number" && Number.isInteger(x) && x >= 0 && x <= 8))) return null;
  if (!["up", "steady", "down", "unknown"].includes(s.trend as string)) return null;
  if (!Array.isArray(s.worsened) || !s.worsened.every((k) => (KEYS as readonly string[]).includes(k as string) && checks[k as Key] !== "ok")) return null;
  return { domain: o.domain, checks, spark: s.spark as (number | null)[], trend: s.trend as Posture["trend"], worsened: s.worsened as Key[] };
}
export const WORDS: Record<Key, string> = { mx: "Mail servers (MX)", spf: "SPF sender policy", dkim: "DKIM signing key", dmarc: "DMARC policy", mta_sts: "MTA-STS (secure delivery)", tls_rpt: "TLS reports (TLS-RPT)", dane: "DANE (TLSA on every mail server)", dnssec: "DNSSEC (signed domain)" };
export const STATE_WORDS: Record<State, string> = { ok: "Passing", missing: "Not published", bogus: "Published but wrong" };
export const FIX: Record<Key, string> = {
  mx: "Publish the MX record that points to the Anexomail mail servers.", spf: "Publish one SPF record that ends in -all or ~all.", dkim: "Publish the DKIM public key at the selector name.",
  dmarc: "Publish a DMARC record with p=quarantine or p=reject and an rua address.", mta_sts: "Publish the _mta-sts TXT record with an id, and serve the policy file.", tls_rpt: "Publish the _smtp._tls TXT record with an rua address.",
  dane: "Publish a TLSA record for every mail server, and sign the domain first.", dnssec: "Add the DS record at the registrar so the domain is signed.",
};
export const TREND_WORDS: Record<Posture["trend"], string> = { up: "More checks pass than 24 hours ago", steady: "Same as 24 hours ago", down: "Fewer checks pass than 24 hours ago", unknown: "No 24-hour history yet" };
export const NOT_YOURS = "This is for people who may open a customer.";
export const NOTE = "Anexomail's own sending domain only. Bounce and complaint rates are not shown yet: they need the delivery log of the mail servers, which does not exist yet.";
export function passing(p: Posture): number { return KEYS.filter((k) => p.checks[k] === "ok").length; }
export function headline(p: Posture): string { const n = passing(p); return n === KEYS.length ? `All ${KEYS.length} checks pass for ${p.domain}.` : `${n} of ${KEYS.length} checks pass for ${p.domain}.`; }
/** Failing checks first (worsened since last hour on top), then the passing ones; fixed order breaks ties. */
export function sortedChecks(p: Posture): Key[] { return KEYS.map((k, i) => ({ k, i })).sort((a, b) => rank(p, a.k) - rank(p, b.k) || a.i - b.i).map((r) => r.k); }
function rank(p: Posture, k: Key): number { return p.worsened.includes(k) ? 0 : p.checks[k] === "ok" ? 2 : 1; }
