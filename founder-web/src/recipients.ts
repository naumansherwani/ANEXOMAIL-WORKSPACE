// QC1a (18 Nov 2026): the ONE address grammar of the compose form. Pure: no DOM, no React, bun-tested (recipients.test.ts).
// It stands on `normAddr` (mail_pure.ts), which has the same grammar as the Rust server's fmail_mime::norm_addr, so a chip the form accepts is never refused by the server for its shape.
// On top of that it adds what a person types and pastes: RFC 5322 style lists ("Name <a@b.com>", quoted names with commas, bare <a@b.com>, ; , space newline),
// internationalised domains (a Unicode domain becomes punycode through the browser's own URL parser, no dependency), and a plain-language REASON for every refusal.
import { normAddr } from "./mail_pure";

export type Field = "To" | "Cc" | "Bcc";
/** One thing the person typed. `addr` is the lower-case ASCII address when it is valid, null when it is not (then `reason` says why). `raw` is what is kept in the form string. */
export type Chip = { raw: string; addr: string | null; name: string; reason: string };

const CTRL = /[\u0000-\u001f\u007f​-‏‪-‮⁦-⁩]/g; // control + zero-width + bidi override characters never enter a chip or a name (spoofing)
const NAME_BAD = /["<>\\]/g;

/** A Unicode domain -> its ASCII (punycode) form with the browser's own URL parser. Returns null when the domain cannot be a host name. */
export function asciiDomain(domain: string): string | null {
  const d = domain.trim().replace(/\.$/, "");
  if (!d) return null;
  if (/^[\x00-\x7f]*$/.test(d)) return d.toLowerCase();
  try { const h = new URL("http://" + d).hostname; return h && /^[\x00-\x7f]+$/.test(h) ? h.toLowerCase() : null; } catch { return null; }
}

/** The address as the server will see it (lower-case ASCII), or null. Accepts an internationalised domain, refuses a non-ASCII local part (needs SMTPUTF8, which the sender does not offer). */
export function cleanAddr(piece: string): string | null {
  const s = piece.replace(CTRL, "").trim(); const at = s.lastIndexOf("@");
  if (at < 1 || at !== s.indexOf("@")) return normAddr(s);
  const dom = asciiDomain(s.slice(at + 1)); if (!dom) return null;
  return normAddr(s.slice(0, at) + "@" + dom);
}

/** WHY a piece is not an address, in words a person understands. Only called when cleanAddr said no. */
export function explain(piece: string): string {
  const s = piece.replace(CTRL, "").trim();
  if (!s) return "Empty";
  if (/["]/.test(s)) return "Quoted addresses are not accepted";
  if (/\[|\]/.test(s)) return "An IP address instead of a domain is not accepted";
  const ats = s.split("@").length - 1;
  if (ats === 0) return "Missing @";
  if (ats > 1) return "More than one @";
  const at = s.indexOf("@"), local = s.slice(0, at), dom = s.slice(at + 1);
  if (!local) return "Nothing before the @";
  if (!dom) return "Nothing after the @";
  if (local.length > 64) return "The part before the @ is too long (64 at most)";
  if (/[^\x00-\x7f]/.test(local)) return "Letters outside English before the @ are not supported yet";
  if (local.startsWith(".") || local.endsWith(".") || local.includes("..")) return "A dot cannot start, end or double up before the @";
  if (!/^[a-zA-Z0-9._%+-]+$/.test(local)) return "A space or special character is not allowed before the @";
  const ascii = asciiDomain(dom);
  if (!ascii) return "The domain is not valid";
  if (ascii.length > 253) return "The domain is too long";
  if (!ascii.includes(".")) return "The domain needs a dot, like example.com";
  const parts = ascii.split(".");
  if (parts.some((p) => p === "")) return "The domain has an empty part";
  if (parts.some((p) => p.startsWith("-") || p.endsWith("-"))) return "A domain part cannot start or end with a dash";
  if (parts.some((p) => !/^[a-z0-9-]{1,63}$/.test(p))) return "The domain has a character that is not allowed";
  const tld = parts[parts.length - 1];
  if (tld.length < 2 || /^[0-9]+$/.test(tld)) return "The ending after the last dot is not valid";
  return "Not a valid address";
}

/** A display name made safe: no control, no quote, no angle bracket, no backslash, collapsed spaces, 120 characters at most. */
export function cleanName(name: string): string { return name.replace(/[\u200b-\u200f\u202a-\u202e\u2066-\u2069]/g, "").replace(CTRL, " ").replace(NAME_BAD, "").replace(/\s+/g, " ").trim().slice(0, 120); }

/** Split a typed or pasted text into pieces. Separators are , ; and a new line OUTSIDE quotes and angle brackets, so "Doe, John" <j@x.com> stays ONE piece.
 *  A piece with spaces and no angle brackets ("a@x.com b@y.org") is split again at the spaces. */
export function pieces(input: string): string[] {
  const segs: string[] = []; let cur = "", q = false, ang = false;
  for (const ch of input) {
    if (ch === '"' && !ang) q = !q; else if (ch === "<" && !q) ang = true; else if (ch === ">" && !q) ang = false;
    if (!q && !ang && (ch === "," || ch === ";" || ch === "\n" || ch === "\r")) { segs.push(cur); cur = ""; continue; }
    cur += ch;
  }
  segs.push(cur);
  const out: string[] = [];
  for (const raw of segs) {
    const s = raw.trim(); if (!s) continue;
    if (/<[^<>]*>\s*$/.test(s) || !/\s/.test(s)) { out.push(s); continue; }
    for (const w of s.split(/\s+/)) if (w) out.push(w); // "a@x.com <c@z.net> nope" -> a@x.com, <c@z.net>, nope
  }
  return out;
}

/** One piece -> one chip. */
export function chipOf(piece: string): Chip {
  const s = piece.trim();
  const m = /^(.*?)<([^<>]*)>\s*$/.exec(s);
  if (m) {
    const nameRaw = m[1].trim().replace(/^"(.*)"$/, "$1"), inner = m[2].trim(), addr = cleanAddr(inner);
    if (addr) {
      const asAddr = cleanAddr(nameRaw);                      // "a@x.com <c@z.net>": the "name" is itself an address -> keep the angle one, the other is split by `pieces`
      const name = asAddr ? "" : cleanName(nameRaw);
      return { raw: join1(name, addr), addr, name, reason: "" };
    }
    return { raw: s, addr: null, name: "", reason: explain(inner) };
  }
  const bare = s.replace(/^<|>$/g, ""); const addr = cleanAddr(bare);
  if (addr) return { raw: addr, addr, name: "", reason: "" };
  return { raw: s.replace(CTRL, ""), addr: null, name: "", reason: explain(bare) };
}
function join1(name: string, addr: string): string { return name ? (/[,;"<>@]/.test(name) ? `"${name}" <${addr}>` : `${name} <${addr}>`) : addr; }

/** The form string -> chips. */
export function chipsOf(value: string): Chip[] { return pieces(value).map(chipOf); }
/** Chips -> the form string (", " between chips, names quoted when they need it). */
export function joinChips(chips: Chip[]): string { return chips.map((c) => c.raw).join(", "); }

/** Add typed or pasted text to a field. `taken` = every address already in To / Cc / Bcc (address -> field name). Returns the new chips and what was refused (shown, said aloud, never silent). */
export function addText(existing: Chip[], text: string, field: Field, taken: Record<string, Field>): { chips: Chip[]; added: Chip[]; skipped: { piece: string; reason: string }[] } {
  const chips = [...existing], added: Chip[] = [], skipped: { piece: string; reason: string }[] = [];
  const seen = new Set(chips.filter((c) => c.addr).map((c) => c.addr as string));
  for (const p of pieces(text)) {
    const c = chipOf(p);
    if (c.addr) {
      if (seen.has(c.addr)) { skipped.push({ piece: c.addr, reason: `Already in ${field}` }); continue; }
      const other = taken[c.addr]; if (other && other !== field) { skipped.push({ piece: c.addr, reason: `Already in ${other}` }); continue; }
      seen.add(c.addr);
    }
    chips.push(c); added.push(c);
  }
  return { chips, added, skipped };
}

/** Remove the chip with this address (or this raw text when it is not valid). */
export function removeChip(chips: Chip[], key: string): Chip[] { return chips.filter((c) => (c.addr ?? c.raw) !== key); }
/** What to show on a chip: the name when there is one, else the address, else the raw text. */
export function label(c: Chip): string { return c.name || c.addr || c.raw; }
/** Does this typed text look like a COMPLETE address (so a space can end the chip)? */
export function looksComplete(text: string): boolean { const t = text.trim(); return !!t && !/[<"]/.test(t) && cleanAddr(t) !== null; }
/** The addresses of all three fields, for the cross-field duplicate check. */
export function takenMap(v: { To: string; Cc: string; Bcc: string }): Record<string, Field> {
  const m: Record<string, Field> = {};
  for (const f of ["To", "Cc", "Bcc"] as Field[]) for (const c of chipsOf(v[f])) if (c.addr && !m[c.addr]) m[c.addr] = f;
  return m;
}
/** Two letters or one for the avatar dot. */
export function initial(c: Chip): string { const s = label(c).replace(/[^\p{L}\p{N}]/gu, ""); return (s[0] ?? "?").toUpperCase(); }

/** What the send door and the draft need: the valid, de-duplicated ASCII addresses (order kept) and the pieces that are not addresses (they block Send). Drop-in for mail_pure.parseAddrs, but it understands "Name <a@b.com>". */
export function parseAddrs(input: string): { ok: string[]; bad: string[] } {
  const ok: string[] = [], bad: string[] = [];
  for (const c of chipsOf(input)) { if (c.addr) { if (!ok.includes(c.addr)) ok.push(c.addr); } else bad.push(c.raw); }
  return { ok, bad };
}
