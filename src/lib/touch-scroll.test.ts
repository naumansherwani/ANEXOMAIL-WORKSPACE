import { describe, expect, test } from "bun:test";

import { pickScroller, scrollFromThumb, thumbMetrics } from "./touch-scroll";

describe("touch scroll handle", () => {
  test("hidden when nothing overflows", () => {
    expect(thumbMetrics(0, 600, 600).visible).toBe(false);
    expect(thumbMetrics(0, 610, 600).visible).toBe(false);
  });
  test("thumb tracks position and keeps a finger-sized minimum", () => {
    const top = thumbMetrics(0, 60000, 600);
    expect(top.visible).toBe(true);
    expect(top.height).toBe(48);
    expect(top.top).toBe(0);
    const end = thumbMetrics(5400, 6000, 600);
    expect(end.top + end.height).toBeCloseTo(600);
  });
  test("dragging the thumb maps back to scrollTop", () => {
    const t = thumbMetrics(2700, 6000, 600);
    expect(scrollFromThumb(t.top, 6000, 600)).toBeCloseTo(2700);
    expect(scrollFromThumb(-50, 6000, 600)).toBe(0);
    expect(scrollFromThumb(9999, 6000, 600)).toBe(5400);
  });
  test("picks the scroller with most overflow, ignoring small ones", () => {
    const pick = pickScroller(
      [
        { el: "main", overflow: 0, depth: 1, height: 700 },
        { el: "inner", overflow: 900, depth: 3, height: 650 },
        { el: "list", overflow: 5000, depth: 4, height: 100 },
      ],
      800,
    );
    expect(pick).toBe("inner");
    expect(pickScroller([], 800)).toBeNull();
  });
});
