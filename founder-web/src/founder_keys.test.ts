import { describe, expect, test } from "bun:test";
import { founderComboTarget, founderHelpKey, founderHomeKey, founderKeyLabel, founderKeyProblems, founderStep, founderStepKey } from "./founder_keys";
const ev = (code: string, o: Partial<{ altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean }> = {}) => ({ code, altKey: false, shiftKey: false, ctrlKey: false, metaKey: false, ...o });
describe("founder keys", () => {
  test("no key twice, every page has one", () => { expect(founderKeyProblems(["dashboard", "bridge", "mail", "people", "ai", "systems", "control", "finance", "release", "move_in", "audit", "settings", "devices", "profile"])).toEqual([]); });
  test("Alt+Shift letter goes to the page", () => {
    expect(founderComboTarget(ev("KeyM", { altKey: true, shiftKey: true }))).toBe("mail"); expect(founderComboTarget(ev("KeyM", { altKey: true }))).toBeNull();
    expect(founderComboTarget(ev("KeyM", { altKey: true, shiftKey: true, ctrlKey: true }))).toBeNull(); expect(founderComboTarget(ev("KeyZ", { altKey: true, shiftKey: true }))).toBeNull();
    expect(founderKeyLabel("finance")).toBe("Alt+Shift+F"); expect(founderKeyLabel("dashboard")).toBe("Ctrl+D");
  });
  test("Ctrl+D, Ctrl+/ and the walk", () => {
    expect(founderHomeKey(ev("KeyD", { ctrlKey: true }))).toBe(true); expect(founderHomeKey(ev("KeyD"))).toBe(false); expect(founderHelpKey(ev("Slash", { ctrlKey: true }))).toBe(true);
    expect(founderStepKey(ev("ArrowDown", { altKey: true, shiftKey: true }))).toBe(1); expect(founderStepKey(ev("ArrowDown"))).toBe(0);
    const ids = ["dashboard", "bridge", "mail"]; expect(founderStep(ids, "bridge", 1)).toBe("mail"); expect(founderStep(ids, "mail", 1)).toBe("mail"); expect(founderStep(ids, "dashboard", -1)).toBe("dashboard"); expect(founderStep(ids, "zz", 1)).toBe("dashboard");
  });
});
