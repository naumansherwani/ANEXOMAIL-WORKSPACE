import { describe, expect, it } from "bun:test";

import { nearestPlace, PLACES, placeForZone, searchPlaces, isPlace } from "./places";

describe("home place", () => {
  it("every city has a real time zone and a sane position", () => {
    for (const p of PLACES) {
      expect(() => new Intl.DateTimeFormat("en-US", { timeZone: p.iana })).not.toThrow();
      expect(Math.abs(p.lat)).toBeLessThanOrEqual(90);
      expect(Math.abs(p.lon)).toBeLessThanOrEqual(180);
    }
  });
  it("Lahore's coordinates find Lahore, not Karachi", () => {
    const n = nearestPlace(31.55, 74.34)!;
    expect(n.place.city).toBe("Lahore");
    expect(n.km).toBeLessThan(10);
    expect(nearestPlace(24.9, 67.1)!.place.city).toBe("Karachi");
    expect(nearestPlace(33.7, 73.1)!.place.city).toBe("Islamabad");
  });
  it("a village near Lahore still lands on Lahore; far away is reported as far", () => {
    expect(nearestPlace(31.3, 74.1)!.place.city).toBe("Lahore");
    expect(nearestPlace(-50, -120)!.km).toBeGreaterThan(1500);
  });
  it("rejects nonsense positions", () => {
    expect(nearestPlace(NaN, 0)).toBeNull();
    expect(nearestPlace(95, 0)).toBeNull();
    expect(nearestPlace(0, 200)).toBeNull();
  });
  it("search is forgiving: prefix first, accents ignored", () => {
    expect(searchPlaces("lah")[0]!.city).toBe("Lahore");
    expect(searchPlaces("montreal")[0]!.city).toBe("Montréal");
    expect(searchPlaces("sao")[0]!.city).toBe("São Paulo");
    expect(searchPlaces("pakistan").length).toBeGreaterThan(5);
    expect(searchPlaces("   ")).toEqual([]);
    expect(searchPlaces("zzzzqq")).toEqual([]);
  });
  it("a bare zone gives its first city; unknown zone gives none", () => {
    expect(placeForZone("Asia/Karachi")!.city).toBe("Karachi");
    expect(placeForZone("Mars/Olympus")).toBeNull();
  });
  it("isPlace guards what comes back from the server", () => {
    expect(isPlace(PLACES[0])).toBe(true);
    expect(isPlace({ city: "", iana: "x", lat: 1, lon: 1 })).toBe(false);
    expect(isPlace(null)).toBe(false);
  });
});
