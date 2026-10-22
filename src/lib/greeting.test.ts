import { describe, expect, it } from "bun:test";

import {
  browserZone,
  dayPart,
  eveningStart,
  MAX_EVENING_START,
  MIN_EVENING_START,
  preferredZone,
} from "./greeting";

// Karachi is UTC+5: 12:00Z = 17:00 local
const khi = (h: number, m = 0) => new Date(Date.UTC(2026, 9, 23, h - 5, m));

describe("greeting follows the clock", () => {
  it("fixed edges (Karachi, late October)", () => {
    const at = (h: number, m: number) => dayPart(khi(h, m), "Asia/Karachi");
    expect(at(22, 0)).toBe("night");
    expect(at(23, 59)).toBe("night");
    expect(at(0, 0)).toBe("night");
    expect(at(4, 59)).toBe("night");
    expect(at(5, 0)).toBe("morning");
    expect(at(11, 59)).toBe("morning");
    expect(at(12, 0)).toBe("afternoon");
    expect(at(16, 55)).toBe("afternoon");
    expect(at(17, 30)).toBe("evening");
    expect(at(21, 59)).toBe("evening");
  });
  it("Karachi in late October starts the evening at about 17:00 (sunset about 18:00)", () => {
    const s = eveningStart(khi(12), "Asia/Karachi");
    expect(s).toBeGreaterThanOrEqual(16 * 60 + 55);
    expect(s).toBeLessThanOrEqual(17 * 60 + 10);
  });
});

describe("greeting follows the season and the place", () => {
  const z = "Europe/Zurich";
  const winter = eveningStart(new Date(Date.UTC(2026, 11, 21, 12)), z);
  const summer = eveningStart(new Date(Date.UTC(2026, 5, 21, 12)), z);
  it("winter evening starts earlier than summer evening", () => {
    expect(winter).toBeLessThan(summer);
    expect(winter).toBe(MIN_EVENING_START);
    expect(summer).toBe(MAX_EVENING_START);
  });
  it("opposite hemisphere has opposite seasons", () => {
    const sydDec = eveningStart(new Date(Date.UTC(2026, 11, 21, 3)), "Australia/Sydney"); // Australian summer
    const sydJun = eveningStart(new Date(Date.UTC(2026, 5, 21, 3)), "Australia/Sydney"); // Australian winter
    expect(sydDec).toBeGreaterThan(sydJun);
  });
  it("always inside the allowed window", () => {
    for (const tz of [
      "Asia/Karachi",
      "Europe/Stockholm",
      "Pacific/Auckland",
      "America/Sao_Paulo",
      "Asia/Dubai",
    ]) {
      for (let mth = 0; mth < 12; mth++) {
        const s = eveningStart(new Date(Date.UTC(2026, mth, 15, 12)), tz);
        expect(s).toBeGreaterThanOrEqual(MIN_EVENING_START);
        expect(s).toBeLessThanOrEqual(MAX_EVENING_START);
        expect(s % 5).toBe(0);
      }
    }
  });
  it("unknown zone or broken zone name keeps the plain 17:00 and never throws", () => {
    expect(eveningStart(khi(12), "Mars/Olympus")).toBe(17 * 60);
    expect(() => dayPart(khi(12), "Not/AZone")).not.toThrow();
  });
});

describe("Settings zone wins over the browser's", () => {
  it("same instant, different home city, different greeting", () => {
    const at = new Date(Date.UTC(2026, 9, 23, 7, 0)); // 12:00 Karachi, 03:00 New York
    expect(dayPart(at, "Asia/Karachi")).toBe("afternoon");
    expect(dayPart(at, "America/New_York")).toBe("night");
  });
  it("saved zone is used when valid, browser's otherwise", () => {
    expect(preferredZone("Asia/Karachi")).toBe("Asia/Karachi");
    expect(preferredZone("Not/AZone")).toBe(browserZone());
    expect(preferredZone(undefined)).toBe(browserZone());
    expect(preferredZone("")).toBe(browserZone());
  });
});
