/**
 * ANEXOMAIL AI — Packages (FOUNDER LOCKED).
 *
 * Ye file sirf display truth hai. Balance, deduction aur ledger sab
 * Supabase (single source of truth) + backend Credit Engine karta hai.
 * Frontend kabhi credits calculate ya deduct nahi karta.
 */

export type AiPlan = {
  id: string;
  name: string;
  price: number;
  credits: number;
  blurb: string;
  highlight?: boolean;
};

/** Locked monthly plans — 10,000 credits maximum monthly plan. */
export const AI_PLANS: AiPlan[] = [
  { id: "ai_pro", name: "AI Pro", price: 400, credits: 1200, blurb: "All Business platform features, plus the AI workspace." },
  { id: "ai_business", name: "AI Business", price: 1500, credits: 5000, blurb: "Business teams that need AI-powered workflow.", highlight: true },
  { id: "ai_executive", name: "AI Executive", price: 4000, credits: 10000, blurb: "Business Pro platform plus the full AI bundle." },
];

export type TopUp = {
  id: string;
  price: number;
  credits: number;
  /** £ per credit — internal margin figure, never rendered to awam. */
  perCredit: number;
  /** false = founder-only pack, awam ko nazar nahi aata. */
  publicVisible: boolean;
};

/** Locked one-off top-ups. Monthly plans hamesha better value hain. */
export const AI_TOPUPS: TopUp[] = [
  { id: "tu_15", price: 15, credits: 40, perCredit: 0.375, publicVisible: true },
  { id: "tu_30", price: 30, credits: 75, perCredit: 0.4, publicVisible: true },
  { id: "tu_60", price: 60, credits: 170, perCredit: 0.353, publicVisible: true },
  { id: "tu_120", price: 120, credits: 360, perCredit: 0.333, publicVisible: true },
  { id: "tu_250", price: 250, credits: 800, perCredit: 0.313, publicVisible: true },
  { id: "tu_500", price: 500, credits: 1800, perCredit: 0.278, publicVisible: true },
  { id: "tu_1000", price: 1000, credits: 4000, perCredit: 0.25, publicVisible: true },
  { id: "tu_2000", price: 2000, credits: 9000, perCredit: 0.222, publicVisible: true },
  { id: "tu_5000", price: 5000, credits: 21000, perCredit: 0.238, publicVisible: false },
];

export const PUBLIC_TOPUPS = AI_TOPUPS.filter((t) => t.publicVisible);

/** Feature groups — exactly the locked list. */
export const AI_FEATURE_GROUPS: { title: string; items: string[] }[] = [
  {
    title: "Dedicated AI Workspace",
    items: [
      "AI Dashboard",
      "AI Chat",
      "AI Studio",
      "AI Knowledge",
      "AI Automation",
      "AI Prompt Library",
      "AI History",
      "AI Favorites",
      "AI Credit Wallet",
      "AI Usage Dashboard",
    ],
  },
  {
    title: "AI Intelligence Suite",
    items: [
      "AI Rewrite",
      "AI Grammar",
      "AI Translate",
      "AI Summarize",
      "AI Smart Reply",
      "AI Draft Generator",
      "AI Email Composer",
      "AI Tone Changer",
      "AI Email Analyzer",
      "AI Search",
      "AI Knowledge Search",
      "AI Task Extraction",
      "AI Meeting Extraction",
      "AI Prompt Templates",
      "AI Workflow Builder",
      "AI Automation Rules",
    ],
  },
  {
    title: "AI Benefits",
    items: [
      "1,200 monthly AI credits on the £400 plan",
      "10 complimentary credits per cycle (5/day for 2 days)",
      "Priority AI queue",
      "AI provider routing",
      "Credit wallet",
      "Credit analytics",
    ],
  },
];

/** Internal workload bands — pre-flight estimate isi se banta hai. */
export const CREDIT_BANDS: { action: string; charge: string }[] = [
  { action: "Tiny Leo question", charge: "1 credit" },
  { action: "Short summary", charge: "1–2 credits" },
  { action: "Quick reply", charge: "1–2 credits" },
  { action: "Normal email", charge: "2–4 credits" },
  { action: "400-word compose", charge: "3–5 credits" },
  { action: "Long email", charge: "5–10 credits" },
  { action: "Huge thread", charge: "8–20 credits" },
  { action: "AI Studio run", charge: "5–25 credits" },
  { action: "Large automation", charge: "10–50+ credits" },
];

export const gbp = (n: number) => `£${n.toLocaleString("en-GB")}`;
