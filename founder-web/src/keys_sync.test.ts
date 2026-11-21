import { describe, expect, test } from "bun:test";
import { reconcile, folderWord } from "./keys_sync_pure";
describe("keys_sync", () => {
  test("server value wins when it differs", () => { expect(reconcile(false, true)).toEqual({ apply: false }); expect(reconcile(true, false)).toEqual({ apply: true }); });
  test("same value: nothing to do", () => { expect(reconcile(true, true)).toEqual({}); expect(reconcile(false, false)).toEqual({}); });
  test("server never set: ON is the default, OFF is pushed once", () => { expect(reconcile(undefined, true)).toEqual({}); expect(reconcile(undefined, false)).toEqual({ push: false }); });
  test("folder word is always a-z and _ , 1..24, never empty", () => {
    expect(folderWord("Inbox")).toBe("inbox"); expect(folderWord("Sent mail")).toBe("sent_mail"); expect(folderWord("  ")).toBe("inbox"); expect(folderWord(null)).toBe("inbox");
    expect(folderWord("Ünïcode/Spam!!")).toMatch(/^[a-z_]{1,24}$/); expect(folderWord("a".repeat(60)).length).toBe(24);
  });
});
