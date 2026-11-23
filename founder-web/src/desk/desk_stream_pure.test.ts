import { expect, test } from "bun:test";
import { backoffMs, chipText, fatal, overall, splitLines, STALE_MS } from "./desk_stream_pure";
test("lines split on LF, the unfinished rest waits, an endless line is refused", () => {
  expect(splitLines("a\nb\nc")).toEqual({ lines: ["a", "b"], rest: "c" });
  expect(splitLines("a\n\nb\n")).toEqual({ lines: ["a", "b"], rest: "" });
  expect(splitLines("x".repeat(300_000))).toBeNull();
});
test("backoff doubles, caps at 30 s, jitter adds at most 20 %", () => {
  expect(backoffMs(0, 0)).toBe(1000); expect(backoffMs(1, 0)).toBe(2000); expect(backoffMs(3, 0)).toBe(8000); expect(backoffMs(9, 0)).toBe(30000); expect(backoffMs(99, 0)).toBe(30000);
  expect(backoffMs(0, 0.999)).toBeLessThanOrEqual(1200); expect(backoffMs(0, -5)).toBe(1000);
});
test("the page says Live only when all four tracks have a fresh verified frame", () => {
  const now = 100_000, fresh = { summary: now - 1000, services: now - 2000, alerts: now - 500, plans: now - 700 };
  expect(overall(true, true, fresh, now)).toBe("live");
  expect(overall(true, true, { ...fresh, alerts: now - STALE_MS - 1 }, now)).toBe("stale");
  expect(overall(true, true, { summary: now }, now)).toBe("connecting");
  expect(overall(false, false, {}, now)).toBe("connecting"); expect(overall(false, true, fresh, now)).toBe("offline");
});
test("plain words, no technology on the chip; sign-out is not retried", () => {
  expect(chipText("live")).toBe("Live · verified"); expect(chipText("offline")).toContain("Offline");
  expect(fatal("ERR 401")).toBe(true); expect(fatal("ERR 401 bad_mac")).toBe(true); expect(fatal("ERR 503")).toBe(false);
});
