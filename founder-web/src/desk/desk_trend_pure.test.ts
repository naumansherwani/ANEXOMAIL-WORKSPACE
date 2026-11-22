import { describe, expect, test } from "bun:test";
import { pushProbe, trendWords, sparkSegments, TREND_MAX, recordServices, trendOf, resetTrends } from "./desk_trend_pure";
const S = (age_s: number | null, ms: number | null, state = "operational") => ({ state, age_s, last_latency_ms: ms });
describe("trend", () => {
  test("a new probe adds a point, the same probe seen again (same age every tick) does not", () => {
    let t = pushProbe(undefined, S(3, 200), 100_000); t = pushProbe(t, S(3, 200), 104_000); t = pushProbe(t, S(3, 200), 108_000);   // 4 s probe, 4 s tick, age stays 3
    expect(t.pts).toEqual([200, 200, 200]);
    t = pushProbe(t, S(3, 200), 108_500); expect(t.pts.length).toBe(3);                                                  // same moment twice: no new point
    let slow = pushProbe(undefined, S(55, 276), 100_000); slow = pushProbe(slow, S(59, 276), 104_000); slow = pushProbe(slow, S(63, 276), 108_000);
    expect(slow.pts).toEqual([276]);                                                                                      // a 60 s probe seen on every tick is ONE probe
    slow = pushProbe(slow, S(2, 281), 165_000); expect(slow.pts).toEqual([276, 281]);
  });
  test("never probed adds nothing; failed or unmeasured is a gap", () => {
    expect(pushProbe(undefined, S(null, null), 1).pts).toEqual([]);
    expect(pushProbe(undefined, S(2, 50, "outage"), 10_000).pts).toEqual([null]);
    expect(pushProbe(undefined, S(2, null, "unknown"), 10_000).pts).toEqual([null]);
  });
  test("keeps only the newest 75", () => { let t = pushProbe(undefined, S(1, 1), 0); for (let i = 1; i <= 100; i++) t = pushProbe(t, S(1, i), i * 4000); expect(t.pts.length).toBe(TREND_MAX); expect(t.pts[TREND_MAX - 1]).toBe(100); });
  test("words need 6 real probes", () => {
    expect(trendWords([100, 100, 100])).toBe("Collecting");
    expect(trendWords([100, 100, 100, 100, 100, 100])).toBe("Steady");
    expect(trendWords([100, 100, 100, 100, 100, 400])).toBe("Slower than usual");
    expect(trendWords([300, 300, 300, 300, 300, 80])).toBe("Faster than usual");
    expect(trendWords([100, 100, 100, 100, 100, 100, null])).toBe("Last probe failed");
  });
  test("a gap breaks the line", () => { expect(sparkSegments([1, 2, null, 3, 4], 100, 20).length).toBe(2); expect(sparkSegments([], 100, 20)).toEqual([]); expect(sparkSegments([5, 5], 100, 20)[0].split(" ").length).toBe(2); });
  test("store feeds from services", () => { resetTrends(); recordServices([{ service: "db", label: "x", critical: true, state: "operational", age_s: 2, last_latency_ms: 150, uptime_24h: 100 }], 50_000); expect(trendOf("db")).toEqual([150]); expect(trendOf("none")).toEqual([]); });
});
