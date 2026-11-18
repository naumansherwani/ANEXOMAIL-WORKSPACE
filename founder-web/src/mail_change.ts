// QLIVE (18 Nov 2026): LIVE MAIL WITHOUT A REFRESH, the pure part. No DOM, no React, no network: bun-tested (mail_change.test.ts).
// Marker for the technology gate Q-live: mail_live_push (the push is a PROMPT; the truth is the cursor door /founder/v1/mail/changes, so a lost or merged frame costs nothing: JMAP RFC 8620 / IMAP NOTIFY RFC 5465).
// The server pushes a signed `tick` that carries `mail: {box, head}`; the kernel has verified it before this file sees it. Everything below decides WHAT TO DO with it.
export const MAIL_LIVE = "mail_live_push";

/** Kinds the E187 change log writes (closed list, the SQL check constraint is the same). */
export const KINDS = ["arrive", "sent", "draft", "expunge", "read", "unread", "star", "unstar", "move", "label", "unlabel", "outbox", "scan", "verdict"] as const;
export type Kind = (typeof KINDS)[number];
export type Change = { seq: number; kind: Kind; folder: string | null; message: string | null; thread: string | null; at: string };
export type Answer = { ok: true; head: number; floor: number; gap: boolean; more: boolean; changes: Change[]; summary: Partial<Record<Kind, number>> } | { ok: false };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** The `mail` part of a verified tick, or null. Strict: anything that is not {box: uuid, head: whole number >= 0} is ignored (never guessed). */
export function mailPart(p: unknown): { box: string; head: number } | null {
  const m = (p as { mail?: { box?: unknown; head?: unknown } } | null)?.mail;
  if (!m || typeof m.box !== "string" || !UUID.test(m.box)) return null;
  const h = m.head;
  return typeof h === "number" && Number.isSafeInteger(h) && h >= 0 ? { box: m.box.toLowerCase(), head: h } : null;
}

/** The door answer, checked. A wrong shape is `{ok:false}` (the caller then does a normal full read). */
export function readAnswer(d: unknown): Answer {
  const a = d as Record<string, unknown> | null;
  if (!a || a.ok !== true || !Number.isSafeInteger(a.head) || !Number.isSafeInteger(a.floor) || typeof a.gap !== "boolean" || typeof a.more !== "boolean" || !Array.isArray(a.changes)) return { ok: false };
  const kinds = new Set<string>(KINDS), changes: Change[] = [];
  for (const c of a.changes as Record<string, unknown>[]) {
    if (!c || !Number.isSafeInteger(c.seq) || typeof c.kind !== "string" || !kinds.has(c.kind)) return { ok: false };
    changes.push({ seq: c.seq as number, kind: c.kind as Kind, folder: typeof c.folder === "string" ? c.folder : null, message: typeof c.message === "string" ? c.message : null, thread: typeof c.thread === "string" ? c.thread : null, at: String(c.at ?? "") });
  }
  for (let i = 1; i < changes.length; i++) if (changes[i].seq !== changes[i - 1].seq + 1) return { ok: false }; // a hole inside one answer is never trusted
  const sum: Partial<Record<Kind, number>> = {};
  for (const c of changes) sum[c.kind] = (sum[c.kind] ?? 0) + 1;
  return { ok: true, head: a.head as number, floor: a.floor as number, gap: a.gap as boolean, more: a.more as boolean, changes, summary: sum };
}

/** What a ping means for the cursor: nothing (we already have it), or fetch. A head BELOW the cursor means the log was reset: fetch (the door answers `gap`). */
export const shouldFetch = (cursor: number | null, head: number): boolean => cursor === null || head !== cursor;

export type Step = { cursor: number | null; refresh: boolean; full: boolean; more: boolean; arrived: number; kinds: Partial<Record<Kind, number>> };
/** One catch-up step. gap = full refresh and the cursor jumps to the head. Otherwise the cursor moves to the last change seen; any change refreshes the screen. The first changes must start right after the cursor (else full refresh). */
export function step(cursor: number | null, a: Answer): Step {
  if (!a.ok) return { cursor, refresh: true, full: true, more: false, arrived: 0, kinds: {} };
  if (a.gap || cursor === null) return { cursor: a.head, refresh: true, full: true, more: false, arrived: 0, kinds: {} };
  if (a.changes.length && a.changes[0].seq !== cursor + 1) return { cursor: a.head, refresh: true, full: true, more: false, arrived: 0, kinds: {} };
  const last = a.changes.length ? a.changes[a.changes.length - 1].seq : cursor;
  return { cursor: last, refresh: a.changes.length > 0, full: false, more: a.more && a.changes.length > 0, arrived: a.summary.arrive ?? 0, kinds: a.summary };
}

/** Does this burst change what the LIST shows? (everything except a pure verdict / scan update changes a row or a count; those two only change the trust ring and are still worth one refresh). */
export const touchesList = (k: Partial<Record<Kind, number>>): boolean => KINDS.some((x) => (k[x] ?? 0) > 0);

/** How often to read while the push is (not) working: 30 s safety while the stream is live, 5 s honest fallback otherwise. */
export const pollMs = (streamLive: boolean): number => (streamLive ? 30_000 : 5_000);

/** One refresh for a burst: calls `fn` once, `ms` after the LAST call. Timer functions are injectable (tests). */
export function coalesce(fn: () => void, ms: number, setT: (f: () => void, ms: number) => unknown = (f, m) => setTimeout(f, m), clearT: (h: unknown) => void = (h) => clearTimeout(h as ReturnType<typeof setTimeout>)) {
  let h: unknown = null;
  return { poke() { if (h !== null) clearT(h); h = setT(() => { h = null; fn(); }, ms); }, cancel() { if (h !== null) { clearT(h); h = null; } } };
}

/** Tab title with the unread count, like a mail client: "(3) Mail". */
export const titleWith = (base: string, unread: number): string => (unread > 0 ? `(${unread > 99 ? "99+" : unread}) ${base}` : base);
