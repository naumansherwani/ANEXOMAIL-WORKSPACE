import { describe, expect, test } from "bun:test";
import { pushProbe, trendWords, sparkSegments, TREND_MAX, recordServices, trendOf, resetTrends } from "./desk_trend_pure";
const S = (age_s: number | null, ms: number | null, state = "operational") => ({ state, age_s, last_latency_ms: ms });
describe("trend", () => {
  test("a new probe adds a point, the same probe again does not", () => {
    let t = pushProbe(undefined, S(3, 200)); t = pushProbe(t, S(7, 200)); expect(t.pts).toEqual([200]);
    t = pushProbe(t, S(1, 210)); expect(t.pts).toEqual([200, 210]);
  });
  test("never probed adds nothing; failed or unmeasured is a gap", () => {
    expect(pushProbe(undefined, S(null, null)).pts).toEqual([]);
    expect(pushProbe(undefined, S(2, 50, "outage")).pts).toEqual([null]);
    expect(pushProbe(undefined, S(2, null, "unknown")).pts).toEqual([null]);
  });
  test("keeps only the newest 75", () => { let t = pushProbe(undefined, S(1, 1)); for (let i = 0; i < 100; i++) t = pushProbe({ ...t, lastAge: 9 }, S(1, i)); expect(t.pts.length).toBe(TREND_MAX); expect(t.pts[TREND_MAX - 1]).toBe(99); });
  test("words need 6 real probes", () => {
    expect(trendWords([100, 100, 100])).toBe("Collecting");
    expect(trendWords([100, 100, 100, 100, 100, 100])).toBe("Steady");
    expect(trendWords([100, 100, 100, 100, 100, 400])).toBe("Slower than usual");
    expect(trendWords([300, 300, 300, 300, 300, 80])).toBe("Faster than usual");
    expect(trendWords([100, 100, 100, 100, 100, 100, null])).toBe("Last probe failed");
  });
  test("a gap breaks the line", () => { expect(sparkSegments([1, 2, null, 3, 4], 100, 20).length).toBe(2); expect(sparkSegments([], 100, 20)).toEqual([]); expect(sparkSegments([5, 5], 100, 20)[0].split(" ").length).toBe(2); });
  test("store feeds from services", () => { resetTrends(); recordServices([{ service: "db", label: "x", critical: true, state: "operational", age_s: 2, last_latency_ms: 150, uptime_24h: 100 }]); expect(trendOf("db")).toEqual([150]); expect(trendOf("none")).toEqual([]); });
});
