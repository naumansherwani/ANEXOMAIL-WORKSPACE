import { expect, test } from "bun:test";
import { asChipText, fold, matches, needle, score, suggest, type Contact } from "./book";

const NOW = Date.parse("2026-11-18T00:00:00Z"), DAY = 86_400_000;
const iso = (daysAgo: number) => new Date(NOW - daysAgo * DAY).toISOString();
const mk = (addr: string, name: string, sent: number, recv = 0, ago = 0, pinned = false): Contact => ({ id: addr, addr, name, sent, recv, last_sent: sent ? iso(ago) : null, last_recv: recv ? iso(ago) : null, pinned });

test("score matches the SQL selftest numbers: ln(1+3*3)", () => { expect(score({ sent: 3, recv: 0, last_sent: iso(0), last_recv: null, pinned: false }, NOW)).toBeCloseTo(Math.log(10), 9); });
test("the half life is 45 days", () => {
  const a = score({ sent: 3, recv: 0, last_sent: iso(45), last_recv: null, pinned: false }, NOW), b = score({ sent: 3, recv: 0, last_sent: iso(0), last_recv: null, pinned: false }, NOW);
  expect(a / b).toBeCloseTo(0.5, 6);
});
test("pinned goes first, receiving counts a third of sending", () => {
  expect(score(mk("p@x.com", "", 1, 0, 0, true), NOW)).toBeGreaterThan(1e8);
  expect(score(mk("a@x.com", "", 0, 3), NOW)).toBeCloseTo(Math.log(4), 9);
  expect(score(mk("a@x.com", "", 1, 0), NOW)).toBeCloseTo(Math.log(4), 9);
});
test("the frecency order of the SQL selftest: B (3 recent), A (1 recent), C (10 sends 200 days ago)", () => {
  const b = score(mk("b@x.com", "", 3), NOW), a = score(mk("a@x.com", "", 1), NOW), c = score(mk("c@x.com", "", 10, 0, 200), NOW);
  expect(b).toBeGreaterThan(a); expect(a).toBeGreaterThan(c);
});
test("fold and needle", () => { expect(fold("Zoyá KHAN")).toBe("zoya khan"); expect(needle('  "Zo')).toBe("zo"); expect(needle("<ali@")).toBe("ali@"); });
test("matches: name word, address, domain", () => {
  const c = mk("zoya.khan@idn.pk", "Zoya Khan", 1);
  expect(matches(c, "kha")).toBe("name"); expect(matches(c, "zo")).toBe("name"); expect(matches(c, "idn")).toBe("domain"); expect(matches(c, "nope")).toBeNull();
  expect(matches(mk("ali@x.com", "", 1), "al")).toBe("address");
});
test("suggest: needs 2 characters, skips taken, ranks by frecency, caps at 8", () => {
  const cs = [mk("zoya@a.com", "Zoya", 1, 0, 100), mk("zara@a.com", "Zara", 5), mk("zed@a.com", "Zed", 2)];
  expect(suggest(cs, "z", {}, NOW)).toEqual([]);
  expect(suggest(cs, "z a", {}, NOW).length).toBe(0);
  expect(suggest(cs, "z", {}, NOW)).toEqual([]);
  expect(suggest(cs, "za", new Set(["zara@a.com"]), NOW)).toEqual([]);
  expect(suggest(cs, "zo", new Set(["zara@a.com"]), NOW).map((h) => h.c.addr)).toEqual(["zoya@a.com"]);
  expect(suggest(cs, "z\u0000", {}, NOW).length).toBe(0);
  expect(suggest(cs, "ze", {}, NOW).map((h) => h.c.addr)).toEqual(["zed@a.com"]);
  const many = Array.from({ length: 30 }, (_, i) => mk(`user${i}@x.com`, "", i + 1));
  expect(suggest(many, "us", {}, NOW).length).toBe(8);
  expect(suggest(many, "us", {}, NOW)[0].c.addr).toBe("user29@x.com");
});
test("a taken record object works like a set (the row map of recipients.ts)", () => { expect(suggest([mk("zara@a.com", "Zara", 5)], "za", { "zara@a.com": "To" }, NOW)).toEqual([]); });
test("asChipText quotes names that need it", () => {
  expect(asChipText({ addr: "a@b.com", name: "" })).toBe("a@b.com"); expect(asChipText({ addr: "a@b.com", name: "Ali Raza" })).toBe("Ali Raza <a@b.com>");
  expect(asChipText({ addr: "a@b.com", name: "Doe, John" })).toBe('"Doe, John" <a@b.com>');
});

import { hitsFromKernel, kernelInput } from "./book";
test("kernelInput reduces a contact to numbers and hitsFromKernel only accepts the promised shape", () => {
  const cs = [{ id: "1", addr: "a@x.com", name: "A", sent: 1, recv: 2, last_sent: "2026-11-01T00:00:00Z", last_recv: "2026-11-10T00:00:00Z", pinned: false }];
  const k = kernelInput(cs, "a", new Set(["b@x.com"]), 5, 3);
  expect(k).toMatchObject({ q: "a", taken: ["b@x.com"], now: 5, max: 3 }); expect(k.c[0]).toEqual({ a: "a@x.com", n: "A", s: 1, r: 2, l: Date.parse("2026-11-10T00:00:00Z"), p: false });
  expect(hitsFromKernel(cs, { ok: true, hits: [{ i: 0, why: "name", score: 1.5 }] })).toEqual([{ c: cs[0], why: "name", score: 1.5 }]);
  for (const bad of [null, { ok: false }, { ok: true }, { ok: true, hits: [{ i: 1, why: "name", score: 1 }] }, { ok: true, hits: [{ i: 0, why: "x", score: 1 }] }, { ok: true, hits: [{ i: 0, why: "name", score: "1" }] }]) expect(hitsFromKernel(cs, bad)).toBeUndefined();
});
