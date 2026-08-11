/**
 * Phase 28 — Revenue Engine (transport + pure maths only).
 *
 * 4 locked money roads (AI ke bina):
 *   1. Core subscriptions — Basic £20 · Pro £40 · Business £85 (recurring)
 *   2. Migration service  — £500–£2,000 one-time per company (Gmail/Outlook → ANEXOMAIL)
 *   3. White-label / reseller — IT agencies, 20–30% recurring commission
 *   4. Premium SLA        — dedicated manager + 1h response, £500/mo add-on
 *
 * NO MOCK: quote maths client-side hai (deterministic, real rate card), lekin
 * har lead/application asli backend row banata hai. Endpoint missing = honest state.
 */

import { useMutation, useQuery } from "@tanstack/react-query";

import { api, type ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

/* ------------------------------ rate card ------------------------------- */

export const PLAN_PRICE = { basic: 20, pro: 40, business: 85 } as const;
export const SLA_PRICE_MONTHLY = 500;
export const MIGRATION_FLOOR = 500;
export const MIGRATION_CEILING = 2000;

export type MigrationInput = {
  mailboxes: number;
  gigabytes: number;
  provider: "gmail" | "outlook" | "zoho" | "imap" | "other";
  urgency: "standard" | "weekend" | "overnight";
  dns: boolean;
  training: boolean;
};

export type MigrationQuote = {
  total: number;
  deposit: number;
  lines: { label: string; amount: number; detail: string }[];
  window: string;
  capped: boolean;
};

/** Deterministic rate card — same input, same £. No hidden numbers. */
export function quoteMigration(input: MigrationInput): MigrationQuote {
  const mailboxes = Math.max(1, Math.round(input.mailboxes || 1));
  const gb = Math.max(1, Math.round(input.gigabytes || 1));

  const lines: { label: string; amount: number; detail: string }[] = [];
  lines.push({ label: "Migration base", amount: MIGRATION_FLOOR, detail: "Project setup, mapping, dry run, cut-over plan" });
  lines.push({ label: `Mailboxes (${mailboxes})`, amount: mailboxes * 25, detail: "£25 per mailbox — mail, folders, aliases, sent history" });
  lines.push({ label: `Data volume (${gb} GB)`, amount: gb * 4, detail: "£4 per GB — verified message-for-message" });

  const providerFee: Record<MigrationInput["provider"], number> = {
    gmail: 0,
    outlook: 100,
    zoho: 75,
    imap: 50,
    other: 150,
  };
  const pf = providerFee[input.provider];
  if (pf > 0) lines.push({ label: "Source complexity", amount: pf, detail: `${input.provider.toUpperCase()} export + label/folder rebuild` });

  if (input.urgency === "weekend") lines.push({ label: "Weekend cut-over", amount: 200, detail: "Cut-over outside working hours, engineer watching the switch" });
  if (input.urgency === "overnight") lines.push({ label: "Overnight cut-over", amount: 400, detail: "Same-night switch, engineer on call" });
  if (input.dns) lines.push({ label: "DNS + deliverability", amount: 150, detail: "MX, SPF, DKIM, DMARC set to green and proven" });
  if (input.training) lines.push({ label: "Team onboarding", amount: 200, detail: "Live session + written runbook for the team" });

  const raw = lines.reduce((s, l) => s + l.amount, 0);
  const total = Math.min(MIGRATION_CEILING, raw);
  const days = mailboxes <= 10 ? "3–5 working days" : mailboxes <= 50 ? "1–2 weeks" : "2–4 weeks";

  return { total, deposit: Math.round(total * 0.5), lines, window: days, capped: raw > MIGRATION_CEILING };
}

export type PartnerInput = { seats: number; plan: keyof typeof PLAN_PRICE; tier: "reseller" | "gold" | "platinum" };

export type PartnerQuote = {
  rate: number;
  monthly: number;
  yearly: number;
  clientBill: number;
  tierLabel: string;
  nextTier: string | null;
};

/** Commission ladder: 20% → 25% → 30% recurring, for as long as the seat lives. */
export function quotePartner(input: PartnerInput): PartnerQuote {
  const seats = Math.max(1, Math.round(input.seats || 1));
  const price = PLAN_PRICE[input.plan];
  const rate = input.tier === "platinum" ? 0.3 : input.tier === "gold" ? 0.25 : 0.2;
  const clientBill = seats * price;
  const monthly = Math.round(clientBill * rate);
  return {
    rate,
    monthly,
    yearly: monthly * 12,
    clientBill,
    tierLabel: input.tier === "platinum" ? "Platinum · 100+ seats" : input.tier === "gold" ? "Gold · 25+ seats" : "Reseller · from 1 seat",
    nextTier:
      input.tier === "reseller" ? "Reach 25 live seats → Gold, 25%" : input.tier === "gold" ? "Reach 100 live seats → Platinum, 30%" : null,
  };
}

/** Kitne customers chahiye ek monthly target ke liye — founder ka honest maths. */
export function seatsForTarget(targetGbp: number, plan: keyof typeof PLAN_PRICE) {
  const price = PLAN_PRICE[plan];
  return { seats: Math.ceil(targetGbp / price), price, target: targetGbp };
}

/* ------------------------------- leads ---------------------------------- */

export type LeadKind = "migration" | "partner" | "sla";

export type LeadPayload = {
  kind: LeadKind;
  company: string;
  email: string;
  name?: string;
  domain?: string;
  seats?: number;
  message?: string;
  quote_gbp?: number;
  detail?: Record<string, unknown>;
};

export type LeadResult = { id: string; reference: string; kind: LeadKind; created_at: string };

/** Public — no session needed. Backend writes a real row and BCCs the founder. */
export function useSubmitLead() {
  return useMutation<LeadResult, ApiError, LeadPayload>({
    mutationFn: (payload) =>
      api<LeadResult>("/api/public/revenue/lead", { method: "POST", body: JSON.stringify(payload), auth: false }),
  });
}

/* --------------------------- founder god-view --------------------------- */

export type RevenueOverview = {
  target_gbp: number;
  mrr_gbp: number;
  arr_gbp: number;
  one_off_gbp: number;
  target_progress: number;
  streams: { stream: string; mrr_gbp: number; one_off_gbp: number; accounts: number }[];
  leads: { id: string; reference: string; kind: LeadKind; company: string; email: string; quote_gbp: number | null; stage: string; created_at: string }[];
  partners: { id: string; company: string; tier: string; live_seats: number; commission_gbp: number; stage: string }[];
  gap: { seats_needed: number; plan: string; note: string };
};

export function useFounderRevenue() {
  return useQuery<RevenueOverview, ApiError>({
    queryKey: ["founder", "revenue", "overview"],
    queryFn: () => rpcOrRest<RevenueOverview>("founder.revenue.overview", { path: "/api/founder/revenue/overview" }),
    retry: false,
  });
}

export const gbp = (n: number | null | undefined) =>
  n == null ? "—" : `£${Math.round(n).toLocaleString("en-GB")}`;
