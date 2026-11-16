// Q1b4 step d: pure logic of the TRUST RING (no React, no network). Every word on the ring comes from facts the Rust verifier + SQL E183 produced; a value the server did not give is "not checked" (grey), never a made-up tick.
export type Tone = "ok" | "warn" | "bad" | "off";
export type Seg = { key: string; label: string; tone: Tone; text: string };
export type Reason = { code: string; pts: number; text: string };
export type RingFacts = { spf: string; dkim: string; dmarc: string; arc: string; lookalike: boolean; scan: string; tls: string | null; score?: number | null; grade?: string | null };
export type Evidence = {
  found?: boolean; score?: number; grade?: string; reasons?: Reason[]; chain_ok?: boolean; seq?: number; row_hash?: string; authres?: string;
  client?: { ip: string | null; helo: string | null; rdns: string | null }; spf?: { result: string; domain: string | null };
  dkim?: { result: string; count: number; sigs: { idx: number; domain: string; selector: string; algo: string; result: string; aligned: boolean }[] };
  dmarc?: { result: string; policy: string | null; disposition: string | null; spf_aligned: boolean; dkim_aligned: boolean; walk: number | null; record_domain: string | null };
  arc?: { result: string; instances: number }; iprev?: string; tls?: { class: string | null; version: string | null; cipher: string | null; group: string | null };
  spoof?: { display: boolean; mixed_script: boolean; lookalike_kind: string | null; lookalike_of: string | null }; sender?: { known: boolean; prior: number };
};
export type OutFacts = { found?: boolean; direction?: string; state?: string; sent_ms?: number | null; accepted?: boolean; reply?: string | null; tls?: string | null; dkim_signed?: boolean; signatures?: { selector: string; alg: string; oversigned?: boolean }[]; attempts?: number };

const pass = (v: string): Tone => (v === "pass" ? "ok" : v === "none" || !v ? "off" : v === "softfail" || v === "neutral" ? "warn" : "bad");
const word = (v: string, ok = "pass") => (v === "none" || !v ? "not checked" : v === ok ? "passed" : v);

/** Exactly eight segments, always in the same order, so the ring never reshuffles between mails. */
export function ringSegments(f: RingFacts, senderKnown?: boolean | null): Seg[] {
  const tlsTone: Tone = f.tls == null ? "off" : f.tls === "tls13_pq" || f.tls === "tls13" ? "ok" : f.tls === "tls12" ? "warn" : "bad";
  const tlsText = f.tls == null ? "not checked" : f.tls === "tls13_pq" ? "TLS 1.3 post-quantum" : f.tls === "tls13" ? "TLS 1.3" : f.tls === "tls12" ? "TLS 1.2" : "no TLS";
  const scanTone: Tone = f.scan === "clean" ? "ok" : f.scan === "pending" || f.scan === "skipped" ? "off" : f.scan === "opaque" ? "warn" : "bad";
  const scanText = f.scan === "clean" ? "clean" : f.scan === "infected" ? "virus found" : f.scan === "opaque" ? "hidden content" : f.scan === "pending" ? "pending" : f.scan === "skipped" ? "not scanned" : "scan error";
  return [
    { key: "spf", label: "SPF", tone: pass(f.spf), text: word(f.spf) },
    { key: "dkim", label: "DKIM", tone: pass(f.dkim), text: word(f.dkim) },
    { key: "dmarc", label: "DMARC", tone: pass(f.dmarc), text: word(f.dmarc) },
    { key: "arc", label: "ARC", tone: f.arc === "pass" ? "ok" : f.arc === "fail" ? "bad" : "off", text: f.arc === "pass" ? "chain valid" : f.arc === "fail" ? "chain broken" : "no chain" },
    { key: "tls", label: "TLS", tone: tlsTone, text: tlsText },
    { key: "scan", label: "Scan", tone: scanTone, text: scanText },
    { key: "sender", label: "Sender", tone: senderKnown == null ? "off" : senderKnown ? "ok" : "warn", text: senderKnown == null ? "no history yet" : senderKnown ? "known sender" : "first mails" },
    { key: "look", label: "Look-alike", tone: f.lookalike ? "bad" : "ok", text: f.lookalike ? "look-alike domain" : "none found" },
  ];
}
export function gradeTone(g: string | null | undefined): Tone { return !g ? "off" : g === "A+" || g === "A" || g === "B" ? "ok" : g === "C" || g === "D" ? "warn" : "bad"; }
/** True when the server never produced a verdict for this mail (older mail, or the verdict step was down): the ring stays grey and says so. */
export function unrated(f: Pick<RingFacts, "score" | "grade">): boolean { return f.score == null || !f.grade; }
export function ringLabel(f: RingFacts): string { return unrated(f) ? "Trust: not checked" : `Trust ${f.score} of 100, grade ${f.grade}`; }
/** Arc fractions of the full circle for the eight segments (equal slices with a small gap), start angle in degrees. Pure so it is tested. */
export function arcs(n = 8, gapDeg = 6): { start: number; end: number }[] { const w = 360 / n; return Array.from({ length: n }, (_, i) => ({ start: i * w + gapDeg / 2, end: (i + 1) * w - gapDeg / 2 })); }
export function reasonLine(r: Reason): string { return `${r.pts > 0 ? "+" : r.pts < 0 ? "" : "·"}${r.pts !== 0 ? r.pts + " " : ""}${r.text}`; }
export function hhmmss(ms: number): string { const d = new Date(ms); const p = (n: number) => String(n).padStart(2, "0"); return `${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`; }
const TLS_WORD: Record<string, string> = { tls13_pq: "TLS 1.3 post-quantum", tls13: "TLS 1.3", tls12: "TLS 1.2", none: "no TLS" };
/** The sentence under an OUTGOING mail (gap G3): what we signed, how it travelled, when the receiver said 250. A mail not yet accepted never shows a sent time. */
export function outLine(o: OutFacts | null | undefined, host = "anexomail.com"): string {
  if (!o || o.found === false) return "Sending facts are not available yet.";
  const sig = (o.signatures ?? []).length ? `Signed by ${host} (${[...new Set((o.signatures ?? []).map((s) => s.alg.startsWith("ed25519") ? "Ed25519" : s.alg.startsWith("rsa") ? "RSA" : s.alg))].join(" + ")})` : o.dkim_signed ? `Signed by ${host}` : "Not signed";
  const via = o.tls ? `delivered over ${TLS_WORD[o.tls] ?? o.tls}` : "delivery link not recorded";
  if (o.accepted && o.sent_ms) return `${sig}, ${via}, accepted by the receiver at ${hhmmss(o.sent_ms)} (${(o.reply ?? "250").slice(0, 3)}).`;
  const st = o.state === "failed" || o.state === "dead" ? "not delivered" : o.state === "sending" ? "being delivered now" : "waiting to be sent";
  return `${sig}. This mail is ${st}${o.attempts ? ` (try ${o.attempts})` : ""}.`;
}
/** The time shown as "Sent": the receiver's 250 when we have it; otherwise nothing (never the compose time dressed up as sent). */
export function sentMs(r: { direction: string; sent_ms?: number | null }): number | null { return r.direction === "out" && r.sent_ms ? r.sent_ms : null; }
