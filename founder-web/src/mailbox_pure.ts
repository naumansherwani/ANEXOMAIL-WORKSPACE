// QUI-LIVE (founder mailbox UI, the living look): the pure part. No fetch, no DOM, nothing invented.
// Search ("ask your mail"), the quick filters and the small decisions of the new Mail screen live here and are tested (mailbox_pure.test.ts).
// INHERITABLE BY AWAM (AWAM-INHERITS law): no founder names inside.
import { type Row } from "./mail_pure";

export type Query = { words: string[]; from: string[]; to: string[]; subject: string[]; unread: boolean; read: boolean; starred: boolean; file: boolean; thread: boolean };

/** "from:bilal is:unread has:file agreement" -> a structured query. Unknown "key:value" tokens stay plain words, so nothing a person types is silently dropped. */
export function parseQuery(input: string): Query {
  const q: Query = { words: [], from: [], to: [], subject: [], unread: false, read: false, starred: false, file: false, thread: false };
  const tokens = input.match(/"[^"]*"|\S+/g) ?? [];
  for (const raw of tokens) {
    const t = raw.replace(/^"|"$/g, "").trim(); if (!t) continue;
    const low = t.toLowerCase();
    if (low === "is:unread") q.unread = true;
    else if (low === "is:read") q.read = true;
    else if (low === "is:starred" || low === "is:flagged") q.starred = true;
    else if (low === "has:file" || low === "has:attachment" || low === "has:attachments") q.file = true;
    else if (low === "is:thread") q.thread = true;
    else if (/^from:./.test(low)) q.from.push(low.slice(5));
    else if (/^to:./.test(low)) q.to.push(low.slice(3));
    else if (/^subject:./.test(low)) q.subject.push(low.slice(8));
    else q.words.push(low);
  }
  return q;
}
export const isEmptyQuery = (q: Query): boolean => !q.words.length && !q.from.length && !q.to.length && !q.subject.length && !q.unread && !q.read && !q.starred && !q.file && !q.thread;

/** Does a loaded row satisfy the query? Sealed (gated / broken) rows are never matched on text, because their text is not on this page; flags still apply to them. */
export function matchQuery(r: Row, q: Query): boolean {
  if (isEmptyQuery(q)) return true;
  if (q.unread && r.read) return false;
  if (q.read && !r.read) return false;
  if (q.starred && !r.starred) return false;
  if (q.file && !(r.attach > 0)) return false;
  if (q.thread && !(r.thread_count > 1)) return false;
  const textual = q.words.length || q.from.length || q.to.length || q.subject.length;
  if (!textual) return true;
  if (r.gated || r.broken || !r.sum) return false;
  const s = r.sum, has = (hay: (string | undefined)[], n: string) => hay.some((x) => (x ?? "").toLowerCase().includes(n));
  if (!q.from.every((n) => has([s.from, s.from_name], n))) return false;
  if (!q.to.every((n) => has([...(s.to ?? []), ...(s.cc ?? [])], n))) return false;
  if (!q.subject.every((n) => has([s.subject], n))) return false;
  return q.words.every((n) => has([s.subject, s.from, s.from_name, s.snippet], n));
}

/** One plain sentence that says how the search was understood ("Showing mail unread, with a file, from bilal"). */
export function describeQuery(q: Query): string {
  if (isEmptyQuery(q)) return "";
  const p: string[] = [];
  if (q.unread) p.push("unread"); if (q.read) p.push("already read"); if (q.starred) p.push("starred"); if (q.thread) p.push("in a thread");
  const out: string[] = []; if (p.length) out.push(p.join(", "));
  if (q.file) out.push("with a file");
  if (q.from.length) out.push(`from ${q.from.join(" or ")}`);
  if (q.to.length) out.push(`to ${q.to.join(" or ")}`);
  if (q.subject.length) out.push(`subject has ${q.subject.join(", ")}`);
  if (q.words.length) out.push(`matching "${q.words.join(" ")}"`);
  return `Showing mail ${out.join(", ")}`;
}

/** Suggestions under the search box (only things that can actually match what is loaded). */
export function suggest(rows: Row[], input: string): string[] {
  const last = (input.match(/\S+$/)?.[0] ?? "").toLowerCase();
  const base = ["is:unread", "has:file", "is:starred", "is:thread"];
  const senders = [...new Set(rows.filter((r) => !r.gated && !r.broken && r.sum).map((r) => (r.sum!.from_name || r.sum!.from || "").split(/[ @<]/)[0].toLowerCase()).filter((x) => x.length > 1))].slice(0, 4).map((x) => `from:${x}`);
  const all = [...base, ...senders];
  const pick = last ? all.filter((x) => x.startsWith(last) && x !== last) : all;
  return pick.slice(0, 6);
}

/** A newly arrived row: the ones that were not in the list before this refresh and are unread. Order = newest first. Never more than `max`. */
export function freshRows(before: Row[], after: Row[], max = 3): Row[] {
  const had = new Set(before.map((r) => r.id));
  return after.filter((r) => !had.has(r.id) && !r.read && r.direction === "in").slice(0, max);
}
/** The text of the arrival pill: who and what, or the honest plain words for a sealed row (no content leaks). */
export function arrivalLine(r: Row): { who: string; what: string } {
  if (r.gated) return { who: r.folder === "quarantine" ? "Quarantined message" : "Confidential thread", what: "needs your key to open" };
  if (r.broken || !r.sum) return { who: "A message arrived", what: "it does not verify and is kept, not shown" };
  return { who: r.sum.from_name || r.sum.from || "Unknown sender", what: r.sum.subject || "(no subject)" };
}

/** The Mail speed box: the median of the whole mail stage as seconds text, or null when the server has no measurement (never a made-up number). */
export function speedWords(total: { p50: number | null; n: number } | undefined | null): { value: string; unit: string; note: string } | null {
  if (!total || total.p50 === null || !Number.isFinite(total.p50) || total.p50 < 0 || total.n < 1) return null;
  const v = total.p50;
  const value = v < 1000 ? String(Math.max(1, Math.round(v))) : (v / 1000).toFixed(v < 10_000 ? 1 : 0).replace(/\.0$/, "");
  return { value, unit: v < 1000 ? "ms median" : "s median", note: `from ${total.n} real mail${total.n === 1 ? "" : "s"}` };
}

/** Which of the three layouts applies, by width. Only used for the one decision that cannot be done in CSS alone (the bottom bar owns the keyboard shortcut hints). */
export const layoutFor = (w: number): "phone" | "tablet" | "desktop" => (w <= 760 ? "phone" : w <= 1000 ? "tablet" : "desktop");
