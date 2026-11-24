// ADMIN DESK desk_bind_pure.ts (BL-46 B13 step T4c, 25 Nov 2026): pure logic of the "Company confirmation" screen (manual company exception with a second reviewer). No network, no browser.
// Fail closed: an answer that is not exactly the expected shape is "not available", an unknown outcome word is a plain refusal. Plan: D6-B13-T4-MANUAL-EXCEPTION-PLAN-25NOV.md; Rust doors: bind_exception.rs; SQL: AD34.
// T4e (25 Nov 2026): the company NAME comes from the Control Plane through the Rust door (tenant_name + name_state ok|missing|unavailable); the screen never invents a name: when the Control Plane did not answer it says so.
// The reviewer sees ONLY: case ref, company UUID, company name, the reason words, the proposer's short note, the proposer's role and the time left. Never customer data or mail text.
export const REASONS = [
  ["customer_emailed_from_other_domain", "The customer wrote from a different domain"],
  ["new_domain_not_yet_verified", "The customer's new domain is not verified yet"],
  ["forwarded_mail", "The mail was forwarded"],
  ["staff_checked_contract", "Staff checked the contract"],
  ["other_with_note", "Another reason (write a note)"],
] as const;
export type Reason = (typeof REASONS)[number][0];
export const NOTE_MAX = 200, NOTE_MIN_OTHER = 10;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const caseRefOk = (c: string) => /^[A-Za-z0-9_.:-]{3,64}$/.test(c.trim());
export const tenantOk = (t: string) => UUID.test(t.trim()) && !/^[0-]+$/.test(t.trim());
export function noteProblem(reason: string, note: string): string | null {
  const n = [...note.trim()].length;
  if (/[\u0000-\u001f\u007f]/.test(note)) return "The note cannot have line breaks.";
  if (n > NOTE_MAX) return `Keep the note under ${NOTE_MAX} characters.`;
  if (reason === "other_with_note" && n < NOTE_MIN_OTHER) return `Write at least ${NOTE_MIN_OTHER} characters so the second person can understand.`;
  return null;
}
export type ProposeBody = { case_ref: string; tenant_id: string; reason: Reason; note: string };
export function buildPropose(f: { caseRef: string; tenantId: string; reason: string; note: string }): ProposeBody | null {
  const c = f.caseRef.trim(), t = f.tenantId.trim().toLowerCase(), n = f.note.trim();
  if (!caseRefOk(c) || !tenantOk(t) || !REASONS.some(([k]) => k === f.reason) || noteProblem(f.reason, n) !== null) return null;
  return { case_ref: c, tenant_id: t, reason: f.reason as Reason, note: n };
}
export function buildDecide(proposalId: string, approve: boolean): { proposal_id: string; approve: boolean } | null { return UUID.test(proposalId) ? { proposal_id: proposalId, approve } : null; }

export type NameState = "ok" | "missing" | "unavailable";
export type Pending = { id: string; caseRef: string; tenantId: string; tenantName: string | null; nameState: NameState; reason: Reason; note: string; proposerRole: string; secondsLeft: number; mine: boolean };
export function parsePending(j: unknown): Pending[] | null {
  const x = j as Record<string, unknown> | null;
  if (x === null || typeof x !== "object" || !Array.isArray(x.items) || x.items.length > 100) return null;
  const out: Pending[] = [];
  for (const r of x.items as unknown[]) {
    const o = r as Record<string, unknown> | null;
    if (o === null || typeof o !== "object" || typeof o.proposal_id !== "string" || !UUID.test(o.proposal_id) || typeof o.case_ref !== "string" || !caseRefOk(o.case_ref)
      || typeof o.tenant_id !== "string" || !UUID.test(o.tenant_id) || !REASONS.some(([k]) => k === o.reason) || typeof o.note !== "string" || [...o.note].length > NOTE_MAX
      || (o.name_state !== "ok" && o.name_state !== "missing" && o.name_state !== "unavailable") || (o.name_state === "ok" ? (typeof o.tenant_name !== "string" || [...o.tenant_name].length > 120 || /[\u0000-\u001f\u007f]/.test(o.tenant_name)) : o.tenant_name !== null)
      || typeof o.proposer_role !== "string" || o.proposer_role.length > 20 || !Number.isInteger(o.seconds_left) || (o.seconds_left as number) < 0 || typeof o.mine !== "boolean") return null;
    out.push({ id: o.proposal_id, caseRef: o.case_ref, tenantId: o.tenant_id, tenantName: o.name_state === "ok" ? (o.tenant_name as string) : null, nameState: o.name_state as NameState, reason: o.reason as Reason, note: o.note, proposerRole: o.proposer_role, secondsLeft: o.seconds_left as number, mine: o.mine });
  }
  return out;
}
/** The company line of a pending item: the real name from the Control Plane, or an honest sentence when it could not be confirmed. Never a guessed name. */
export function companyWords(m: { tenantName: string | null; nameState: NameState }): string { return m.nameState === "ok" && m.tenantName !== null ? (m.tenantName.trim() === "" ? "Company (no name on record)" : m.tenantName) : m.nameState === "missing" ? "No company has this ID any more" : "Company name could not be confirmed right now"; }
export const reasonWords = (r: string): string => REASONS.find(([k]) => k === r)?.[1] ?? "Unknown reason";
export function leftWords(sec: number): string { const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60); return h > 0 ? `${h} h ${String(m).padStart(2, "0")} min left` : m > 0 ? `${m} min left` : `${sec} s left`; }

/** The closed outcome words of the Rust doors (bind_exception.rs), in plain words. A word we do not know is a plain refusal (fail closed). */
export function outcomeOf(j: unknown): string | null { const o = j !== null && typeof j === "object" ? (j as Record<string, unknown>).outcome : null; return typeof o === "string" ? o : null; }
export function outcomeWords(w: string | null): string {
  switch (w) {
    case "proposed": return "Sent. A different person with the same right has to confirm it. It stays open for 24 hours.";
    case "approved": return "Confirmed. The case is now tied to that company.";
    case "denied": return "Declined. Nothing was changed.";
    case "withdrawn": return "Taken back.";
    case "same_person": return "You cannot confirm your own proposal. A different person has to do it.";
    case "no_right": return "You do not have the right to assign cases, so you cannot do this.";
    case "not_active_staff": return "Your account is not active.";
    case "no_case": return "No case has that reference.";
    case "bad_tenant": return "That company ID is not valid.";
    case "no_tenant": return "No company has that ID. Check the ID and try again.";
    case "bad_reason": case "bad_note": return "The reason or the note is not accepted. Check them and try again.";
    case "already_bound": return "This case is already tied to a company. A bound case never changes company.";
    case "already_open": return "This case already has an open proposal. Wait for it to be decided or to run out.";
    case "too_many_open": return "You already have 5 open proposals. Wait for some to be decided.";
    case "expired": return "This proposal ran out after 24 hours. Nothing was changed. Propose it again if it is still needed.";
    case "already_decided": return "This proposal was already decided.";
    case "no_proposal": return "That proposal no longer exists.";
    case "not_proposer": return "Only the person who proposed it can take it back.";
    case "bind_refused": return "The Desk could not tie the case to that company (for example it was bound in the meantime). Nothing was changed.";
    default: return "The Desk did not accept that. Nothing was changed.";
  }
}

/** Rust WASM boundary (acceptance 8): when the kernel refuses an answer, the screen does NOT claim "nothing changed" (the server may have acted); it says so and asks the person to look at the list. Final authority = server + database. */
export const UNVERIFIED_TEXT = "The answer from the Desk could not be verified, so it is not shown. The request may or may not have gone through: look at the list below before you try again.";
