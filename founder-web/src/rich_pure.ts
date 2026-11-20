// QC2 (founder mail): the pure side of the rich compose box. No DOM, no network. Twin of server/founder/src/fmail_rich.rs (the server cleans everything again; this only guides the person).
export const MAX_NAME = 40;
/** A snippet / signature name: lower-case letters, digits, "-" and "_" (the Rust clean_name). Returns null when it is not allowed. */
export function cleanName(n: string): string | null {
  const s = n.trim().replace(/^\/+/, "").toLowerCase();
  return s && s.length <= MAX_NAME && /^[a-z0-9_-]+$/.test(s) ? s : null;
}
const PH = /\{([a-z0-9_]{1,40})\}/g;
/** The {placeholders} of a text, in order of first use, no repeats (Rust placeholders). */
export function placeholders(t: string): string[] { const out: string[] = []; for (const m of t.matchAll(PH)) if (!out.includes(m[1])) out.push(m[1]); return out; }
/** Fill the known variables. Values go in once (a value can never bring a new placeholder in). Returns the text and the placeholders left unfilled (Rust fill). */
export function fill(t: string, vars: Record<string, string>): { text: string; open: string[] } {
  const open: string[] = [];
  const text = t.replace(PH, (whole, n: string) => { const v = vars[n]; if (v) return v; if (!open.includes(n)) open.push(n); return whole; });
  return { text, open };
}
/** The variables the box knows: {first_name} {my_name} {date}. Anything else the person types stays a placeholder and is warned about before sending. */
export function knownVars(o: { toName?: string; myName?: string; now: Date }): Record<string, string> {
  const first = (o.toName ?? "").trim().split(/\s+/)[0] ?? "";
  const d = o.now; const date = `${d.getDate()} ${["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"][d.getMonth()]} ${d.getFullYear()}`;
  return { first_name: first, my_name: o.myName ?? "", date };
}
/** The slash menu: the text typed after "/" at a word start, matched against the snippet names (prefix first, then contains). */
export function slashMatches(typed: string, names: string[], limit = 6): string[] {
  const q = typed.toLowerCase().replace(/^\/+/, ""); const pre = names.filter((n) => n.startsWith(q)); const mid = names.filter((n) => !n.startsWith(q) && q && n.includes(q));
  return [...pre, ...mid].slice(0, limit);
}
/** The signature for a From address: its own, else the mailbox fallback one (fallback = true), else none. Shape = what the server opens (fmail_rich_ep::open_signature). */
export type Sig = { id: string; from: string; text: string; fallback: boolean; version: number };
export function pickSignature<T extends { from?: string | null; fallback?: boolean }>(sigs: T[], from: string): T | null {
  const f = from.trim().toLowerCase(); return sigs.find((s) => (s.from ?? "").toLowerCase() === f && !s.fallback) ?? sigs.find((s) => s.fallback) ?? null;
}
export type Snippet = { id: string; name: string; text: string; used: number; last_used: string | null; version: number; vars: string[] };
const ESC = (s: string) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
/** Signature / snippet plain text -> the HTML the editor inserts: paragraphs split on blank lines, line breaks inside, http(s) links made clickable. Nothing else can come in. */
export function textToHtml(t: string): string {
  const link = (l: string) => ESC(l).replace(/(https:\/\/[^\s<>"]+[^\s<>".,;:!?)\]])/g, (u) => `<a href="${u}">${u}</a>`);
  return t.split(/\n{2,}/).map((p) => `<p>${p.split("\n").map(link).join("<br>")}</p>`).join("");
}
/** True when the editor holds nothing worth sending (only empty paragraphs / spaces). */
export const htmlIsEmpty = (h: string): boolean => !h.replace(/<(?!img\b)[^>]*>/gi, "").replace(/&nbsp;|\s/g, "");
