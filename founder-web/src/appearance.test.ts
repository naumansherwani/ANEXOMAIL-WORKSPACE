import { describe, expect, test } from "bun:test";
import { APPEARANCE_DEFAULTS, appearanceAttrs, effectiveMotion, readAppearance, TEMPO, TEXT_SIZES } from "./appearance";
import { KIND, MIN_PERIOD, at, catalogOk, effectiveRate, indexOf, paint, radix, same, step, stepSizes, totalOf, valid, type Catalog, type Recipe } from "./ambient";

const cat = (): Catalog => ({
  palettes: Array.from({ length: 120 }, (_, i) => ({ id: i, name: `P${i}`, stops: ["#112233", "#223344", "#334455"] as [string, string, string], family: "F", mood: "M" })),
  patterns: Array.from({ length: 24 }, (_, i) => ({ id: i, name: `T${i}`, motion: i !== 0, flashes_per_sec: i === 23 ? 1.2 : i === 0 ? 0 : 0.3, note: "" })),
  blends: Array.from({ length: 8 }, (_, i) => ({ id: i, name: `B${i}`, css: i === 0 ? "normal" : "screen" })),
  speeds: Array.from({ length: 20 }, (_, i) => ({ id: i, factor: Math.round(0.25 * Math.pow(8, i / 19) * 1000) / 1000 })),
  intensities: Array.from({ length: 10 }, (_, i) => ({ id: i, percent: (i + 1) * 10 })),
  seeds: 65536, total: 120 * 24 * 20 * 10 * 8 * 65536, default: { palette: 60, pattern: 1, speed: 9, intensity: 6, blend: 0, seed: 0 }, max_favourites: 24,
});
const DEF: Recipe = { palette: 60, pattern: 1, speed: 9, intensity: 6, blend: 0, seed: 0 };

describe("Appearance (same values as the user app)", () => {
  test("text sizes and tempo are the user app's", () => { expect([...TEXT_SIZES]).toEqual([90, 100, 115, 130, 150]); expect(TEMPO).toEqual({ fast: 0.6, normal: 1, slow: 1.5 }); });
  test("missing or bad values fall back to the defaults", () => {
    expect(readAppearance(undefined)).toEqual(APPEARANCE_DEFAULTS);
    expect(readAppearance({ "appearance.text_scale": 120, "appearance.animations": "off", "appearance.density": "cozy", "appearance.celebration": "yes" })).toEqual(APPEARANCE_DEFAULTS);
    expect(readAppearance({ "appearance.text_scale": 130, "appearance.animations": "none", "appearance.transitions": "slow", "appearance.celebration": false, "appearance.focus_ring": true, "appearance.density": "compact", "appearance.reduce_motion": true }))
      .toEqual({ text_scale: 130, animations: "none", transitions: "slow", celebration: false, focus_ring: true, density: "compact", reduce_motion: true });
  });
  test("the OS reduced-motion setting always wins, and never makes motion richer", () => {
    expect(effectiveMotion(APPEARANCE_DEFAULTS, true)).toBe("reduced");
    expect(effectiveMotion({ ...APPEARANCE_DEFAULTS, animations: "none" }, true)).toBe("none");
    expect(effectiveMotion({ ...APPEARANCE_DEFAULTS, reduce_motion: true }, false)).toBe("reduced");
    expect(effectiveMotion(APPEARANCE_DEFAULTS, false)).toBe("full");
  });
  test("attributes", () => { const x = appearanceAttrs({ ...APPEARANCE_DEFAULTS, text_scale: 115, focus_ring: true }, false); expect(x.zoom).toBe("1.15"); expect(x.focus).toBe("hc"); });
});

describe("Ambient Studio maths (mirrors SQL E114 and Rust ambient.rs)", () => {
  const c = cat();
  test("catalog is checked, total is the product", () => { expect(catalogOk(c)).toBe(true); expect(totalOf(c)).toBe(301_989_888_000); expect(catalogOk({ ...c, total: 5 })).toBe(false); expect(catalogOk(null)).toBe(false); });
  test("default look number and the edges match SQL", () => {
    expect(indexOf(c, DEF)).toBe(60 + 120 * 1 + 120 * 24 * 9 + 120 * 24 * 20 * 6);
    expect(at(c, 0)).toEqual({ palette: 0, pattern: 0, speed: 0, intensity: 0, blend: 0, seed: 0 });
    expect(at(c, totalOf(c) - 1)).toEqual({ palette: 119, pattern: 23, speed: 19, intensity: 9, blend: 7, seed: 65535 });
  });
  test("one number per look (round trip) and stepping wraps both ways", () => {
    for (let i = 0; i < 2000; i++) { const n = (i * 1_000_003 + 17) % totalOf(c); expect(indexOf(c, at(c, n))).toBe(n); }
    expect(step(c, DEF, 1)).toEqual({ ...DEF, palette: 61 });
    expect(step(c, { ...DEF, palette: 119 }, 1)).toEqual({ ...DEF, palette: 0, pattern: 2 });
    expect(same(step(c, step(c, DEF, 37), -37), DEF)).toBe(true);
    expect(step(c, at(c, totalOf(c) - 1), 1)).toEqual(at(c, 0));
    expect(step(c, at(c, 0), -1)).toEqual(at(c, totalOf(c) - 1));
    expect(stepSizes(c)).toEqual({ palette: 1, pattern: 120, speed: 2880 });
  });
  test("validation is strict", () => {
    expect(valid(c, DEF)).toBe(true);
    expect(valid(c, { ...DEF, palette: 120 })).toBe(false); expect(valid(c, { ...DEF, palette: 1.5 })).toBe(false); expect(valid(c, { ...DEF, seed: 65536 })).toBe(false);
    expect(valid(c, { ...DEF, extra: 1 })).toBe(false); expect(valid(c, null)).toBe(false); expect(valid(c, "x")).toBe(false);
  });
  test("photosensitivity: no pattern at any speed flashes more than twice a second, and no cycle is shorter than half a second", () => {
    for (let t = 0; t < 24; t++) for (let s = 0; s < 20; s++) {
      expect(effectiveRate(c, { ...DEF, pattern: t, speed: s })).toBeLessThanOrEqual(2);
      const p = paint(c, { ...DEF, pattern: t, speed: s }, "full"); if (!p.still) expect(parseFloat(p.vars["--per"])).toBeGreaterThanOrEqual(MIN_PERIOD);
    }
    expect(effectiveRate(c, { ...DEF, pattern: 23, speed: 19 })).toBe(2);
    expect(KIND.length).toBe(24);
  });
  test("still, 'none' motion and reduced motion are calm", () => {
    expect(paint(c, { ...DEF, pattern: 0 }, "full").still).toBe(true);
    expect(paint(c, DEF, "none").still).toBe(true);
    expect(paint(c, { ...DEF, pattern: 6 }, "reduced").kind).toBe("breathe");
    expect(paint(c, DEF, "full").vars["--op"]).toBe("0.7");
    expect(radix(c).Z).toBe(65536);
  });
});
