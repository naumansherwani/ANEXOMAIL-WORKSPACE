import { describe, expect, test } from "bun:test";
import { orbAlert } from "./orbalert_pure";
import type { DbscStatus } from "./dbsc_pure";
const st = (r: Partial<NonNullable<DbscStatus["report"]>>, avail = true): DbscStatus => ({ mode: "enforce", available: avail, report: { verdict: "ok", sessions_active: 1, refreshes_24h: 9, rejects_24h: 3, would_block_24h: 0, blocked_24h: 0, ...r } });
describe("orbAlert (LA-4)", () => {
  test("all clear is said out loud, even with refused proofs (key rotation is normal)", () => { const a = orbAlert(st({}))!; expect(a.tone).toBe("ok"); expect(a.text).toBe("No blocked requests in the last 24 h"); });
  test("nothing when the server did not answer", () => { expect(orbAlert(null)).toBeNull(); expect(orbAlert(st({}, false))).toBeNull(); expect(orbAlert({ mode: "enforce", available: true })).toBeNull(); });
  test("blocked is a fail", () => { const a = orbAlert(st({ blocked_24h: 2 }))!; expect(a.tone).toBe("fail"); expect(a.text).toBe("2 requests blocked in the last 24 h"); });
  test("would-block is a warn, singular", () => { const o = orbAlert({ ...st({ would_block_24h: 1 }), mode: "observe" })!; expect(o.tone).toBe("warn"); expect(o.text).toBe("1 request would have been blocked in the last 24 h"); expect(orbAlert(st({ would_block_24h: 1 }))!.text).toBe("1 request would have been blocked in the last 24 h (logged before enforcement began)"); });
  test("broken chain wins", () => { expect(orbAlert(st({ blocked_24h: 1, chain: { ok: false, checked: 5 } }))!.text).toContain("chain broken"); });
  test("garbage counters are ignored", () => { expect(orbAlert(st({ blocked_24h: NaN as number, would_block_24h: -4 }))!.tone).toBe("ok"); });
});
