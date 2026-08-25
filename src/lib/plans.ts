/**
 * ANEXOMAIL — Pricing truth (FOUNDER LOCKED).
 *
 * Ek hi jagah: workspace plans, AI plans, annual discount math.
 * Frontend sirf display karta hai; charge Polar + Supabase se hota hai.
 *
 * Annual rules (locked):
 *  - Basic / Pro          → 1 month free             → monthly * 11
 *  - Business / Business Pro → 2 months free (16.67%) → monthly * 10
 *  - All AI plans         → 2 months free (16.67%)   → monthly * 10
 */

export type BillingCycle = "monthly" | "yearly";

export type AnnualRule = "one-month-free" | "two-months-free";

export type PricedPlan = {
  id: string;
  name: string;
  /** Monthly list price in £. */
  monthly: number;
  /** Billing unit shown next to the price. */
  unit: string;
  tagline: string;
  annual: AnnualRule;
  /** Founder-locked yearly charge in £. */
  yearly: number;
  features: string[];
  /** Explicit "not included" lines. */
  excludes?: string[];
  badge?: string;
};

export const ANNUAL_NOTE: Record<AnnualRule, string> = {
  "one-month-free": "Get 1 month free",
  "two-months-free": "Get 2 months free",
};

/** Yearly total for a plan, rounded to the penny. */
export function yearlyTotal(plan: Pick<PricedPlan, "yearly">): number {
  return plan.yearly;
}

/** Effective per-month price when paid yearly. */
export function yearlyPerMonth(plan: Pick<PricedPlan, "yearly">): number {
  return Math.round((plan.yearly / 12) * 100) / 100;
}

/** How much a year of yearly billing saves against 12 monthly payments. */
export function yearlySaving(plan: Pick<PricedPlan, "monthly" | "yearly">): number {
  return Math.round((plan.monthly * 12 - plan.yearly) * 100) / 100;
}

export function discountPercent(rule: AnnualRule): string {
  return rule === "two-months-free" ? "16.67%" : "8.33%";
}

export const money = (n: number) =>
  `£${n.toLocaleString("en-GB", { maximumFractionDigits: n % 1 === 0 ? 0 : 2 })}`;

/** Price + suffix for a card, for the selected cycle. Yearly shows the REAL
 *  yearly total big (Lovable style) — monthly number kabhi repeat nahi hota. */
export function priceFor(plan: PricedPlan, cycle: BillingCycle) {
  if (cycle === "monthly")
    return { big: money(plan.monthly), suffix: plan.unit, note: null as string | null };
  return {
    big: money(plan.yearly),
    suffix: plan.unit.replace(/month/i, "year"),
    note: `${ANNUAL_NOTE[plan.annual]} · ${money(plan.monthly)}${plan.unit} billed monthly`,
  };
}

/* ── Workspace plans (anexomail.com — no AI) ─────────────────────────── */

export const WORKSPACE_PLANS: PricedPlan[] = [
  {
    id: "basic",
    name: "Basic",
    monthly: 23,
    yearly: 253,
    unit: "/ user / month",
    tagline: "Solo founder, freelancer, individual professional.",
    annual: "one-month-free",
    features: [
      "1 company address",
      "3 mailboxes",
      "5GB per mailbox",
      "5 free aliases",
      "Undo send (30s)",
      "Contacts & calendar",
      "Thread ownership",
      "Cmd+K workspace search",
      "Human support — 72h response",
    ],
  },
  {
    id: "pro",
    name: "Pro",
    monthly: 46,
    yearly: 506,
    unit: "/ user / month",
    tagline: "Teams answering customers every day.",
    annual: "one-month-free",
    features: [
      "Everything in Basic",
      "3 company addresses",
      "5 mailboxes",
      "10GB per mailbox",
      "Shared inbox with collision guard",
      "Snooze & schedule send",
      "Email templates",
      "Boards & notes",
      "Tasks & thread analytics",
      "Human support — 48h response",
    ],
  },
  {
    id: "business",
    name: "Business",
    monthly: 97,
    yearly: 970,
    unit: "/ user / month",
    tagline: "Growing companies that need workspace governance.",
    annual: "two-months-free",
    features: [
      "Everything in Pro",
      "Up to 30 users",
      "25GB per mailbox",
      "Roles & departments",
      "Policies & audit ledger",
      "One-click access revocation",
      "One-click data export",
      "Native integrations",
      "ANEXOChat included",
      "15GB transfer per user / month",
      "2GB max file sending",
      "Business workspace identity",
      "Team collaboration tools",
      "Human support — 24h response",
    ],
  },
  {
    id: "business_pro",
    name: "Business Pro",
    monthly: 2850,
    yearly: 28500,
    unit: "/ company / month",
    tagline: "Established companies with the full communication stack.",
    annual: "two-months-free",
    badge: "Most complete",
    features: [
      "Everything in Business",
      "Unlimited internal users",
      "ANEXOChat Business Pro",
      "1TB pooled workspace storage",
      "5GB max file / video sending",
      "Resumable file transfer (Rust engine)",
      "Device Trust & cryptographic vault",
      "Audit Ledger & message provenance",
      "Conversation → Task engine",
      "Promise tracking",
      "Decision ledger",
      "Conversation health & timeline",
      "Permanent business search",
      "Email ↔ Chat bridge",
      "Export & no lock-in guarantee",
      "Priority human support — 12h response",
    ],
  },
];

/* ── AI plans (ai.anexomail.com only) ────────────────────────────────── */

export type AiPricedPlan = PricedPlan & { credits: number };

export const AI_PRICED_PLANS: AiPricedPlan[] = [
  {
    id: "ai_pro",
    name: "AI Pro",
    monthly: 400,
    yearly: 4000,
    credits: 1200,
    unit: "/ month",
    tagline: "Individual professionals who need AI assistance.",
    annual: "two-months-free",
    features: [
      "All Business platform features included",
      "1,200 AI credits / month",
      "Leo chat assistant",
      "Ask, Explain, Summarize",
      "Draft, Translate, Find",
      "Document understanding — PDF, DOCX, XLSX, PPTX",
      "Grammar & rewrite",
      "Smart reply suggestions",
      "Conversation summary",
      "Citation-only answers",
      "Pre-flight credit estimate",
      "Receipt for every AI action",
      "AI top-up recharge available",
      "ANEXOChat included",
    ],
  },
  {
    id: "ai_business",
    name: "AI Business",
    monthly: 1500,
    yearly: 15000,
    credits: 5000,
    unit: "/ month",
    tagline: "Business teams that need AI-powered workflow.",
    annual: "two-months-free",
    features: [
      "Everything in AI Pro",
      "Business platform + ANEXOChat included",
      "5,000 AI credits / month",
      "AI workflow builder",
      "Task extraction from conversations",
      "Promise intelligence",
      "Decision extraction",
      "Meeting extraction — decisions, tasks, owners, deadlines",
      "Work intelligence",
      "AI Studio — build structured AI operations",
      "AI business search in natural language",
      "AI top-up recharge available",
    ],
  },
  {
    id: "ai_executive",
    name: "AI Executive",
    monthly: 4000,
    yearly: 40000,
    credits: 10000,
    unit: "/ month",
    tagline: "Companies that want the full AI + platform bundle.",
    annual: "two-months-free",
    badge: "Full bundle",
    features: [
      "Everything in AI Business",
      "Business Pro platform — unlimited users + 1TB + ANEXOChat",
      "10,000 AI credits / month",
      "AI Executive Briefing — daily business communication summary",
      "AI personal work assistant",
      "AI file comparison",
      "AI email composer",
      'AI inbox intelligence — "What needs my attention today?"',
      "AI automation preparation",
      "AI attention brief",
      "AI risk detection",
      "AI conversation prioritization",
      "Priority model routing & higher context limits",
      "AI top-up recharge available",
    ],
  },
];
