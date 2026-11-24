// ADMIN DESK 1m-L (card Ledger), 24 Nov 2026. Pure parsing of the one read-only door /desk/v1/ledger/board (SQL AD27). Fail-closed: anything that is not exactly the agreed shape = null = "Data unavailable".
// Kind, role and time only (never the detail of a line, an e-mail or a name). A broken chain is SHOWN, never hidden; a probe that never ran is words, never a guess.
export const ROLES = ["owner", "agent", "system", "unknown"] as const;
export type Role = (typeof ROLES)[number];
export type Line = { seq: number; at: string; kind: string; role: Role };
export type Board = {
  generated_at: string; lines: number; newest_seq: number | null; newest_at: string | null; window_lines: number; chain_ok: boolean;
  probe: { ok: boolean | null; at: string | null }; tail: Line[]; kinds: { kind: string; n: number }[];
};
export const NOT_YOURS = "This is for people who may see staff and security detail (owners and admins).";
const nat = (x: unknown): x is number => typeof x === "number" && Number.isInteger(x) && x >= 0;
const rec = (x: unknown): Record<string, unknown> | null => (x && typeof x === "object" && !Array.isArray(x) ? (x as Record<string, unknown>) : null);
const hasKeys = (o: Record<string, unknown>, keys: readonly string[]) => Object.keys(o).length === keys.length && keys.every((k) => k in o);
const stamp = (x: unknown): x is string => typeof x === "string" && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(x);
const kind = (x: unknown): x is string => typeof x === "string" && x.length >= 1 && x.length <= 60 && /^[a-z0-9._-]+$/.test(x);
export function parseBoard(j: unknown): Board | null {
  const o = rec(j); if (!o || !hasKeys(o, ["generated_at", "lines", "newest_seq", "newest_at", "window_lines", "chain_ok", "probe", "tail", "kinds_24h"])) return null;
  if (!stamp(o.generated_at) || typeof o.chain_ok !== "boolean" || !nat(o.lines) || !nat(o.window_lines) || o.window_lines > o.lines || o.window_lines > 2000) return null;
  const pr = rec(o.probe); if (!pr || !hasKeys(pr, ["ok", "at"])) return null;
  if ((pr.ok === null) !== (pr.at === null) || (pr.ok !== null && (typeof pr.ok !== "boolean" || !stamp(pr.at)))) return null;
  if (!Array.isArray(o.tail) || !Array.isArray(o.kinds_24h) || o.kinds_24h.length > 8) return null;
  if (o.lines === 0) return o.newest_seq === null && o.newest_at === null && o.tail.length === 0 ? { generated_at: o.generated_at, lines: 0, newest_seq: null, newest_at: null, window_lines: 0, chain_ok: o.chain_ok, probe: { ok: pr.ok as boolean | null, at: pr.at as string | null }, tail: [], kinds: [] } : null;
  if (!nat(o.newest_seq) || o.newest_seq < o.lines || !stamp(o.newest_at) || o.tail.length < 1 || o.tail.length > 20 || o.tail.length > o.lines) return null;
  const tail: Line[] = []; let last = Number.MAX_SAFE_INTEGER;
  for (let i = 0; i < o.tail.length; i++) {
    const l = rec(o.tail[i]); if (!l || !hasKeys(l, ["seq", "at", "kind", "role"])) return null;
    if (!nat(l.seq) || l.seq >= last || l.seq > o.newest_seq || (i === 0 && l.seq !== o.newest_seq) || !stamp(l.at) || !kind(l.kind) || !ROLES.includes(l.role as Role)) return null;
    last = l.seq; tail.push({ seq: l.seq, at: l.at, kind: l.kind, role: l.role as Role });
  }
  const kinds: { kind: string; n: number }[] = []; let prev = Number.MAX_SAFE_INTEGER;
  for (const k of o.kinds_24h) {
    const r = rec(k); if (!r || !hasKeys(r, ["kind", "n"]) || !kind(r.kind) || !nat(r.n) || r.n < 1 || r.n > prev) return null;
    prev = r.n; kinds.push({ kind: r.kind, n: r.n });
  }
  return { generated_at: o.generated_at, lines: o.lines, newest_seq: o.newest_seq, newest_at: o.newest_at as string, window_lines: o.window_lines, chain_ok: o.chain_ok, probe: { ok: pr.ok as boolean | null, at: pr.at as string | null }, tail, kinds };
}
export const ROLE_WORDS: Record<Role, string> = { owner: "an owner", agent: "an agent", system: "the Desk itself", unknown: "an account that no longer exists" };
/** The headline: plain words for every employee. A broken chain is the loudest sentence the card can say. */
export function chainWords(b: Board): { level: "ok" | "outage"; text: string } {
  if (!b.chain_ok) return { level: "outage", text: "The ledger chain does NOT verify. A line was changed after it was written. Tell an owner now." };
  if (b.lines === 0) return { level: "ok", text: "The ledger is empty. Nothing has been written yet." };
  return { level: "ok", text: `The ledger chain verifies: the newest ${b.window_lines} line${b.window_lines === 1 ? "" : "s"} each match their hash and the line before.` };
}
export function probeWords(b: Board): string {
  if (b.probe.ok === null) return "The whole-chain check has not run yet.";
  return b.probe.ok ? `The whole chain, from the first line, was checked OK at ${b.probe.at}.` : `The whole-chain check FAILED at ${b.probe.at}.`;
}
export const kindWords = (k: string) => k.replace(/[._-]+/g, " ");
export const NOTE = "Each line shows what happened, when, and by which kind of account. The private detail of a line is never shown here.";
