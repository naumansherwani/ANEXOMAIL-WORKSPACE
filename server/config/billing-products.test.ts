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

  test("carries the founder-created Personal Polar IDs", () => {
    expect(configuredProduct("POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY")?.productId).toBe(
      "485fa38d-1bbd-4136-bd71-eed42121ca5d",
    );
    expect(configuredProduct("POLAR_PRODUCT_PLAN_PERSONAL_PRO_YEARLY")?.productId).toBe(
      "a93f0bf2-37aa-45f6-9a8a-fa356d37d59f",
    );
    expect(configuredProduct("POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_YEARLY")?.productId).toBe(
      "a485e76a-9338-4dfb-b680-7cc3df0adaf8",
    );
  });

  test("resolves Personal products by Polar ID and stays account-kind bound", () => {
    const product = productById("cde7edac-a9fb-4cf2-ab6a-8e4154968e52");
    expect(product?.plan).toBe("business_pro");
    expect(product?.accountKind).toBe("personal");
    expect(product?.amountGbp).toBe(1850);
  });
});
