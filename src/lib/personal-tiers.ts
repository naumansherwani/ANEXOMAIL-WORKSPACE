/**
 * Personal account tier display — what each Polar SKU means for a personal user.
 *
 * plans.ts NO-TOUCH. This file is a read/display layer only.
 * Personal kind ≠ Business kind. Checkout ke baad onboarding decides kind.
 *
 * Polar mapping (locked):
 *   Personal Basic   → Polar Basic       £23  /user/month
 *   Personal Pro     → Polar Pro         £46  /user/month  (power = Business Pro, no Org)
 *   Personal Premium → Polar Business Pro £2,850/company   (max, personal, no Org)
 *
 * Feature gates (plan-surface.ts):
 *   basic  → Personal Basic  — mail, contacts, calendar, work (personal tasks only)
 *   pro    → Personal Pro    — + CRM, ANEXOChat, pro mail tools (power = business_pro)
 *   business_pro → Personal Premium — same power + 1TB / 5GB file / advanced features
 */

export type PersonalTierId = "personal_basic" | "personal_pro" | "personal_premium";

export type PersonalTier = {
  id: PersonalTierId;
  name: string;
  /** Polar SKU id used for billing-products checkout key */
  polarPlanId: "basic" | "pro" | "business_pro";
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
    monthly: 23,
    yearly: 253,
    yearlyRule: "one-month-free",
    unit: "/ user / month",
    tagline: "Solo founder, freelancer, individual professional.",
    features: [
      "1 company address",
      "3 mailboxes · 5GB per mailbox",
      "5 free aliases",
      "Undo send (30 seconds)",
      "Contacts & calendar",
      "Thread ownership",
      "Cmd+K workspace search",
      "Work — personal tasks",
      "Human support — 72h response",
    ],
  },
  {
    id: "personal_pro",
    name: "Personal Pro",
    polarPlanId: "pro",
    monthly: 46,
    yearly: 506,
    yearlyRule: "one-month-free",
    unit: "/ user / month",
    tagline: "Professionals who need the full communication stack — no company account.",
    features: [
      "Everything in Personal Basic",
      "3 company addresses",
      "5 mailboxes · 10GB per mailbox",
      "Shared inbox with collision guard",
      "Snooze & schedule send",
      "Email templates",
      "Work — boards, notes, tasks & thread analytics",
      "Full CRM — leads, pipeline, contacts intelligence",
      "ANEXOChat — full access",
      "ANEXOVideoCall with screen share",
      "Human support — 48h response",
    ],
  },
  {
    id: "personal_premium",
    name: "Personal Premium",
    polarPlanId: "business_pro",
    monthly: 2850,
    yearly: 28500,
    yearlyRule: "two-months-free",
    unit: "/ company / month",
    tagline: "Maximum communication stack for a professional — every feature, no company seat.",
    badge: "Most complete",
    features: [
      "Everything in Personal Pro",
      "Unlimited mailboxes · 1TB pooled storage",
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
      "Priority human support — 12h response",
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
