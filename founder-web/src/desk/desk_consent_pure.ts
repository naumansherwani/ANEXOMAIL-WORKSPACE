// ADMIN DESK desk_consent_pure.ts (BL-46 B13 step Z3, 24 Nov 2026): pure logic of the Customer data access screen. No network, no browser. Fail closed: an answer that is not exactly the expected shape is "unavailable".
// Staff see metadata only; customer data opens ONLY after the customer's Company Admin / Security Admin approves, for a short window (metadata 60, headers 30, content 15 minutes). No break-glass, no auto-approval, no self-approval field exists.
export const SCOPES = [["metadata", "Metadata (60 minutes)"], ["headers", "Message headers (30 minutes)"], ["content", "Message content (15 minutes)"]] as const;
export type Scope = (typeof SCOPES)[number][0];
export const REASON_MIN = 20, REASON_MAX = 300;
export const caseRefOk = (c: string) => /^[A-Za-z0-9_.:-]{3,64}$/.test(c.trim());
export function reasonProblem(r: string): string | null {
  const n = [...r.trim()].length;
  if (n < REASON_MIN) return `Write at least ${REASON_MIN} characters: why does this case need a look?`;
  if (n > REASON_MAX) return `Keep the reason under ${REASON_MAX} characters.`;
  if (/[\u0000-\u001f\u007f]/.test(r)) return "The reason cannot have line breaks.";
  return null;
}
export type ConsentBody = { case_ref: string; scope: Scope; reason: string };
export function buildRequest(f: { caseRef: string; scope: Scope; reason: string }): ConsentBody | null {
  const c = f.caseRef.trim(), r = f.reason.trim();
  if (!caseRefOk(c) || !SCOPES.some(([k]) => k === f.scope) || reasonProblem(r) !== null) return null;
  return { case_ref: c, scope: f.scope, reason: r };
}
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function parseRequested(j: unknown): { id: string } | null {
  const x = j as Record<string, unknown> | null;
  return x !== null && typeof x === "object" && typeof x.consent_id === "string" && UUID.test(x.consent_id) && x.status === "requested" ? { id: x.consent_id } : null;
}
export type Row = { id: string; caseRef: string; scope: Scope; status: "requested" | "approved" | "denied" | "revoked" | "expired" | "cancelled"; secondsLeft: number | null };
export type Board = { waiting: number; live: number; mine: Row[] };
const STATUSES = ["requested", "approved", "denied", "revoked", "expired", "cancelled"];
export function parseBoard(j: unknown): Board | null {
  const x = j as Record<string, unknown> | null;
  if (x === null || typeof x !== "object" || !Number.isInteger(x.waiting) || !Number.isInteger(x.live) || !Array.isArray(x.mine) || x.mine.length > 25) return null;
  const mine: Row[] = [];
  for (const r of x.mine as unknown[]) {
    const o = r as Record<string, unknown> | null;
    if (o === null || typeof o !== "object" || typeof o.id !== "string" || !UUID.test(o.id) || typeof o.case !== "string" || !caseRefOk(o.case) || !SCOPES.some(([k]) => k === o.scope) || typeof o.status !== "string" || !STATUSES.includes(o.status)) return null;
    const left = o.seconds_left;
    if (o.status === "approved" ? !(Number.isInteger(left) && (left as number) >= 0) : left !== null && left !== undefined) return null;   // a time exists exactly while approved
    mine.push({ id: o.id, caseRef: o.case, scope: o.scope as Scope, status: o.status as Row["status"], secondsLeft: o.status === "approved" ? (left as number) : null });
  }
  return { waiting: x.waiting as number, live: x.live as number, mine };
}
export function parseOpened(j: unknown): { scope: Scope; secondsLeft: number } | null {
  const x = j as Record<string, unknown> | null;
  return x !== null && typeof x === "object" && SCOPES.some(([k]) => k === x.scope) && Number.isInteger(x.seconds_left) && (x.seconds_left as number) >= 0 ? { scope: x.scope as Scope, secondsLeft: x.seconds_left as number } : null;
}
export function statusWords(s: Row["status"]): string {
  return ({ requested: "Waiting for the customer's Company Admin", approved: "Approved, open now", denied: "The customer said no", revoked: "Closed early", expired: "Time is over", cancelled: "Cancelled" } as const)[s];
}
export function leftWords(sec: number): string { const m = Math.floor(sec / 60), s = sec % 60; return m > 0 ? `${m} min ${String(s).padStart(2, "0")} s left` : `${s} s left`; }

/** AD30: why the Desk refused a request, in plain words. "not_bound" = the case has no company yet (the Desk never guesses a company from free text). */
export function refusalWords(j: unknown): string {
  const e = j !== null && typeof j === "object" ? (j as Record<string, unknown>).error : null;
  return e === "not_bound"
    ? "This case is not tied to a customer company yet, so nothing can be asked. The company has to be confirmed first (a verified domain, or two staff for an exception)."
    : "The Desk did not accept that request. Content of a restricted case never opens, and you can have 5 requests waiting.";
}
