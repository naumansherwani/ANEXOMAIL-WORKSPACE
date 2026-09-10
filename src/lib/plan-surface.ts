/**
 * Plan → rail (anexomail.com). One codebase, three hosts — 57 phases copy nahi.
 * plans.ts prices — DO NOT import / change.
 *
 * Dashboard: har package.
 * Admin: sirf founder host — family (Humza/Raana/Masood) pe nahi.
 * AI: sirf jiska ai_plan ho (Raana AI Executive).
 */
export function hasAiPlan(aiPlan: string | null | undefined): boolean {
  const p = String(aiPlan || "").trim().toLowerCase();
  return Boolean(p) && p !== "none" && (p.startsWith("ai_") || p === "ai" || p === "ai_executive");
}

export function hasBusinessPlan(plan: string | null | undefined): boolean {
  const p = String(plan || "").trim().toLowerCase();
  return p === "business" || p === "business_pro";
}

export function showDashboard(): boolean {
  return true;
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

export function showAdmin(opts: { founder: boolean; founderHost: boolean }): boolean {
  return opts.founder && opts.founderHost;
}

export function showAiCenter(aiPlan: string | null | undefined, aiHost: boolean): boolean {
  return hasAiPlan(aiPlan) || aiHost;
}
