import { describe, expect, test } from "bun:test";
import { FACTS, NONE_FACTS, UNKNOWN_FACTS } from "./desk_packages_pure";
import { PKGS, PKG_WORDS } from "./desk_customers_pure";
describe("package facts", () => {
  test("all six packages have facts and a name that matches the label", () => { expect(PKGS.length).toBe(6); for (const k of PKGS) { expect(FACTS[k].name).toBe(PKG_WORDS[k]); expect(FACTS[k].features.length).toBeGreaterThan(1); expect(FACTS[k].price).toContain("£"); } });
  test("Premium and Max are flagged as not yet verified, the four older ones are not", () => { expect(FACTS.business_premium.unverified && FACTS.business_max.unverified).toBe(true); expect(FACTS.basic.unverified || FACTS.pro.unverified || FACTS.business.unverified || FACTS.business_pro.unverified).toBe(false); });
  test("Max says unlimited means seats only", () => { expect(FACTS.business_max.users).toContain("seats only"); });
  test("the two non-package buckets are named in plain words", () => { expect(NONE_FACTS.name).toBe("No plan yet"); expect(PKG_WORDS.none).toBe("No plan yet"); expect(UNKNOWN_FACTS.name).toBe("Plan not recognised"); });
});
