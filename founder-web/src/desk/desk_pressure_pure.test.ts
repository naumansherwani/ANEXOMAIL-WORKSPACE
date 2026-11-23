import { describe, expect, test } from "bun:test";
import { ageWords, parsePressure, parseRisk, riskWords, totalAtRisk, totalWaiting, WINDOW_NOTE } from "./desk_pressure_pure";
const q = (queue: string, n = 0, risk = 0, old: number | null = null) => ({ queue, new: n, open: 0, waiting: 0, at_risk: risk, oldest_minutes: old });
const good = () => ({ risk_window_minutes: 15, queues: [q("general"), q("support", 2, 1, 42), q("movein"), q("billing")] });
describe("queue pressure", () => {
  test("a good answer parses, in the fixed order", () => { const p = parsePressure(good())!; expect(p.map((r) => r.queue)).toEqual(["general", "support", "movein", "billing"]); expect(totalWaiting(p)).toBe(2); expect(totalAtRisk(p)).toBe(1); });
  test("fail-closed on every wrong shape", () => {
    expect(parsePressure(null)).toBeNull(); expect(parsePressure({})).toBeNull();
    expect(parsePressure({ ...good(), risk_window_minutes: 30 })).toBeNull();
    const a = good(); a.queues.pop(); expect(parsePressure(a)).toBeNull();
    const b = good(); b.queues[1].new = -1; expect(parsePressure(b)).toBeNull();
    const c = good(); (c.queues[1] as Record<string, unknown>).new = "2"; expect(parsePressure(c)).toBeNull();
    const d = good(); d.queues[0].queue = "support"; expect(parsePressure(d)).toBeNull();
    const e = good(); (e.queues[1] as Record<string, unknown>).oldest_minutes = 1.5; expect(parsePressure(e)).toBeNull();
  });
  test("age words", () => { expect(ageWords(null)).toBe("none waiting"); expect(ageWords(42)).toBe("42 min"); expect(ageWords(135)).toBe("2 h 15 min"); expect(ageWords(60 * 72)).toBe("3 days"); });
});
describe("SLA at risk", () => {
  test("parse and words", () => {
    const r = parseRisk({ risk_window_minutes: 15, cases: [{ ref: "C-000012", queue: "support", minutes_left: 10, overdue: false }, { ref: "C-000013", queue: "support", minutes_left: -5, overdue: true }] })!;
    expect(r.length).toBe(2); expect(riskWords(r[0])).toBe("10 min left to the target"); expect(riskWords(r[1])).toBe("5 min past its target");
  });
  test("fail-closed", () => {
    expect(parseRisk({ risk_window_minutes: 15, cases: [{ ref: "X1", queue: "support", minutes_left: 1, overdue: false }] })).toBeNull();
    expect(parseRisk({ risk_window_minutes: 15, cases: [{ ref: "C-000012", queue: "x", minutes_left: 1, overdue: false }] })).toBeNull();
    expect(parseRisk({ risk_window_minutes: 15, cases: Array.from({ length: 21 }, (_, i) => ({ ref: `C-${String(i).padStart(6, "0")}`, queue: "support", minutes_left: 1, overdue: false })) })).toBeNull();
    expect(parseRisk(null)).toBeNull();
  });
  test("the note never promises", () => { expect(WINDOW_NOTE).toContain("not a promise"); expect(/guarantee|definitely|refund/i.test(WINDOW_NOTE)).toBe(false); });
});
