import { expect, test } from "bun:test";
import { companyWords, REASONS, buildDecide, buildPropose, caseRefOk, leftWords, noteProblem, outcomeOf, outcomeWords, parsePending, reasonWords, tenantOk, UNVERIFIED_TEXT } from "./desk_bind_pure";

const T = "123e4567-e89b-12d3-a456-426614174000", P = "223e4567-e89b-12d3-a456-426614174000";
const item = (o: Record<string, unknown> = {}) => ({ proposal_id: P, case_ref: "CASE-251125-00001", tenant_id: T, reason: "forwarded_mail", note: "", proposer_role: "agent", seconds_left: 3600, mine: false, tenant_name: "Acme Ltd", name_state: "ok", ...o });

test("the five reasons match the database list", () => { expect(REASONS.map(([k]) => k)).toEqual(["customer_emailed_from_other_domain", "new_domain_not_yet_verified", "forwarded_mail", "staff_checked_contract", "other_with_note"]); });
test("case ref and company ID checks are strict, the nil UUID is refused", () => {
  expect(caseRefOk("CASE-1")).toBe(true); expect(caseRefOk("a'; drop")).toBe(false); expect(caseRefOk("ab")).toBe(false);
  expect(tenantOk(T)).toBe(true); expect(tenantOk("00000000-0000-0000-0000-000000000000")).toBe(false); expect(tenantOk("nope")).toBe(false);
});
test("notes: 200 max, no line breaks, other_with_note needs 10 characters", () => {
  expect(noteProblem("forwarded_mail", "")).toBeNull(); expect(noteProblem("forwarded_mail", "x".repeat(201))).not.toBeNull(); expect(noteProblem("forwarded_mail", "a\nb")).not.toBeNull();
  expect(noteProblem("other_with_note", "short")).not.toBeNull(); expect(noteProblem("other_with_note", "contract seen on paper")).toBeNull();
});
test("buildPropose returns the exact body or null", () => {
  expect(buildPropose({ caseRef: " CASE-1 ", tenantId: T.toUpperCase(), reason: "forwarded_mail", note: " " })).toEqual({ case_ref: "CASE-1", tenant_id: T, reason: "forwarded_mail", note: "" });
  expect(buildPropose({ caseRef: "CASE-1", tenantId: "x", reason: "forwarded_mail", note: "" })).toBeNull();
  expect(buildPropose({ caseRef: "CASE-1", tenantId: T, reason: "because", note: "" })).toBeNull();
  expect(buildPropose({ caseRef: "CASE-1", tenantId: T, reason: "other_with_note", note: "short" })).toBeNull();
});
test("buildDecide needs a real proposal id", () => { expect(buildDecide(P, true)).toEqual({ proposal_id: P, approve: true }); expect(buildDecide("x", false)).toBeNull(); });
test("parsePending accepts the exact shape and fails closed on anything else", () => {
  expect(parsePending({ items: [] })).toEqual([]);
  expect(parsePending({ items: [item({ note: "a short note", mine: true })] })).toEqual([{ id: P, caseRef: "CASE-251125-00001", tenantId: T, tenantName: "Acme Ltd", nameState: "ok", reason: "forwarded_mail", note: "a short note", proposerRole: "agent", secondsLeft: 3600, mine: true }]);
  for (const bad of [null, "x", {}, { items: "x" }, { items: [item({ proposal_id: "x" })] }, { items: [item({ tenant_id: 5 })] }, { items: [item({ reason: "because" })] }, { items: [item({ seconds_left: -1 })] },
    { items: [item({ seconds_left: 1.5 })] }, { items: [item({ mine: "yes" })] }, { items: [item({ note: "x".repeat(201) })] }, { items: Array.from({ length: 101 }, () => item()) }]) expect(parsePending(bad)).toBeNull();
});
test("words: reasons, time left, and a closed list of outcomes with a safe default", () => {
  expect(reasonWords("staff_checked_contract")).toBe("Staff checked the contract"); expect(reasonWords("x")).toBe("Unknown reason");
  expect(leftWords(7500)).toBe("2 h 05 min left"); expect(leftWords(300)).toBe("5 min left"); expect(leftWords(42)).toBe("42 s left");
  expect(outcomeOf({ outcome: "approved" })).toBe("approved"); expect(outcomeOf({ outcome: 5 })).toBeNull(); expect(outcomeOf(null)).toBeNull();
  for (const w of ["proposed", "approved", "denied", "withdrawn", "same_person", "no_right", "not_active_staff", "no_case", "bad_tenant", "no_tenant", "bad_reason", "bad_note", "already_bound", "already_open", "too_many_open", "expired", "already_decided", "no_proposal", "not_proposer", "bind_refused"]) expect(outcomeWords(w).length).toBeGreaterThan(10);
  expect(outcomeWords("hacked")).toBe("The Desk did not accept that. Nothing was changed."); expect(outcomeWords(null)).toBe("The Desk did not accept that. Nothing was changed.");
  expect(outcomeWords("same_person")).toContain("cannot confirm your own");
});
test("a refused (unverified) answer never claims that nothing changed", () => { expect(UNVERIFIED_TEXT).toContain("may or may not"); expect(UNVERIFIED_TEXT.toLowerCase()).not.toContain("nothing was changed"); });
test("T4e: the company name comes from the Control Plane and is never guessed", () => {
  const ok = parsePending({ items: [item()] })![0]; expect(companyWords(ok)).toBe("Acme Ltd");
  const gone = parsePending({ items: [item({ name_state: "missing", tenant_name: null })] })![0]; expect(gone.tenantName).toBeNull(); expect(companyWords(gone)).toMatch(/No company has this ID/);
  const down = parsePending({ items: [item({ name_state: "unavailable", tenant_name: null })] })![0]; expect(companyWords(down)).toMatch(/could not be confirmed/); expect(companyWords(down)).not.toMatch(/Acme/);
  for (const bad of [item({ name_state: "ok", tenant_name: null }), item({ name_state: "missing", tenant_name: "Acme" }), item({ name_state: "weird", tenant_name: null }), item({ tenant_name: "x".repeat(121) }), item({ tenant_name: "A\u0007B" }), { ...item(), name_state: undefined }]) expect(parsePending({ items: [bad] })).toBeNull();
  expect(outcomeWords("no_tenant")).toMatch(/No company has that ID/);
});
