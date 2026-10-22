import { describe, expect, test } from "bun:test";

import { collectFingerprint, groupHash, hasNoise, NOISY } from "./device-fingerprint";

describe("device fingerprint (E70)", () => {
  test("groupHash: 64 hex, deterministic", async () => {
    const a = await groupHash("hw", [8, 16, 0, "Win32", 1920, 1080]);
    expect(a).toMatch(/^[0-9a-f]{64}$/);
    expect(await groupHash("hw", [8, 16, 0, "Win32", 1920, 1080])).toBe(a);
  });
  test("groupHash: group label separates identical inputs (all five groups differ)", async () => {
    const p = ["x", 1];
    const all = await Promise.all((["hw", "gpu", "font", "gfx", "env"] as const).map((g) => groupHash(g, p)));
    expect(new Set(all).size).toBe(5);
  });
  test("groupHash: order and boundaries matter, null is 'na' (no accidental collision)", async () => {
    expect(await groupHash("hw", ["a", "b"])).not.toBe(await groupHash("hw", ["b", "a"]));
    expect(await groupHash("hw", ["ab", "c"])).not.toBe(await groupHash("hw", ["a", "bc"]));
    expect(await groupHash("hw", [null, 1])).toBe(await groupHash("hw", [undefined, 1]));
    expect(await groupHash("hw", [null])).not.toBe(await groupHash("hw", [""]));
  });
  test("a tiny change in one trait changes the digest", async () => {
    expect(await groupHash("env", ["Asia/Karachi", "en-GB"])).not.toBe(await groupHash("env", ["Asia/Karachi", "en-US"]));
  });
  test("noise marker: any noisy component marks the group noisy", () => {
    expect(hasNoise(["a", NOISY, null])).toBe(true);
    expect(hasNoise(["a", null, 3])).toBe(false);
  });
  test("no browser => null, never throws (SSR / tests)", async () => {
    expect(await collectFingerprint()).toBeNull();
  });
});
