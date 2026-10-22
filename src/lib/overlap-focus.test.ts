import { describe, expect, test } from "bun:test";

import { focusLoad, type OverlapAssess } from "./overlap";

const a = (o: Partial<OverlapAssess>): OverlapAssess => ({
  zone: "green",
  outside_min: 0,
  day_len_min: 480,
  extra_min: 0,
  booked_min: 150,
  work_min: 480,
  ...o,
});

describe("focusLoad", () => {
  test("adds the meeting minutes that sit inside working hours", () => {
    const r = focusLoad(a({}), 60)!;
    expect(r.withMeeting).toBe(210);
    expect(r.frac).toBeCloseTo(210 / 480);
    expect(r.text).toBe("3h 30m booked of 8h with this meeting");
  });
  test("minutes outside their hours are not counted into the ring", () => {
    expect(focusLoad(a({ outside_min: 30 }), 60)!.withMeeting).toBe(180);
  });
  test("caps at a full ring", () => {
    expect(focusLoad(a({ booked_min: 470 }), 60)!.frac).toBe(1);
  });
  test("nothing honest to draw -> null", () => {
    expect(focusLoad(undefined, 30)).toBeNull();
    expect(focusLoad(a({ booked_min: null }), 30)).toBeNull();
    expect(focusLoad(a({ work_min: 0 }), 30)).toBeNull();
  });
});
