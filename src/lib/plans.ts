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
  /** Rule 55: flat-per-month plans ka user cap, price ke neeche saaf dikhta hai. */
  userCap?: string;
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
 *  yearly total big — monthly number kabhi repeat nahi hota. */
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
    monthly: 40,
    yearly: 440,
    unit: "/ month",
    tagline: "Small teams that want a professional company inbox.",
    annual: "one-month-free",
    userCap: "Up to 5 users · flat price for the whole company, no per-user fees",
    features: [
      "Up to 5 users — no per-user fees",
      "Every app below is included — no charges for any app, nothing extra to buy",
      "Bring your own company domain (1 domain)",
      "3 mailboxes, 15GB shared storage",
      "Free aliases — no extra seat",
      "Email attachments up to 25MB, undo send (30s)",
      "Calendar with Find-a-time and 1 public booking link",
      "Contacts and thread ownership",
      "Cmd+K workspace search",
      "Passkey sign-in and 2 trusted devices",
      "One-click data export",
      "Human support — 72h response",
    ],
  },
  {
    id: "pro",
    name: "Pro",
    monthly: 105,
    yearly: 1155,
    unit: "/ month",
    tagline: "Teams answering customers every day.",
    annual: "one-month-free",
    userCap: "Up to 20 users · flat price for the whole company, no per-user fees",
    features: [
      "Everything in Basic",
      "Up to 20 users — no per-user fees",
      "Every app below is included — no charges for any app, nothing extra to buy",
      "3 company domains",
      "10 mailboxes, 300GB shared storage",
      "Shared inbox with collision guard",
      "Snooze & schedule send",
      "Email templates",
      "Boards & notes",
      "Tasks & thread analytics",
      "CRM: accounts, leads and pipeline",
      "CRM setup: your own pipeline stages, 5 custom fields, duplicate merge",
      "Web form that turns visitors into leads",
      "Pre-send scan, follow-up reminders and snippets",
      "Availability, focus time and meeting cost",
      "Overlap Matrix for team time zones",
      "3 public booking links",
      "Email attachments up to 35MB",
      "4 trusted devices",
      "Human support — 48h response",
    ],
  },
  {
    id: "business",
    name: "Business",
    monthly: 360,
    yearly: 3960,
    unit: "/ month",
    tagline: "For growing companies that need governance over their email, not just storage.",
    annual: "one-month-free",
    userCap: "Up to 60 users · flat price for the whole company, no per-user fees",
    features: [
      "Everything in Basic + Pro",
      "Every app and feature included — nothing extra to buy",
      "Up to 60 users and 1.5TB of shared storage for the whole company",
      "Roles and departments",
      "Policies and a full audit ledger",
      "One-click access revocation for any person or device",
      "One-click data export, no lock-in",
      "Native integrations",
      "ANEXOChat included",
      "15GB transfer per user per month limit, 2GB maximum file send",
      "Email attachments up to 45MB",
      "Business workspace identity with MX, SPF, DKIM and DMARC proven green",
      "Human support, response within 24 hours",
    ],
  },
  {
    id: "business_pro",
    name: "Business Pro",
    monthly: 2850,
    yearly: 28500,
    unit: "/ month",
    tagline: "The complete company communication stack — one price for the whole company, not per user.",
    annual: "two-months-free",
    badge: "Most complete",
    userCap: "Up to 570 users · flat price for the whole company, no per-user fees",
    features: [
      "Everything in Basic + Pro + Business",
      "Every app and feature included — nothing extra to buy",
      "Up to 570 users and 10TB of shared storage for the whole company",
      "ANEXOChat Business Pro for the whole company",
      "Resumable large-file transfer",
      "Email attachments up to 60MB",
      "Device Trust and Device Safety Vault — every device carries a trust score and can be killed in one click",
      "Audit ledger with message provenance",
      "Conversation to task — work leaves the inbox and becomes owned work",
      "Promise tracking and promise recovery, with a written reason for every moved deadline",
      "Conversation health and conversation-to-outcome timeline",
      "Search across your mail, people and companies",
      "One-click data export and no lock-in",
      "Priority human support, response within 12 hours",
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
      "File evidence chain — Selected → Verified → Available",
      "Self-hosted file safety (no external moderation service)",
      "Device Safety Vault + trust list with one-click revoke",
      "Report a message, person, file or conversation",
      "Message → Task · Promise · Decision with evidence chain",
      "Promise recovery — remind + deadline change with written reason",
      "Conversation → outcome timeline with matter health and owner",
      "Message provenance with delivery confirmation and Integrity Verified",
      "Delete for me · delete for everyone — still works after 48 hours",
      "Relay video calls with screen share",
      "One person, one account — sealed device identity, no biometrics",
      "72-hour export window if an account is ever blocked",
      "File business context card + duplicate-by-hash + stale-file warning",
      "Deterministic document version diff (no AI)",
      "Call business record with join truth and real duration (group up to 8)",
      "Call → Task · Promise · Decision with call provenance",
      // PHASE 31A — NEW ADDED (lightspeed calling)
      "QUIC call setup on our own engine — invite and answer in one trip",
      "Pre-warmed network path before the call button",
      "Our own ringtone and ringback, with silent Calm Mode ring",
      "45-second ring window recorded as “no answer”, never “missed”",
      "Audio-first survival — the voice and the call stay up",
      "AV1 → VP9 → H.264 → VP8 codec ladder with three simulcast layers",
      "Opus in-band FEC + DTX and live P2P / TURN path badge",
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
      "Promise handover with logged reason + downstream impact",
      "Decision extraction",
      "Meeting extraction — decisions, tasks, owners, deadlines",
      "Work intelligence",
      "AI Studio — build structured AI operations",
      "AI business search in natural language",
      "Work dependencies + evidence-locked completion",
      "5,000 open work objects",
      "5GB max file sending + resumable transfer (Rust engine)",
      "Suspicious-device detection with final-warning ladder",
      "Commitment collision prevention on recorded dependencies",
      "Tamper-evident conversation record — whole-chain integrity audit",
      "Relationship graph — file ↔ person ↔ company ↔ decision (recorded links only)",
      "Group calls up to 40 participants with full join truth ledger",
      // PHASE 31A — NEW ADDED (lightspeed calling)
      "Group calls on our own media engine with three quality layers each",
      "60-second ring window with millisecond ring result on record",
      "Audio-first survival with the written reason for every pause",
      "AV1-first codec ladder, three simulcast layers and Opus FEC/DTX",
      "Live Direct P2P / TURN relay path badge from real call readings",
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
      "Full file safety review queue + enforcement history",
      "Safety review queue with logged evidence reveal",
      "Device ban list + enforcement history",
      "8K-capable Relay video calls with simulcast & telemetry",
      "Company-wide delete for everyone (no time limit) with audit record",
      "20,000 open work objects",
      "Full promise recovery ledger + device block appeal review",
      "Full commitment collision prevention with append-only decision ledger",
      "Whole-conversation tamper-evident provenance audit",
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
      "Group calls up to 60 participants with full call business record",
      // PHASE 31A — NEW ADDED (lightspeed calling)
      "Company connect report — p50 · p95 · p99 setup times from real calls",
      "Every connection step timed: pre-warm · signal · answer · media · first frame",
      "Full ring ledger across the company — answered · declined · no answer",
      "Rust SFU media forwarding for group calls up to 60 participants",
      "AV1-first three-layer simulcast + Opus FEC/DTX + relay truth",
      "Company-wide relationship graph + 5,000-line document diffs",
      "Priority model routing & higher context limits",
      "AI top-up recharge available",
    ],
  },
];
