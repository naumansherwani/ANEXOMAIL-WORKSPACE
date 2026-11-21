import { describe, expect, test } from "bun:test";
import { greeting, parseWhen, remaining } from "./DeskShell";

describe("desk shell pure helpers", () => {
  test("parses the Postgres time with a short offset", () => { const d = parseWhen("2026-11-22 13:58:12.54123+05"); expect(d?.toISOString()).toBe("2026-11-22T08:58:12.541Z"); });
  test("garbage gives null, not a wrong date", () => { expect(parseWhen("not a time")).toBeNull(); });
  test("remaining time in hours and minutes", () => { const e = new Date("2026-11-22T10:00:00Z"); expect(remaining(e, Date.parse("2026-11-22T08:18:00Z"))).toBe("1 h 42 min"); expect(remaining(e, Date.parse("2026-11-22T09:30:00Z"))).toBe("30 min"); expect(remaining(e, Date.parse("2026-11-22T10:00:00Z"))).toBe("ended"); });
  test("greeting by hour", () => { expect(greeting(8)).toBe("Good morning"); expect(greeting(13)).toBe("Good afternoon"); expect(greeting(20)).toBe("Good evening"); });
});
