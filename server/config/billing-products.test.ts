import { afterEach, describe, expect, test } from "bun:test";

import { BILLING_PRODUCTS, configuredProduct, productById } from "./billing-products";

const PERSONAL_ENV = [
  "POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY",
  "POLAR_PRODUCT_PLAN_PERSONAL_BASIC_YEARLY",
  "POLAR_PRODUCT_PLAN_PERSONAL_PRO_MONTHLY",
  "POLAR_PRODUCT_PLAN_PERSONAL_PRO_YEARLY",
  "POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_MONTHLY",
  "POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_YEARLY",
] as const;

afterEach(() => {
  for (const key of PERSONAL_ENV) delete process.env[key];
});

describe("Personal Polar products", () => {
  test("keeps existing Business prices unchanged", () => {
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_BASIC_MONTHLY?.amountGbp).toBe(23);
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_PRO_MONTHLY?.amountGbp).toBe(46);
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY?.amountGbp).toBe(97);
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY?.amountGbp).toBe(2850);
  });

  test("uses exact Personal monthly and yearly prices", () => {
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY?.amountGbp).toBe(17);
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_PERSONAL_BASIC_YEARLY?.amountGbp).toBe(187);
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_PERSONAL_PRO_MONTHLY?.amountGbp).toBe(83);
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_PERSONAL_PRO_YEARLY?.amountGbp).toBe(913);
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_MONTHLY?.amountGbp).toBe(1850);
    expect(BILLING_PRODUCTS.POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_YEARLY?.amountGbp).toBe(18500);
  });

  test("fails closed until a Personal Polar ID is configured", () => {
    expect(configuredProduct("POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY")).toBeNull();
  });

  test("resolves configured Personal IDs without changing the catalog", () => {
    process.env.POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY = "personal-basic-monthly-id";
    const product = configuredProduct("POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY");
    expect(product?.productId).toBe("personal-basic-monthly-id");
    expect(product?.accountKind).toBe("personal");
    expect(productById("personal-basic-monthly-id")?.plan).toBe("basic");
  });
});
