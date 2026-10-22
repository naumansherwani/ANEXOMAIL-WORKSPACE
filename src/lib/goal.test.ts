import { describe, expect, test } from "bun:test";

import { goalTone } from "./goal";

const H = 3_600_000;
const base = { starts_at: "2026-10-22T10:00:00Z", ends_at: "2026-10-22T11:00:00Z", recurring: false, status: "confirmed" };
const t0 = new Date(base.starts_at).getTime();
const end = new Date(base.ends_at).getTime();

describe("goalTone (clock + tap, nothing else)", () => {
  test("no goal and no tap = not drawn", () => {
    expect(goalTone({ ...base, goal: null, goal_state: "open" }, t0 + H)).toBeNull();
  });
  test("open goal follows the clock: upcoming -> due -> late", () => {
    const ev = { ...base, goal: "Contract signed", goal_state: "open" as const };
    expect(goalTone(ev, t0 - 1)).toBe("upcoming");
    expect(goalTone(ev, t0)).toBe("due");
    expect(goalTone(ev, end + 24 * H - 1)).toBe("due");
    expect(goalTone(ev, end + 24 * H)).toBe("late");
  });
  test("the organiser's tap beats the clock", () => {
    expect(goalTone({ ...base, goal: "x", goal_state: "achieved" }, end + 99 * H)).toBe("achieved");
    expect(goalTone({ ...base, goal: null, goal_state: "missed" }, t0 - H)).toBe("missed");
  });
  test("repeating series and cancelled meetings are never marked", () => {
    expect(goalTone({ ...base, recurring: true, goal: "x", goal_state: "achieved" }, end)).toBeNull();
    expect(goalTone({ ...base, status: "cancelled", goal: "x" }, end)).toBeNull();
  });
});
