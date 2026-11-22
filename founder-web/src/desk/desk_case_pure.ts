// ADMIN DESK desk_case_pure.ts (D5c, phase 1l, 23 Nov 2026): pure logic of the Escalate screen. No network, no browser. Fail closed: a case list that is not exactly the expected shape is "unavailable".
// Words are plain and never promise: the acknowledge target is "a target to reply", not a promise to fix. Only metadata and an audit reference: no money field exists here.
export const REASONS = [
  ["payment_not_active", "Paid but the service is not active"], ["features_missing", "Features missing"], ["limit_reached", "Storage or seats limit reached"], ["grace_period", "Grace period"], ["suspended", "Account suspended"],
  ["cannot_sign_in", "Cannot sign in"], ["mail_not_delivered", "Email not delivered"], ["attachment_blocked", "Attachment blocked"], ["many_customers", "Many customers affected"], ["other", "Something else"],
] as const;
export const PRIORITIES = [["urgent", "Urgent"], ["high", "High"], ["normal", "Normal"]] as const;
export type Reason = (typeof REASONS)[number][0]; export type Priority = (typeof PRIORITIES)[number][0];
export const TARGET_MIN: Record<Priority, number> = { urgent: 15, high: 60, normal: 240 };
/** The runbook that goes with a reason (its escalate line is the guide the employee just followed). */
export const RUNBOOK_FOR: Partial<Record<Reason, string>> = { payment_not_active: "R1", features_missing: "R2", limit_reached: "R3", grace_period: "R4", suspended: "R5", cannot_sign_in: "R6", mail_not_delivered: "R7", attachment_blocked: "R8", many_customers: "R9" };
export const FLAG_FOR: Partial<Record<Reason, string>> = { payment_not_active: "payment_received_not_active", limit_reached: "limit_reached", suspended: "suspended", many_customers: "many_customers" };
/** Words the database refuses in the free note (money and promise words): the screen tells the employee BEFORE sending. Same list as AD10. */
const BANNED = /(promise|guarantee|definitely|refund|credit|compensat|discount|invoice|price|amount|iban|card number|[$£€])/i;   // no-money-gate-ok
export const NOTE_MAX = 280;
export function noteProblem(n: string): string | null {
  if (n.length > NOTE_MAX) return `Keep the note under ${NOTE_MAX} characters.`;
  if (/[\u0000-\u001f\u007f]/.test(n)) return "The note cannot have line breaks.";
  if (BANNED.test(n)) return "The note cannot mention money or a promise. Say what you see, not what will happen.";
  return null;
}
export const companyOk = (c: string) => /^[A-Za-z0-9_.:-]{3,64}$/.test(c.trim());
export const requestIdOk = (r: string) => /^[A-Za-z0-9_-]{16,64}$/.test(r);
/** ONE request id per form fill: pressing the button twice, or a retry, is the same case (the database answers a repeat with the same case number). */
export function newRequestId(rand: (n: number) => Uint8Array = (n) => crypto.getRandomValues(new Uint8Array(n))): string { return "req-" + Array.from(rand(12), (b) => b.toString(16).padStart(2, "0")).join(""); }
export type EscBody = { request_id: string; company_ref: string; reason: Reason; priority: Priority; flag: string; audit_ref: string; runbook_key?: string; note: string };
export function buildBody(f: { requestId: string; company: string; reason: Reason; priority: Priority; auditRef: string; note: string }): EscBody | null {
  const company = f.company.trim(), auditRef = f.auditRef.trim();
  if (!requestIdOk(f.requestId) || !companyOk(company) || !/^[A-Za-z0-9_.:-]{0,80}$/.test(auditRef) || noteProblem(f.note) !== null) return null;
  const b: EscBody = { request_id: f.requestId, company_ref: company, reason: f.reason, priority: f.priority, flag: FLAG_FOR[f.reason] ?? "none", audit_ref: auditRef, note: f.note };
  const rb = RUNBOOK_FOR[f.reason]; if (rb) b.runbook_key = rb;
  return b;
}
export type Created = { caseNo: string; status: string; duplicate: boolean };
export function parseCreated(j: unknown): Created | null {
  const x = j as Record<string, unknown> | null;
  if (x === null || typeof x !== "object" || typeof x.case_no !== "string" || !/^ESC-\d{6}-\d{5,}$/.test(x.case_no) || typeof x.status !== "string" || typeof x.duplicate !== "boolean") return null;
  return { caseNo: x.case_no, status: x.status, duplicate: x.duplicate };
}
export type CaseRow = { caseNo: string; company: string; reason: string; priority: Priority; status: string; createdAt: string; targetMin: number; by: string };
const STATUS = new Set(["created", "queued", "received", "in_review", "decided", "returned", "closed", "stuck"]);
export function parseCases(j: unknown): CaseRow[] | null {
  if (!Array.isArray(j)) return null; const out: CaseRow[] = [];
  for (const x of j as Record<string, unknown>[]) {
    if (x === null || typeof x !== "object" || typeof x.case_no !== "string" || typeof x.company_ref !== "string" || typeof x.reason !== "string" || typeof x.status !== "string" || !STATUS.has(x.status)
      || typeof x.created_at !== "string" || typeof x.target_minutes !== "number" || typeof x.by !== "string" || !PRIORITIES.some((p) => p[0] === x.priority)) return null;
    out.push({ caseNo: x.case_no, company: x.company_ref, reason: x.reason, priority: x.priority as Priority, status: x.status, createdAt: x.created_at, targetMin: x.target_minutes, by: x.by });
  }
  return out;
}
/** Plain words for a status. Honest about the founder side not receiving yet: "queued" says it is waiting to be received. Never a promise of time. */
export function statusWords(s: string): string {
  return ({ created: "Created", queued: "Created, waiting to be received", received: "Received by the owner", in_review: "Being looked at", decided: "Decision made", returned: "Answer is back", closed: "Closed", stuck: "Could not be handed over yet, a person is looking" } as Record<string, string>)[s] ?? "Unknown";
}
export function targetWords(p: Priority): string { const m = TARGET_MIN[p]; return `Target to answer: ${m < 60 ? `${m} minutes` : `${m / 60} ${m === 60 ? "hour" : "hours"}`} (a target, not a promise)`; }
export function reasonWords(r: string): string { return REASONS.find((x) => x[0] === r)?.[1] ?? r; }
