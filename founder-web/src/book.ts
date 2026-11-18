// QC1b (18 Nov 2026): the browser side of the sealed address book. Pure: no DOM, no React, bun-tested (book.test.ts).
// The server opens the top 500 (fmail_book.rs) and sends them over the signed channel; THIS file filters and ranks them while the founder types, so typing makes ZERO server calls
// (research: a blind index can not do prefix search; big mail clients filter a cached list in the client, debounce about 150 ms, show after 2 characters, dedupe by address, 5 to 8 rows).
// score() mirrors E186 fmail_contact_score186 bit for bit (ln(1 + 3*sent + recv) * 2^(-days/45), pinned +1e9); book.test.ts holds the same hand-calculated numbers as the SQL selftest.
// Gate marker Q-contacts-kernel: kernel_contacts_filter (the same filter + frecency also runs in the Rust WASM kernel, module contacts@1; this file is its TypeScript twin and the fallback)
export const KERNEL_CONTACTS = "kernel_contacts_filter";
export type Contact = { id: string; addr: string; name: string; sent: number; recv: number; last_sent: string | null; last_recv: string | null; pinned: boolean; score?: number | null };
export type Hit = { c: Contact; why: "name" | "address" | "domain"; score: number };

export const MIN_CHARS = 2, MAX_ROWS = 8, DEBOUNCE_MS = 150, HALF_LIFE_DAYS = 45;

/** Frecency, identical to the SQL function. `now` in ms. */
export function score(c: Pick<Contact, "sent" | "recv" | "last_sent" | "last_recv" | "pinned">, now: number): number {
  const ts = [c.last_sent, c.last_recv].map((t) => (t ? Date.parse(t) : NaN)).filter((n) => Number.isFinite(n));
  const last = ts.length ? Math.max(...ts) : now;
  const days = Math.max(0, now - last) / 86_400_000;
  return (c.pinned ? 1e9 : 0) + Math.log(1 + 3 * Math.max(c.sent, 0) + Math.max(c.recv, 0)) * Math.pow(2, -days / HALF_LIFE_DAYS);
}

/** Lower-case, accents folded, so "zoya" finds "Zoyá" and "ALI" finds "ali". */
export function fold(s: string): string { return s.normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase(); }

/** What the founder typed, reduced to the part that is searched: the text after the last separator, "Name <" and quotes removed. */
export function needle(typed: string): string { return fold(typed.replace(/^[\s"<]+/, "").replace(/[>"]+$/, "")).trim(); }

/** Prefix match on the START of the name, of any word of the name, of the address, or of the domain. Returns the best reason or null. */
export function matches(c: Contact, q: string): Hit["why"] | null {
  if (!q) return null;
  const name = fold(c.name), addr = fold(c.addr), at = addr.indexOf("@"), dom = at >= 0 ? addr.slice(at + 1) : "";
  if (name.split(/[\s.,_-]+/).some((w) => w && w.startsWith(q)) || name.startsWith(q)) return "name";
  if (addr.startsWith(q) || (at > 0 && addr.slice(0, at).split(/[._+%-]+/).some((w) => w.startsWith(q)))) return "address";
  if (q.includes("@") ? addr.startsWith(q) : dom.startsWith(q)) return "domain";
  return null;
}

/** The suggestions for what is typed: needs MIN_CHARS characters, skips addresses already in a row (`taken`, lower-case), ranks by frecency (a name match beats a domain match at equal rank), caps at MAX_ROWS. */
export function suggest(contacts: Contact[], typed: string, taken: ReadonlySet<string> | Record<string, unknown>, now: number, max = MAX_ROWS): Hit[] {
  const q = needle(typed);
  if (q.length < MIN_CHARS) return [];
  const has = (a: string) => (taken instanceof Set ? taken.has(a) : Object.prototype.hasOwnProperty.call(taken, a));
  const rank = { name: 0.02, address: 0.01, domain: 0 } as const;
  const hits: Hit[] = [];
  for (const c of contacts) {
    if (has(c.addr)) continue;
    const why = matches(c, q);
    if (why) hits.push({ c, why, score: score(c, now) + rank[why] });
  }
  hits.sort((a, b) => b.score - a.score || (a.c.addr < b.c.addr ? -1 : a.c.addr > b.c.addr ? 1 : 0)); // plain code-unit order, the same as the kernel's (contacts@1): a tie can never be ordered differently on the two sides
  return hits.slice(0, Math.max(1, max));
}

/** "Name <a@b.com>" when the contact has a name, else the address: what a chosen suggestion becomes in the row string. */
export function asChipText(c: Pick<Contact, "addr" | "name">): string {
  const n = c.name.replace(/["<>\\]/g, "").trim();
  return n ? (/[,;@]/.test(n) ? `"${n}" <${c.addr}>` : `${n} <${c.addr}>`) : c.addr;
}

// ---------------------------------------------------------------- Q-contacts-kernel (18 Nov 2026): the same filter + rank, run in the Rust WASM kernel (contacts@1).
/** The kernel input: every contact reduced to numbers (the later of last_sent / last_recv as ms, so the kernel never parses a date). */
export function kernelInput(contacts: Contact[], typed: string, taken: ReadonlySet<string> | Record<string, unknown>, now: number, max = MAX_ROWS) {
  const ms = (c: Contact) => { const t = [c.last_sent, c.last_recv].map((x) => (x ? Date.parse(x) : NaN)).filter((n) => Number.isFinite(n)); return t.length ? Math.max(...t) : null; };
  const tk = taken instanceof Set ? [...taken] : Object.keys(taken);
  return { q: typed, taken: tk, now, max, c: contacts.map((c) => ({ a: c.addr, n: c.name, s: c.sent, r: c.recv, l: ms(c), p: c.pinned })) };
}
/** The kernel answer turned back into Hit[] (same shape `suggest` returns). A wrong shape or an index out of range = undefined, and the caller uses `suggest` (the TypeScript twin). */
export function hitsFromKernel(contacts: Contact[], answer: unknown): Hit[] | undefined {
  const a = answer as { ok?: unknown; hits?: unknown } | null;
  if (!a || a.ok !== true || !Array.isArray(a.hits)) return undefined;
  const out: Hit[] = [];
  for (const h of a.hits as { i?: unknown; why?: unknown; score?: unknown }[]) {
    if (!Number.isInteger(h?.i) || (h.i as number) < 0 || (h.i as number) >= contacts.length || (h.why !== "name" && h.why !== "address" && h.why !== "domain") || typeof h.score !== "number") return undefined;
    out.push({ c: contacts[h.i as number], why: h.why, score: h.score });
  }
  return out;
}
