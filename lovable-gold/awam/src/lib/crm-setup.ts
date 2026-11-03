/**
 * CRM setup — pipelines, custom fields, duplicate merge, web forms (CRM P1 + P2).
 * Transport only: every call is a Rust proc (crmx module) over the kernel's WebTransport/QUIC, falling back to plain HTTP.
 * Plan caps and the Pro+ gate are enforced by the server; the numbers in `limits` come from it (-1 = unlimited).
 */
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type Limits = { pipelines: number; fields: number; forms: number };

export type StageKind = "open" | "won" | "lost";
export type PipelineStage = { key: string; label: string; position: number; probability: number; kind: StageKind };
export type Pipeline = { id: string; name: string; is_default: boolean; position: number; stages: PipelineStage[] };

export type FieldKind = "text" | "number" | "date" | "select" | "checkbox";
export type FieldDef = { id: string; entity: "lead" | "deal"; key: string; label: string; kind: FieldKind; options: string[]; position: number };

export type FormFieldKind = "text" | "email" | "number" | "date" | "select" | "textarea";
export type FormField = { key: string; label: string; kind: FormFieldKind; required: boolean; options?: string[] };
export type WebForm = {
  id: string;
  slug: string;
  name: string;
  owner: string;
  fields: FormField[];
  success_message: string;
  active: boolean;
  submissions: number;
  created_at: string;
  path: string;
};

export type DupRecord = {
  id: string;
  email?: string;
  display_name?: string | null;
  title?: string;
  company?: string | null;
  stage?: string;
  value?: number;
  currency?: string;
  source?: string;
  created_at: string;
};
export type DupGroup = { records: DupRecord[] };

export type BoardDeal = {
  id: string;
  title: string;
  company: string | null;
  contact_email: string | null;
  stage: string;
  value: number;
  currency: string;
  probability: number | null;
  owner: string | null;
  next_step: string | null;
  next_step_due: string | null;
  thread_id: string | null;
  stale_days: number | null;
  updated_at: string;
  custom: Record<string, string>;
  pipeline_id: string;
};
export type Board = {
  pipeline: Pipeline;
  pipelines: { id: string; name: string; is_default: boolean }[];
  deals: BoardDeal[];
  fields: FieldDef[];
};

/** -1 means unlimited. */
export const capText = (n: number) => (n < 0 ? "Unlimited" : String(n));
export const atCap = (used: number, cap: number) => cap >= 0 && used >= cap;

const q = ["crm", "setup"] as const;

function useSetupMutation<TOut, TIn>(proc: string, keys: string[]) {
  const qc = useQueryClient();
  return useMutation<TOut, ApiError, TIn>({
    mutationFn: (input) => rpc<TOut>(proc, input),
    onSuccess: () => {
      for (const k of keys) void qc.invalidateQueries({ queryKey: [...q, k] });
      void qc.invalidateQueries({ queryKey: ["crm", "board"] });
    },
  });
}

export function usePipelines() {
  return useQuery<{ pipelines: Pipeline[]; limits: Limits }, ApiError>({
    queryKey: [...q, "pipelines"],
    queryFn: () => rpc("crm.pipelines.list", {}),
    retry: false,
  });
}
export type StageInput = { key?: string; label: string; probability: number; kind: StageKind };
export const useSavePipeline = () =>
  useSetupMutation<{ id: string }, { id?: string; name: string; stages: StageInput[] }>("crm.pipelines.save", ["pipelines"]);
export const useDeletePipeline = () => useSetupMutation<{ deleted: true }, { id: string }>("crm.pipelines.delete", ["pipelines"]);

export function useFieldDefs() {
  return useQuery<{ fields: FieldDef[]; limits: Limits }, ApiError>({
    queryKey: [...q, "fields"],
    queryFn: () => rpc("crm.fields.list", {}),
    retry: false,
  });
}
export const useSaveField = () =>
  useSetupMutation<{ id: string }, { id?: string; entity: "lead" | "deal"; label: string; kind: FieldKind; options?: string[] }>("crm.fields.save", ["fields"]);
export const useDeleteField = () => useSetupMutation<{ deleted: true }, { id: string }>("crm.fields.delete", ["fields"]);

export function useWebForms() {
  return useQuery<{ forms: WebForm[]; limits: Limits }, ApiError>({
    queryKey: [...q, "forms"],
    queryFn: () => rpc("crm.forms.list", {}),
    retry: false,
  });
}
export const useSaveForm = () =>
  useSetupMutation<
    { id: string; slug: string; path: string },
    { id?: string; name: string; fields: FormField[]; success_message?: string; active?: boolean }
  >("crm.forms.save", ["forms"]);
export const useDeleteForm = () => useSetupMutation<{ deleted: true }, { id: string }>("crm.forms.delete", ["forms"]);

export function useDuplicates(kind: "lead" | "deal") {
  return useQuery<{ kind: string; groups: DupGroup[]; total_groups: number }, ApiError>({
    queryKey: [...q, "dups", kind],
    queryFn: () => rpc("crm.dups.list", { kind }),
    retry: false,
  });
}
export function useMerge() {
  const qc = useQueryClient();
  return useMutation<{ merged: number; kept_id: string }, ApiError, { kind: "lead" | "deal"; keep: string; drop: string[] }>({
    mutationFn: (input) => rpc("crm.merge", input),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: [...q, "dups"] });
      void qc.invalidateQueries({ queryKey: ["crm"] });
    },
  });
}

/* ---- board (deals of one pipeline, with that pipeline's own stages) */

export function useCrmBoard(pipelineId: string | undefined) {
  return useQuery<Board, ApiError>({
    queryKey: ["crm", "board", pipelineId ?? "default"],
    queryFn: () => rpc("crm.board", pipelineId ? { pipeline_id: pipelineId } : {}),
    retry: false,
  });
}
export function useMoveDealStage() {
  const qc = useQueryClient();
  return useMutation<{ deal: { id: string; stage: string } }, ApiError, { id: string; stage: string }>({
    mutationFn: (input) => rpc("crm.deals.move", input),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["crm", "board"] });
      void qc.invalidateQueries({ queryKey: ["crm", "overview"] });
      void qc.invalidateQueries({ queryKey: ["crm", "deals"] });
    },
  });
}
export function useSetDealPipeline() {
  const qc = useQueryClient();
  return useMutation<{ deal: { id: string } }, ApiError, { id: string; pipeline_id: string }>({
    mutationFn: (input) => rpc("crm.deals.setPipeline", input),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["crm", "board"] }),
  });
}
export function useSetCustom() {
  const qc = useQueryClient();
  return useMutation<{ custom: Record<string, string> }, ApiError, { entity: "lead" | "deal"; id: string; values: Record<string, string | null> }>({
    mutationFn: (input) => rpc("crm.custom.set", input),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["crm", "board"] });
      void qc.invalidateQueries({ queryKey: ["crm", "leads"] });
    },
  });
}

/* ---- public form (no login) */

export type PublicForm = { name: string; fields: FormField[]; success_message: string };
export const getPublicForm = (slug: string) => rpc<PublicForm>("crm.form.get", { slug });
export const submitPublicForm = (slug: string, data: Record<string, string>, hp: string, ms: number) =>
  rpc<{ received: true }>("crm.form.submit", { slug, data, hp, ms });
