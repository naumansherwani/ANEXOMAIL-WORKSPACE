// Q1d-1a a4: pure helpers of the DKIM panel (no network, no React). The twin of E175 fmail_dkim_selector175 and the wording of the health read.
export type Alg = "ed25519-sha256" | "rsa-sha256";
export type KeyHealth = { key_id: string; selector: string; alg: Alg; status: string; dns: { result: string; dnssec: string; age_s: number } | null; signed_24h: number; last_proof: string | null };
export type Rotation = { key_id: string; selector: string; alg: Alg; status: string; age_days: number; due_in_days: number | null; state: "ok" | "soon" | "due" | "overdue" | "retired"; dns_removable?: boolean | null; dns_keep_until?: string | null };
export type Policy = { rotate_days: number; overlap_days: number; sig_ttl_days: number; require_oversign: boolean; require_dual: boolean; require_dns_match: boolean };
export type Health = { policy: Policy; keys: KeyHealth[]; rotation: Rotation[]; blockers: string[]; warnings: string[]; send_ready: boolean; signed_24h: number; oversigned_24h: number };
export const RECEIVERS = ["gmail", "outlook", "yahoo", "icloud", "other"] as const;

/** First free dated selector of this month, exactly as SQL picks it: e|r + YYMM (UTC) + a..z. null = all 26 used. */
export function nextSelector(alg: Alg, existing: string[], now: Date = new Date()): string | null {
  const ym = `${String(now.getUTCFullYear() % 100).padStart(2, "0")}${String(now.getUTCMonth() + 1).padStart(2, "0")}`, pre = alg === "ed25519-sha256" ? "e" : "r";
  for (let i = 0; i < 26; i++) { const s = pre + ym + String.fromCharCode(97 + i); if (!existing.includes(s)) return s; }
  return null;
}
export function dnsWords(r: string | undefined | null): { text: string; tone: "ok" | "warn" | "bad" | "idle" } {
  switch (r) {
    case "match": return { text: "DNS record confirmed", tone: "ok" };
    case "absent": return { text: "Not in DNS yet", tone: "warn" };
    case "mismatch": return { text: "DNS holds a different key", tone: "bad" };
    case "empty_p": return { text: "DNS record is empty (key revoked there)", tone: "bad" };
    case "lookup_error": return { text: "DNS lookup failed, try again", tone: "warn" };
    default: return { text: "Not checked yet", tone: "idle" };
  }
}
export function headline(h: Health | null): { text: string; tone: "ok" | "warn" | "bad" | "idle" } {
  if (!h) return { text: "Signing status unavailable", tone: "idle" };
  if (!h.send_ready) return { text: h.keys.length === 0 ? "No signing key yet" : "Sending blocked", tone: "bad" };
  return h.warnings.length ? { text: "Ready, with advice", tone: "warn" } : { text: "Signing ready", tone: "ok" };
}
export function rotationWords(r: Rotation): string {
  if (r.state === "retired") return r.dns_removable ? "Retired. Its DNS record may be deleted now." : `Retired. Keep its DNS record until ${r.dns_keep_until ? r.dns_keep_until.slice(0, 10) : "the overlap ends"}.`;
  if (r.state === "ok") return `Rotate in ${r.due_in_days} days`;
  if (r.state === "soon") return `Rotate soon (${r.due_in_days} days)`;
  return r.state === "due" ? "Rotation is due" : "Rotation is overdue";
}
export const ratchetWords = (on: boolean) => (on ? "On. It can never be turned off." : "Off");
