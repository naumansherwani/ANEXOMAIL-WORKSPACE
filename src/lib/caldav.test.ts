import { describe, expect, test } from "bun:test";

import { keyAge } from "./caldav";

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
