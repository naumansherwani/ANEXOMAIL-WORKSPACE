import { describe, expect, test } from "bun:test";

import { feedUrl, googleAddUrl, keyAge } from "./caldav";

describe("keyAge", () => {
  const now = Date.parse("2026-10-23T10:00:00Z");
  test("never used", () => {
    expect(keyAge(null, now)).toBe("Never used");
    expect(keyAge("junk", now)).toBe("Never used");
  });
  test("recent and older", () => {
    expect(keyAge("2026-10-23T09:59:30Z", now)).toBe("Used just now");
    expect(keyAge("2026-10-23T09:30:00Z", now)).toBe("Used 30 min ago");
    expect(keyAge("2026-10-23T05:00:00Z", now)).toBe("Used 5 h ago");
    expect(keyAge("2026-10-20T10:00:00Z", now)).toBe("Used 3 d ago");
  });
});

describe("calendar link helpers", () => {
  const good = "/dav/feed/abcdefghij234567abcdefghij2345.ics";
  test("feedUrl accepts only our exact shape", () => {
    expect(feedUrl(good)).toBe(`https://anexomail.com${good}`);
    expect(feedUrl("/dav/feed/short.ics")).toBe("");
    expect(feedUrl("/dav/feed/abcdefghij234567abcdefghij2341.ics")).toBe(""); // 1 is not base32
    expect(feedUrl("https://evil.example/dav/feed/abcdefghij234567abcdefghij2345.ics")).toBe("");
    expect(feedUrl(`${good}?x=1`)).toBe("");
    expect(feedUrl("")).toBe("");
  });
  test("googleAddUrl wraps the link as webcal and encodes it", () => {
    const u = feedUrl(good);
    const g = googleAddUrl(u);
    expect(g.startsWith("https://calendar.google.com/calendar/r?cid=")).toBe(true);
    expect(decodeURIComponent(g.split("cid=")[1]!)).toBe(`webcal://anexomail.com${good}`);
    expect(g.includes("https://anexomail.com")).toBe(false); // plain https never left unencoded in the query
    expect(googleAddUrl("")).toBe("");
    expect(googleAddUrl("http://anexomail.com/x.ics")).toBe("");
  });
});
