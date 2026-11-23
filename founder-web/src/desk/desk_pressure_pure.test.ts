import { describe, expect, test } from "bun:test";
import { ageWords, clearWords, LEVEL_WORDS, paceWords, parsePressure, parseRisk, riskWords, sparkScale, summaryWords, totalAtRisk, totalWaiting, TREND_WORDS, WINDOW_NOTE } from "./desk_pressure_pure";
const q = (queue: string, n = 0, risk = 0, readable = true) => ({ queue, readable, new: n, open: 0, waiting: 0, at_risk: risk, oldest_minutes: n ? 42 : null, arrived_60m: n, answered_60m: 0, ages: [n, 0, 0, 0, 0],
  spark: [null, null, null, null, null, null, null, null, null, null, 1, n], trend: readable ? "steady" : "unknown", clear_minutes: null, level: readable ? (risk >= 3 ? "overloaded" : "calm") : "none" });
const good = () => ({ risk_window_minutes: 15, queues: [q("general"), q("support", 4, 3), q("movein", 0, 0, false), q("billing", 0, 0, false)] });
describe("queue pressure", () => {
  test("a good answer parses, in the fixed order", () => { const p = parsePressure(good())!; expect(p.map((r) => r.queue)).toEqual(["general", "support", "movein", "billing"]); expect(totalWaiting(p)).toBe(4); expect(totalAtRisk(p)).toBe(3); expect(p[1].level).toBe("overloaded"); expect(p[2].readable).toBe(false); });
  test("the summary counts only what the person may read", () => { expect(summaryWords(parsePressure(good())!)).toBe("4 cases waiting, 3 at risk."); const none = good(); none.queues = none.queues.map((r) => q(r.queue, 0, 0, false)); expect(summaryWords(parsePressure(none)!)).toBe("No queue is yours to see."); });
  test("fail-closed on every wrong shape", () => {
    expect(parsePressure(null)).toBeNull(); expect(parsePressure({})).toBeNull();
    expect(parsePressure({ ...good(), risk_window_minutes: 30 })).toBeNull();
    const a = good(); a.queues.pop(); expect(parsePressure(a)).toBeNull();
    const b = good(); b.queues[1].new = -1; expect(parsePressure(b)).toBeNull();
    const c = good(); (c.queues[1] as Record<string, unknown>).new = "2"; expect(parsePressure(c)).toBeNull();
    const d = good(); d.queues[0].queue = "support"; expect(parsePressure(d)).toBeNull();
    const e = good(); (e.queues[1] as Record<string, unknown>).oldest_minutes = 1.5; expect(parsePressure(e)).toBeNull();
    const f = good(); (f.queues[1] as Record<string, unknown>).level = "panic"; expect(parsePressure(f)).toBeNull();
    const g = good(); (g.queues[2] as Record<string, unknown>).level = "calm"; expect(parsePressure(g)).toBeNull();
    const h = good(); (h.queues[1] as Record<string, unknown>).ages = [1, 2]; expect(parsePressure(h)).toBeNull();
    const i = good(); (i.queues[1] as Record<string, unknown>).spark = [1]; expect(parsePressure(i)).toBeNull();
    const k = good(); (k.queues[1] as Record<string, unknown>).trend = "up"; expect(parsePressure(k)).toBeNull();
    const l = good(); (l.queues[1] as Record<string, unknown>).clear_minutes = 0; expect(parsePressure(l)).toBeNull();
  });
  test("age, pace, clear-time and trend words never promise", () => {
    expect(ageWords(null)).toBe("none waiting"); expect(ageWords(42)).toBe("42 min"); expect(ageWords(135)).toBe("2 h 15 min"); expect(ageWords(60 * 72)).toBe("3 days");
    expect(clearWords(null)).toContain("needs at least 3 answers"); expect(clearWords(90)).toBe("About 1 h 30 min at the pace of the last hour. An estimate, not a promise.");
    expect(paceWords(parsePressure(good())!.find((r) => r.queue === "support")!)).toBe("4 came in, 0 answered in the last hour");
    for (const w of [...Object.values(LEVEL_WORDS), ...Object.values(TREND_WORDS), clearWords(5), WINDOW_NOTE]) expect(/guarantee|definitely|refund|promise you/i.test(w)).toBe(false);
  });
  test("the sparkline scales to its largest point and keeps gaps", () => { expect(sparkScale([null, 2, 4, 0])).toEqual([null, 0.5, 1, 0]); expect(sparkScale([null, null])).toEqual([null, null]); });
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
