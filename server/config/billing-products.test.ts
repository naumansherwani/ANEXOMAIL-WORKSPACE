import { describe, expect, test } from "bun:test";
import { BILLING_PRODUCTS, configuredProduct } from "./billing-products";

// Personal plans were retired on 2 Nov 2026 (founder). This guard fails if one comes back.
describe("Personal Polar products are retired", () => {
  test("no Personal product contract exists", () => {
    expect(Object.keys(BILLING_PRODUCTS).filter((k) => k.includes("PERSONAL"))).toEqual([]);
    expect(Object.values(BILLING_PRODUCTS).filter((p) => p.accountKind === "personal")).toEqual([]);
  });
  test("the old Personal keys no longer resolve", () => {
    for (const k of ["BASIC_MONTHLY", "PRO_PLUS_YEARLY", "PREMIUM_YEARLY"]) {
      expect(configuredProduct(`POLAR_PRODUCT_PLAN_PERSONAL_${k}`)).toBeNull();
    }
  });
});
