export type BillingCycle = "monthly" | "yearly";

export type BillingProduct = {
  envKey: string;
  productId: string;
  kind: "plan" | "movein" | "support";
  plan?: string;
  band?: string;
  cycle?: BillingCycle;
  amountGbp: number;
  perSeat: boolean;
};

export const BILLING_PRODUCTS: Record<string, BillingProduct> = {
  POLAR_PRODUCT_PLAN_BASIC_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_BASIC_MONTHLY",
    productId: "5e1c7b50-fee5-4214-873c-ad9f350476d9",
    kind: "plan",
    plan: "basic",
    cycle: "monthly",
    amountGbp: 23,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BASIC_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BASIC_YEARLY",
    productId: "d3642ce7-a750-484c-940f-eb39039ed9c2",
    kind: "plan",
    plan: "basic",
    cycle: "yearly",
    amountGbp: 253,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PRO_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_PRO_MONTHLY",
    productId: "df1aa320-346f-451b-a16a-e737c0703e12",
    kind: "plan",
    plan: "pro",
    cycle: "monthly",
    amountGbp: 46,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PRO_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_PRO_YEARLY",
    productId: "7d87a72e-6be6-4aa2-86d6-5eca3d448956",
    kind: "plan",
    plan: "pro",
    cycle: "yearly",
    amountGbp: 506,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY",
    productId: "b12be1b1-a02d-4701-9475-08e796d99b69",
    kind: "plan",
    plan: "business",
    cycle: "monthly",
    amountGbp: 97,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_YEARLY",
    productId: "7a1d5445-92c5-4472-81a3-4820b8579854",
    kind: "plan",
    plan: "business",
    cycle: "yearly",
    amountGbp: 970,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY",
    productId: "3a1e1699-59c0-4334-8be0-d4b08a1202d1",
    kind: "plan",
    plan: "business_pro",
    cycle: "monthly",
    amountGbp: 2850,
    perSeat: false,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY",
    productId: "80bca014-b832-474e-bd3e-084a04453de0",
    kind: "plan",
    plan: "business_pro",
    cycle: "yearly",
    amountGbp: 28500,
    perSeat: false,
  },
  // ── Personal plans (alag Polar products — personal-tiers.ts) ────────────
  POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY",
    productId: "485fa38d-1bbd-4136-bd71-eed42121ca5d",
    kind: "plan",
    plan: "basic",
    cycle: "monthly",
    amountGbp: 17,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PERSONAL_BASIC_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_PERSONAL_BASIC_YEARLY",
    productId: "e4913e6d-4667-4979-a131-60acc429ec53",
    kind: "plan",
    plan: "basic",
    cycle: "yearly",
    amountGbp: 187,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PERSONAL_PRO_PLUS_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_PERSONAL_PRO_PLUS_MONTHLY",
    productId: "320a2cab-4ae8-47c9-8469-3bae6e342f59",
    kind: "plan",
    plan: "pro",
    cycle: "monthly",
    amountGbp: 83,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PERSONAL_PRO_PLUS_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_PERSONAL_PRO_PLUS_YEARLY",
    productId: "a93f0bf2-37aa-45f6-9a8a-fa356d37d59f",
    kind: "plan",
    plan: "pro",
    cycle: "yearly",
    amountGbp: 913,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_MONTHLY",
    productId: "cde7edac-a9fb-4cf2-ab6a-8e4154968e52",
    kind: "plan",
    plan: "business_pro",
    cycle: "monthly",
    amountGbp: 1850,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_YEARLY",
    productId: "a485e76a-9338-4dfb-b680-7cc3df0adaf8",
    kind: "plan",
    plan: "business_pro",
    cycle: "yearly",
    amountGbp: 18500,
    perSeat: true,
  },
  POLAR_PRODUCT_MOVEIN_1_5: {
    envKey: "POLAR_PRODUCT_MOVEIN_1_5",
    productId: "fdcdabc2-9e50-4e4b-91d4-45e4128ef829",
    kind: "movein",
    band: "1-5",
    amountGbp: 568,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_6_15: {
    envKey: "POLAR_PRODUCT_MOVEIN_6_15",
    productId: "a9d1bec3-0d5f-4b9b-ae1c-993efde66da2",
    kind: "movein",
    band: "6-15",
    amountGbp: 1670,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_16_29: {
    envKey: "POLAR_PRODUCT_MOVEIN_16_29",
    productId: "c7b502c5-ff75-4138-b34d-25d94878fe79",
    kind: "movein",
    band: "16-29",
    amountGbp: 2210,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_30PLUS: {
    envKey: "POLAR_PRODUCT_MOVEIN_30PLUS",
    productId: "f3ff5002-b55f-45b5-b0b9-d80c1f33d3c8",
    kind: "movein",
    band: "30plus",
    amountGbp: 3350,
    perSeat: false,
  },
  POLAR_PRODUCT_PRIORITY_SUPPORT: {
    envKey: "POLAR_PRODUCT_PRIORITY_SUPPORT",
    productId: "8f6d7c8e-1722-421f-b28c-2a031f63731d",
    kind: "support",
    cycle: "monthly",
    amountGbp: 790,
    perSeat: false,
  },
};

export function configuredProduct(key: string): BillingProduct | null {
  const product = BILLING_PRODUCTS[key];
  if (!product) return null;
  const configuredId = process.env[product.envKey];
  if (configuredId && configuredId !== product.productId) return null;
  return product;
}

export function productById(productId: string): BillingProduct | null {
  for (const product of Object.values(BILLING_PRODUCTS)) {
    if (product.productId === productId) return product;
  }
  return null;
}
