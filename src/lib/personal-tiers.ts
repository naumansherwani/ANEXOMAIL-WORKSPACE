/**
 * Personal account tier display — what each personal Polar SKU means.
 *
 * plans.ts NO-TOUCH. This file is a read/display layer only.
 * Personal kind ≠ Business kind. Checkout ke baad onboarding decides kind.
 *
 * Personal Polar products (alag from workspace/business plans):
 *   Personal Basic   → £17  /user/month  (POLAR_PRODUCT_PLAN_PERSONAL_BASIC_*)
 *   Personal Pro+    → £83  /user/month  (POLAR_PRODUCT_PLAN_PERSONAL_PRO_PLUS_*)
 *   Personal Premium → £1,850/user/month (POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_*)
 *
 * Feature gates (plan-surface.ts) — every line below must stay true to them:
 *   basic        → Personal Basic   — Dashboard, Mail, People, Calendar, Work. NO Domains
 *                  (so no company address / aliases / extra mailboxes), NO CRM, NO Chat, NO Org.
 *   pro          → Personal Pro+    — + CRM, ANEXOChat, video, pro mail tools. Still no Domains/Org.
 *   business_pro → Personal Premium — same power + 1TB pooled / 5GB file / advanced features
 * Storage numbers come from sql/phase48_storage_quota.sql (basic 5GB, pro 10GB, business_pro 1TB pooled).
 * A Personal account is one person: no teammates, so no shared inbox, no thread ownership, no company address.
 */

export type PersonalTierId = "personal_basic" | "personal_pro" | "personal_premium";

export type PersonalTier = {
  id: PersonalTierId;
  name: string;
  /** Polar plan-surface tier (for feature gates) */
  polarPlanId: "basic" | "pro" | "business_pro";
  /** billing-products.ts env key — monthly */
  productKeyMonthly: string;
  /** billing-products.ts env key — yearly */
  productKeyYearly: string;
  /** Monthly price in £ */
  monthly: number;
  /** Yearly total in £ */
  yearly: number;
  yearlyRule: "one-month-free" | "two-months-free";
  unit: string;
  tagline: string;
  badge?: string;
  features: string[];
};

export const PERSONAL_TIERS: PersonalTier[] = [
  {
    id: "personal_basic",
    name: "Personal Basic",
    polarPlanId: "basic",
    productKeyMonthly: "POLAR_PRODUCT_PLAN_PERSONAL_BASIC_MONTHLY",
    productKeyYearly: "POLAR_PRODUCT_PLAN_PERSONAL_BASIC_YEARLY",
    monthly: 17,
    yearly: 187,
    yearlyRule: "one-month-free",
    unit: "for one person",
    tagline: "One private inbox that is simply yours — no company setup.",
    features: [
      "Your own @anexomail.com address",
      "5 GB of mail storage",
      "Undo send — 30 seconds to change your mind",
      "Contacts and a full calendar — invites with replies, booking page, world clocks",
      "A simple task list in Work",
      "One search box for your mail and contacts",
      "Works on phone, tablet and laptop",
      "Email support — we reply within 72 hours",
    ],
  },
  {
    id: "personal_pro",
    name: "Personal Pro+",
    polarPlanId: "pro",
    productKeyMonthly: "POLAR_PRODUCT_PLAN_PERSONAL_PRO_PLUS_MONTHLY",
    productKeyYearly: "POLAR_PRODUCT_PLAN_PERSONAL_PRO_PLUS_YEARLY",
    monthly: 83,
    yearly: 913,
    yearlyRule: "one-month-free",
    unit: "for one person",
    tagline: "Professionals who need the full communication stack — no company account.",
    features: [
      "Everything in Personal Basic",
      "10 GB of mail storage",
      "Snooze & schedule send",
      "Email templates",
      "Work — boards, notes, tasks & thread analytics",
      "Full CRM — leads, pipeline, contacts intelligence",
      "ANEXOChat — full access",
      "ANEXOVideoCall with screen share",
      "Email support — we reply within 48 hours",
    ],
  },
  {
    id: "personal_premium",
    name: "Personal Premium",
    polarPlanId: "business_pro",
    productKeyMonthly: "POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_MONTHLY",
    productKeyYearly: "POLAR_PRODUCT_PLAN_PERSONAL_PREMIUM_YEARLY",
    monthly: 1850,
    yearly: 18500,
    yearlyRule: "two-months-free",
    unit: "for one person",
    tagline: "Maximum communication stack for a professional — every feature, no company seat.",
    badge: "Most complete",
    features: [
      "Everything in Personal Pro+",
      "1 TB of pooled storage",
      "5GB max file / video sending",
      "Resumable file transfer (Rust engine)",
      "File evidence chain with download proof",
      "Device Trust & cryptographic vault",
      "Self-hosted content safety — nothing leaves our infrastructure",
      "5,000 open work objects",
      "Work dependencies — nothing closes out of order",
      "Completion refuses to happen without evidence",
      "Promise handover with a logged reason",
      "Tamper-evident conversation record",
      "Group calls up to 40 participants",
      "8K-capable Relay video calls with simulcast",
      "Priority support — we reply within 12 hours",
    ],
  },
];

/** Map from Polar workspace_plan to personal tier id */
export function polarToPersonalTierId(
  polarPlan: "basic" | "pro" | "business" | "business_pro",
): PersonalTierId {
  if (polarPlan === "business_pro") return "personal_premium";
  if (polarPlan === "pro" || polarPlan === "business") return "personal_pro";
  return "personal_basic";
}

/** Tier rank for upgrade/downgrade detection */
function tierRank(id: PersonalTierId): number {
  if (id === "personal_premium") return 3;
  if (id === "personal_pro") return 2;
  return 1;
}

export function personalTierLabel(id: PersonalTierId): string {
  const t = PERSONAL_TIERS.find((t) => t.id === id);
  return t?.name ?? "Personal Basic";
}

export function isPersonalUpgrade(from: PersonalTierId, to: PersonalTierId): boolean {
  return tierRank(to) > tierRank(from);
}
