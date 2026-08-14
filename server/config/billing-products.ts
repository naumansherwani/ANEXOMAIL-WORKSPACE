export type BillingCycle = "monthly" | "yearly";

export type BillingProduct = {
  envKey: string;
  kind: "plan" | "ai_plan" | "movein" | "support";
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
    amountGbp: 20,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BASIC_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BASIC_YEARLY",
    kind: "plan",
    plan: "basic",
    cycle: "yearly",
    amountGbp: 216,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PRO_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_PRO_MONTHLY",
    kind: "plan",
    plan: "pro",
    cycle: "monthly",
    amountGbp: 40,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_PRO_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_PRO_YEARLY",
    kind: "plan",
    plan: "pro",
    cycle: "yearly",
    amountGbp: 432,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_MONTHLY",
    kind: "plan",
    plan: "business",
    cycle: "monthly",
    amountGbp: 85,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_YEARLY",
    kind: "plan",
    plan: "business",
    cycle: "yearly",
    amountGbp: 850,
    perSeat: true,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_PRO_MONTHLY",
    kind: "plan",
    plan: "business_pro",
    cycle: "monthly",
    amountGbp: 2500,
    perSeat: false,
  },
  POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY: {
    envKey: "POLAR_PRODUCT_PLAN_BUSINESS_PRO_YEARLY",
    kind: "plan",
    plan: "business_pro",
    cycle: "yearly",
    amountGbp: 25000,
    perSeat: false,
  },
  POLAR_PRODUCT_AI_PRO_MONTHLY: {
    envKey: "POLAR_PRODUCT_AI_PRO_MONTHLY",
    kind: "ai_plan",
    plan: "ai_pro",
    cycle: "monthly",
    amountGbp: 400,
    perSeat: false,
  },
  POLAR_PRODUCT_AI_PRO_YEARLY: {
    envKey: "POLAR_PRODUCT_AI_PRO_YEARLY",
    kind: "ai_plan",
    plan: "ai_pro",
    cycle: "yearly",
    amountGbp: 4000,
    perSeat: false,
  },
  POLAR_PRODUCT_AI_BUSINESS_MONTHLY: {
    envKey: "POLAR_PRODUCT_AI_BUSINESS_MONTHLY",
    kind: "ai_plan",
    plan: "ai_business",
    cycle: "monthly",
    amountGbp: 1500,
    perSeat: false,
  },
  POLAR_PRODUCT_AI_BUSINESS_YEARLY: {
    envKey: "POLAR_PRODUCT_AI_BUSINESS_YEARLY",
    kind: "ai_plan",
    plan: "ai_business",
    cycle: "yearly",
    amountGbp: 15000,
    perSeat: false,
  },
  POLAR_PRODUCT_AI_EXECUTIVE_MONTHLY: {
    envKey: "POLAR_PRODUCT_AI_EXECUTIVE_MONTHLY",
    kind: "ai_plan",
    plan: "ai_executive",
    cycle: "monthly",
    amountGbp: 4000,
    perSeat: false,
  },
  POLAR_PRODUCT_AI_EXECUTIVE_YEARLY: {
    envKey: "POLAR_PRODUCT_AI_EXECUTIVE_YEARLY",
    kind: "ai_plan",
    plan: "ai_executive",
    cycle: "yearly",
    amountGbp: 40000,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_1_5: {
    envKey: "POLAR_PRODUCT_MOVEIN_1_5",
    kind: "movein",
    band: "1-5",
    amountGbp: 500,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_6_15: {
    envKey: "POLAR_PRODUCT_MOVEIN_6_15",
    kind: "movein",
    band: "6-15",
    amountGbp: 1500,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_16_29: {
    envKey: "POLAR_PRODUCT_MOVEIN_16_29",
    kind: "movein",
    band: "16-29",
    amountGbp: 2000,
    perSeat: false,
  },
  POLAR_PRODUCT_MOVEIN_30PLUS: {
    envKey: "POLAR_PRODUCT_MOVEIN_30PLUS",
    kind: "movein",
    band: "30plus",
    amountGbp: 3000,
    perSeat: false,
  },
  POLAR_PRODUCT_PRIORITY_SUPPORT: {
    envKey: "POLAR_PRODUCT_PRIORITY_SUPPORT",
    kind: "support",
    cycle: "monthly",
    amountGbp: 700,
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
