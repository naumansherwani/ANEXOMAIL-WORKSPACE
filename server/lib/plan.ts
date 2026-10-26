/**
 * ANEXOMAIL — central plan + feature-gating (single source of truth).
 *
 * Pricing table (server/config/billing-products.ts ke prices se match):
 *   Basic £23 · Pro £46 · Business £97 · Business Pro £2,850
 *
 * Yeh file wahi resolvePlan/normalizePlan logic hai jo crm.ts mein thi
 * (family_accounts / trial_accounts se plan nikalna) — ab shared hai
 * taake mail.ts, workspace.ts, admin.ts sab yehi EK jagah se import karein.
 */
import { admin } from "./supa";

export type PlanTier = "basic" | "pro" | "business" | "business_pro";

export type PlanLimits = {
  mailboxesIncluded: number | "on_request" | "unlimited";
  storageBytesPerMailbox: number;
  domainsIncluded: number | "on_request";
  freeAliases: number | "on_request";
  sharedInbox: boolean;
  tasksAndNotes: boolean;
  threadAnalytics: boolean;
  integrationsAndLeoActions: boolean;
  auditLedger: boolean;
  deviceRevoke: boolean;
  supportSlaHours: number;
};

const GB = 1024 * 1024 * 1024;

export const PLAN_LIMITS: Record<PlanTier, PlanLimits> = {
  basic: {
    mailboxesIncluded: 3,
    storageBytesPerMailbox: 5 * GB,
    domainsIncluded: 1,
    freeAliases: 5,
    sharedInbox: false,
    tasksAndNotes: false,
    threadAnalytics: false,
    integrationsAndLeoActions: false,
    auditLedger: false,
    deviceRevoke: false,
    supportSlaHours: 72,
  },
  pro: {
    // v6 (E88, 26 Oct 2026): Pro = 10 mailboxes, 300 GB SHARED pool (SQL truth: storage_plans.pro). Yeh Bun fallback table hai —
    // asli rok Rust + SQL karte hain; storageBytesPerMailbox sirf purane display/fallback ke liye 30 GB (300 GB / 10 mailboxes).
    mailboxesIncluded: 10,
    storageBytesPerMailbox: 30 * GB,
    domainsIncluded: 3,
    freeAliases: 5,
    sharedInbox: true,
    tasksAndNotes: true,
    threadAnalytics: true,
    integrationsAndLeoActions: false,
    auditLedger: false,
    deviceRevoke: false,
    supportSlaHours: 48,
  },
  business: {
    mailboxesIncluded: 30, // SQL truth: sql/phase48_storage_quota.sql storage_plans.mailbox_limit
    storageBytesPerMailbox: 25 * GB,
    domainsIncluded: "on_request",
    freeAliases: "on_request",
    sharedInbox: true,
    tasksAndNotes: true,
    threadAnalytics: true,
    integrationsAndLeoActions: true,
    auditLedger: true,
    deviceRevoke: true,
    supportSlaHours: 24,
  },
  business_pro: {
    mailboxesIncluded: "unlimited",
    storageBytesPerMailbox: 1024 * GB,
    domainsIncluded: "on_request",
    freeAliases: "on_request",
    sharedInbox: true,
    tasksAndNotes: true,
    threadAnalytics: true,
    integrationsAndLeoActions: true,
    auditLedger: true,
    deviceRevoke: true,
    supportSlaHours: 24,
  },
};

export function normalizePlan(plan: string | null | undefined): PlanTier {
  const p = String(plan || "basic")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  if (p === "business_pro" || p === "businesspro") return "business_pro";
  if (p === "business") return "business";
  if (p === "pro") return "pro";
  return "basic";
}

function platformPlan(workspace: string | null | undefined, ai: string | null | undefined): PlanTier {
  const w = normalizePlan(workspace);
  const a = String(ai || "").trim().toLowerCase();
  let included: PlanTier = "basic";
  if (a === "ai_executive") included = "business_pro";
  else if (a === "ai_business" || a === "ai_pro" || a === "ai") included = "business";
  const rank = (p: PlanTier) => (p === "business_pro" ? 4 : p === "business" ? 3 : p === "pro" ? 2 : 1);
  return rank(included) > rank(w) ? included : w;
}

/** Org/user ka ASAL plan resolve karta hai (family_accounts / trial_accounts se). */
export async function resolvePlan(uid: string, email: string): Promise<PlanTier> {
  const emailLower = email.toLowerCase();
  const anexo = emailLower.endsWith("@anexomail.com") ? emailLower : null;
  const family = anexo
    ? await admin.from("family_accounts").select("plan,ai_plan").eq("email", anexo).maybeSingle()
    : { data: null as any };
  const trial = await admin.from("trial_accounts").select("plan,anexomail_address").eq("user_id", uid).maybeSingle();
  const addr = String(trial.data?.anexomail_address || anexo || "").toLowerCase();
  const familyByAddr =
    !family.data && addr
      ? await admin.from("family_accounts").select("plan,ai_plan").eq("email", addr).maybeSingle()
      : family;
  const row = familyByAddr.data || family.data;
  return platformPlan(row?.plan || trial.data?.plan, row?.ai_plan);
}

export function limitsFor(plan: PlanTier): PlanLimits {
  return PLAN_LIMITS[plan];
}

/** True agar plan mein yeh boolean feature included hai. */
export function hasFeature(
  plan: PlanTier,
  feature: "sharedInbox" | "tasksAndNotes" | "threadAnalytics" | "integrationsAndLeoActions" | "auditLedger" | "deviceRevoke",
): boolean {
  return Boolean(PLAN_LIMITS[plan][feature]);
}

/** Mailbox count limit check. `current` = ab tak org mein kitni mailboxes hain. */
export function canAddMailbox(plan: PlanTier, current: number): boolean {
  const limit = PLAN_LIMITS[plan].mailboxesIncluded;
  if (limit === "unlimited" || limit === "on_request") return true;
  return current < limit;
}

/** Storage limit (bytes) ek mailbox ke liye is plan par. */
export function storageLimitBytes(plan: PlanTier): number {
  return PLAN_LIMITS[plan].storageBytesPerMailbox;
}

/** Domain (company address) count limit check. */
export function canAddDomain(plan: PlanTier, current: number): boolean {
  const limit = PLAN_LIMITS[plan].domainsIncluded;
  if (limit === "on_request") return true;
  return current < limit;
}

/** Free-alias count limit check. */
export function canAddAlias(plan: PlanTier, current: number): boolean {
  const limit = PLAN_LIMITS[plan].freeAliases;
  if (limit === "on_request") return true;
  return current < limit;
}
