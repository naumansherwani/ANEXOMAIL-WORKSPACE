import { describe, expect, test } from "bun:test";
import { TONE_HEX, orbParams, orbScale, pickRenderer, nextGfx } from "./scene_pure";

describe("L: pure decisions of the 3D layer", () => {
  test("tone colours are the cinematic ones (never changed by the renderer)", () => {
    expect(TONE_HEX).toEqual({ ok: 0x3dd598, warn: 0xf2b84b, fail: 0xef6a58, unknown: 0x6b7a99 });
  });
  test("breathing numbers per tone (same on WebGL2 and WebGPU)", () => {
    expect(orbParams("ok")).toEqual({ hz: 0.7, amp: 0.06, pulse: 0.025 });
    expect(orbParams("warn")).toEqual({ hz: 1.1, amp: 0.09, pulse: 0.025 });
    expect(orbParams("fail")).toEqual({ hz: 2.2, amp: 0.12, pulse: 0.045 });
    expect(orbParams("unknown")).toEqual({ hz: 0.5, amp: 0.06, pulse: 0.025 });
  });
  test("orb scale swings around 1 by the pulse and never leaves it", () => {
    for (const tone of ["ok", "warn", "fail", "unknown"] as const) for (let t = 0; t < 10; t += 0.137) { const s = orbScale(t, tone), p = orbParams(tone).pulse; expect(Math.abs(s - 1)).toBeLessThanOrEqual(p + 1e-12); }
    expect(orbScale(0, "ok")).toBe(1);
  });
  test("WebGPU only with an adapter AND a TSL build; else WebGL2", () => {
    expect(pickRenderer(true, true)).toBe("webgpu");
    expect(pickRenderer(false, true)).toBe("webgl");
    expect(pickRenderer(true, false)).toBe("webgl");
    expect(pickRenderer(false, false)).toBe("webgl");
  });
  test("a failing level steps down exactly one: webgpu -> webgl -> css, css stays css", () => {
    expect(nextGfx("webgpu")).toBe("webgl"); expect(nextGfx("webgl")).toBe("css"); expect(nextGfx("css")).toBe("css");
  });
});
