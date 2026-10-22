import { describe, expect, test } from "bun:test";

import { agoLabel, dayStartIso, historyReady, jumpSearch, snippetParts, yearList, yearRange } from "./history";
import { jumpAnchor, validateJump } from "./calendar-jump";

const base = { q: "", person: "", from: "", to: "", order: "recent" as const };
const DAY = 86_400_000;

describe("history search (client side)", () => {
  test("ready only with 2+ letters, a person or a date", () => {
    expect(historyReady(base)).toBe(false);
    expect(historyReady({ ...base, q: "a" })).toBe(false);
    expect(historyReady({ ...base, q: "ab" })).toBe(true);
    expect(historyReady({ ...base, person: "gi" })).toBe(true);
    expect(historyReady({ ...base, from: "2020-01-01" })).toBe(true);
    expect(historyReady({ ...base, to: "2020-01-01" })).toBe(true);
  });

  test("snippet markers become text parts, never HTML", () => {
    const parts = snippetParts("go through the \u0001Contract\u0002 clauses and \u0001sign\u0002 off");
    expect(parts.map((p) => [p.text, p.hit])).toEqual([
      ["go through the ", false],
      ["Contract", true],
      [" clauses and ", false],
      ["sign", true],
      [" off", false],
    ]);
    expect(snippetParts(null)).toEqual([]);
    expect(snippetParts("<b>x</b>")[0]?.text).toBe("<b>x</b>");
  });

  test("agoLabel is plain arithmetic on the real dates", () => {
    const now = new Date("2026-10-22T12:00:00Z").getTime();
    expect(agoLabel("2026-10-22T08:00:00Z", now)).toBe("today");
    expect(agoLabel(new Date(now - 3 * DAY).toISOString(), now)).toBe("3 days ago");
    expect(agoLabel(new Date(now - 21 * DAY).toISOString(), now)).toBe("3 weeks ago");
    expect(agoLabel(new Date(now - 200 * DAY).toISOString(), now)).toBe("6 months ago");
    expect(agoLabel("2006-03-14T10:00:00Z", now)).toBe("20 years ago");
    expect(agoLabel(new Date(now + 4 * DAY).toISOString(), now)).toBe("in 4 days");
  });

  test("date inputs become local day boundaries (the end is inclusive)", () => {
    const a = new Date(dayStartIso("2024-03-10"));
    const b = new Date(dayStartIso("2024-03-10", 1));
    expect([a.getFullYear(), a.getMonth(), a.getDate(), a.getHours()]).toEqual([2024, 2, 10, 0]);
    expect([b.getFullYear(), b.getMonth(), b.getDate(), b.getHours()]).toEqual([2024, 2, 11, 0]);
  });

  test("calendar deep link: well-formed values only", () => {
    expect(validateJump({ date: "2006-03-14", event: "3f2a9c10-aaaa-bbbb-cccc-123456789012" })).toEqual({
      date: "2006-03-14",
      event: "3f2a9c10-aaaa-bbbb-cccc-123456789012",
    });
    expect(validateJump({ date: "14/03/2006", event: "<script>" })).toEqual({});
    expect(validateJump({ date: 5, event: ["x"] })).toEqual({});
    const at = jumpAnchor({ date: "2006-03-14" });
    expect([at.getFullYear(), at.getMonth(), at.getDate()]).toEqual([2006, 2, 14]);
    const j = jumpSearch({ id: "abc123", starts_at: "2006-03-14T10:00:00" });
    expect(j.date).toBe("2006-03-14");
    expect(j.event).toBe("abc123");
  });

  test("a century of history: year strip newest first, whole-year range, 100 years ago", () => {
    expect(yearList({ "1926": 1, "2090": 4, "2006": 3, "1948": 0 })).toEqual([
      { year: 2090, count: 4 },
      { year: 2006, count: 3 },
      { year: 1926, count: 1 },
    ]);
    expect(yearList(null)).toEqual([]);
    expect(yearRange(1926)).toEqual({ from: "1926-01-01", to: "1926-12-31" });
    const now = new Date("2026-10-22T12:00:00Z").getTime();
    expect(agoLabel("1926-05-01T09:00:00Z", now)).toBe("100 years ago");
    expect(agoLabel("2090-01-15T09:00:00Z", now)).toBe("in 63 years");
  });
});
