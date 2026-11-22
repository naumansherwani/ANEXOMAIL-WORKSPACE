import { describe, expect, test } from "bun:test";
import { PRIORITIES, REASONS, TARGET_MIN, buildBody, companyOk, newRequestId, noteProblem, parseCases, parseCreated, reasonWords, requestIdOk, statusWords, targetWords } from "./desk_case_pure";

const f = (o: Partial<Parameters<typeof buildBody>[0]> = {}) => ({ requestId: "req-aaaaaaaaaaaaaaaa", company: "TESTCO001", reason: "suspended" as const, priority: "high" as const, auditRef: "audit:abc1", note: "asked twice", ...o });
describe("escalate body", () => {
  test("a good form becomes the exact body, with the flag and the runbook that belong to the reason", () => {
    expect(buildBody(f())).toEqual({ request_id: "req-aaaaaaaaaaaaaaaa", company_ref: "TESTCO001", reason: "suspended", priority: "high", flag: "suspended", audit_ref: "audit:abc1", note: "asked twice", runbook_key: "R5" });
    expect(buildBody(f({ reason: "other" }))?.runbook_key).toBeUndefined(); expect(buildBody(f({ reason: "other" }))?.flag).toBe("none");
  });
  test("a bad company, request id, audit reference or note is refused before it leaves the screen", () => {
    for (const o of [{ company: "ab" }, { company: "a b c" }, { requestId: "short" }, { auditRef: "has space" }, { note: "x".repeat(281) }, { note: "line\nbreak" }, { note: "we will refund you" }, { note: "I promise a fix" }, { note: "costs £5" }]) expect(buildBody(f(o))).toBeNull();
    expect(noteProblem("")).toBeNull(); expect(noteProblem("customer cannot sign in since morning")).toBeNull();
  });
  test("request id: random, 16..64 plain characters, a new one each time", () => { const a = newRequestId(), b = newRequestId(); expect(requestIdOk(a)).toBe(true); expect(a).not.toBe(b); expect(requestIdOk("req-" + "z".repeat(61))).toBe(false); });
  test("every reason has words and every priority has a target that is never called a promise", () => {
    expect(REASONS.every((r) => reasonWords(r[0]).length > 3)).toBe(true); expect(PRIORITIES.every((p) => TARGET_MIN[p[0]] > 0)).toBe(true);
    expect(targetWords("urgent")).toContain("15 minutes"); expect(targetWords("high")).toContain("1 hour"); expect(targetWords("normal")).toContain("4 hours"); expect(targetWords("normal")).toContain("not a promise"); expect(companyOk(" TESTCO001 ")).toBe(true);
  });
});
describe("answers fail closed", () => {
  test("created", () => {
    expect(parseCreated({ case_no: "ESC-231123-00042", status: "queued", duplicate: false })).toEqual({ caseNo: "ESC-231123-00042", status: "queued", duplicate: false });
    for (const bad of [null, {}, { case_no: "x", status: "queued", duplicate: false }, { case_no: "ESC-231123-00042", status: 1, duplicate: false }, { case_no: "ESC-231123-00042", status: "queued", duplicate: "no" }]) expect(parseCreated(bad)).toBeNull();
  });
  const row = { case_no: "ESC-231123-00042", company_ref: "TESTCO001", reason: "suspended", priority: "high", status: "queued", created_at: "2026-11-23T00:00:00Z", target_minutes: 60, by: "Agent" };
  test("list", () => {
    expect(parseCases([row])?.[0]).toMatchObject({ caseNo: "ESC-231123-00042", targetMin: 60, status: "queued" }); expect(parseCases([])).toEqual([]);
    for (const bad of [null, {}, [null], [{ ...row, status: "weird" }], [{ ...row, priority: "asap" }], [{ ...row, target_minutes: "60" }], [{ ...row, by: 5 }]]) expect(parseCases(bad)).toBeNull();
  });
  test("status words are honest: queued says it waits to be received, nothing promises a time", () => { expect(statusWords("queued")).toContain("waiting to be received"); expect(statusWords("stuck")).toContain("person"); expect(statusWords("nope")).toBe("Unknown"); for (const s of ["created", "received", "decided", "returned", "closed"]) expect(/promise|refund|guarantee/i.test(statusWords(s))).toBe(false); });
});
