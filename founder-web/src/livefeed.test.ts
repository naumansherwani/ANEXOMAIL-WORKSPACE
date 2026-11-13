// 4b-3 guard: the change merge and the backoff are pure and must never regress (wire format = what Rust live.rs sends).
import { expect, test } from "bun:test";
import { backoffMs, mergeEvents } from "./livemerge";

test("merge keeps newest first, no duplicates, at most 20", () => {
  const ev = (id: number) => ({ id, ts: "", source: "s", kind: "change", detail: {} });
  expect(mergeEvents([ev(1), ev(2)].reverse(), [ev(2), ev(3)]).map((e) => e.id)).toEqual([3, 2, 1]);
  expect(mergeEvents([], Array.from({ length: 30 }, (_, i) => ev(i + 1))).length).toBe(20);
  expect(mergeEvents([], [{ nope: 1 } as any]).length).toBe(0);
});
test("backoff doubles from 1 s and stops at 15 s", () => {
  expect([1, 2, 3, 4, 5, 6, 9].map(backoffMs)).toEqual([1000, 2000, 4000, 8000, 15000, 15000, 15000]);
});
