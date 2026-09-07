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
      "File evidence chain — Selected → Verified → Available",
      "Device Safety Vault — sealed, non-biometric device identity",
      "Device trust list with one-click revoke",
      "Report a message, person, file or conversation",
      "Delete for me · delete for everyone — still works after 48 hours",
      "Edit a sent message with an honest edit marker",
      "Reply quoting, forwarding, starring and pinned messages",
      "Voice notes, photos, video and documents in chat",
      "Relay video calls with screen share (ANEXOVideoCall)",
      "One person, one account — sealed device identity, no biometrics",
      "72-hour export window if an account is ever blocked",
      "Message → Task · Promise · Decision (deterministic, no AI)",
      "Work chain: owner · deadline · completion evidence",
      "200 open work objects",
      "Promise recovery — remind, move a deadline with a written reason",
      "Conversation → outcome timeline — what was said beside what actually resulted",
      "Mark a message Important (marking and unmarking both stay on record)",
      "Matter health — on track · waiting · blocked · completed, with owner and next date",
      "Every health state shows its reason and the record it came from",
      "Message provenance — sender, workspace, exact UTC time, delivery confirmation",
      "Integrity Verified — the message still matches its sealed copy",
      "Original promise date never overwritten (append-only ledger)",
      "Self-hosted malware & file-type scanning (no external service)",
      "File business context card — uploader · conversation · related work · related email",
      "Deterministic document version diff (no AI) with the message that sent each version",
      "Duplicate-by-hash detection across the workspace — pooled storage saved",
      "Stale-file warning when a decision moved past the file version, with evidence",
      "Call business record — who started, who joined, who never joined (ms UTC)",
      "Real call duration from join/leave events — never estimated",
      "In-call file sharing on the same evidence chain (no “Delivered” wording)",
      "Call → Task · Promise · Decision with call provenance",
      "Relay honesty badge — direct or our own relay, and the moment it switched",
      "Group calls up to 8 participants",
      // PHASE 31A — NEW ADDED (lightspeed calling)
      "QUIC call setup — invite and answer travel on our own engine, not a queue",
      "Pre-warmed network path before you press call (measured, never claimed)",
      "Our own ringtone and ringback — no third-party sound service",
      "Calm Mode ring — silent visual pulse instead of sound",
      "45-second ring window recorded as “no answer”, never as “missed”",
      "Answered · declined · no answer — the ring result is on record",
      "Audio-first survival — video pauses, the voice and the call stay up",
      "Every connection step timed: signal · answer · media · first frame",
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
      "File evidence chain with download proof",
      "Self-hosted content safety — nothing leaves our infrastructure",
      "Archive-bomb & disguised-file protection",
      "Device Trust & cryptographic vault",
      "Safety review queue — new → under review → action → resolved",
      "Sealed report evidence: opening it is logged with a reason",
      "Enforcement history & device ban list",
      "Company-wide delete for everyone (no time limit) with audit record",
      "Suspicious-device detection: 3+ accounts or 3 signups in 24h",
      "Final-warning ladder before any account block",
      "8K-capable Relay video calls with simulcast & call telemetry",
      "Work dependencies — nothing closes out of order",
      "Completion refuses to happen without evidence",
      "5,000 open work objects",
      "Promise handover — reassign an owner with a logged reason",
      "Downstream impact recorded on every slipping promise",
      "Tamper-evident conversation record — whole-chain integrity audit",
      "Commitment collision prevention — warns only on links your team recorded",
      "Collision actions (move the date · hand over · unlink · dismiss) need a written reason",
      "Append-only collision ledger — every warning and decision stays readable",
      "Device block appeals — one device only, never your network",
      "Relationship graph — file ↔ person ↔ company ↔ decision (recorded links only)",
      "2,000-line document version diffs",
      "Group calls up to 40 participants",
      // PHASE 31A — NEW ADDED (lightspeed calling)
      "QUIC call setup on our Rust engine — one round trip, no polling queue",
      "Pre-warmed network path with relay readiness shown honestly",
      "Our own ringtone and ringback — nothing leaves our infrastructure",
      "Calm Mode ring — silent pulse, never a hidden sound",
      "60-second ring window, recorded as “no answer” with the exact millisecond",
      "Audio-first survival with the written reason video was paused",
      "Group calls run on our own media engine — a relay is never called an engine",
      "Three quality layers per participant (AV1 · VP9 · H.264 · VP8 order)",
      "Connect report p50 · p95 · p99 across every company call",
      "Full join truth ledger — invited · ringing · joined · rejoined · left",
      "Every transport switch recorded — direct, our relay, and why",
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
      "Company-wide relationship graph + 5,000-line document diffs",
      "Priority model routing & higher context limits",
      "AI top-up recharge available",
    ],
  },
];
