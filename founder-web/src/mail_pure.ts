// Q1c (founder mailbox UI), the pure part: no fetch, no DOM, nothing invented. Everything the Mail page shows as words, numbers or order is decided here and tested (mail_pure.test.ts).
// INHERITABLE BY AWAM (AWAM-INHERITS law): no founder names inside; the awam mailbox migration lifts this file as it is.
export type Seal = "vault" | "recipient_pq";
export type Sum = { subject?: string; from?: string; from_name?: string; to?: string[]; cc?: string[]; date?: string; message_id?: string; snippet?: string; attach?: number };
export type Row = {
  id: string; thread_id: string; folder: string; direction: "in" | "out"; received_ms: number; size: number; attach: number; read: boolean; starred: boolean; draft: boolean; thread_count: number;
  spf: string; dkim: string; dmarc: string; arc: string; lookalike: boolean; scan: string; tls: string | null; domain: string | null; seal_mode: Seal; gated: boolean;
  sum?: Sum | null; broken?: boolean;
};
export type Box = { id: string; address: string; brand?: string; display_name?: string; seal_mode: Seal; status: string; key_id?: string | null; vault_key_id?: string | null };
export type Lane = { lane: string; label: string; dir: "in" | "out"; count: number; last_ms: number; tone: "ok" | "warn" | "bad" };
export type Counts = Record<string, { total: number; unread: number }>;

export const FOLDERS: { key: string; label: string; icon: string; gated?: boolean }[] = [
  { key: "inbox", label: "Inbox", icon: "inbox" }, { key: "sent", label: "Sent", icon: "sent" }, { key: "drafts", label: "Drafts", icon: "draft" },
  { key: "outbox", label: "Outbox", icon: "outbox" }, { key: "archive", label: "Archive", icon: "archive" }, { key: "snoozed", label: "Snoozed", icon: "snooze" },
  { key: "spam", label: "Spam", icon: "spam" }, { key: "quarantine", label: "Quarantine", icon: "shield", gated: true }, { key: "vault", label: "Vault", icon: "vault", gated: true }, { key: "trash", label: "Trash", icon: "trash" },
];
export const folderLabel = (k: string) => FOLDERS.find((f) => f.key === k)?.label ?? k;
export const isGatedView = (k: string) => !!FOLDERS.find((f) => f.key === k)?.gated;

/** Compact number for a lane/rail badge: 0..999 as is, 1.2k, 12k, 1.2M. Never negative, never NaN. */
export function compact(n: number): string {
  if (!Number.isFinite(n) || n < 0) return "0";
  if (n < 1000) return String(Math.round(n));
  if (n < 10_000) return (Math.floor(n / 100) / 10).toFixed(1).replace(/\.0$/, "") + "k";
  if (n < 1_000_000) return Math.floor(n / 1000) + "k";
  return (Math.floor(n / 100_000) / 10).toFixed(1).replace(/\.0$/, "") + "M";
}
/** The number shown while a count glides from `from` to `to`. t in [0,1]. Easing out (fast start, soft landing); the end is always exactly `to`. */
export function glide(from: number, to: number, t: number): number {
  if (!(t < 1)) return to; if (!(t > 0)) return from;
  const e = 1 - Math.pow(1 - t, 3);
  return Math.round(from + (to - from) * e);
}
export function ago(ms: number | null | undefined, now = Date.now()): string {
  if (!ms || !Number.isFinite(ms)) return "never";
  const s = Math.max(0, (now - ms) / 1000);
  return s < 60 ? "just now" : s < 3600 ? `${Math.floor(s / 60)} min ago` : s < 86400 ? `${Math.floor(s / 3600)} h ago` : `${Math.floor(s / 86400)} d ago`;
}
/** Short date for the list: today = time, this year = "13 Nov", older = "13 Nov 2025". */
export function when(ms: number, now = Date.now()): string {
  const d = new Date(ms), n = new Date(now), p2 = (x: number) => String(x).padStart(2, "0");
  if (d.toDateString() === n.toDateString()) return `${p2(d.getHours())}:${p2(d.getMinutes())}`;
  const mon = d.toLocaleString("en-GB", { month: "short" });
  return d.getFullYear() === n.getFullYear() ? `${d.getDate()} ${mon}` : `${d.getDate()} ${mon} ${d.getFullYear()}`;
}
export const fmtSize = (b: number) => (b < 1024 ? `${b} B` : b < 1024 * 1024 ? `${Math.round(b / 1024)} KB` : `${(b / 1024 / 1024).toFixed(1)} MB`);

/** The sender line and subject of a row. A gated row shows NO content (not even a placeholder that leaks a length). */
export function rowText(r: Row): { who: string; subject: string; snippet: string; locked: boolean } {
  if (r.gated) return { who: r.folder === "quarantine" ? "Quarantined message" : "Confidential thread", subject: "Touch your key to open", snippet: "", locked: true };
  if (r.broken || !r.sum) return { who: "Unreadable", subject: "This message does not verify", snippet: "The seal or its mailbox binding failed. It is kept, not shown.", locked: false };
  const s = r.sum;
  return { who: s.from_name || s.from || "Unknown sender", subject: s.subject || "(no subject)", snippet: s.snippet || "", locked: false };
}
/** Page merge: new rows replace old by id, newest first, no duplicates. */
export function merge(old: Row[], add: Row[]): Row[] {
  const m = new Map<string, Row>(); for (const r of old) m.set(r.id, r); for (const r of add) m.set(r.id, r);
  return [...m.values()].sort((a, b) => b.received_ms - a.received_ms || (a.id < b.id ? 1 : -1));
}
/** Verdict chips for the reader. Only facts the database holds; "none" is shown as "not checked", never as a pass. */
export function verdicts(r: Pick<Row, "spf" | "dkim" | "dmarc" | "scan" | "lookalike" | "tls">): { k: string; text: string; tone: "ok" | "warn" | "bad" | "off" }[] {
  const t = (v: string): "ok" | "bad" | "off" | "warn" => (v === "pass" ? "ok" : v === "none" ? "off" : v === "softfail" || v === "neutral" ? "warn" : "bad");
  const out: { k: string; text: string; tone: "ok" | "warn" | "bad" | "off" }[] = [
    { k: "spf", text: `SPF ${r.spf === "none" ? "not checked" : r.spf}`, tone: t(r.spf) }, { k: "dkim", text: `DKIM ${r.dkim === "none" ? "not checked" : r.dkim}`, tone: t(r.dkim) },
    { k: "dmarc", text: `DMARC ${r.dmarc === "none" ? "not checked" : r.dmarc}`, tone: t(r.dmarc) },
    { k: "scan", text: r.scan === "clean" ? "Virus scan clean" : r.scan === "infected" ? "Virus found" : r.scan === "pending" ? "Scan pending" : r.scan === "skipped" ? "Not scanned" : r.scan === "opaque" ? "Hidden content (encrypted)" : "Scan error", tone: r.scan === "clean" ? "ok" : r.scan === "pending" || r.scan === "skipped" ? "off" : "bad" },
  ];
  if (r.lookalike) out.push({ k: "look", text: "Look-alike domain", tone: "bad" });
  if (r.tls) out.push({ k: "tls", text: r.tls === "tls13_pq" ? "TLS 1.3 post-quantum" : r.tls === "tls13" ? "TLS 1.3" : r.tls === "tls12" ? "TLS 1.2" : "No TLS", tone: r.tls === "none" ? "bad" : r.tls === "tls12" ? "warn" : "ok" });
  return out;
}

export type Proof = { scope: "message" | "ledger"; found?: boolean; anchored?: boolean; seq?: number; row_hash?: string; prev_hash?: string; body_sha256_ledger?: string; body_sha256_now?: string; match?: boolean; chain_ok_from_here?: boolean; chain_ok?: boolean; audit_seq?: number | null; head_seq?: number };
export type ProofChip = { state: "verified" | "unanchored" | "mismatch" | "broken" | "unknown"; text: string; detail: string[] };
/** The ledger-anchor chip. "verified" ONLY when the ledger row exists, the hash recorded then equals the hash of the ciphertext now AND the chain verifies from that row. Never a fake tick. */
export function proofChip(p: Proof | null | undefined): ProofChip {
  if (!p || p.scope !== "message" || p.found === false) return { state: "unknown", text: "Ledger anchor unknown", detail: ["The server did not return a proof for this message."] };
  if (!p.anchored) return { state: "unanchored", text: "Not anchored yet", detail: ["This message has no ledger row (yet).", `Ciphertext SHA-256 now: ${short(p.body_sha256_now)}`] };
  if (p.match === false) return { state: "mismatch", text: "Ledger anchor MISMATCH", detail: [`Recorded: ${short(p.body_sha256_ledger)}`, `Now: ${short(p.body_sha256_now)}`, "The stored ciphertext changed after it was anchored."] };
  if (p.chain_ok_from_here === false) return { state: "broken", text: "Ledger chain broken", detail: [`Ledger row #${p.seq}`, "A later row fails its hash check."] };
  return { state: "verified", text: "Ledger anchor verified · SHA-256", detail: [`Ledger row #${p.seq}`, `Row hash: ${short(p.row_hash)}`, `Previous: ${short(p.prev_hash)}`, `Ciphertext SHA-256: ${short(p.body_sha256_ledger)}`, p.audit_seq ? `Founder audit anchor #${p.audit_seq}` : "Hash chain only: no audit batch yet, so no Merkle proof is claimed."] };
}
export const short = (h: string | null | undefined) => (h && h.length > 20 ? `${h.slice(0, 10)}…${h.slice(-8)}` : h || "n/a");

export type Pill = { quic: { ok: boolean; text: string }; dbsc: { ok: boolean; text: string }; seal: { ok: boolean; text: string } };
/** The header pill. Each segment is a measured fact; a failed or unknown check is shown as "not verified" with a hollow dot, never hidden and never green.
 *  h3: performance navigation `nextHopProtocol` of THIS page ("h3" = QUIC). dbsc: this device's row of /founder/v1/dbsc/status. box: the open mailbox. */
export function pill(h3: string | null | undefined, dbscBound: boolean | null | undefined, box: Pick<Box, "seal_mode" | "key_id"> | null | undefined): Pill {
  const wt = h3 === "wt";
  const quic = wt || h3 === "h3" || (typeof h3 === "string" && h3.startsWith("h3"));
  const seal = !!box && (box.seal_mode === "vault" || (box.seal_mode === "recipient_pq" && !!box.key_id));
  return {
    quic: { ok: quic, text: wt ? "QUIC · WebTransport" : quic ? "QUIC" : h3 ? `${h3.toUpperCase()} (not QUIC)` : "transport unknown" },
    dbsc: { ok: dbscBound === true, text: dbscBound === true ? "DBSC verified" : "DBSC not verified" },
    seal: { ok: seal, text: !box ? "not sealed" : box.seal_mode === "recipient_pq" ? (seal ? "PQC sealed" : "PQC key missing") : "AES-256 sealed" },
  };
}

/** Which pending action a gated open needs; the server also says it (needs_touch). */
export const touchAction = (folder: string, vault: boolean) => ({ action: "mail.unseal", why: vault ? "This thread is in your Vault." : folder === "quarantine" ? "This message is in Quarantine." : "This message is confidential." });

/** Keyboard: j/k move, Enter opens, e archive, # trash, s star, u unread, g+i/s/d/q/v folders. Returns the command or null. */
export function keyCmd(k: string, mods: { ctrl?: boolean; meta?: boolean; alt?: boolean }, pending: string | null): { cmd: string; arg?: string } | { pending: string } | null {
  if (mods.ctrl || mods.meta || mods.alt) return null;
  if (pending === "g") { const m: Record<string, string> = { i: "inbox", s: "sent", d: "drafts", a: "archive", q: "quarantine", v: "vault", t: "trash", p: "spam" }; return m[k] ? { cmd: "folder", arg: m[k] } : null; }
  switch (k) { case "c": return { cmd: "compose" }; case "j": return { cmd: "next" }; case "k": return { cmd: "prev" }; case "Enter": return { cmd: "open" }; case "e": return { cmd: "move", arg: "archive" }; case "#": return { cmd: "move", arg: "trash" };
    case "s": return { cmd: "star" }; case "u": return { cmd: "unread" }; case "g": return { pending: "g" }; case "Escape": return { cmd: "close" }; default: return null; }
}

/** Search over the rows that are already loaded and opened (sender, subject, snippet). Sealed rows are never matched: their text is not on this page. */
export function matchRow(r: Row, q: string): boolean {
  const n = q.trim().toLowerCase(); if (!n) return true; if (r.gated || r.broken || !r.sum) return false;
  return [r.sum.subject, r.sum.from, r.sum.from_name, r.sum.snippet].some((x) => (x ?? "").toLowerCase().includes(n));
}

/** Two-letter avatar text: first letters of the first two words of the name, else the first two letters of the address. Never empty. */
export function initials(name: string | undefined, addr: string | undefined): string {
  const w = (name ?? "").replace(/[^\p{L}\p{N} ]/gu, " ").split(/\s+/).filter(Boolean);
  const t = w.length >= 2 ? w[0][0] + w[1][0] : w.length === 1 ? w[0].slice(0, 2) : (addr ?? "?").replace(/[^\p{L}\p{N}]/gu, "").slice(0, 2) || "?";
  return t.toUpperCase();
}
/** A stable hue 0..359 from the sender (same sender, same colour, on every screen). */
export function hue(key: string | undefined): number { let h = 7; for (const c of key ?? "") h = (h * 31 + c.codePointAt(0)!) % 360; return h; }

// ================================================================== Q1d: compose + send (pure; the Rust twin is server/founder/src/fmail_mime.rs)

export type Compose = { to: string[]; cc: string[]; bcc: string[]; subject: string; text: string; in_reply_to?: string };
const LABEL = /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/;
/** Same grammar as fmail_mime::norm_addr: dot-atom local part, a host with a dot, no quotes, no comments, no IP literals. Returns the lower-case address or null. */
export function normAddr(a: string): string | null {
  const s = a.trim().toLowerCase(); const at = s.indexOf("@"); if (at < 1 || at !== s.lastIndexOf("@")) return null;
  const l = s.slice(0, at), d = s.slice(at + 1);
  if (l.length > 64 || d.length > 253 || l.startsWith(".") || l.endsWith(".") || l.includes("..") || !/^[a-z0-9._%+-]+$/.test(l)) return null;
  const parts = d.split("."); if (parts.length < 2 || !parts.every((p) => LABEL.test(p))) return null;
  const tld = parts[parts.length - 1]; if (tld.length < 2 || /^[0-9]+$/.test(tld)) return null;
  return s;
}
/** "a@x.com, B@y.org; c@z.net" -> valid, de-duplicated (order kept) and the pieces that are not addresses. */
export function parseAddrs(input: string): { ok: string[]; bad: string[] } {
  const ok: string[] = [], bad: string[] = [];
  for (const piece of input.split(/[\s,;]+/).map((x) => x.replace(/^<|>$/g, "")).filter(Boolean)) { const n = normAddr(piece); if (n) { if (!ok.includes(n)) ok.push(n); } else bad.push(piece); }
  return { ok, bad };
}
/** What the form can know before the server is asked. The server checks all of it again. */
export function composeProblem(c: Compose): string | null {
  if (!c.to.length) return "Add at least one recipient in To.";
  if (new Set([...c.to, ...c.cc, ...c.bcc]).size > 100) return "At most 100 recipients.";
  if (c.subject.length > 300) return "The subject is too long.";
  if (/[\u0000-\u0008\u000a-\u001f\u007f]/.test(c.subject)) return "The subject has a control character.";
  if (!c.subject.trim() && !c.text.trim()) return "An empty mail with no subject is not sent.";
  if (c.text.length > 2 * 1024 * 1024) return "The message is too long.";
  return null;
}
const enc = new TextEncoder();
/** The touch target of a send: SHA-256 over the length-prefixed fields; byte for byte the same as fmail_mime::send_target (golden vector in both test files). */
export async function sendTarget(mailbox: string, c: Compose, schedule: string): Promise<string> {
  const fields = ["fmail-send-v1", mailbox, c.to.join(","), c.cc.join(","), c.bcc.join(","), c.subject.trim(), c.text, schedule];
  const parts: Uint8Array[] = [];
  for (const f of fields) { const b = enc.encode(f); const len = new Uint8Array(8); new DataView(len.buffer).setBigUint64(0, BigInt(b.length)); parts.push(len, b); }
  const all = new Uint8Array(parts.reduce((n, p) => n + p.length, 0)); let o = 0; for (const p of parts) { all.set(p, o); o += p.length; }
  return [...new Uint8Array(await crypto.subtle.digest("SHA-256", all))].map((x) => x.toString(16).padStart(2, "0")).join("");
}
/** Seconds left in the undo window (never negative). */
export const undoLeft = (undoUntilMs: number, nowMs: number): number => Math.max(0, Math.ceil((undoUntilMs - nowMs) / 1000));
/** "Re: " once, never "Re: Re: ". */
export const replySubject = (s: string): string => (/^\s*re:/i.test(s) ? s.trim() : `Re: ${s.trim()}`);
/** A quoted reply body: "On <date>, <who> wrote:" and every line prefixed "> ". */
export function quoteReply(who: string, date: string, text: string): string {
  return `\n\nOn ${date}, ${who} wrote:\n${text.split(/\r?\n/).map((l) => `> ${l}`).join("\n")}`;
}
export const OUTBOX_STATE: Record<string, string> = { queued: "Waiting for the undo window", scheduled: "Scheduled", sending: "Sending…", sent: "Delivered", failed: "Failed - will retry", cancelled: "Cancelled", undone: "Undone" };
