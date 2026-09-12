/**
 * Package rail — locked cards in `src/lib/plans.ts` (DO NOT import or change
 * prices / copy). Basic £23 · Pro £46 · Business £97 · Business Pro £2850.
 *
 * Two account kinds (onboarding first): Personal | Business.
 * Inside each: Basic / Pro / Premium. Premium = Business Pro card.
 * Rule (founder 11 Sep 2026): Personal Pro = Business Pro **power**,
 * presentation alag (no Org / company centre). LEO zero on anexomail.com.
 */

export type WorkspacePlanId = "basic" | "pro" | "business" | "business_pro";

export type AccountKind = "personal" | "business";

export type PersonalTierId = "personal_basic" | "personal_pro" | "personal_premium";

/**
 * Paise Polar landing cards se. Kind personal hone ke baad SKU yeh naam ban'ta hai.
 * Landing pe Personal Polar SKU nahi. Webhook no-touch — `workspace_plan` pehle se.
 *
 * Polar Basic £23 → Personal Basic
 * Polar Pro £46 → Personal Pro
 * Polar Business £97 → Business kind (company). Agar kind personal ho to Personal Pro power.
 * Polar Business Pro £2850 → kind personal = Personal Premium; kind business = Business Pro
 */
export function polarToPersonalTier(plan: WorkspacePlanId): PersonalTierId {
  if (plan === "business_pro") return "personal_premium";
  if (plan === "pro" || plan === "business") return "personal_pro";
  return "personal_basic";
}

export type SurfaceHosts = {
  publicMailHost: boolean;
  aiHost: boolean;
  founderHost: boolean;
};

export type SurfaceOpts = SurfaceHosts & {
  /** Polar / entitlement billed plan (Basic · Pro · Business · Business Pro). */
  plan: WorkspacePlanId;
  /** Personal | Business — NOT a Polar product. Session/backend. */
  kind?: AccountKind;
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

/** Display name. AI grant apna naam rakhta hai — Raana = AI Executive, Business Pro nahi. */
export function packageCopyName(
  plan: WorkspacePlanId,
  kind?: AccountKind | null,
  aiPlan?: string | null,
): string {
  const ai = String(aiPlan || "")
    .trim()
    .toLowerCase();
  if (ai === "ai_executive") return "AI Executive";
  if (ai === "ai_business") return "AI Business";
  if (ai === "ai_pro" || ai === "ai") return "AI Pro";
  const k = kind ?? resolveAccountKind(null, plan);
  if (k === "personal") {
    if (plan === "business_pro") return "Personal Premium";
    if (plan === "pro" || plan === "business") return "Personal Pro";
    return "Personal Basic";
  }
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

/**
 * Personal | Business — from session, else slug, else plan:
 * basic/pro → personal (Masood Pro buyer). business / business_pro → company.
 */
export function resolveAccountKind(
  kind: string | null | undefined,
  workspacePlan: string | null | undefined,
  orgSlug?: string | null,
): AccountKind {
  const k = String(kind || "")
    .trim()
    .toLowerCase();
  if (k === "personal" || k === "business") return k;
  if (String(orgSlug || "").toLowerCase().startsWith("personal-")) return "personal";
  const plan = normalizeWorkspacePlan(workspacePlan);
  if (plan === "basic" || plan === "pro") return "personal";
  return "business";
}

/** Personal Pro / Premium = Business Pro feature rank. Org still needs kind=business. */
export function featurePlan(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: AccountKind | string | null | undefined = null,
): WorkspacePlanId {
  const base = platformPlan(workspacePlan, aiPlan);
  const k = resolveAccountKind(kind, workspacePlan);
  if (k === "personal" && base !== "basic") return "business_pro";
  return base;
}

export function surfaceFromSession(
  user?: {
    workspace_plan?: string | null;
    ai_plan?: string | null;
    account_kind?: string | null;
    personal_plan_name?: string | null;
  } | null,
  orgSlug?: string | null,
): { billed: WorkspacePlanId; kind: AccountKind; power: WorkspacePlanId; copyName: string } {
  const billed = platformPlan(user?.workspace_plan, user?.ai_plan);
  const kind = resolveAccountKind(user?.account_kind, user?.workspace_plan, orgSlug);
  const power = featurePlan(user?.workspace_plan, user?.ai_plan, kind);
  const fromSql =
    kind === "personal" && !hasAiPlan(user?.ai_plan) ? String(user?.personal_plan_name || "").trim() : "";
  return {
    billed,
    kind,
    power,
    copyName: fromSql || packageCopyName(billed, kind, user?.ai_plan),
  };
}

export function hasBusinessPlan(plan: string | null | undefined): boolean {
  const id = normalizeWorkspacePlan(plan);
  return id === "business" || id === "business_pro";
}

export function showDashboard(): boolean {
  return true;
}

type KindArg = AccountKind | string | null | undefined;

function powerOf(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined,
  kind: KindArg,
): WorkspacePlanId {
  return featurePlan(workspacePlan, aiPlan, kind);
}

/** Personal table: Work on every Personal tier. Business: Pro+. */
export function showWork(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  const k = resolveAccountKind(kind, workspacePlan);
  if (k === "personal") return true;
  const plan = platformPlan(workspacePlan, aiPlan);
  return plan === "pro" || hasBusinessPlan(plan);
}

/** Personal Pro+ = full chat. Personal Basic = wall. Business card+ = chat. */
export function showChat(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return hasBusinessPlan(powerOf(workspacePlan, aiPlan, kind));
}

/** Company Org — Business account type only. Personal never (even Personal Pro). */
export function showOrg(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  const k = resolveAccountKind(kind, workspacePlan);
  if (k !== "business") return false;
  return hasBusinessPlan(platformPlan(workspacePlan, aiPlan));
}

/** Full CRM rail. Personal Basic = People only. Personal Pro+ = full book. */
export function showCrm(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  const k = resolveAccountKind(kind, workspacePlan);
  if (k === "personal") return powerOf(workspacePlan, aiPlan, k) === "business_pro";
  return showWork(workspacePlan, aiPlan, k);
}

/** Collaboration inside CRM — Personal Pro power and Business cards. */
export function showCrmCollab(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return hasBusinessPlan(powerOf(workspacePlan, aiPlan, kind));
}

/** Activity ledger — Personal Pro / Premium and Business Pro. */
export function showCrmLedger(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return powerOf(workspacePlan, aiPlan, kind) === "business_pro";
}

/** Work ledgers (files, calls, recovery) — same power rule as CRM collab. */
export function showWorkBusinessRecord(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return hasBusinessPlan(powerOf(workspacePlan, aiPlan, kind));
}

export function showCrmRisk(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return hasBusinessPlan(powerOf(workspacePlan, aiPlan, kind));
}

export function showCrmGraph(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return showCrmLedger(workspacePlan, aiPlan, kind);
}

export function showProMailTools(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return powerOf(workspacePlan, aiPlan, kind) !== "basic";
}

export function showCrmHealth(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return showCrm(workspacePlan, aiPlan, kind);
}

export function showMultipleIdentities(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return powerOf(workspacePlan, aiPlan, kind) !== "basic";
}

export function showFullVideo(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return powerOf(workspacePlan, aiPlan, kind) !== "basic";
}

export function showAdmin(opts: { founder: boolean; founderHost: boolean }): boolean {
  return opts.founder && opts.founderHost;
}

/** Safety centre (review queue + device appeals) — Business Pro power only. */
export function showSafety(
  workspacePlan: string | null | undefined,
  aiPlan: string | null | undefined = null,
  kind: KindArg = null,
): boolean {
  return powerOf(workspacePlan, aiPlan, kind) === "business_pro";
}

/** LEO / AI Center — AI host only. Workspace cards have no AI. */
export function showAiCenter(aiHost: boolean): boolean {
  return aiHost;
}

function optsKind(opts: SurfaceOpts): AccountKind {
  return opts.kind ?? resolveAccountKind(null, opts.plan);
}

export function railItemVisible(to: string, opts: SurfaceOpts): boolean {
  if (opts.founderHost) return true;
  const kind = optsKind(opts);
  if (to.startsWith("/app/founder")) return false;
  if (to === "/app/perf") return false;
  if (to === "/app/crm") return showCrm(opts.plan, null, kind);
  if (to === "/app/admin") return showAdmin({ founder: opts.founder, founderHost: opts.founderHost });
  if (to === "/app/ai-center") return showAiCenter(opts.aiHost);
  if (to === "/app") return showDashboard();
  if (to === "/app/chat") return showChat(opts.plan, null, kind);
  if (to === "/app/org") return showOrg(opts.plan, null, kind);
  if (to === "/app/work") return showWork(opts.plan, null, kind);
  if (to === "/app/safety") return showSafety(opts.plan, null, kind);
  return true;
}

export function surfaceDenial(pathname: string, opts: SurfaceOpts): SurfaceDenial | null {
  if (opts.founderHost) return null;
  const path = pathname.replace(/\/+$/, "") || "/app";
  const kind = optsKind(opts);
  const personal = kind === "personal";

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
    if (showCrmCollab(opts.plan, null, kind)) return null;
    return {
      title: personal ? "Collaboration is on Personal Pro" : "Shared CRM work is on Business",
      body: personal
        ? "Assignment and shared CRM work sit on Personal Pro and Personal Premium. Your package is {package}."
        : "Assignment, mentions and approvals sit on Business and Business Pro. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/crm/activity")) {
    if (showCrmLedger(opts.plan, null, kind)) return null;
    return {
      title: personal ? "CRM activity is on Personal Pro" : "CRM activity ledger is on Business Pro",
      body: personal
        ? "The timeline of every touch sits on Personal Pro and Personal Premium. Your package is {package}."
        : "The company timeline of every touch sits on Business Pro. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/crm")) {
    if (showCrm(opts.plan, null, kind)) return null;
    return {
      title: personal ? "Full CRM is on Personal Pro" : "CRM is on Pro",
      body: personal
        ? "People stay on Personal Basic. Leads, pipeline and intelligence sit on Personal Pro. Your package is {package}."
        : "Leads and pipeline sit on Pro, Business and Business Pro. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/ai-center") || path === "/app/ai" || path.startsWith("/app/ai/")) {
    return {
      title: "LEO is not on this workspace",
      body: "Basic, Pro, Business and Business Pro have no AI. AI plans open on ai.anexomail.com.",
    };
  }
  if (path.startsWith("/app/chat")) {
    if (showChat(opts.plan, null, kind)) return null;
    return {
      title: personal ? "ANEXOChat is on Personal Pro" : "ANEXOChat is on Business",
      body: personal
        ? "Your package is {package}. Chat and ANEXOVideoCall sit on Personal Pro and Personal Premium."
        : "Your package is {package}. Chat and ANEXOVideoCall sit on Business and Business Pro.",
    };
  }
  if (path.startsWith("/app/org")) {
    if (showOrg(opts.plan, null, kind)) return null;
    return {
      title: personal ? "Organisation centre is a Business workspace" : "Organisation centre is on Business",
      body: personal
        ? "Personal workspaces have no company Org. Roles and departments sit on a Business account. Your package is {package}."
        : "Roles, departments, policies and the audit ledger sit on Business and Business Pro. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/work")) {
    if (showWork(opts.plan, null, kind)) return null;
    return {
      title: "Work is on Pro",
      body: "Boards, notes, tasks and thread analytics sit on Pro and above. Your package is {package}.",
    };
  }
  if (path.startsWith("/app/safety")) {
    if (showSafety(opts.plan, null, kind)) return null;
    return {
      title: "Safety centre is on Business Pro",
      body: "The review queue, sealed evidence and device appeals sit on Business Pro. Your package is {package}.",
    };
  }
  return null;
}
