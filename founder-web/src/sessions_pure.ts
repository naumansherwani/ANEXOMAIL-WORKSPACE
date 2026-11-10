// D3 (11 Nov 2026): Devices & Sessions, the PURE half of the screen. Plan: docs/claude/G-MIX-D3-PLAN-11NOV.md.
// No React, no fetch, no founder wording inside the logic: everything here is a function of the signed answers of
// GET /founder/v1/sessions/board and /ledger (SQL E155 + E156), so the awam copy later only swaps the labels (AP9).
// Rule: nothing is invented. A field that is missing or of the wrong type becomes "unknown", never a guess.

export type Level = "ok" | "suspect" | "spoof";
export type KeySource = "dbsc" | "webcrypto" | "none" | "unknown";
export type Integrity = "verified" | "stale" | "failed" | "never" | "unknown";

export type Sess = {
  sid: string; sidHash: string; current: boolean; live: boolean; method: string; device: string;
  keySource: KeySource; keyFp: string; claimed: string; proven: string;
  spoof: { level: Level; score: number; reasons: string[] };
  protocol: string; pathBadge: string; kernel: string;
  integrity: { state: Integrity; lastVerifiedAt: number | null; ok: number; fail: number };
  country: string | null; geoState: string; netFlips: number; failStreak: number;
  createdAt: number | null; lastSeenAt: number | null; revokedAt: number | null; revokeReason: string | null;
};
export type Policy = { geoMode: "off" | "observe" | "enforce" | "unknown"; countries: string[]; spoofAction: string; staleAfterS: number; maxLive: number; failLimit: number; flapLimit: number; flapAction: string; idleS: number; absoluteS: number };
export type Board = { ok: boolean; sessions: Sess[]; live: number; liveWithAlert: number; policy: Policy | null; chainOk: boolean | null; chainBrokenAt: number | null; anchorOk: boolean | null; anchorWhy: string; limits: string[] };
export type Row = { id: number; atMs: number | null; kind: string; sid: string; net: string; kernel: string; protocol: string; country: string | null; facts: Record<string, unknown> };

const rec = (v: unknown): Record<string, unknown> => (v && typeof v === "object" && !Array.isArray(v) ? (v as Record<string, unknown>) : {});
const str = (v: unknown, d = ""): string => (typeof v === "string" ? v : d);
const num = (v: unknown, d = 0): number => (typeof v === "number" && Number.isFinite(v) ? v : d);
const bool = (v: unknown): boolean | null => (typeof v === "boolean" ? v : null);
const strs = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === "string").slice(0, 60) : []);
/** ISO string or epoch ms to epoch ms; anything else = null ("unknown"), never "now". */
export function ms(v: unknown): number | null {
  if (typeof v === "number" && Number.isFinite(v) && v > 0) return v;
  if (typeof v === "string") { const t = Date.parse(v); return Number.isFinite(t) ? t : null; }
  return null;
}
const oneOf = <T extends string>(v: unknown, set: readonly T[], d: T): T => (typeof v === "string" && (set as readonly string[]).includes(v) ? (v as T) : d);

export function parseSession(x: unknown): Sess | null {
  const r = rec(x), sp = rec(r.spoof), ig = rec(r.integrity);
  const sidHash = str(r.sid_hash);
  if (!/^[0-9a-f]{64}$/i.test(sidHash)) return null; // a row without a real id can never be closed by the screen, so it is not shown as a session
  const cc = str(r.country);
  return {
    sid: str(r.sid, sidHash.slice(0, 12)).slice(0, 12), sidHash: sidHash.toLowerCase(), current: r.current === true, live: r.live === true, method: str(r.method, "unknown"), device: str(r.device).slice(0, 12),
    keySource: oneOf(r.key_source, ["dbsc", "webcrypto", "none"] as const, "unknown"), keyFp: str(r.key_fp).slice(0, 16),
    claimed: str(r.claimed_browser, "unknown"), proven: str(r.proven_browser, "unknown"),
    spoof: { level: oneOf(sp.level, ["ok", "suspect", "spoof"] as const, "ok"), score: Math.max(0, Math.min(100, num(sp.score))), reasons: strs(sp.reasons).slice(0, 8) },
    protocol: str(r.protocol, "unknown"), pathBadge: str(r.path_badge, "protocol not measured"), kernel: str(r.kernel, "unknown"),
    integrity: { state: oneOf(ig.state, ["verified", "stale", "failed", "never"] as const, "unknown"), lastVerifiedAt: ms(ig.last_verified_at), ok: num(ig.ok), fail: num(ig.fail) },
    country: /^[A-Z]{2}$/.test(cc) ? cc : null, geoState: str(r.geo_state, "unknown"), netFlips: num(r.net_flips), failStreak: num(r.fail_streak),
    createdAt: ms(r.created_at), lastSeenAt: ms(r.last_seen_at), revokedAt: ms(r.revoked_at), revokeReason: typeof r.revoke_reason === "string" ? r.revoke_reason : null,
  };
}

export function parsePolicy(x: unknown): Policy | null {
  const p = rec(x);
  if (!Object.keys(p).length) return null;
  return { geoMode: oneOf(p.geo_mode, ["off", "observe", "enforce"] as const, "unknown"), countries: strs(p.countries).filter((c) => /^[A-Z]{2}$/.test(c)), spoofAction: str(p.spoof_action, "alert"),
    staleAfterS: num(p.stale_after_s, 900), maxLive: num(p.max_live, 20), failLimit: num(p.fail_limit, 10), flapLimit: num(p.flap_limit, 4), flapAction: str(p.flap_action, "alert"), idleS: num(p.idle_s, 86400), absoluteS: num(p.absolute_s, 604800) };
}

/** The board answer (the `data` of the signed envelope). `available:false` / garbage = null (the screen says "not answering", never fakes an empty list). */
export function parseBoard(d: unknown): Board | null {
  const b = rec(rec(d).data ?? d);
  if (b.ok !== true) return null;
  const ch = rec(b.ledger_chain), an = rec(b.anchor);
  return {
    ok: true, sessions: (Array.isArray(b.sessions) ? b.sessions : []).map(parseSession).filter((s): s is Sess => !!s).slice(0, 60),
    live: num(b.live), liveWithAlert: num(b.live_with_alert), policy: parsePolicy(b.policy),
    chainOk: bool(ch.ok), chainBrokenAt: typeof ch.broken_at === "number" ? ch.broken_at : null, anchorOk: bool(an.ok), anchorWhy: str(an.why), limits: strs(b.limits),
  };
}

export function parseLedger(d: unknown): Row[] {
  const b = rec(rec(d).data ?? d);
  return (Array.isArray(b.rows) ? b.rows : []).map((x): Row | null => {
    const r = rec(x); const id = num(r.id, -1);
    if (id < 0) return null;
    const cc = str(r.country);
    return { id, atMs: ms(r.at_ms), kind: str(r.kind, "unknown"), sid: str(r.sid).slice(0, 12), net: str(r.net).slice(0, 12), kernel: str(r.kernel, "unknown"), protocol: str(r.protocol, "unknown"), country: /^[A-Z]{2}$/.test(cc) ? cc : null, facts: rec(r.facts) };
  }).filter((r): r is Row => !!r).slice(0, 200);
}

// ------------------------------------------------------------------------------------------------------------------------------
// words: every code the SQL can send has a plain sentence; an unknown one is shown as itself, never dropped, never as HTML
// ------------------------------------------------------------------------------------------------------------------------------
export const KIND: Record<string, { icon: string; tone: "info" | "warn" | "bad"; text: string }> = {
  registered: { icon: "✚", tone: "info", text: "A session was opened" },
  seen: { icon: "•", tone: "info", text: "Session checked in" },
  protocol_changed: { icon: "⇄", tone: "info", text: "The connection protocol changed" },
  kernel_changed: { icon: "⚙", tone: "info", text: "The app build changed inside the session" },
  net_changed: { icon: "⌁", tone: "warn", text: "The network address changed" },
  net_flapping: { icon: "⚠", tone: "bad", text: "The network keeps flipping: two machines may share this session" },
  spoof_alert: { icon: "⚠", tone: "warn", text: "The browser's claim does not match what it proves" },
  spoof_blocked: { icon: "⛔", tone: "bad", text: "A session was closed because the browser identity did not add up" },
  identity_drift: { icon: "⚠", tone: "bad", text: "The browser or device key changed in the middle of a session" },
  geo_observed: { icon: "◎", tone: "info", text: "Location noted (observe mode)" },
  geo_refused: { icon: "⛔", tone: "bad", text: "A new device was refused: outside the allowed countries" },
  geo_moved: { icon: "⛔", tone: "bad", text: "A session was closed: used from outside the allowed countries" },
  integrity_fail: { icon: "⚠", tone: "bad", text: "Request signatures failed" },
  revoked: { icon: "✕", tone: "warn", text: "A session was closed" },
  nuke_others: { icon: "✕", tone: "warn", text: "All other sessions were closed" },
  policy_changed: { icon: "⚙", tone: "warn", text: "The session policy was changed" },
  expired: { icon: "⏱", tone: "info", text: "A session expired" },
  session_cap: { icon: "⛶", tone: "warn", text: "The oldest idle session was closed: too many live sessions" },
  anchored: { icon: "⚓", tone: "info", text: "The ledger head was anchored into the audit chain" },
};
export const kindInfo = (k: string) => KIND[k] ?? { icon: "?", tone: "warn" as const, text: `Unknown event (${k.slice(0, 40)})` };
/** The kinds that matter for the alert strip. */
export const ALERT_KINDS = ["spoof_alert", "spoof_blocked", "identity_drift", "geo_moved", "geo_refused", "net_flapping", "session_cap", "integrity_fail"] as const;

const REASON: Record<string, string> = {
  claims_one_browser_proves_another: "Claims one browser but proves another",
  device_key_changed: "The device key changed",
  device_key_missing_on_keyed_device: "This device had a key before and showed none now",
  no_device_key: "No device key (software-only session)",
};
export const reasonText = (r: string) => REASON[r] ?? `Unknown reason (${r.slice(0, 40)})`;
const REVOKE: Record<string, string> = {
  founder_nuke: "Closed by you", founder_nuke_others: "Closed by you (sign out everywhere else)", integrity_fail: "Closed: request signatures kept failing", replaced: "Closed: too many live sessions",
  expired: "Expired", geo_moved: "Closed: used outside the allowed countries", session_shared: "Closed: looked like two machines sharing one session", selftest: "Self-test",
};
export const revokeText = (r: string | null) => (r == null ? "" : REVOKE[r] ?? `Closed (${r.slice(0, 40)})`);
export const KEY_TEXT: Record<KeySource, string> = { dbsc: "Hardware-bound key (DBSC)", webcrypto: "Device key (WebCrypto)", none: "No device key", unknown: "Key state unknown" };
export const INTEGRITY_TEXT: Record<Integrity, string> = { verified: "Requests verified", stale: "Verification is stale", failed: "Verification failed", never: "Not verified yet", unknown: "Unknown" };
export const BROWSER_TEXT: Record<string, string> = { chrome: "Chrome", edge: "Edge", firefox: "Firefox", safari: "Safari", opera: "Opera", samsung: "Samsung Internet", other: "Other browser", unknown: "Unknown" };
export const browserText = (b: string) => BROWSER_TEXT[b] ?? "Unknown";
export const METHOD_TEXT: Record<string, string> = { passkey: "Passkey", password: "Password", magic_link: "Email link" };
export const methodText = (m: string) => METHOD_TEXT[m] ?? "Unknown method";
/** quic = the real HTTP/3 path; h2/h1 = over TCP (a proxy hop is still TCP). The SQL badge text is shown as is; this is only the short chip. */
export const pathShort = (p: string) => (p === "quic" ? "QUIC" : p === "h2" ? "TCP · h2" : p === "h1" ? "TCP · h1" : "not measured");

/** Regional-indicator flag from a 2-letter code ("PK" -> flag). No image files, no network. Invalid = "". */
export function flag(cc: string | null): string {
  if (!cc || !/^[A-Z]{2}$/.test(cc)) return "";
  return String.fromCodePoint(...[...cc].map((c) => 0x1f1e6 + c.charCodeAt(0) - 65));
}
export function countryName(cc: string | null, locale = "en"): string {
  if (!cc) return "Unknown country";
  try { return new Intl.DisplayNames([locale], { type: "region" }).of(cc) ?? cc; } catch { return cc; }
}

/** "3 minutes ago" / "in 2 hours"; null = "unknown". Pure over (then, now). */
export function ago(then: number | null, now: number, locale = "en"): string {
  if (then == null) return "unknown";
  const s = Math.round((then - now) / 1000), a = Math.abs(s);
  const f = new Intl.RelativeTimeFormat(locale, { numeric: "auto" });
  if (a < 45) return "just now";
  if (a < 3600) return f.format(Math.round(s / 60), "minute");
  if (a < 86400) return f.format(Math.round(s / 3600), "hour");
  return f.format(Math.round(s / 86400), "day");
}
/** "1 d 4 h" / "35 min" for a duration in seconds (idle / absolute lifetime). */
export function span(secs: number): string {
  if (!Number.isFinite(secs) || secs < 0) return "unknown";
  if (secs < 90) return `${Math.round(secs)} s`;
  if (secs < 5400) return `${Math.round(secs / 60)} min`;
  if (secs < 129600) return `${Math.round(secs / 3600)} h`;
  return `${Math.round(secs / 86400)} d`;
}
/** Time left before the policy closes this session: the smaller of idle and absolute. null when unknown. */
export function remaining(s: Sess, pol: Policy | null, now: number): { secs: number; why: "idle" | "absolute" } | null {
  if (!pol || !s.live || s.lastSeenAt == null || s.createdAt == null) return null;
  const idle = pol.idleS - (now - s.lastSeenAt) / 1000, abs = pol.absoluteS - (now - s.createdAt) / 1000;
  return idle <= abs ? { secs: Math.max(0, idle), why: "idle" } : { secs: Math.max(0, abs), why: "absolute" };
}

// ------------------------------------------------------------------------------------------------------------------------------
// the Trust Ring: four real facts about THIS session and one honest word
// ------------------------------------------------------------------------------------------------------------------------------
export type Arc = { id: "key" | "path" | "integrity" | "chain"; label: string; state: "good" | "warn" | "bad" | "unknown"; detail: string };
export type Ring = { verdict: "clear" | "attention" | "alert" | "unknown"; word: string; arcs: Arc[] };

export function ring(cur: Sess | null, b: Board | null): Ring {
  const key: Arc = !cur ? { id: "key", label: "Device key", state: "unknown", detail: "This session is not in the list yet" }
    : cur.keySource === "dbsc" || cur.keySource === "webcrypto" ? { id: "key", label: "Device key", state: cur.spoof.reasons.includes("device_key_changed") ? "bad" : "good", detail: `${KEY_TEXT[cur.keySource]}${cur.keyFp ? ` · ${cur.keyFp.slice(0, 8)}` : ""}` }
    : cur.keySource === "none" ? { id: "key", label: "Device key", state: "warn", detail: KEY_TEXT.none } : { id: "key", label: "Device key", state: "unknown", detail: KEY_TEXT.unknown };
  const path: Arc = !cur ? { id: "path", label: "Path", state: "unknown", detail: "unknown" }
    : cur.protocol === "quic" ? { id: "path", label: "Path", state: "good", detail: cur.pathBadge }
    : cur.protocol === "h2" || cur.protocol === "h1" ? { id: "path", label: "Path", state: "warn", detail: cur.pathBadge } : { id: "path", label: "Path", state: "unknown", detail: cur.pathBadge };
  const integ: Arc = !cur ? { id: "integrity", label: "Integrity", state: "unknown", detail: "unknown" }
    : { id: "integrity", label: "Integrity", state: cur.integrity.state === "verified" ? "good" : cur.integrity.state === "failed" ? "bad" : cur.integrity.state === "unknown" ? "unknown" : "warn", detail: INTEGRITY_TEXT[cur.integrity.state] };
  const chain: Arc = !b || b.chainOk == null || b.anchorOk == null ? { id: "chain", label: "Ledger", state: "unknown", detail: "Ledger check unavailable" }
    : b.chainOk && b.anchorOk ? { id: "chain", label: "Ledger", state: "good", detail: "Chain verified · anchor matches the audit chain" }
    : { id: "chain", label: "Ledger", state: "bad", detail: !b.chainOk ? `Chain broken${b.chainBrokenAt != null ? ` at row ${b.chainBrokenAt}` : ""}` : `Anchor does not match (${b.anchorWhy || "unknown reason"})` };
  const arcs = [key, path, integ, chain];
  const spoofed = !!cur && cur.spoof.level === "spoof";
  const verdict: Ring["verdict"] = arcs.some((a) => a.state === "bad") || spoofed ? "alert" : arcs.every((a) => a.state === "unknown") ? "unknown" : arcs.some((a) => a.state === "warn" || a.state === "unknown") || (!!cur && cur.spoof.level === "suspect") ? "attention" : "clear";
  return { verdict, word: { clear: "All clear", attention: "Needs attention", alert: "Alert", unknown: "Not enough data" }[verdict], arcs };
}

// ------------------------------------------------------------------------------------------------------------------------------
// list: filter + search, alert strip, actions
// ------------------------------------------------------------------------------------------------------------------------------
export type Filter = "all" | "live" | "closed" | "alert";
export const hasAlert = (s: Sess) => s.spoof.level !== "ok" || s.netFlips >= 3 || s.integrity.state === "failed" || s.failStreak > 0;

export function visible(list: Sess[], f: Filter, q: string): Sess[] {
  const needle = q.trim().toLowerCase().slice(0, 40);
  return list.filter((s) => (f === "all" || (f === "live" && s.live) || (f === "closed" && !s.live) || (f === "alert" && hasAlert(s)))
    && (!needle || [s.sid, s.claimed, s.proven, s.kernel, s.method, s.country ?? "", countryName(s.country), s.pathBadge].some((x) => x.toLowerCase().includes(needle))));
}

/** The last `hours` of the ledger, counted per alert kind (kinds with zero are left out). */
export function alerts(rows: Row[], now: number, hours = 24): { kind: string; count: number; last: number | null }[] {
  const from = now - hours * 3600_000, m = new Map<string, { count: number; last: number | null }>();
  for (const r of rows) {
    if (!(ALERT_KINDS as readonly string[]).includes(r.kind) || r.atMs == null || r.atMs < from) continue;
    const c = m.get(r.kind) ?? { count: 0, last: null };
    c.count += 1; c.last = Math.max(c.last ?? 0, r.atMs); m.set(r.kind, c);
  }
  return [...m.entries()].map(([kind, v]) => ({ kind, ...v })).sort((a, b) => (b.last ?? 0) - (a.last ?? 0));
}

/** One sentence for a ledger row. Facts are only read for known numeric fields; everything is returned as plain text. */
export function rowText(r: Row): string {
  const base = kindInfo(r.kind).text;
  const f = r.facts, parts: string[] = [];
  if (r.country) parts.push(countryName(r.country));
  if (r.protocol !== "unknown") parts.push(pathShort(r.protocol));
  if (typeof f.flips === "number") parts.push(`${f.flips} network changes`);
  if (typeof f.score === "number") parts.push(`score ${f.score}`);
  return parts.length ? `${base} · ${parts.join(" · ")}` : base;
}

/** What closing a session means for the person pressing the button. */
export function closeWarning(s: Sess): string {
  return s.current ? "This is the session you are using now. You will be signed out of this browser." : `Close the ${browserText(s.claimed)} session${s.country ? ` from ${countryName(s.country)}` : ""}? It stops working on its very next request.`;
}
export const canClose = (s: Sess) => s.live;
export const othersLive = (b: Board | null) => (b ? b.sessions.filter((s) => s.live && !s.current).length : 0);

/** How stale the screen is: fresh (< 2 refreshes), stale otherwise; null = never loaded. */
export function freshness(loadedAt: number | null, now: number, everyMs = 15000): "fresh" | "stale" | "never" {
  if (loadedAt == null) return "never";
  return now - loadedAt <= everyMs * 2.2 ? "fresh" : "stale";
}
