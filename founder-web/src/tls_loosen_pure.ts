// QC1c F8-5: the pure half of the "Send only if TLS" card (no network, no DOM): shapes, checks, words. Tested in tls_loosen_pure.test.ts.
export type Active = { domain: string; loosened_until: string; reason: string };
export type Hist = { at: string; event: string; note: string | null };
export type TlsPolicy = { strict: boolean; active: Active[]; left_today: number; history: Hist[]; chain_ok: boolean; server_now: string };
export type Begun = { ceremony: string; options: Record<string, unknown>; hash: string; expires_in_s: number; domain: string; hours: number; reason: string; left_today: number; action: string; target: string; params: Record<string, string>; nonce: string };

export const HOURS = [1, 4, 12, 24] as const;

const isStr = (x: unknown): x is string => typeof x === "string";
/** Same rule as Rust `valid_domain` and the SQL check: lower-case host name, 2+ labels, alphabetic last label. */
export function validDomain(d: string): boolean {
  if (d.length < 3 || d.length > 253) return false;
  const ls = d.split(".");
  if (ls.length < 2) return false;
  return ls.every((l, i) => /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/.test(l) && (i < ls.length - 1 || /^[a-z]{2,63}$/.test(l)));
}
export const cleanDomain = (s: string) => s.trim().toLowerCase();
export function problem(domain: string, reason: string): string {
  if (!validDomain(cleanDomain(domain))) return "Write the partner's domain, for example partner.com.";
  const r = reason.trim();
  if (r.length < 8) return "Write a reason of at least 8 characters.";
  if (r.length > 200 || /[<>\u0000-\u001f\u007f]/.test(r)) return "The reason can have at most 200 characters and no < >.";
  return "";
}
/** The server's answer is data: anything that does not have exactly this shape is "not available", never half shown. */
export function parsePolicy(d: unknown): TlsPolicy | null {
  const p = (d as { policy?: Record<string, unknown> } | null)?.policy;
  if (!p || typeof p.strict !== "boolean" || !Array.isArray(p.active) || typeof p.left_today !== "number" || !Array.isArray(p.history)) return null;
  const active = p.active.filter((a): a is Active => !!a && isStr((a as Active).domain) && isStr((a as Active).loosened_until) && isStr((a as Active).reason));
  if (active.length !== p.active.length) return null;
  const history = p.history.filter((h): h is Hist => !!h && isStr((h as Hist).at) && isStr((h as Hist).event));
  return { strict: p.strict, active, left_today: Math.max(0, Math.min(3, p.left_today)), history, chain_ok: p.chain_ok === true, server_now: isStr(p.server_now) ? p.server_now : "" };
}
export function parseBegun(b: unknown): Begun | null {
  const x = b as Partial<Begun> | null;
  if (!x || !isStr(x.ceremony) || !isStr(x.hash) || !isStr(x.nonce) || !isStr(x.action) || !isStr(x.target) || !x.options || typeof x.options !== "object" || !x.params || typeof x.params !== "object") return null;
  if (!isStr(x.domain) || typeof x.hours !== "number" || !isStr(x.reason)) return null;
  return x as Begun;
}
/** "3h 12m left" from the SERVER's clock difference (never the browser's own idea of the time). */
export function leftWords(untilIso: string, nowIso: string, skewMs = 0): string {
  const ms = Date.parse(untilIso) - (Date.parse(nowIso) + skewMs);
  if (!Number.isFinite(ms) || ms <= 0) return "ending now";
  const m = Math.ceil(ms / 60000), h = Math.floor(m / 60);
  return h > 0 ? `${h}h ${m % 60}m left` : `${m}m left`;
}
export function histWords(h: Hist): string {
  if (h.event === "policy_loosen") return `Allowed plain delivery to one domain (${h.note ?? ""})`.replace(" ()", "");
  if (h.event === "policy_tighten") return h.note === "healed" ? "Strict again by itself: the domain delivered over TLS" : "Made strict again";
  if (h.event === "policy_expired") return "Time ended, strict again";
  return h.event;
}
export function refusal(status: number, body: { error?: string; note?: string } | null | undefined): string {
  if (body?.note) return body.note;
  if (status === 429) return "Too many tries. Wait a little and try again.";
  if (status === 401) return "Your session ended. Sign in again.";
  if (status === 409) return "Register a passkey first (Settings → Privacy).";
  if (status === 403) return body?.error && /another|passkey|ceremony|device/i.test(body.error) ? body.error : "The server refused this change.";
  return body?.error && body.error.length < 140 ? body.error : "The change was not made.";
}
