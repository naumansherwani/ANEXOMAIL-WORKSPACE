/**
 * Phase 13 — CRM Workspace (transport only).
 *
 * Mail-native CRM on anexomail.com for Pro / Business / Business Pro.
 * LEO insights stay off this host (AI-EXECUTE).
 * NO MOCK: a missing endpoint surfaces as an honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

/* ------------------------------------------------------------------ types */

export type DealStage = "new" | "qualified" | "proposal" | "negotiation" | "won" | "lost";

export const STAGE_LABEL: Record<DealStage, string> = {
  new: "New",
  qualified: "Qualified",
  proposal: "Proposal",
  negotiation: "Negotiation",
  won: "Won",
  lost: "Lost",
};

export const STAGE_ORDER: DealStage[] = [
  "new",
  "qualified",
  "proposal",
  "negotiation",
  "won",
  "lost",
];

export type CrmOverview = {
  currency: string;
  pipeline_value: number;
  weighted_value: number;
  won_this_month: number;
  open_deals: number;
  leads_new: number;
  leads_unworked: number;
  stale_deals: number;
  avg_first_reply_minutes: number | null;
  stage_counts: { stage: DealStage; count: number; value: number }[];
};

export type Lead = {
  id: string;
  display_name: string | null;
  email: string;
  company: string | null;
  source: string | null;
  score: number | null;
  /** Server truth — why the score is what it is. */
  score_reason: string | null;
  owner: string | null;
  state: "new" | "working" | "converted" | "dropped";
  last_touch_at: string | null;
  created_at: string;
};

export type Deal = {
  id: string;
  title: string;
  company: string | null;
  contact_email: string | null;
  stage: DealStage;
  value: number;
  currency: string;
  probability: number | null;
  owner: string | null;
  next_step: string | null;
  next_step_due: string | null;
  thread_id: string | null;
  stale_days: number | null;
  updated_at: string;
};

export type CrmActivity = {
  id: string;
  kind: "email_in" | "email_out" | "call" | "meeting" | "note" | "stage_change" | "task";
  actor: string | null;
  subject: string | null;
  body: string | null;
  deal_id: string | null;
  contact_email: string | null;
  created_at: string;
};

export type AiInsight = {
  id: string;
  agent: string;
  kind: "risk" | "opportunity" | "next_step" | "summary";
  title: string;
  detail: string;
  confidence: number | null;
  deal_id: string | null;
  created_at: string;
};

export type SharedItem = {
  id: string;
  kind: "inbox" | "draft";
  subject: string;
  preview: string;
  from_address: string;
  assigned_to: string | null;
  state: "unassigned" | "assigned" | "awaiting_approval" | "done";
  thread_id: string | null;
  created_at: string;
};

export type Mention = {
  id: string;
  actor: string;
  target: string;
  context: string;
  thread_id: string | null;
  deal_id: string | null;
  read: boolean;
  created_at: string;
};

export type Approval = {
  id: string;
  requested_by: string;
  subject: string;
  reason: string;
  amount: number | null;
  currency: string | null;
  state: "pending" | "approved" | "rejected";
  created_at: string;
};

export type CrmAuditEntry = {
  id: string;
  actor: string;
  action: string;
  target: string | null;
  ip: string | null;
  created_at: string;
};

export type TeamMemberPermission = {
  user_id: string;
  email: string;
  role: "owner" | "admin" | "member" | "viewer";
  can_see_all_deals: boolean;
  can_send_as_shared: boolean;
  can_approve: boolean;
};

export type FounderCrmState = {
  /** Kill switch — server truth. When false the public CRM refuses writes. */
  crm_enabled: boolean;
  ai_enabled: boolean;
  organisations: number;
  users: number;
  deals: number;
  leads: number;
  last_write_at: string | null;
};

/* ------------------------------------------------------------------ reads */

const get = <T>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path }, input);

export function useCrmOverview() {
  return useQuery<CrmOverview, ApiError>({
    queryKey: ["crm", "overview"],
    queryFn: () => get<CrmOverview>("crm.overview", "/api/crm/overview"),
    retry: false,
  });
}

export type CrmLiveAction = { kind: string; title: string; action: string; why: string; href: string };
export type CrmLiveRadar = { kind: string; title: string; why: string; source: string; href: string };
export type CrmLiveEvent = { at: string; kind: string; title: string; source?: string | null; href: string };
export type CrmLive = {
  radar: CrmLiveRadar[];
  next_actions: CrmLiveAction[];
  timeline: CrmLiveEvent[];
  people: {
    id: string;
    display_name: string | null;
    primary_address: string;
    company_name: string | null;
    relationship: string | null;
    health_score: number | null;
    last_contact_at: string | null;
    open_threads: number;
  }[];
  graph: { nodes: { id: string; kind: string; label: string; email?: string | null }[]; edges: { from: string; to: string; kind: string }[] };
  counts: { contacts: number; open_deals: number; overdue_tasks: number; promises: number };
};

export function useCrmLive() {
  return useQuery<CrmLive, ApiError>({
    queryKey: ["crm", "live"],
    queryFn: () => get<CrmLive>("crm.live", "/api/crm/live"),
    retry: false,
    refetchInterval: 30_000,
  });
}

export type CrmMemory = {
  email: string;
  person: Record<string, unknown> | null;
  deals: Deal[];
  tasks: { id: string; title: string; status: string; due_at: string | null; thread_id: string | null }[];
  timeline: { at: string; kind: string; title: string; detail: string | null; href: string }[];
  next_actions: { action: string; why: string; href: string }[];
};

export function useCrmMemory(email: string | undefined) {
  const clean = String(email || "").trim().toLowerCase();
  return useQuery<CrmMemory, ApiError>({
    queryKey: ["crm", "memory", clean],
    queryFn: () => get<CrmMemory>("crm.memory", `/api/crm/memory?email=${encodeURIComponent(clean)}`, { email: clean }),
    enabled: clean.includes("@"),
    retry: false,
  });
}

export function useCrmLeads(state: Lead["state"] | "all") {
  return useQuery<{ leads: Lead[] }, ApiError>({
    queryKey: ["crm", "leads", state],
    queryFn: () => get<{ leads: Lead[] }>("crm.leads", `/api/crm/leads?state=${state}`, { state }),
    retry: false,
  });
}

/** People who wrote you in the last 30 days and are not on the book yet. */
export type SuggestedLead = { email: string; message_count: number; last_mail_at: string };

export function useCrmLeadSuggestions() {
  return useQuery<{ suggestions: SuggestedLead[] }, ApiError>({
    queryKey: ["crm", "leads", "suggest"],
    queryFn: () => get<{ suggestions: SuggestedLead[] }>("crm.leads.suggest", "/api/crm/leads/suggest"),
    retry: false,
    staleTime: 60_000,
  });
}

export function useCrmDeals() {
  return useQuery<{ deals: Deal[] }, ApiError>({
    queryKey: ["crm", "deals"],
    queryFn: () => get<{ deals: Deal[] }>("crm.deals", "/api/crm/deals"),
    retry: false,
  });
}

export function useCrmActivities(dealId?: string) {
  return useQuery<{ activities: CrmActivity[] }, ApiError>({
    queryKey: ["crm", "activities", dealId ?? "all"],
    queryFn: () =>
      get<{ activities: CrmActivity[] }>(
        "crm.activities",
        `/api/crm/activities${dealId ? `?deal_id=${dealId}` : ""}`,
        dealId ? { deal_id: dealId } : {},
      ),
    retry: false,
  });
}

export function useCrmInsights(dealId?: string) {
  return useQuery<{ insights: AiInsight[] }, ApiError>({
    queryKey: ["crm", "insights", dealId ?? "all"],
    queryFn: () =>
      get<{ insights: AiInsight[] }>(
        "crm.insights",
        `/api/crm/insights${dealId ? `?deal_id=${dealId}` : ""}`,
        dealId ? { deal_id: dealId } : {},
      ),
    retry: false,
  });
}

export function useSharedItems(kind: SharedItem["kind"]) {
  return useQuery<{ items: SharedItem[] }, ApiError>({
    queryKey: ["crm", "shared", kind],
    queryFn: () =>
      get<{ items: SharedItem[] }>("crm.shared", `/api/crm/shared?kind=${kind}`, { kind }),
    retry: false,
  });
}

export function useMentions() {
  return useQuery<{ mentions: Mention[] }, ApiError>({
    queryKey: ["crm", "mentions"],
    queryFn: () => get<{ mentions: Mention[] }>("crm.mentions", "/api/crm/mentions"),
    retry: false,
  });
}

export function useApprovals() {
  return useQuery<{ approvals: Approval[] }, ApiError>({
    queryKey: ["crm", "approvals"],
    queryFn: () => get<{ approvals: Approval[] }>("crm.approvals", "/api/crm/approvals"),
    retry: false,
  });
}

export function useCrmAudit() {
  return useQuery<{ entries: CrmAuditEntry[] }, ApiError>({
    queryKey: ["crm", "audit"],
    queryFn: () => get<{ entries: CrmAuditEntry[] }>("crm.audit", "/api/crm/audit"),
    retry: false,
  });
}

export function useTeamPermissions() {
  return useQuery<{ members: TeamMemberPermission[] }, ApiError>({
    queryKey: ["crm", "permissions"],
    queryFn: () =>
      get<{ members: TeamMemberPermission[] }>("crm.permissions", "/api/crm/permissions"),
    retry: false,
  });
}

export function useFounderCrmState() {
  return useQuery<FounderCrmState, ApiError>({
    queryKey: ["crm", "founder-state"],
    queryFn: () => get<FounderCrmState>("crm.founderState", "/api/founder/crm/state"),
    retry: false,
  });
}

/* --------------------------------------------------------------- mutations */

function useCrmMutation<TOut, TIn>(procedure: string, path: string, invalidate: string[]) {
  const qc = useQueryClient();
  return useMutation<TOut, ApiError, TIn>({
    mutationFn: (input) => rpcOrRest<TOut>(procedure, { path, method: "POST", body: input }, input),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["crm", ...invalidate] });
    },
  });
}

/** Move a deal between stages. Server rewrites probability + writes audit. */
export function useMoveDeal() {
  return useCrmMutation<{ deal: Deal }, { id: string; stage: DealStage }>(
    "crm.moveDeal",
    "/api/crm/deals/stage",
    ["deals", "live", "evidence"],
  );
}

export function useCreateLead() {
  return useCrmMutation<{ ok: boolean; id?: string }, { email: string; display_name?: string; company?: string }>(
    "crm.createLead",
    "/api/crm/leads",
    ["leads", "overview", "live", "evidence"],
  );
}

export function useCreateDeal() {
  return useCrmMutation<
    { ok: boolean; id?: string },
    { title: string; company?: string; contact_email?: string; value?: number; next_step?: string }
  >("crm.createDeal", "/api/crm/deals", ["deals", "overview", "live", "evidence"]);
}

export function useDealToWork() {
  return useCrmMutation<{ ok: boolean; task_id?: string }, { id: string }>(
    "crm.dealWork",
    "/api/crm/deals/work",
    ["deals", "live", "evidence"],
  );
}

export function useAttachDealThread() {
  return useCrmMutation<{ ok: boolean; thread_id?: string }, { id: string }>(
    "crm.dealThread",
    "/api/crm/deals/thread",
    ["deals", "live", "overview", "evidence"],
  );
}

export type CrmEvidenceEntry = {
  id: string;
  actor: string | null;
  decision: string;
  why: string | null;
  source_table: string | null;
  source_id: string | null;
  action: string | null;
  result: string | null;
  created_at: string;
};

export function useCrmEvidence() {
  return useQuery<{ entries: CrmEvidenceEntry[] }, ApiError>({
    queryKey: ["crm", "evidence"],
    queryFn: () => get<{ entries: CrmEvidenceEntry[] }>("crm.evidence", "/api/crm/evidence"),
    retry: false,
  });
}

export function useConvertLead() {
  return useCrmMutation<{ deal_id: string }, { id: string }>(
    "crm.convertLead",
    "/api/crm/leads/convert",
    ["leads", "deals", "overview", "live", "evidence"],
  );
}

export function useAssignShared() {
  return useCrmMutation<{ ok: boolean }, { id: string; assignee: string }>(
    "crm.assignShared",
    "/api/crm/shared/assign",
    ["shared"],
  );
}

export function useDecideApproval() {
  return useCrmMutation<{ ok: boolean }, { id: string; decision: "approved" | "rejected" }>(
    "crm.decideApproval",
    "/api/crm/approvals/decide",
    ["approvals"],
  );
}

/** Founder kill switch — stops every public CRM write instantly. */
export function useCrmKillSwitch() {
  return useCrmMutation<FounderCrmState, { crm_enabled?: boolean; ai_enabled?: boolean }>(
    "crm.founderToggle",
    "/api/founder/crm/toggle",
    ["founder-state"],
  );
}

/* ------------------------------------------------------------------ format */

export function probabilityPercent(value: number | null | undefined): number | null {
  if (value === null || value === undefined || Number.isNaN(Number(value))) return null;
  const n = Number(value);
  return Math.max(0, Math.min(100, Math.round(n <= 1 ? n * 100 : n)));
}

export function money(value: number, currency = "GBP") {
  try {
    return new Intl.NumberFormat("en-GB", {
      style: "currency",
      currency,
      maximumFractionDigits: 0,
    }).format(value);
  } catch {
    return `${currency} ${Math.round(value)}`;
  }
}
