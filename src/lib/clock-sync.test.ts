import { describe, expect, it } from "bun:test";

import { bestSample, describeDrift, latencyStats, percentile, protocolLabel } from "./clock-sync";

describe("percentiles", () => {
  it("nearest-rank", () => {
    const s = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
    expect(percentile(s, 50)).toBe(50);
    expect(percentile(s, 95)).toBe(100);
    expect(percentile(s, 0)).toBe(10);
    expect(percentile([], 50)).toBe(0);
    expect(percentile([7], 95)).toBe(7);
  });
  it("latencyStats sorts, drops junk, reports n", () => {
    const r = latencyStats([90, 10, NaN, 30, -5, 20, Infinity]);
    expect(r).toEqual({ p50: 20, p95: 90, n: 4 });
    expect(latencyStats([])).toEqual({ p50: 0, p95: 0, n: 0 });
  });
});

describe("bestSample", () => {
  it("picks the shortest round-trip, ignores junk", () => {
    const b = bestSample([
      { rttMs: 80, offsetMs: 500 },
      { rttMs: 12, offsetMs: 40 },
      { rttMs: NaN, offsetMs: 1 },
      { rttMs: 30, offsetMs: 90 },
    ]);
    expect(b).toEqual({ rttMs: 12, offsetMs: 40 });
    expect(bestSample([])).toBeNull();
    expect(bestSample([{ rttMs: -1, offsetMs: 0 }])).toBeNull();
  });
});

describe("describeDrift", () => {
  it("in sync inside one second, with the real error bar", () => {
    const d = describeDrift(-340, 11.4);
    expect(d.tone).toBe("ok");
    expect(d.text).toBe("Device clock is in sync (± 11 ms)");
    expect(describeDrift(999, 0.4).text).toBe("Device clock is in sync");
  });
  it("says fast/slow and how far", () => {
    expect(describeDrift(-4200, 20).text).toBe("Your device clock is 4.2 s fast");
    expect(describeDrift(4200, 20).text).toBe("Your device clock is 4.2 s slow");
    expect(describeDrift(-45_000, 20).text).toBe("Your device clock is 45 s fast");
    expect(describeDrift(300_000, 20).text).toBe("Your device clock is 5 min slow");
    expect(describeDrift(-4200, 20).tone).toBe("warn");
    expect(describeDrift(-4200, 20).fix).toContain("automatic date & time");
  });
});

describe("protocolLabel", () => {
  it("names what the browser negotiated", () => {
    expect(protocolLabel("h3")).toBe("HTTP/3");
    expect(protocolLabel("h2")).toBe("HTTP/2");
    expect(protocolLabel("http/1.1")).toBe("HTTP/1.1");
    expect(protocolLabel("")).toBe("");
  });
});
