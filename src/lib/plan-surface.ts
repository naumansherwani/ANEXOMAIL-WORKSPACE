/**
 * Plan → UI surface (anexomail.com). Pricing lives in plans.ts — DO NOT import to change prices.
 * Hosts stay one codebase. Gate the rail; do not copy 57 phases per subdomain.
 */
export function hasAiPlan(aiPlan: string | null | undefined): boolean {
  const p = String(aiPlan || "").trim().toLowerCase();
  return p.startsWith("ai_") || p === "ai";
}

export function hasBusinessPlan(plan: string | null | undefined): boolean {
  const p = String(plan || "").trim().toLowerCase();
  return p === "business" || p === "business_pro";
}

/** Today dashboard (image 3) — Business / Business Pro / any AI plan. Basic+Pro = mail-first. */
export function showTodayDashboard(plan: string | null | undefined, aiPlan: string | null | undefined): boolean {
  return hasBusinessPlan(plan) || hasAiPlan(aiPlan);
}

export function showChat(plan: string | null | undefined, aiPlan: string | null | undefined): boolean {
  return hasBusinessPlan(plan) || hasAiPlan(aiPlan);
}

export function showOrg(plan: string | null | undefined, aiPlan: string | null | undefined): boolean {
  return hasBusinessPlan(plan) || hasAiPlan(aiPlan);
}

export function showWork(plan: string | null | undefined, aiPlan: string | null | undefined): boolean {
  const p = String(plan || "").trim().toLowerCase();
  return p === "pro" || hasBusinessPlan(plan) || hasAiPlan(aiPlan);
}

/** Admin / Ownership Center — not for hosted @anexomail.com family testers. */
export function showAdmin(opts: { founder: boolean; founderHost: boolean }): boolean {
  return opts.founder && opts.founderHost;
}

export function showAiCenter(aiPlan: string | null | undefined, aiHost: boolean): boolean {
  return hasAiPlan(aiPlan) || aiHost;
}
