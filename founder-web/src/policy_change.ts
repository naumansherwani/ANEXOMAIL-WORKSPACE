import type { Policy } from "./sessions_pure";

// D2b-5 (11 Nov 2026): the policy editor's pure logic + the passkey flow. Plan: docs/claude/G-MIX-D2B5-PLAN-11NOV.md.
// The browser only PROPOSES fields. The server validates them, keeps the payload, and returns a plain-words summary + the digest; the WASM kernel
// re-derives that digest here BEFORE the key is touched; only the assertion goes back (the payload cannot change after the touch).
export type Draft = { geoMode: "off" | "observe" | "enforce"; countries: string; spoofAction: "alert" | "block"; staleAfterS: number; maxLive: number; failLimit: number; flapLimit: number; flapAction: "alert" | "revoke"; idleS: number; absoluteS: number };
export type Change = { field: string; label: string; from: unknown; to: unknown };

export const LIMITS = { staleAfterS: [30, 86400], maxLive: [2, 200], failLimit: [3, 100], flapLimit: [2, 50], idleS: [300, 2592000], absoluteS: [3600, 7776000] } as const;

export function draftOf(p: Policy): Draft {
  return { geoMode: p.geoMode === "unknown" ? "off" : p.geoMode, countries: p.countries.join(", "), spoofAction: p.spoofAction === "block" ? "block" : "alert", staleAfterS: p.staleAfterS, maxLive: p.maxLive,
    failLimit: p.failLimit, flapLimit: p.flapLimit, flapAction: p.flapAction === "revoke" ? "revoke" : "alert", idleS: p.idleS, absoluteS: p.absoluteS };
}
/** "pk, US  us" -> ["PK","US"]; anything that is not two letters is kept out so validation can name it. */
export function parseCountries(s: string): { ok: string[]; bad: string[] } {
  const parts = s.split(/[\s,;]+/).map((x) => x.trim().toUpperCase()).filter(Boolean);
  const ok: string[] = [], bad: string[] = [];
  for (const c of parts) { if (/^[A-Z]{2}$/.test(c)) { if (!ok.includes(c)) ok.push(c); } else bad.push(c); }
  return { ok: ok.sort(), bad };
}
const inR = (n: number, [lo, hi]: readonly [number, number]) => Number.isInteger(n) && n >= lo && n <= hi;
/** The first thing wrong with the draft, in plain words, or "" when it can be sent. The server and SQL check everything again. */
export function validate(d: Draft, reason: string, current: Policy | null): string {
  const c = parseCountries(d.countries);
  if (c.bad.length) return `“${c.bad[0]}” is not a country code (two letters, like PK).`;
  if (c.ok.length > 40) return "At most 40 countries.";
  if (d.geoMode === "enforce" && c.ok.length === 0) return "Enforcing the location lock needs at least one allowed country.";
  for (const [k, label] of [["staleAfterS", "Quiet time"], ["maxLive", "Live sessions"], ["failLimit", "Failed signatures"], ["flapLimit", "Network changes"], ["idleS", "Idle limit"], ["absoluteS", "Absolute limit"]] as const) {
    if (!inR(d[k], LIMITS[k])) return `${label} must be between ${LIMITS[k][0]} and ${LIMITS[k][1]}.`;
  }
  if (d.absoluteS < d.idleS) return "The absolute limit cannot be shorter than the idle limit.";
  const r = reason.trim();
  if (r.length < 8 || r.length > 200 || /[<>\u0000-\u001f\u007f]/.test(r)) return "Say why in 8 to 200 characters (no < or >).";
  if (current && !changed(d, current)) return "Nothing is different from the current settings.";
  return "";
}
export function changed(d: Draft, p: Policy): boolean {
  const x = draftOf(p);
  return (Object.keys(x) as (keyof Draft)[]).some((k) => (k === "countries" ? parseCountries(d.countries).ok.join() !== parseCountries(x.countries).ok.join() : d[k] !== x[k]));
}
export function bodyOf(d: Draft, reason: string) {
  return { geo_mode: d.geoMode, countries: parseCountries(d.countries).ok, spoof_action: d.spoofAction, stale_after_s: d.staleAfterS, max_live: d.maxLive, fail_limit: d.failLimit, flap_limit: d.flapLimit,
    flap_action: d.flapAction, idle_s: d.idleS, absolute_s: d.absoluteS, reason: reason.trim() };
}
/** What the server says when it refuses (plain words; unknown codes never show raw SQL). */
export function refusalText(status: number, body: { error?: string; note?: string } | null | undefined): string {
  if (body?.note) return body.note;
  if (status === 429) return "Too many tries. Wait a little and try again.";
  if (status === 401) return "Your session ended. Sign in again.";
  if (status === 403) return body?.error && /another|network|passkey|ceremony/i.test(body.error) ? body.error : "The server refused this change.";
  if (status === 409) return "Register a passkey first (Settings → Privacy).";
  return body?.error && body.error.length < 140 ? body.error : "The change was not made.";
}

export type Begun = { ceremony: string; options: Record<string, unknown>; hash: string; expires_in_s: number; changes: Change[]; reason: string; action: string; target: string; params: Record<string, string>; nonce: string };
export function parseBegun(b: unknown): Begun | null {
  const o = (b && typeof b === "object" ? b : {}) as Record<string, unknown>;
  if (typeof o.ceremony !== "string" || typeof o.hash !== "string" || !o.options || typeof o.options !== "object" || typeof o.nonce !== "string" || !o.params || typeof o.params !== "object") return null;
  const changes = Array.isArray(o.changes) ? (o.changes as Change[]).filter((c) => c && typeof c.field === "string" && typeof c.label === "string") : [];
  return { ceremony: o.ceremony, options: o.options as Record<string, unknown>, hash: o.hash, expires_in_s: typeof o.expires_in_s === "number" ? o.expires_in_s : 120, changes, reason: String(o.reason ?? ""),
    action: String(o.action ?? "session.policy"), target: String(o.target ?? "policy"), params: o.params as Record<string, string>, nonce: o.nonce };
}
/** One change line in words: "Location lock: off -> enforce". */
export function changeText(c: Change): string {
  const f = (v: unknown) => (Array.isArray(v) ? (v.length ? v.join(", ") : "none") : v === undefined || v === null ? "?" : String(v));
  return `${c.label}: ${f(c.from)} → ${f(c.to)}`;
}
