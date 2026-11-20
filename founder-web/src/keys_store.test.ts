import { describe, expect, test } from "bun:test";
import { KEY, readSingle, writeSingle } from "./keys_store";
const mem = () => { const m = new Map<string, string>(); return { getItem: (k: string) => m.get(k) ?? null, setItem: (k: string, v: string) => { m.set(k, v); } }; };
describe("QC8a keys switch store", () => {
  test("default ON, only an explicit off turns it off, on again works", () => { const s = mem(); expect(readSingle(s)).toBe(true); expect(writeSingle(false, s)).toBe(true); expect(s.getItem(KEY)).toBe("off"); expect(readSingle(s)).toBe(false); writeSingle(true, s); expect(readSingle(s)).toBe(true); });
  test("no storage or a throwing storage never crashes and reads ON", () => {
    expect(readSingle(null)).toBe(true); expect(writeSingle(false, null)).toBe(false);
    const bad = { getItem: () => { throw new Error("blocked"); }, setItem: () => { throw new Error("blocked"); } };
    expect(readSingle(bad)).toBe(true); expect(writeSingle(false, bad)).toBe(false);
  });
});
