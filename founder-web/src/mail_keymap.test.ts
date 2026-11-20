import { describe, expect, test } from "bun:test";
import { HELP_ROWS, helpFor, isCharShortcut, listMove, silenceSingle, singleKeysOn, typeAhead } from "./mail_keymap";
const S = { composeOpen: false, inDialog: false, typing: false };
describe("QC8a single-letter switch (WCAG 2.1.4)", () => {
  test("ON: nothing is silenced", () => { for (const k of ["j", "k", "c", "e", "#", "/", "g"]) expect(silenceSingle(k, {}, true, S)).toBe(false); });
  test("OFF: bare character shortcuts are silenced", () => { for (const k of ["j", "k", "c", "e", "#", "/", "g", "J"]) expect(silenceSingle(k, {}, false, S)).toBe(true); });
  test("OFF: modifiers, Esc, Enter, arrows, space, ? and unknown letters pass", () => {
    expect(silenceSingle("k", { ctrl: true }, false, S)).toBe(false); expect(silenceSingle("k", { meta: true }, false, S)).toBe(false);
    for (const k of ["Escape", "Enter", "ArrowDown", "Home", " ", "?", "z", "x"]) expect(silenceSingle(k, {}, false, S)).toBe(false);
  });
  test("OFF: typing places, dialogs and Compose own their keys", () => {
    expect(silenceSingle("j", {}, false, { ...S, typing: true })).toBe(false); expect(silenceSingle("j", {}, false, { ...S, inDialog: true })).toBe(false); expect(silenceSingle("j", {}, false, { ...S, composeOpen: true })).toBe(false);
  });
  test("setting: only an explicit off switches it off", () => { expect(singleKeysOn(undefined)).toBe(true); expect(singleKeysOn(null)).toBe(true); expect(singleKeysOn(true)).toBe(true); expect(singleKeysOn(false)).toBe(false); expect(singleKeysOn("off")).toBe(false); });
  test("isCharShortcut", () => { expect(isCharShortcut("j", {})).toBe(true); expect(isCharShortcut("Enter", {})).toBe(false); expect(isCharShortcut("j", { alt: true })).toBe(false); });
});
describe("QC8a list movement", () => {
  test("arrows clamp", () => { expect(listMove("ArrowDown", {}, 2, 5)).toEqual({ to: 3 }); expect(listMove("ArrowDown", {}, 4, 5)).toEqual({ to: 4 }); expect(listMove("ArrowUp", {}, 0, 5)).toEqual({ to: 0 }); expect(listMove("ArrowUp", {}, -1, 5)).toEqual({ to: 0 }); });
  test("Home End Shift", () => { expect(listMove("Home", {}, 3, 5)).toEqual({ to: 0 }); expect(listMove("End", {}, 1, 5)).toEqual({ to: 4 }); expect(listMove("ArrowDown", { shift: true }, 1, 5)).toEqual({ to: 2, extend: true }); });
  test("empty list, modifiers and other keys give null", () => { expect(listMove("ArrowDown", {}, 0, 0)).toBeNull(); expect(listMove("ArrowDown", { ctrl: true }, 0, 3)).toBeNull(); expect(listMove("x", {}, 0, 3)).toBeNull(); });
});
describe("QC8a type-ahead", () => {
  const L = ["Anna", "Bilal", "Bea", "Carl"];
  test("first letter jumps to the next match after the current row", () => { expect(typeAhead(L, 0, "", "b", 1000, 0).hit).toBe(1); expect(typeAhead(L, 1, "", "b", 1000, 0).hit).toBe(2); });
  test("a quick second letter extends the prefix, a slow one starts again", () => { const a = typeAhead(L, 0, "", "b", 1000, 0); expect(typeAhead(L, a.hit, a.buf, "e", 1200, 1000).hit).toBe(2); expect(typeAhead(L, 2, "be", "c", 5000, 1200).hit).toBe(3); });
  test("no match, no list, non-character keys", () => { expect(typeAhead(L, 0, "", "z", 1, 0).hit).toBe(-1); expect(typeAhead([], 0, "", "a", 1, 0).hit).toBe(-1); expect(typeAhead(L, 0, "", "Enter", 1, 0).hit).toBe(-1); });
});
describe("QC8a help rows", () => {
  test("every row has keys and words; list scene shows list and page rows only", () => { for (const r of HELP_ROWS) { expect(r.keys.length).toBeGreaterThan(0); expect(r.does.length).toBeGreaterThan(3); } expect(helpFor("list").every((r) => r.where === "list" || r.where === "page")).toBe(true); expect(helpFor("compose").some((r) => r.keys === "Ctrl Enter")).toBe(true); });
});
