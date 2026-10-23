import { describe, expect, test } from "bun:test";

import { EXCHANGES, marketLine, marketState } from "@/lib/markets";

const ex = (c: string) => EXCHANGES.find((e) => e.code === c)!;

describe("marketState", () => {
  test("NYSE open mid-session, closes in the right time (DST aware)", () => {
    // Wed 21 Oct 2026 14:00 UTC = 10:00 EDT
    const s = marketState(ex("NYSE"), Date.UTC(2026, 9, 21, 14, 0));
    expect(s.open).toBe(true);
    expect(s.minsToChange).toBe(6 * 60);
  });
  test("NYSE before the bell", () => {
    const s = marketState(ex("NYSE"), Date.UTC(2026, 9, 21, 12, 0)); // 08:00 EDT
    expect(s.open).toBe(false);
    expect(s.minsToChange).toBe(90);
  });
  test("weekend is closed", () => {
    const s = marketState(ex("LSE"), Date.UTC(2026, 9, 24, 10, 0)); // Saturday
    expect(s.weekend).toBe(true);
    expect(marketLine(ex("LSE"), s)).toBe("LSE closed (weekend)");
  });
  test("Tokyo lunch break is closed, reopens", () => {
    const s = marketState(ex("TSE"), Date.UTC(2026, 9, 21, 3, 0)); // 12:00 JST
    expect(s.open).toBe(false);
    expect(s.minsToChange).toBe(30);
    expect(marketLine(ex("TSE"), s)).toBe("TSE closed · opens in 30 min");
  });
  test("after the close: closed, no invented next open", () => {
    const s = marketState(ex("NSE"), Date.UTC(2026, 9, 21, 12, 0)); // 17:30 IST
    expect(s.open).toBe(false);
    expect(s.minsToChange).toBeNull();
  });
});
