import { expect, test } from "bun:test";
import { boardView, pct } from "./delivery_pure";
import type { DeliveryBoard } from "./mail_api";
const base = (o: Partial<DeliveryBoard> = {}): DeliveryBoard => ({ server_now: null, days: 7, total: 3, by_phase: { accepted: 2, failed: 1 }, accepted_took_seconds: { p50: 3, p95: 12 }, accepted_rate: 0.6667, deferred_rate: 0, failed_rate: 0.3333, rows: [], ...o });
test("pct never shows NaN and rounds", () => { expect(pct(0)).toBe("0%"); expect(pct(NaN)).toBe("0%"); expect(pct(0.004)).toBe("<1%"); expect(pct(0.3333)).toBe("33%"); expect(pct(1)).toBe("100%"); });
test("null or empty board = calm empty line", () => { expect(boardView(null, 0).empty).toBe(true); expect(boardView(base({ total: 0 }), 0).empty).toBe(true); });
test("tiles: only phases that exist, failed rate only when > 0", () => {
  const v = boardView(base(), 0); const ks = v.tiles.map((t) => t.k);
  expect(ks).toEqual(["Sent", "Accepted", "Failed", "Accepted rate", "Failed rate"]);
  expect(boardView(base({ failed_rate: 0, by_phase: { accepted: 3 } }), 0).tiles.map((t) => t.k)).toEqual(["Sent", "Accepted", "Accepted rate"]);
});
test("speed line is honest: accepted is not inbox; null p50 = no line", () => {
  expect(boardView(base(), 0).speed).toContain("not that it reached the inbox");
  expect(boardView(base(), 0).speed).toContain("3 seconds");
  expect(boardView(base({ accepted_took_seconds: { p50: null, p95: null } }), 0).speed).toBeNull();
});
test("rows: max 8, singular recipient, time ago, accepted shows Accepted", () => {
  const rows = Array.from({ length: 12 }, (_, i) => ({ outbox_id: "o" + i, message_id: "m" + i, phase: "accepted" as const, tone: "done" as const, final: true, rcpt: i === 0 ? 1 : 2, attempts: 1, created_at: "2026-11-20T03:00:00Z", finished_at: "2026-11-20T03:00:30Z", next_attempt: null, reason: null, last_error: null }));
  const v = boardView(base({ rows }), Date.parse("2026-11-20T03:10:30Z"));
  expect(v.rows.length).toBe(8); expect(v.rows[0].who).toBe("1 recipient"); expect(v.rows[1].who).toBe("2 recipients");
  expect(v.rows[0].word).toBe("Accepted"); expect(v.rows[0].when).toBe("10 min ago");
});
