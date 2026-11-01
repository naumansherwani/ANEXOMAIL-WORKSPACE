// 4b-3 guard: the SSE parser, the merge and the backoff are pure and must never regress (wire format = what Rust live.rs sends).
import { expect, test } from "bun:test";
import { backoffMs, mergeEvents, takeFrames } from "./sse";

test("parses the exact frames the Rust server writes, keeps a partial frame for later", () => {
  const wire = "id: 0\nevent: snapshot\ndata: {\"a\":1}\n\n: hb\n\nid: 2\nevent: tick\ndata: {\"b\":2}\n\nid: 3\nevent: ti";
  const { frames, rest } = takeFrames(wire);
  expect(frames).toEqual([{ kind: "frame", id: "0", event: "snapshot", data: "{\"a\":1}" }, { kind: "comment" }, { kind: "frame", id: "2", event: "tick", data: "{\"b\":2}" }]);
  expect(rest).toBe("id: 3\nevent: ti");
  expect(takeFrames(rest + "ck\ndata: {}\n\n").frames[0]).toEqual({ kind: "frame", id: "3", event: "tick", data: "{}" });
});
test("CRLF and multi-line data are handled", () => {
  const { frames } = takeFrames("event: x\r\ndata: a\r\ndata: b\r\n\r\n");
  expect(frames).toEqual([{ kind: "frame", id: undefined, event: "x", data: "a\nb" }]);
});
test("merge keeps newest first, no duplicates, at most 20", () => {
  const ev = (id: number) => ({ id, ts: "", source: "s", kind: "change", detail: {} });
  expect(mergeEvents([ev(1), ev(2)].reverse(), [ev(2), ev(3)]).map((e) => e.id)).toEqual([3, 2, 1]);
  expect(mergeEvents([], Array.from({ length: 30 }, (_, i) => ev(i + 1))).length).toBe(20);
  expect(mergeEvents([], [{ nope: 1 } as any]).length).toBe(0);
});
test("backoff doubles from 1 s and stops at 15 s", () => {
  expect([1, 2, 3, 4, 5, 6, 9].map(backoffMs)).toEqual([1000, 2000, 4000, 8000, 15000, 15000, 15000]);
});
