/**
 * Package rail — locked cards in `src/lib/plans.ts` (DO NOT import or change
 * prices / copy). Basic £23 · Pro £46 · Business £97 · Business Pro £2850.
 *
 * Tech (constitution): same AppShell + `host.ts`. No new host, no Polar edit,
 * Chat/Org nav is Business+ only. CRM is Pro+ (mail-native, no LEO).
 * LEO is zero on anexomail.com — AI-EXECUTE opens it on ai.anexomail.com.
 *
 * AI grant includes a workspace platform (`ai-packages.ts` blurbs, no-touch):
 *   AI Pro / AI Business → Business
 *   AI Executive → Business Pro
 * So Raana on anexomail.com gets Biz Pro mail UX, not an AI rail.
 */

export type WorkspacePlanId = "basic" | "pro" | "business" | "business_pro";

export type SurfaceHosts = {
  publicMailHost: boolean;
  aiHost: boolean;
  founderHost: boolean;
};

export type SurfaceOpts = SurfaceHosts & {
  plan: WorkspacePlanId;
  founder: boolean;
};

export type SurfaceDenial = {
  title: string;
  body: string;
};

export function normalizeWorkspacePlan(plan: string | null | undefined): WorkspacePlanId {
  const p = String(plan || "basic")
    .trim()
    .toLowerCase()
    .replace(/[\s-]+/g, "_");
  if (p === "business_pro" || p === "businesspro") return "business_pro";
  if (p === "business") return "business";
  if (p === "pro") return "pro";
  return "basic";
}

export function packageCopyName(plan: WorkspacePlanId): string {
  if (plan === "business_pro") return "Business Pro";
  if (plan === "business") return "Business";
  if (plan === "pro") return "Pro";
  return "Basic";
}

export function hasAiPlan(aiPlan: string | null | undefined): boolean {
  const p = String(aiPlan || "")
    .trim()
    .toLowerCase();
  return Boolean(p) && p !== "none" && (p.startsWith("ai_") || p === "ai" || p === "ai_executive");
}

function planRank(plan: WorkspacePlanId): number {
  if (plan === "business_pro") return 4;
  if (plan === "business") return 3;
  if (plan === "pro") return 2;
  return 1;
}

/** Workspace plan after applying the AI grant's included platform. */
export function platformPlan(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined,
): WorkspacePlanId {
  const workspace = normalizeWorkspacePlan(workspacePlan);
  const ai = String(aiPlan || "")
    .trim()
    .toLowerCase();
  let included: WorkspacePlanId = "basic";
  if (ai === "ai_executive") included = "business_pro";
  else if (ai === "ai_business" || ai === "ai_pro" || ai === "ai") included = "business";
  return planRank(included) > planRank(workspace) ? included : workspace;
}

export function hasBusinessPlan(plan: string | null | undefined): boolean {
  const id = normalizeWorkspacePlan(plan);
  return id === "business" || id === "business_pro";
}

export function showDashboard(): boolean {
  return true;
}

export function showWork(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  const plan = platformPlan(workspacePlan, aiPlan);
  return plan === "pro" || hasBusinessPlan(plan);
}

export function showChat(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return hasBusinessPlan(platformPlan(workspacePlan, aiPlan));
}

export function showOrg(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return showChat(workspacePlan, aiPlan);
}

/** Mail-native CRM — Pro book of business. Not on Basic. No LEO. */
export function showCrm(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return showWork(workspacePlan, aiPlan);
}

/** Shared inbox / mentions / approvals inside CRM — Business card. */
export function showCrmCollab(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return hasBusinessPlan(platformPlan(workspacePlan, aiPlan));
}

/** Activity timeline + CRM audit — Business Pro (Humza). */
export function showCrmLedger(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return platformPlan(workspacePlan, aiPlan) === "business_pro";
}

/** File / call / promise-recovery / decision ledger on Work — Business card, not Pro. */
export function showWorkBusinessRecord(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return hasBusinessPlan(platformPlan(workspacePlan, aiPlan));
}

/** CRM risk radar — Business card. Pro keeps own book (leads + pipeline). */
export function showCrmRisk(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return hasBusinessPlan(platformPlan(workspacePlan, aiPlan));
}

/** CRM graph — Business Pro card. */
export function showCrmGraph(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return showCrmLedger(workspacePlan, aiPlan);
}

/** Templates, snooze, schedule send — Pro card. */
export function showProMailTools(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
): boolean {
  return showWork(workspacePlan, aiPlan);
}

export function showAdmin(opts: { founder: boolean; founderHost: boolean }): boolean {
  return opts.founder && opts.founderHost;
}

/** LEO / AI Center — AI host only. Workspace cards have no AI. */
export function showAiCenter(aiHost: boolean): boolean {
  return aiHost;
}

export function railItemVisible(to: string, opts: SurfaceOpts): boolean {
  if (opts.founderHost) return true;
  if (to.startsWith("/app/founder")) return false;
  if (to === "/app/perf") return false;
  if (to === "/app/crm") return showCrm(opts.plan);
  if (to === "/app/admin") return showAdmin({ founder: opts.founder, founderHost: opts.founderHost });
  if (to === "/app/ai-center") return showAiCenter(opts.aiHost);
  if (to === "/app") return showDashboard();
  if (to === "/app/chat") return showChat(opts.plan);
  if (to === "/app/org") return showOrg(opts.plan);
  if (to === "/app/work") return showWork(opts.plan);
  return true;
}

export function surfaceDenial(pathname: string, opts: SurfaceOpts): SurfaceDenial | null {
  if (opts.founderHost) return null;
  const path = pathname.replace(/\/+$/, "") || "/app";

  if (path.startsWith("/app/founder")) {
    return {
      title: "Founder view is not on this host",
      body: "Founder tools open only on the founder workspace host. This mail workspace stays on your package.",
    };
  }
  if (path.startsWith("/app/perf")) {
    return {
      title: "Speed is not part of this workspace",
      body: "Speed lives on the founder host. It is not a mail package feature.",
    };
  }
  if (path.startsWith("/app/admin")) {
    return {
      title: "Platform admin is not on this package",
      body: "Your package is {package}. Organisation tools for Business sit under Org, not platform Admin.",
    };
  }
  if (path.startsWith("/app/crm/collab")) {
    if (showCrmCollab(opts.plan)) return null;
    return {
      title: "Shared CRM work is on Business",
      body: "Assignment, mentions and approvals sit on Business and Business Pro. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/crm/activity")) {
    if (showCrmLedger(opts.plan)) return null;
    return {
      title: "CRM activity ledger is on Business Pro",
      body: "The company timeline of every touch sits on Business Pro. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/crm")) {
    if (showCrm(opts.plan)) return null;
    return {
      title: "CRM is on Pro",
      body: "Leads and pipeline sit on Pro, Business and Business Pro. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/ai-center") || path === "/app/ai" || path.startsWith("/app/ai/")) {
    return {
      title: "LEO is not on this workspace",
      body: "Basic, Pro, Business and Business Pro have no AI. AI plans open on ai.anexomail.com.",
    };
  }
  if (path.startsWith("/app/chat")) {
    if (showChat(opts.plan)) return null;
    return {
      title: "ANEXOChat is on Business",
      body: "Your package is {package}. Chat and ANEXOVideoCall sit on Business and Business Pro.",
    };
  }
  if (path.startsWith("/app/org")) {
    if (showOrg(opts.plan)) return null;
    return {
      title: "Organisation centre is on Business",
      body: "Roles, departments, policies and the audit ledger sit on Business and Business Pro. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/work")) {
    if (showWork(opts.plan)) return null;
    return {
      title: "Work is on Pro",
      body: "Boards, notes, tasks and thread analytics sit on Pro and above. Your package is {package}.",
    };
  }
  return null;
}
