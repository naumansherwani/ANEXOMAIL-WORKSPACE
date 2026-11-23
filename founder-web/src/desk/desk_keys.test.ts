import { describe as _d, expect as _e, test as _t } from "bun:test";
import { keyOf, keyLabel, keyProblems, paletteKey, helpKey, railComboTarget, railStep, searchItems, stepKey } from "./desk_keys";
import { MODULES } from "./modules/registry";
const ev = (code: string, o: Partial<{ altKey: boolean; shiftKey: boolean; ctrlKey: boolean; metaKey: boolean }> = {}) => ({ code, altKey: false, shiftKey: false, ctrlKey: false, metaKey: false, ...o });
_d("rail keys", () => {
  _t("no key is used twice and every rail folder has a key", () => { _e(keyProblems(["dashboard", ...MODULES.map((m) => m.key)])).toEqual([]); });
  _t("audit keeps its card key, plans its card key", () => { _e(keyOf("audit")).toBe("u"); _e(keyOf("plans")).toBe("p"); _e(keyLabel("bridge")).toBe("Alt+Shift+6"); _e(keyLabel("dashboard")).toBe("Ctrl+D"); });
  _t("Alt+Shift letter and digit go to the folder", () => {
    _e(railComboTarget(ev("KeyI", { altKey: true, shiftKey: true }))).toBe("/dashboard/inboxes");
    _e(railComboTarget(ev("Digit7", { altKey: true, shiftKey: true }))).toBe("/dashboard/policy");
    _e(railComboTarget(ev("KeyI", { altKey: true }))).toBeNull(); _e(railComboTarget(ev("KeyI", { altKey: true, shiftKey: true, ctrlKey: true }))).toBeNull(); _e(railComboTarget(ev("KeyA", { altKey: true, shiftKey: true }))).toBeNull();
  });
  _t("walk Up / Down", () => {
    _e(stepKey(ev("ArrowDown", { altKey: true, shiftKey: true }))).toBe(1); _e(stepKey(ev("ArrowUp", { altKey: true, shiftKey: true }))).toBe(-1); _e(stepKey(ev("ArrowUp"))).toBe(0);
    const ids = ["dashboard", "cases", "plans"]; _e(railStep(ids, "cases", 1)).toBe("plans"); _e(railStep(ids, "plans", 1)).toBe("plans"); _e(railStep(ids, "dashboard", -1)).toBe("dashboard"); _e(railStep(ids, "zzz", 1)).toBe("dashboard");
  });
  _t("Ctrl+K and Ctrl+/ only with Ctrl or Cmd", () => { _e(paletteKey(ev("KeyK", { ctrlKey: true }))).toBe(true); _e(paletteKey(ev("KeyK"))).toBe(false); _e(paletteKey(ev("KeyK", { ctrlKey: true, shiftKey: true }))).toBe(false); _e(helpKey(ev("Slash", { metaKey: true }))).toBe(true); _e(helpKey(ev("Slash"))).toBe(false); });
  _t("palette search: starts-with first, then contains", () => {
    const it = [{ id: "plans", label: "Plans" }, { id: "viewas", label: "View as user" }, { id: "people", label: "People" }];
    _e(searchItems(it, "pe").map((x) => x.id)).toEqual(["people"]); _e(searchItems(it, "as").map((x) => x.id)).toEqual(["viewas"]); _e(searchItems(it, "").length).toBe(3); _e(searchItems(it, "zz")).toEqual([]);
  });
});
