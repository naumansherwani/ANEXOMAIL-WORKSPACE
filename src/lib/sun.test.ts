import { describe, expect, it } from "bun:test";

import { project, projectClamped, unproject } from "./globe-geo";
import { dayPhase, subsolarPoint, sunAltitude, wrapLon } from "./sun";

describe("subsolarPoint", () => {
  it("is on the equator at an equinox, near the tropic at a solstice", () => {
    const eq = subsolarPoint(new Date("2026-03-20T14:46:00Z"));
    expect(Math.abs(eq.lat)).toBeLessThan(0.3);
    const jun = subsolarPoint(new Date("2026-06-21T08:24:00Z"));
    expect(jun.lat).toBeGreaterThan(23.3);
    expect(jun.lat).toBeLessThan(23.5);
    const dec = subsolarPoint(new Date("2026-12-21T20:50:00Z"));
    expect(dec.lat).toBeLessThan(-23.3);
  });
  it("sun is over Greenwich near 12:00 UTC (equation of time <= ~16 min = 4°)", () => {
    for (const d of ["2026-02-11", "2026-05-14", "2026-08-01", "2026-11-03"]) {
      const s = subsolarPoint(new Date(`${d}T12:00:00Z`));
      expect(Math.abs(s.lon)).toBeLessThan(4.2);
    }
  });
  it("moves west 15° per hour", () => {
    const a = subsolarPoint(new Date("2026-10-23T00:00:00Z")).lon;
    const b = subsolarPoint(new Date("2026-10-23T01:00:00Z")).lon;
    expect(wrapLon(a - b)).toBeGreaterThan(14.9);
    expect(wrapLon(a - b)).toBeLessThan(15.1);
  });
});

describe("day / night", () => {
  it("the sub-solar point is 90° up; the opposite side is deep night", () => {
    const d = new Date("2026-10-23T06:00:00Z");
    const s = subsolarPoint(d);
    expect(sunAltitude(s.lat, s.lon, s)).toBeGreaterThan(89.9);
    expect(sunAltitude(-s.lat, wrapLon(s.lon + 180), s)).toBeLessThan(-89.9);
  });
  it("Karachi is day at 07:00 UTC (noon local) and night at 22:00 UTC (03:00 local)", () => {
    expect(dayPhase(24.86, 67.01, new Date("2026-10-23T07:00:00Z"))).toBe("day");
    expect(dayPhase(24.86, 67.01, new Date("2026-10-23T22:00:00Z"))).toBe("night");
  });
});

describe("projection", () => {
  const c = { lat: 20, lon: 40 };
  it("centre maps to the origin and is visible", () => {
    const p = project(20, 40, c);
    expect(p.x).toBeCloseTo(0, 9);
    expect(p.y).toBeCloseTo(0, 9);
    expect(p.visible).toBe(true);
  });
  it("antipode is hidden; clamped version lands on the rim", () => {
    expect(project(-20, -140, c).visible).toBe(false);
    const q = projectClamped(-20, -140, c);
    expect(Math.hypot(q.x, q.y)).toBeCloseTo(1, 6);
  });
  it("north is up (y negative) and east is right (x positive)", () => {
    expect(project(50, 40, c).y).toBeLessThan(0);
    expect(project(20, 60, c).x).toBeGreaterThan(0);
  });
  it("unproject inverts project for visible points", () => {
    for (const [la, lo] of [
      [24.86, 67.01],
      [51.5, -0.12],
      [-33.9, 151.2],
      [35.7, 139.7],
    ] as const) {
      const p = project(la, lo, { lat: 30, lon: 70 });
      if (!p.visible) continue;
      const u = unproject(p.x, p.y, { lat: 30, lon: 70 });
      expect(u?.lat).toBeCloseTo(la, 5);
      expect(u?.lon).toBeCloseTo(lo, 5);
    }
    expect(unproject(1.2, 0, c)).toBeNull();
  });
});
