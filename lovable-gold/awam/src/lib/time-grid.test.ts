import { describe, expect, test } from "bun:test";

import { packDay, snap, movedTo } from "./time-grid";

describe("time-grid", () => {
  test("snap to 15", () => {
    expect(snap(7)).toBe(0);
    expect(snap(8)).toBe(15);
    expect(snap(62)).toBe(60);
  });
  test("non-overlapping events take full width", () => {
    const p = packDay([
      { ev: "a", start: 60, end: 120 },
      { ev: "b", start: 120, end: 180 },
    ]);
    expect(p.every((x) => x.cols === 1 && x.col === 0)).toBe(true);
  });
  test("overlap splits columns", () => {
    const p = packDay([
      { ev: "a", start: 60, end: 150 },
      { ev: "b", start: 90, end: 120 },
      { ev: "c", start: 200, end: 230 },
    ]);
    const get = (k: string) => p.find((x) => x.ev === k)!;
    expect(get("a").cols).toBe(2);
    expect(get("b").cols).toBe(2);
    expect(get("a").col).not.toBe(get("b").col);
    expect(get("c").cols).toBe(1);
  });
  test("movedTo clamps and snaps", () => {
    const day = new Date(2026, 9, 21);
    const r = movedTo(day, 9 * 60, 30, 1, 22);
    const d = new Date(r.starts_at);
    expect(d.getDate()).toBe(22);
    expect(d.getHours() * 60 + d.getMinutes()).toBe(9 * 60 + 15);
    expect(r.duration_minutes).toBe(30);
    expect(new Date(movedTo(day, 10, 5, 0, -500).starts_at).getHours()).toBe(0);
  });
});
