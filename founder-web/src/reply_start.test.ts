import { describe, expect, test } from "bun:test";
import { buildStart, countPeople } from "./reply_start";
const sum = { subject: "Re: Plan", from: "a@x.com", from_name: "Ann", to: ["me@y.com", "b@x.com"], cc: ["c@x.com"], date: "2026-11-20T04:00:00Z", message_id: "<m2@x>", references: ["<m1@x>"], reply_to: ["r@x.com"] };
describe("QC4b buildStart", () => {
  test("reply goes to Reply-To only, keeps the thread", () => {
    const s = buildStart("reply", { sum, text: "hi", me: ["me@y.com"] });
    expect(s.to).toBe("r@x.com"); expect(s.cc).toBeUndefined(); expect(s.subject).toBe("Re: Plan"); expect(s.in_reply_to).toBe("<m2@x>"); expect(s.references).toEqual(["m1@x", "m2@x"]); expect(s.inline).toBe(true);
  });
  test("reply all removes me and keeps Cc", () => {
    const s = buildStart("all", { sum, text: "hi", me: ["me@y.com"] });
    expect(s.to).toBe("r@x.com, b@x.com"); expect(s.cc).toBe("c@x.com");
  });
  test("selection replaces the whole quote", () => {
    const s = buildStart("reply", { sum, text: "one\ntwo", me: [], selection: "two" });
    expect(s.text).toContain("> two"); expect(s.text).not.toContain("> one");
  });
  test("forward: Fwd once, empty To, no thread header, block inside", () => {
    const s = buildStart("forward", { sum: { ...sum, subject: "Fwd: Plan" }, text: "body", me: [] });
    expect(s.subject).toBe("Fwd: Plan"); expect(s.to).toBe(""); expect(s.in_reply_to).toBeUndefined(); expect(s.text).toContain("---------- Forwarded message ----------"); expect(s.text).toContain("body");
  });
  test("countPeople", () => { expect(countPeople("a@x.com, b@x.com", "", "c@x.com;")).toBe(3); });
});
