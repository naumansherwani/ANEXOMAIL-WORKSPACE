export type BillingCycle = "monthly" | "yearly";

export type BillingProduct = {
  envKey: string;
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
    kind: "plan",
    plan: "basic",
    cycle: "monthly",
    amountGbp: 23,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BASIC_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BASIC_YEARLY",
    kind: "plan",
    plan: "basic",
    cycle: "yearly",
    amountGbp: 253,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PRO_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_PRO_MONTHLY",
    kind: "plan",
    plan: "pro",
    cycle: "monthly",
    amountGbp: 46,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PRO_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_PRO_YEARLY",
    kind: "plan",
    plan: "pro",
    cycle: "yearly",
    amountGbp: 506,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY",
    kind: "plan",
    plan: "business",
    cycle: "monthly",
    amountGbp: 97,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_YEARLY",
    kind: "plan",
    plan: "business",
    cycle: "yearly",
    amountGbp: 970,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY",
    kind: "plan",
    plan: "business_pro",
    cycle: "monthly",
    amountGbp: 2850,
    perSeat: false,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY",
    kind: "plan",
    plan: "business_pro",
    cycle: "yearly",
    amountGbp: 28500,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_1_5: {
    envKey: "POLAR_PRODUCT_MOVEIN_1_5",
    kind: "movein",
    band: "1-5",
    amountGbp: 568,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_6_15: {
    envKey: "POLAR_PRODUCT_MOVEIN_6_15",
    kind: "movein",
    band: "6-15",
    amountGbp: 1670,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_16_29: {
    envKey: "POLAR_PRODUCT_MOVEIN_16_29",
    kind: "movein",
    band: "16-29",
    amountGbp: 2210,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_30PLUS: {
    envKey: "POLAR_PRODUCT_MOVEIN_30PLUS",
    kind: "movein",
    band: "30plus",
    amountGbp: 3350,
    perSeat: false,
  },
  POLAR_PRODUCT_PRIORITY_SUPPORT: {
    envKey: "POLAR_PRODUCT_PRIORITY_SUPPORT",
    kind: "support",
    cycle: "monthly",
    amountGbp: 790,
    perSeat: false,
  },
};

export function configuredProduct(key: string): (BillingProduct & { productId: string }) | null {
  const product = BILLING_PRODUCTS[key];
  const productId = product ? process.env[product.envKey] : undefined;
  return product && productId ? { ...product, productId } : null;
}

export function productById(productId: string): (BillingProduct & { productId: string }) | null {
  for (const product of Object.values(BILLING_PRODUCTS)) {
    if (process.env[product.envKey] === productId) return { ...product, productId };
  }
  return null;
}
