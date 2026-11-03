import { describe, expect, it } from "bun:test";

import {
  buildTrip,
  holdsReminders,
  isTrip,
  tripLine,
  tripPhase,
  zonedToUtc,
  type Trip,
} from "./travel";

const trip: Trip = {
  to_city: "Tokyo",
  to_zone: "Asia/Tokyo",
  depart_at: "2026-10-23T14:00:00Z",
  arrive_at: "2026-10-23T23:00:00Z",
};
const t = (s: string) => Date.parse(s);

describe("zonedToUtc", () => {
  it("fixed-offset zones", () => {
    expect(zonedToUtc("2026-10-23T19:00", "Asia/Karachi")).toBe("2026-10-23T14:00:00Z"); // +05
    expect(zonedToUtc("2026-10-24T08:00", "Asia/Tokyo")).toBe("2026-10-23T23:00:00Z"); // +09
    expect(zonedToUtc("2026-10-23T12:00", "UTC")).toBe("2026-10-23T12:00:00Z");
    expect(zonedToUtc("2026-10-23T12:00", "Asia/Kolkata")).toBe("2026-10-23T06:30:00Z"); // +05:30
    expect(zonedToUtc("2026-10-23T12:00", "Asia/Kathmandu")).toBe("2026-10-23T06:15:00Z"); // +05:45
  });
  it("daylight saving: New York in summer (-04) and winter (-05)", () => {
    expect(zonedToUtc("2026-07-01T12:00", "America/New_York")).toBe("2026-07-01T16:00:00Z");
    expect(zonedToUtc("2026-12-01T12:00", "America/New_York")).toBe("2026-12-01T17:00:00Z");
    // 2026 DST ends 1 Nov (02:00 -> 01:00): 00:30 is still EDT (-04), 03:00 is EST (-05)
    expect(zonedToUtc("2026-11-01T00:30", "America/New_York")).toBe("2026-11-01T04:30:00Z");
    expect(zonedToUtc("2026-11-01T03:00", "America/New_York")).toBe("2026-11-01T08:00:00Z");
  });
  it("refuses nonsense", () => {
    expect(zonedToUtc("2026-02-30T10:00", "UTC")).toBeNull();
    expect(zonedToUtc("2026-13-01T10:00", "UTC")).toBeNull();
    expect(zonedToUtc("2026-10-23 10:00", "UTC")).toBeNull();
    expect(zonedToUtc("2026-10-23T10:00", "Nowhere/Land")).toBeNull();
    expect(zonedToUtc("", "UTC")).toBeNull();
  });
});

describe("phases", () => {
  it("upcoming -> transit -> landed -> over", () => {
    expect(tripPhase(trip, t("2026-10-23T13:59:59Z"))).toBe("upcoming");
    expect(tripPhase(trip, t("2026-10-23T14:00:00Z"))).toBe("transit");
    expect(tripPhase(trip, t("2026-10-23T22:59:59Z"))).toBe("transit");
    expect(tripPhase(trip, t("2026-10-23T23:00:00Z"))).toBe("landed");
    expect(tripPhase(trip, t("2026-10-25T22:59:59Z"))).toBe("landed");
    expect(tripPhase(trip, t("2026-10-25T23:00:00Z"))).toBe("over");
  });
  it("only the air time holds reminders; mail is never part of this", () => {
    expect(holdsReminders(trip, t("2026-10-23T10:00:00Z"))).toBe(false);
    expect(holdsReminders(trip, t("2026-10-23T18:00:00Z"))).toBe(true);
    expect(holdsReminders(trip, t("2026-10-23T23:30:00Z"))).toBe(false);
    expect(holdsReminders(null, t("2026-10-23T18:00:00Z"))).toBe(false);
  });
});

describe("isTrip", () => {
  it("accepts the stored shape only", () => {
    expect(isTrip(trip)).toBe(true);
    expect(isTrip({ ...trip, depart_at: "2026-10-23T14:00:00+05:00" })).toBe(false);
    expect(isTrip({ ...trip, to_city: "" })).toBe(false);
    expect(isTrip(null)).toBe(false);
    expect(isTrip("Tokyo")).toBe(false);
  });
});

describe("buildTrip", () => {
  const now = t("2026-10-23T10:00:00Z");
  it("karachi 19:00 -> tokyo 08:00 next day is a 9 h trip", () => {
    const r = buildTrip(
      {
        city: " Tokyo ",
        zone: "Asia/Tokyo",
        departLocal: "2026-10-23T19:00",
        arriveLocal: "2026-10-24T08:00",
      },
      "Asia/Karachi",
      now,
    );
    expect(r).toEqual({
      ok: true,
      trip: {
        to_city: "Tokyo",
        to_zone: "Asia/Tokyo",
        depart_at: "2026-10-23T14:00:00Z",
        arrive_at: "2026-10-23T23:00:00Z",
      },
    });
  });
  it("catches the usual mistakes with a plain sentence", () => {
    const base = {
      city: "Tokyo",
      zone: "Asia/Tokyo",
      departLocal: "2026-10-23T19:00",
      arriveLocal: "2026-10-24T08:00",
    };
    const err = (o: Partial<typeof base>) => {
      const r = buildTrip({ ...base, ...o }, "Asia/Karachi", now);
      return r.ok ? "" : r.error;
    };
    expect(err({ city: "" })).toContain("where you are going");
    expect(err({ departLocal: "" })).toContain("departure");
    expect(err({ arriveLocal: "" })).toContain("arrival");
    expect(err({ arriveLocal: "2026-10-23T18:00" })).toContain("after departure"); // 18:00 Tokyo = 09:00 UTC, before 14:00 UTC
    expect(err({ arriveLocal: "2026-11-05T08:00" })).toContain("72 hours");
    expect(err({ departLocal: "2026-10-10T19:00", arriveLocal: "2026-10-11T08:00" })).toContain(
      "48 hours ago",
    );
  });
});

describe("tripLine", () => {
  const fmt = (iso: string) => iso.slice(11, 16) + "Z";
  const fmtAt = (iso: string, z: string) => `${iso.slice(11, 16)}@${z}`;
  it("one plain sentence per phase", () => {
    expect(tripLine(trip, t("2026-10-23T10:00:00Z"), fmt, fmtAt)).toBe(
      "Trip to Tokyo · leaves 14:00Z",
    );
    expect(tripLine(trip, t("2026-10-23T18:00:00Z"), fmt, fmtAt)).toContain(
      "In transit to Tokyo · lands 23:00Z your time",
    );
    expect(tripLine(trip, t("2026-10-24T01:00:00Z"), fmt, fmtAt)).toBe(
      "Landed in Tokyo · local time 01:00@Asia/Tokyo",
    );
    expect(tripLine(trip, t("2026-11-30T00:00:00Z"), fmt, fmtAt)).toBe("");
  });
});
