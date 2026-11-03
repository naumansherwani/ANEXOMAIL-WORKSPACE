import { describe, expect, test } from "bun:test";

import { cleanStep, HOUR_PX, READ_ZOOMS, stepFrom } from "./zoom-prefs";

describe("zoom prefs", () => {
  test("junk values fall back / snap to the nearest step", () => {
    expect(cleanStep(READ_ZOOMS, 100, "abc")).toBe(100);
    expect(cleanStep(READ_ZOOMS, 100, null)).toBe(100);
    expect(cleanStep(READ_ZOOMS, 100, "120")).toBe(115);
    expect(cleanStep(HOUR_PX, 52, 1000)).toBe(96);
    expect(cleanStep(HOUR_PX, 52, 1)).toBe(36);
  });
  test("steps move one notch and stop at the ends", () => {
    expect(stepFrom(READ_ZOOMS, 100, 1)).toBe(115);
    expect(stepFrom(READ_ZOOMS, 100, -1)).toBe(85);
    expect(stepFrom(READ_ZOOMS, 85, -1)).toBe(85);
    expect(stepFrom(READ_ZOOMS, 175, 1)).toBe(175);
    expect(stepFrom(HOUR_PX, 52, 1)).toBe(72);
  });
});
