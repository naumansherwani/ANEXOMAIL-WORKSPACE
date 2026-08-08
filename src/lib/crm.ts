/**
 * Phase 13 — AI CRM Workspace (transport only).
 *
 * NO DUPLICATE rule: lead scoring, pipeline maths, deal probability, AI insights,
 * shared-inbox assignment, mentions/comments, approvals and audit ALL live on the
 * server (Server 2 -> Supabase 4). This file only speaks HTTP/RPC.
 * NO MOCK rule: a missing endpoint surfaces as an honest "not wired" state.
 *
 * Awam surface: aicrm.anexomail.com -> /app/crm
 * Founder surface: founderworkspace.anexomail.com/app/founder/crm (IP locked)
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

/* ------------------------------------------------------------------ types */

export type DealStage =
  | "new"
  | "qualified"
  | "proposal"
  | "negotiation"
  | "won"
  | "lost";

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
  stale_days: number | null
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

const get = <T,>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path }, input);

export function useCrmOverview() {
  return useQuery<CrmOverview, ApiError>({
    queryKey: ["crm", "overview"],
    queryFn: () => get<CrmOverview>("crm.overview", "/api/crm/overview"),
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
    mutationFn: (input) =>
      rpcOrRest<TOut>(procedure, { path, method: "POST", body: input }, input),
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
    ["deals"],
  );
}

export function useConvertLead() {
  return useCrmMutation<{ deal_id: string }, { id: string }>(
    "crm.convertLead",
    "/api/crm/leads/convert",
    ["leads"],
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
