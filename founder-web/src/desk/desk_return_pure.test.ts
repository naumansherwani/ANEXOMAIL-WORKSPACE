import { expect, test } from "bun:test";
import { isHome, markSelectors, origin, remember, subOf } from "./desk_return_pure";
const mem = () => { const m = new Map<string, string>(); return { setItem: (k: string, v: string) => void m.set(k, v), getItem: (k: string) => m.get(k) ?? null }; };
test("sub page id comes from the path only", () => { expect(subOf("/dashboard/alerts?severity=urgent#x")).toBe("alerts"); expect(subOf("/dashboard")).toBe(""); expect(subOf("/x/alerts")).toBe(""); expect(isHome("/dashboard/")).toBe(true); });
test("the origin is remembered and only shown on the dashboard home", () => {
  const s = mem(); remember("/dashboard/services#hs", s); expect(origin("/dashboard", s)).toBe("services"); expect(origin("/dashboard/alerts", s)).toBe(""); remember("/dashboard/plans", s); expect(origin("/dashboard", s)).toBe("plans");
  remember("/dashboard", s); expect(origin("/dashboard", s)).toBe("plans");
});
test("no storage, a throwing storage or a hostile id never breaks or injects", () => {
  expect(origin("/dashboard", null)).toBe(""); remember("/dashboard/alerts", null);
  const bad = { getItem: () => { throw new Error("x"); }, setItem: () => { throw new Error("x"); } }; expect(origin("/dashboard", bad)).toBe(""); remember("/dashboard/alerts", bad);
  expect(origin("/dashboard", { getItem: () => '"]; alert(1);//' })).toBe(""); expect(markSelectors('a"b')).toEqual([]); expect(markSelectors("alerts").length).toBe(2);
});
