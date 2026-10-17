import { describe, expect, test } from "bun:test";

import {
  buildWindows,
  clockIn,
  hoursIn,
  rankSlots,
  toLocalInput,
  unkindness,
  zoneLabel,
} from "../../../../src/lib/find-time";

// 2026-10-20 (Tuesday), UTC instants. Karachi = UTC+5, Tokyo = UTC+9, New York = UTC-4 (EDT), London = UTC+1 (BST).
const at = (h: number, m = 0) => new Date(Date.UTC(2026, 9, 20, h, m));
const plus = (d: Date, min: number) => new Date(d.getTime() + min * 60_000);

describe("hoursIn / clockIn", () => {
  test("reads the wall clock of a zone, not of the machine", () => {
    expect(hoursIn("Asia/Karachi", at(10))).toBe(15);
    expect(hoursIn("America/New_York", at(10))).toBe(6);
    expect(hoursIn("Asia/Tokyo", at(10, 30))).toBe(19.5);
    expect(clockIn("Asia/Karachi", at(10, 5))).toBe("15:05");
  });
  test("midnight is 00:xx, never 24:xx", () => {
    expect(clockIn("Asia/Karachi", at(19))).toBe("00:00");
  });
});

describe("unkindness", () => {
  test("a civilised hour costs nothing", () => {
    expect(unkindness("Asia/Karachi", at(10), plus(at(10), 30))).toBe(0); // 15:00-15:30
    expect(unkindness("Europe/London", at(7), plus(at(7), 60))).toBe(0); // 08:00-09:00 BST
  });
  test("outside 08:00-20:00 costs, and the further out the worse", () => {
    const late1 = unkindness("Asia/Tokyo", at(12), plus(at(12), 30)); // 21:00-21:30
    const early2 = unkindness("America/New_York", at(10), plus(at(10), 30)); // 06:00-06:30
    expect(late1).toBeGreaterThan(0);
    expect(early2).toBeGreaterThan(late1);
  });
  test("night is clearly worse than early/late", () => {
    const night = unkindness("America/New_York", at(7), plus(at(7), 30)); // 03:00
    expect(night).toBeGreaterThanOrEqual(200);
    expect(unkindness("Asia/Tokyo", at(12), plus(at(12), 30))).toBeLessThan(200);
  });
  test("a meeting that runs past midnight is unkind", () => {
    expect(unkindness("Asia/Karachi", at(18, 30), plus(at(18, 30), 60))).toBeGreaterThanOrEqual(200); // 23:30-00:30
  });
});

describe("rankSlots", () => {
  const slots = [
    { start: at(10).toISOString(), end: plus(at(10), 30).toISOString() }, // KHI 15:00 | TYO 19:00 | NYC 06:00 (early)
    { start: at(12).toISOString(), end: plus(at(12), 30).toISOString() }, // KHI 17:00 | TYO 21:00 (late) | NYC 08:00
    { start: at(5).toISOString(), end: plus(at(5), 30).toISOString() }, // KHI 10:00 | TYO 14:00 | NYC 01:00 (night)
  ];
  test("everyone-comfortable slots come first; a nearly-ok late hour beats a 2-hours-early one", () => {
    const ranked = rankSlots(slots, 30, ["Asia/Karachi", "Asia/Tokyo", "America/New_York"], 3);
    expect(ranked.map((r) => r.start.toISOString())).toEqual([at(12).toISOString(), at(10).toISOString(), at(5).toISOString()]);
    expect(ranked[2]!.notes.find((n) => n.zone === "America/New_York")?.text).toBe("night");
  });
  test("with no extra zones the order is simply chronological", () => {
    const ranked = rankSlots(slots, 30, ["Asia/Karachi"], 3);
    expect(ranked.map((r) => r.penalty)).toEqual([0, 0, 0]);
    expect(ranked[0]!.start.toISOString()).toBe(at(5).toISOString());
  });
  test("respects the limit", () => {
    expect(rankSlots(slots, 30, ["Asia/Karachi"], 2)).toHaveLength(2);
  });
});

describe("buildWindows", () => {
  test("one window per day inside working hours, never in the past, weekends skipped on request", () => {
    const w = buildWindows(14, 9, 18, true);
    expect(w.length).toBeGreaterThan(5);
    expect(w.length).toBeLessThanOrEqual(10);
    const now = Date.now();
    for (const x of w) {
      expect(new Date(x.end).getTime()).toBeGreaterThan(now);
      expect(new Date(x.start).getTime()).toBeLessThan(new Date(x.end).getTime());
      const day = new Date(x.start).getDay();
      expect(day === 0 || day === 6).toBe(false);
    }
  });
  test("weekends included when asked", () => {
    const all = buildWindows(7, 9, 18, false).length;
    const wk = buildWindows(7, 9, 18, true).length;
    expect(all).toBeGreaterThanOrEqual(wk);
  });
  test("empty when the hours are empty", () => {
    expect(buildWindows(3, 18, 18, false)).toHaveLength(0);
  });
});

describe("misc", () => {
  test("toLocalInput is a datetime-local value", () => {
    expect(toLocalInput(new Date(2026, 9, 20, 9, 5))).toBe("2026-10-20T09:05");
  });
  test("zoneLabel shows the city and the offset", () => {
    expect(zoneLabel("Asia/Karachi", at(10))).toContain("Karachi");
    expect(zoneLabel("America/New_York", at(10))).toContain("New York");
  });
});
