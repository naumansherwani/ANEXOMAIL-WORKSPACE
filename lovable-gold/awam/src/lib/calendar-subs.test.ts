import { describe, expect, it } from "bun:test";

import {
  externalId,
  isExternalId,
  lastDay,
  localMidnightIso,
  lookup,
  mergeEvents,
  subStatus,
  toCalendarEvent,
  type CalendarSub,
  type SubEvent,
} from "./calendar-subs";
import type { CalendarEvent } from "./calendar";

const ev = (over: Partial<SubEvent> = {}): SubEvent => ({
  sub_id: "s1",
  sub_name: "PSL",
  color: "#112233",
  uid: "u~1",
  title: "Match",
  location: "Karachi",
  description: "",
  start: "2026-11-01T15:00:00Z",
  end: "2026-11-01T16:30:00Z",
  all_day: false,
  ...over,
});
const sub = (over: Partial<CalendarSub> = {}): CalendarSub => ({
  id: "s1",
  name: "PSL",
  host: "x.example.com",
  color: "#112233",
  enabled: true,
  refresh_minutes: 60,
  last_ok_at: null,
  last_fetch_at: null,
  last_error: null,
  fail_count: 0,
  event_count: 0,
  ...over,
});

describe("calendar subscriptions (client)", () => {
  it("outside ids are recognisable and stable", () => {
    const id = externalId(ev());
    expect(isExternalId(id)).toBe(true);
    expect(isExternalId("abc~123")).toBe(false);
    expect(id).toBe(externalId(ev()));
    expect(externalId(ev({ start: "2026-11-08T15:00:00Z" }))).not.toBe(id);
    expect(id.split("~").length).toBe(4); // ext, sub, uid ("~" replaced), start
  });

  it("maps to a read-only calendar row", () => {
    const row = toCalendarEvent(ev({ title: "" }));
    expect(row.title).toBe("(no title)");
    expect(row.attendees).toEqual([]);
    expect(row.calendar_key).toBe("ext:s1");
    expect(row.conflict).toBe(false);
  });

  it("merges in time order and never touches our own events", () => {
    const own = [
      { id: "a", starts_at: "2026-11-01T10:00:00Z" } as CalendarEvent,
      { id: "c", starts_at: "2026-11-01T20:00:00Z" } as CalendarEvent,
    ];
    const merged = mergeEvents(own, [ev()]);
    expect(merged.map((e) => e.id[0])).toEqual(["a", "e", "c"]);
    expect(mergeEvents(own, [])).toBe(own);
  });

  it("finds an event by its id", () => {
    const e = ev();
    expect(lookup([e], externalId(e))).toBe(e);
    expect(lookup([e], "ext~nope")).toBeUndefined();
  });

  it("describes status in plain words", () => {
    const now = Date.parse("2026-11-01T12:00:00Z");
    expect(subStatus(sub(), now)).toBe("Waiting for the first update");
    expect(subStatus(sub({ last_ok_at: "2026-11-01T11:55:00Z" }), now)).toBe("Updated 5 min ago");
    expect(subStatus(sub({ last_ok_at: "2026-11-01T09:00:00Z" }), now)).toBe("Updated 3 h ago");
    expect(subStatus(sub({ last_ok_at: "2026-10-29T12:00:00Z" }), now)).toBe("Updated 3 d ago");
    expect(
      subStatus(sub({ last_error: "feed_not_found", last_ok_at: "2026-11-01T11:00:00Z" }), now),
    ).toContain("failed");
    expect(subStatus(sub({ enabled: false }), now)).toBe("Paused");
    expect(
      subStatus(sub({ enabled: false, last_error: "disabled_too_many_failures" }), now),
    ).toContain("kept failing");
  });

  it("all-day dates: last day is inclusive, single day shows once", () => {
    expect(lastDay("2026-10-20", "2026-10-21")).toBe("2026-10-20");
    expect(lastDay("2026-12-01", "2026-12-03")).toBe("2026-12-02");
    expect(lastDay("2026-12-31", "2027-01-01")).toBe("2026-12-31");
    expect(lastDay("2026-10-20")).toBe("2026-10-20");
    expect(lastDay("2026-10-20", "2026-10-20")).toBe("2026-10-20");
  });

  it("an all-day event sits on the viewer's own calendar day, in any time zone", () => {
    const iso = localMidnightIso("2026-10-20");
    expect(iso).not.toBeNull();
    const d = new Date(iso as string);
    expect([d.getFullYear(), d.getMonth() + 1, d.getDate()]).toEqual([2026, 10, 20]);
    expect(localMidnightIso("nope")).toBeNull();
    const row = toCalendarEvent(
      ev({
        all_day: true,
        date: "2026-10-20",
        end_date: "2026-10-21",
        start: "2026-10-20T00:00:00Z",
        end: "2026-10-21T00:00:00Z",
      }),
    );
    const s = new Date(row.starts_at);
    expect([s.getFullYear(), s.getMonth() + 1, s.getDate(), s.getHours()]).toEqual([
      2026, 10, 20, 0,
    ]);
  });
});
