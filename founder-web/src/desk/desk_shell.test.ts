import { describe, expect, test } from "bun:test";
import { greeting, orderNav, parseWhen, remaining } from "./DeskShell";

describe("desk shell pure helpers", () => {
  test("parses the Postgres time with a short offset", () => { const d = parseWhen("2026-11-22 13:58:12.54123+05"); expect(d?.toISOString()).toBe("2026-11-22T08:58:12.541Z"); });
  test("garbage gives null, not a wrong date", () => { expect(parseWhen("not a time")).toBeNull(); });
  test("remaining time in hours and minutes", () => { const e = new Date("2026-11-22T10:00:00Z"); expect(remaining(e, Date.parse("2026-11-22T08:18:00Z"))).toBe("1 h 42 min"); expect(remaining(e, Date.parse("2026-11-22T09:30:00Z"))).toBe("30 min"); expect(remaining(e, Date.parse("2026-11-22T10:00:00Z"))).toBe("ended"); });
  test("greeting by hour", () => { expect(greeting(8)).toBe("Good morning"); expect(greeting(13)).toBe("Good afternoon"); expect(greeting(20)).toBe("Good evening"); });
  test("pinned items float to a Pinned group and unpinning puts them back", () => {
    const it = [{ key: "dashboard", group: "" }, { key: "inboxes", group: "A" }, { key: "cases", group: "B" }] as unknown as Parameters<typeof orderNav>[0];
    expect(orderNav(it, ["cases"]).map((g) => g.label)).toEqual(["", "Pinned", "A"]);
    expect(orderNav(it, []).map((g) => g.label)).toEqual(["", "A", "B"]);
    expect(orderNav(it, ["dashboard"]).some((g) => g.label === "Pinned")).toBe(false);
  });
});
