/**
 * Phase 18 — AI Automation (transport only).
 *
 * AI LOCK: automation ai.anexomail.com product ka hissa hai.
 * NO DUPLICATE: trigger evaluation, rule matching, sending aur approval gates
 * sab server par (Server 2 -> Supabase 4). UI sirf state dikhati hai.
 * NO WEBHOOK / NO PUBLIC API: automation LEO Actions + native integrations se chalti hai.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type TriggerKind = "mail_received" | "thread_idle" | "schedule" | "manual" | "deal_stage";

export const TRIGGER_LABEL: Record<TriggerKind, string> = {
  mail_received: "Mail arrives",
  thread_idle: "Thread goes quiet",
  schedule: "On a schedule",
  manual: "Manual run",
  deal_stage: "Deal changes stage",
};

export type WorkflowStep = {
  id: string;
  position: number;
  action: string;
  config: Record<string, unknown>;
};

export type Workflow = {
  id: string;
  name: string;
  description: string | null;
  trigger_kind: TriggerKind;
  trigger_config: Record<string, unknown>;
  enabled: boolean;
  requires_approval: boolean;
  runs: number;
  failures: number;
  last_run_at: string | null;
  steps: WorkflowStep[];
};

export type WorkflowRun = {
  id: string;
  workflow_id: string;
  workflow_name: string | null;
  trigger_ref: string | null;
  state: "running" | "done" | "failed" | "awaiting_approval" | "skipped";
  steps_done: number;
  cost: number;
  currency: string;
  latency_ms: number | null;
  error: string | null;
  created_at: string;
};

export type AiRule = {
  id: string;
  name: string;
  scope: "mail" | "crm" | "calendar" | "tasks";
  conditions: { field: string; op: string; value: string }[];
  actions: { action: string; config?: Record<string, unknown> }[];
  priority: number;
  enabled: boolean;
  matches: number;
  last_match_at: string | null;
};

export type AiVariable = {
  id: string;
  key: string;
  value: string;
  kind: "static" | "computed" | "secret_free";
  description: string | null;
};

export type AiSuggestion = {
  id: string;
  kind: "workflow" | "rule" | "variable" | "cleanup";
  title: string;
  reason: string;
  confidence: number | null;
  state: "open" | "accepted" | "dismissed";
  created_at: string;
};

export type EmailAutomation = {
  id: string;
  mailbox: string;
  name: string;
  mode: "draft_only" | "auto_send" | "notify_only";
  workflow_id: string | null;
  enabled: boolean;
  handled: number;
  escalations: number;
  last_handled_at: string | null;
};

const list = <T,>(key: string, procedure: string, path: string) =>
  ({
    queryKey: ["ai", "automation", key],
    queryFn: () => rpcOrRest<T>(procedure, { path }),
    retry: false as const,
  });

export function useWorkflows() {
  return useQuery<{ workflows: Workflow[] }, ApiError>(
    list<{ workflows: Workflow[] }>("workflows", "ai.workflows", "/api/ai/automation/workflows"),
  );
}

export function useWorkflowRuns() {
  return useQuery<{ runs: WorkflowRun[] }, ApiError>(
    list<{ runs: WorkflowRun[] }>("runs", "ai.workflowRuns", "/api/ai/automation/runs"),
  );
}

export function useAiRules() {
  return useQuery<{ rules: AiRule[] }, ApiError>(
    list<{ rules: AiRule[] }>("rules", "ai.rules", "/api/ai/automation/rules"),
  );
}

export function useAiVariables() {
  return useQuery<{ variables: AiVariable[] }, ApiError>(
    list<{ variables: AiVariable[] }>("variables", "ai.variables", "/api/ai/automation/variables"),
  );
}

export function useAiSuggestions() {
  return useQuery<{ suggestions: AiSuggestion[] }, ApiError>(
    list<{ suggestions: AiSuggestion[] }>(
      "suggestions",
      "ai.suggestions",
      "/api/ai/automation/suggestions",
    ),
  );
}

export function useEmailAutomations() {
  return useQuery<{ automations: EmailAutomation[] }, ApiError>(
    list<{ automations: EmailAutomation[] }>(
      "email",
      "ai.emailAutomations",
      "/api/ai/automation/email",
    ),
  );
}

function invalidate(qc: ReturnType<typeof useQueryClient>) {
  void qc.invalidateQueries({ queryKey: ["ai", "automation"] });
}

export function useToggleWorkflow() {
  const qc = useQueryClient();
  return useMutation<{ enabled: boolean }, ApiError, { id: string; enabled: boolean }>({
    mutationFn: (body) =>
      rpcOrRest<{ enabled: boolean }>(
        "ai.toggleWorkflow",
        { path: `/api/ai/automation/workflows/${body.id}/toggle`, method: "POST", body },
        body,
      ),
    onSuccess: () => invalidate(qc),
  });
}

export function useRunWorkflow() {
  const qc = useQueryClient();
  return useMutation<{ run: WorkflowRun }, ApiError, { id: string }>({
    mutationFn: (body) =>
      rpcOrRest<{ run: WorkflowRun }>(
        "ai.runWorkflow",
        { path: `/api/ai/automation/workflows/${body.id}/run`, method: "POST", body },
        body,
      ),
    onSuccess: () => invalidate(qc),
  });
}

/** Dry run = kuch send nahi hota, sirf batata hai kya hota. */
export function useDryRunWorkflow() {
  return useMutation<
    { would_match: number; log: string[] },
    ApiError,
    { id: string }
  >({
    mutationFn: (body) =>
      rpcOrRest<{ would_match: number; log: string[] }>(
        "ai.dryRunWorkflow",
        { path: `/api/ai/automation/workflows/${body.id}/dry-run`, method: "POST", body },
        body,
      ),
  });
}

export function useToggleRule() {
  const qc = useQueryClient();
  return useMutation<{ enabled: boolean }, ApiError, { id: string; enabled: boolean }>({
    mutationFn: (body) =>
      rpcOrRest<{ enabled: boolean }>(
        "ai.toggleRule",
        { path: `/api/ai/automation/rules/${body.id}/toggle`, method: "POST", body },
        body,
      ),
    onSuccess: () => invalidate(qc),
  });
}

export function useSaveVariable() {
  const qc = useQueryClient();
  return useMutation<
    { variable: AiVariable },
    ApiError,
    { key: string; value: string; description?: string }
  >({
    mutationFn: (body) =>
      rpcOrRest<{ variable: AiVariable }>(
        "ai.saveVariable",
        { path: "/api/ai/automation/variables", method: "POST", body },
        body,
      ),
    onSuccess: () => invalidate(qc),
  });
}

export function useDeleteVariable() {
  const qc = useQueryClient();
  return useMutation<{ deleted: number }, ApiError, { id: string }>({
    mutationFn: (body) =>
      rpcOrRest<{ deleted: number }>(
        "ai.deleteVariable",
        { path: `/api/ai/automation/variables/${body.id}`, method: "DELETE" },
        body,
      ),
    onSuccess: () => invalidate(qc),
  });
}

export function useDecideSuggestion() {
  const qc = useQueryClient();
  return useMutation<{ state: string }, ApiError, { id: string; decision: "accept" | "dismiss" }>({
    mutationFn: (body) =>
      rpcOrRest<{ state: string }>(
        "ai.decideSuggestion",
        { path: `/api/ai/automation/suggestions/${body.id}/decide`, method: "POST", body },
        body,
      ),
    onSuccess: () => invalidate(qc),
  });
}

export function useToggleEmailAutomation() {
  const qc = useQueryClient();
  return useMutation<
    { enabled: boolean },
    ApiError,
    { id: string; enabled?: boolean; mode?: EmailAutomation["mode"] }
  >({
    mutationFn: (body) =>
      rpcOrRest<{ enabled: boolean }>(
        "ai.toggleEmailAutomation",
        { path: `/api/ai/automation/email/${body.id}`, method: "POST", body },
        body,
      ),
    onSuccess: () => invalidate(qc),
  });
}