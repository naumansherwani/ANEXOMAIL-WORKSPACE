// QC1c F6 (18 Nov 2026): the lock on a recipient chip, the PURE part. No DOM, no React, no network: bun-tested (tls_pure.test.ts).
// The word "unknown" does not exist (his 18 Nov 07:50 order): a domain with no fact yet is "checking" (dotted), every other state is a named verdict with its reason.
// Verdicts come from the server (E189 + the Rust probe); this file only decides what to SHOW. Colours: pq blue, classic grey, old grey, warn amber, nomail red, checking dotted.
export type Verdict = "pq" | "classic13" | "classic12" | "none" | "refused" | "unreachable" | "nomail" | "checking";
export type TlsFact = {
  domain: string; verdict: Verdict; kex_group?: string | null; tls_version?: string | null; cipher?: string | null; cert_verified?: boolean | null;
  source?: "probe" | "sent" | "received" | null; attempts?: number; next_try_at?: string | null; checked_at?: string | null;
  proven_verdict?: string | null; mismatch?: boolean; line?: string | null; detail?: { detail?: string; hosts_tried?: string[] } | null;
};
export type Tone = "pq" | "classic" | "old" | "warn" | "nomail" | "checking";
export type LockView = { tone: Tone; short: string; label: string; aria: string; lines: string[]; dotted: boolean };

export const domainOf = (addr: string): string => { const i = addr.lastIndexOf("@"); return i > 0 ? addr.slice(i + 1).trim().toLowerCase() : ""; };
const CLEAN = /^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$/;
/** The distinct, valid domains of a list of addresses (at most 50: the server's read door takes 50). */
export function domainsOf(addrs: string[]): string[] { const s = new Set<string>(); for (const a of addrs) { const d = domainOf(a); if (d && d.length <= 253 && CLEAN.test(d)) s.add(d); } return [...s].sort().slice(0, 50); }
/** Which domains still need a probe: no fact at all, or a fact that is only a temporary 'checking' older than 90 s (a probe that died). Never one that already has an answer. */
export function needCheck(domains: string[], facts: Record<string, TlsFact | undefined>, now: number): string[] {
  return domains.filter((d) => { const f = facts[d]; if (!f) return true; if (f.verdict !== "checking") return false; const t = f.checked_at ? Date.parse(f.checked_at) : 0; return !t || now - t > 90_000; }).slice(0, 10);
}
const SRC: Record<string, string> = { sent: "a real mail we sent", received: "a mail that arrived (a hint only)", probe: "a check from our server" };
const hhmm = (iso?: string | null) => { if (!iso) return ""; const d = new Date(iso); return Number.isNaN(d.getTime()) ? "" : d.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }); };
export const nextTryText = (iso?: string | null, now = Date.now()): string => { const t = iso ? Date.parse(iso) : NaN; if (!Number.isFinite(t)) return ""; return t <= now ? "next try: any moment" : `next try ${hhmm(iso)}`; };

/** What the lock shows for one domain. `f` undefined = no fact yet = checking (dotted). */
export function lockView(f: TlsFact | undefined, now = Date.now()): LockView {
  if (!f || f.verdict === "checking") return { tone: "checking", short: "…", label: "Checking this mail server", aria: "Encryption: checking this mail server", dotted: true, lines: ["The server is looking at this domain's mail server now."] };
  const lines: string[] = [];
  const kex = f.kex_group ? `Key exchange: ${f.kex_group}` : ""; const ver = f.tls_version ? `TLS version: ${f.tls_version.replace(/^TLSv/, "")}` : "";
  const cert = f.cert_verified === true ? "Certificate: verified" : f.cert_verified === false ? "Certificate: NOT verified (the lock was read, nothing was sent over it)" : "";
  const src = f.source ? `Source: ${SRC[f.source] ?? f.source}` : ""; const at = f.checked_at ? `Checked ${hhmm(f.checked_at)}` : "";
  const hosts = f.detail?.hosts_tried?.length ? `Servers tried: ${f.detail.hosts_tried.join(", ")}` : ""; const why = f.detail?.detail ? f.detail.detail : "";
  const push = (...x: string[]) => x.filter(Boolean).forEach((s) => lines.push(s));
  switch (f.verdict) {
    case "pq": push(kex, ver, cert, src, at); return { tone: "pq", short: "PQ", label: "Post-quantum encryption", aria: "Encryption: post-quantum, TLS 1.3 with X25519MLKEM768", dotted: false, lines: withProof(lines, f) };
    case "classic13": push(kex, ver, cert, src, at); return { tone: "classic", short: "TLS", label: "Encrypted, TLS 1.3 (classic key exchange)", aria: "Encryption: TLS 1.3, classic key exchange", dotted: false, lines: withProof(lines, f) };
    case "classic12": push(ver, kex, cert, src, at); return { tone: "old", short: "TLS", label: "Encrypted, an older TLS version", aria: "Encryption: an older TLS version (1.2 or older)", dotted: false, lines: withProof(lines, f) };
    case "none": push("This mail server does not offer encryption (no STARTTLS).", src, at, hosts); return { tone: "warn", short: "!", label: "Not encrypted", aria: "Warning: this mail server does not offer encryption", dotted: false, lines: withProof(lines, f) };
    case "refused": push(why || "The encryption handshake failed.", hosts, src, at); return { tone: "warn", short: "!", label: "Encryption failed", aria: "Warning: the encryption handshake with this mail server failed", dotted: false, lines: withProof(lines, f) };
    case "unreachable": { const nx = nextTryText(f.next_try_at, now); push(why || "No mail server of this domain could be reached.", hosts, nx || "No more tries scheduled.", at); return { tone: "warn", short: "?!", label: nx ? `Cannot reach, ${nx}` : "Cannot reach this mail server", aria: `Warning: cannot reach this mail server${nx ? ", " + nx : ""}`, dotted: !!nx, lines: withProof(lines, f) }; }
    case "nomail": push(why || "This domain does not accept mail (no mail server).", at); return { tone: "nomail", short: "✕", label: "This domain takes no mail", aria: "Error: this domain does not accept mail", dotted: false, lines: withProof(lines, f) };
  }
  return { tone: "checking", short: "…", label: "Checking this mail server", aria: "Encryption: checking this mail server", dotted: true, lines: [] };
}
function withProof(lines: string[], f: TlsFact): string[] { return f.line ? [...lines, f.line] : lines; }

/** The 'proven' line under a SENT mail: what the real delivery proved, per recipient domain. Only domains that have a proof; empty = no line. */
export function provenLine(facts: Record<string, TlsFact | undefined>, domains: string[]): string {
  const parts: string[] = [];
  for (const d of domains) { const f = facts[d]; if (!f || !f.proven_verdict || f.source !== "sent") continue; const w = f.proven_verdict === "pq" ? "post-quantum" : f.proven_verdict === "classic13" ? "TLS 1.3" : f.proven_verdict === "classic12" ? "TLS 1.2 or older" : "no TLS"; parts.push(`${d}: ${w}${f.mismatch ? " (the check had predicted another lock)" : ""}`); }
  return parts.length ? `Proven by the real delivery: ${parts.join(" · ")}` : "";
}
