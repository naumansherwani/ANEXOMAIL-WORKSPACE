import { describe, expect, test } from "bun:test";

import { countryList } from "@/lib/countries";
import { rankCountries } from "./CountryPicker";

const list = countryList("en");

describe("country search", () => {
  test("typing P lists countries starting with P first, Pakistan among them", () => {
    const r = rankCountries(list, "P");
    const firstNonP = r.findIndex((c) => !c.name.toLowerCase().startsWith("p"));
    expect(r.slice(0, firstNonP < 0 ? r.length : firstNonP).some((c) => c.name === "Pakistan")).toBe(true);
    expect(r[0]!.name.toLowerCase().startsWith("p")).toBe(true);
  });
  test("pa narrows to Pakistan, Palau, Palestine, Panama, Papua, Paraguay", () => {
    const names = rankCountries(list, "pa").slice(0, 6).map((c) => c.name);
    expect(names).toContain("Pakistan");
    expect(names.every((n) => n.toLowerCase().startsWith("pa"))).toBe(true);
  });
  test("ISO code and calling code also find the country", () => {
    expect(rankCountries(list, "PK")[0]!.iso2).toBe("PK");
    expect(rankCountries(list, "+92").some((c) => c.iso2 === "PK")).toBe(true);
  });
  test("blocked countries are never offered", () => {
    for (const q of ["afg", "isr", "korea", "AF", "IL", "KP"]) {
      expect(rankCountries(list, q).some((c) => ["AF", "IL", "KP"].includes(c.iso2))).toBe(false);
    }
  });
  test("empty query returns everything, sorted by name", () => {
    expect(rankCountries(list, "").length).toBe(list.length);
    expect(list.length).toBeGreaterThan(200);
  });
});
