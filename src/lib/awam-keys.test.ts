import { describe, expect, test } from "bun:test";
import { awamComboTarget, awamCurrent, awamHelpKey, awamHomeKey, awamKeyLabel, awamKeyProblems, awamStep, awamStepKey } from "./awam-keys";
const ev = (code: string, o: Partial<{ altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean }> = {}) => ({ code, altKey: false, shiftKey: false, ctrlKey: false, metaKey: false, ...o });
describe("awam keys", () => {
  test("no key twice, every rail page has one", () => {
    expect(awamKeyProblems(["/app", "/app/mail", "/app/people", "/app/calendar", "/app/work", "/app/crm", "/app/org", "/app/analytics", "/app/domains", "/app/safety", "/app/chat", "/app/ai-center", "/app/perf", "/app/founder", "/app/admin"])).toEqual([]);
  });
  test("Alt+Shift letter goes to the page (mail goes to the inbox)", () => {
    expect(awamComboTarget(ev("KeyM", { altKey: true, shiftKey: true }))).toBe("/app/mail/inbox"); expect(awamComboTarget(ev("KeyW", { altKey: true, shiftKey: true }))).toBe("/app/work");
    expect(awamComboTarget(ev("KeyM", { altKey: true }))).toBeNull(); expect(awamComboTarget(ev("KeyM", { altKey: true, shiftKey: true, metaKey: true }))).toBeNull(); expect(awamComboTarget(ev("KeyZ", { altKey: true, shiftKey: true }))).toBeNull();
    expect(awamKeyLabel("/app")).toBe("Ctrl+D"); expect(awamKeyLabel("/app/crm")).toBe("Alt+Shift+R"); expect(awamKeyLabel("/nope")).toBe("");
  });
  test("Ctrl+D, Ctrl+/ and the walk", () => {
    expect(awamHomeKey(ev("KeyD", { ctrlKey: true }))).toBe(true); expect(awamHomeKey(ev("KeyD"))).toBe(false); expect(awamHelpKey(ev("Slash", { metaKey: true }))).toBe(true); expect(awamHelpKey(ev("Slash"))).toBe(false);
    expect(awamStepKey(ev("ArrowUp", { altKey: true, shiftKey: true }))).toBe(-1); expect(awamStepKey(ev("ArrowUp"))).toBe(0);
    const ids = ["/app", "/app/mail", "/app/people"]; expect(awamStep(ids, "/app/mail", 1)).toBe("/app/people"); expect(awamStep(ids, "/app/people", 1)).toBe("/app/people"); expect(awamStep(ids, "/app", -1)).toBe("/app"); expect(awamStep(ids, null, 1)).toBe("/app"); expect(awamStep([], "/app", 1)).toBeNull();
  });
  test("the current page is the longest prefix, /app only when exact", () => {
    expect(awamCurrent("/app")).toBe("/app"); expect(awamCurrent("/app/")).toBe("/app"); expect(awamCurrent("/app/mail/inbox/abc")).toBe("/app/mail"); expect(awamCurrent("/app/crm/deals")).toBe("/app/crm"); expect(awamCurrent("/app/unknown")).toBeNull(); expect(awamCurrent("/auth")).toBeNull();
  });
});
