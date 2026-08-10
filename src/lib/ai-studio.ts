/**
 * Phase 17 — AI Studio (transport only).
 *
 * AI LOCK: studio sirf ai.anexomail.com / aiemail.anexomail.com ka hissa hai.
 * NO DUPLICATE: prompts, model routing, guardrails, receipts, credits — sab server par.
 * NO MOCK: endpoint na ho to honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import type { AiGuardrailEvent, AiReceipt } from "@/lib/ai-workspace";
import { rpcOrRest } from "@/lib/rpc";

export type StudioToolKey =
  | "rewrite"
  | "grammar"
  | "translate"
  | "summarize"
  | "draft"
  | "tone"
  | "meeting"
  | "tasks"
  | "template";

export type StudioTool = {
  key: StudioToolKey;
  label: string;
  job: string;
  /** Kahan real write hota hai — server ka kaam, UI sirf batati hai. */
  writesTo: string | null;
  option?: { name: "language" | "tone" | "length" | "audience"; choices: string[] };
};

export const STUDIO_TOOLS: StudioTool[] = [
  {
    key: "rewrite",
    label: "Rewrite",
    job: "Same meaning, tighter words. Before/after diff har run pe.",
    writesTo: "compose",
    option: { name: "length", choices: ["shorter", "same", "longer"] },
  },
  {
    key: "grammar",
    label: "Grammar",
    job: "Sirf grammar aur spelling — matlab kabhi nahi badalta.",
    writesTo: "compose",
  },
  {
    key: "translate",
    label: "Translate",
    job: "Auto-detect source, chosen target. Manual sirf override.",
    writesTo: "compose",
    option: {
      name: "language",
      choices: ["English", "Urdu", "Roman Urdu", "Arabic", "French", "German", "Spanish", "Chinese"],
    },
  },
  {
    key: "summarize",
    label: "Summarize",
    job: "Poora thread ek paragraph plus decisions.",
    writesTo: null,
    option: { name: "length", choices: ["one line", "brief", "full"] },
  },
  {
    key: "draft",
    label: "Draft generator",
    job: "Thread ke context se pehla draft — blank box nahi.",
    writesTo: "compose",
    option: { name: "audience", choices: ["customer", "supplier", "team", "investor"] },
  },
  {
    key: "tone",
    label: "Tone changer",
    job: "Wohi baat, doosra tone. Meaning lock rehta hai.",
    writesTo: "compose",
    option: {
      name: "tone",
      choices: ["formal", "friendly", "direct", "apologetic", "firm"],
    },
  },
  {
    key: "meeting",
    label: "Meeting extraction",
    job: "Time, attendees, agenda nikaal ke asli calendar event banata hai.",
    writesTo: "calendar_events",
  },
  {
    key: "tasks",
    label: "Task extraction",
    job: "Promise aur deadline nikaal ke asli task banata hai.",
    writesTo: "work_tasks",
  },
  {
    key: "template",
    label: "AI templates",
    job: "Repeat hone wale replies ko Phase 9 template bana deta hai.",
    writesTo: "mail_templates",
  },
];

export const TOOL_LABEL: Record<StudioToolKey, string> = STUDIO_TOOLS.reduce(
  (acc, t) => ({ ...acc, [t.key]: t.label }),
  {} as Record<StudioToolKey, string>,
);

export type StudioRun = {
  id: string;
  tool: StudioToolKey;
  input: string;
  output: string;
  options: Record<string, string>;
  source_kind: string | null;
  source_ref: string | null;
  applied: boolean;
  applied_to: string | null;
  applied_ref: string | null;
  state: "done" | "failed" | "paused";
  error: string | null;
  receipt: AiReceipt | null;
  guardrail: AiGuardrailEvent | null;
  created_at: string;
};

export type StudioRecipeStep = { tool: StudioToolKey; options?: Record<string, string> };

export type StudioRecipe = {
  id: string;
  name: string;
  description: string | null;
  steps: StudioRecipeStep[];
  runs: number;
  last_run_at: string | null;
};

export type StudioBatch = {
  id: string;
  tool: StudioToolKey;
  total: number;
  done: number;
  failed: number;
  cost: number;
  currency: string;
  state: "running" | "done" | "failed";
  created_at: string;
};

export type StudioTarget = { kind: string; ref: string; label: string };

export function useStudioRuns(tool: StudioToolKey | "all") {
  return useQuery<{ runs: StudioRun[] }, ApiError>({
    queryKey: ["ai", "studio", "runs", tool],
    queryFn: () =>
      rpcOrRest<{ runs: StudioRun[] }>(
        "ai.studioRuns",
        { path: `/api/ai/studio/runs?tool=${tool}` },
        { tool },
      ),
    retry: false,
  });
}

export function useStudioRecipes() {
  return useQuery<{ recipes: StudioRecipe[] }, ApiError>({
    queryKey: ["ai", "studio", "recipes"],
    queryFn: () =>
      rpcOrRest<{ recipes: StudioRecipe[] }>("ai.studioRecipes", {
        path: "/api/ai/studio/recipes",
      }),
    retry: false,
  });
}

export function useStudioBatches() {
  return useQuery<{ batches: StudioBatch[] }, ApiError>({
    queryKey: ["ai", "studio", "batches"],
    queryFn: () =>
      rpcOrRest<{ batches: StudioBatch[] }>("ai.studioBatches", {
        path: "/api/ai/studio/batches",
      }),
    retry: false,
  });
}

/** Studio targets = asli threads/drafts, server se. Koi dummy list nahi. */
export function useStudioTargets() {
  return useQuery<{ targets: StudioTarget[] }, ApiError>({
    queryKey: ["ai", "studio", "targets"],
    queryFn: () =>
      rpcOrRest<{ targets: StudioTarget[] }>("ai.studioTargets", {
        path: "/api/ai/studio/targets",
      }),
    retry: false,
  });
}

export type RunToolInput = {
  tool: StudioToolKey;
  input: string;
  options?: Record<string, string>;
  source_kind?: string;
  source_ref?: string;
};

export function useRunStudioTool() {
  const qc = useQueryClient();
  return useMutation<{ run: StudioRun }, ApiError, RunToolInput>({
    mutationFn: (body) =>
      rpcOrRest<{ run: StudioRun }>(
        "ai.studioRun",
        { path: "/api/ai/studio/run", method: "POST", body },
        body,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["ai", "studio", "runs"] });
      void qc.invalidateQueries({ queryKey: ["ai", "credits"] });
    },
  });
}

/** Apply = server ka real write (compose, calendar_events, work_tasks, mail_templates). */
export function useApplyStudioRun() {
  const qc = useQueryClient();
  return useMutation<
    { applied: boolean; applied_to: string; applied_ref: string | null },
    ApiError,
    { id: string; target?: string }
  >({
    mutationFn: (body) =>
      rpcOrRest<{ applied: boolean; applied_to: string; applied_ref: string | null }>(
        "ai.studioApply",
        { path: `/api/ai/studio/runs/${body.id}/apply`, method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai", "studio", "runs"] }),
  });
}

export function useRunStudioBatch() {
  const qc = useQueryClient();
  return useMutation<
    { batch: StudioBatch },
    ApiError,
    { tool: StudioToolKey; options?: Record<string, string>; targets: StudioTarget[] }
  >({
    mutationFn: (body) =>
      rpcOrRest<{ batch: StudioBatch }>(
        "ai.studioBatch",
        { path: "/api/ai/studio/batch", method: "POST", body },
        body,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["ai", "studio", "batches"] });
      void qc.invalidateQueries({ queryKey: ["ai", "studio", "runs"] });
    },
  });
}

export function useSaveStudioRecipe() {
  const qc = useQueryClient();
  return useMutation<
    { recipe: StudioRecipe },
    ApiError,
    { name: string; description?: string; steps: StudioRecipeStep[] }
  >({
    mutationFn: (body) =>
      rpcOrRest<{ recipe: StudioRecipe }>(
        "ai.studioSaveRecipe",
        { path: "/api/ai/studio/recipes", method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai", "studio", "recipes"] }),
  });
}

export function useRunStudioRecipe() {
  const qc = useQueryClient();
  return useMutation<
    { output: string; runs: StudioRun[] },
    ApiError,
    { recipe_id: string; input: string }
  >({
    mutationFn: (body) =>
      rpcOrRest<{ output: string; runs: StudioRun[] }>(
        "ai.studioRunRecipe",
        { path: `/api/ai/studio/recipes/${body.recipe_id}/run`, method: "POST", body },
        body,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["ai", "studio"] });
      void qc.invalidateQueries({ queryKey: ["ai", "credits"] });
    },
  });
}

/** Word-level before/after diff — purely presentational, koi AI call nahi. */
export type DiffPart = { text: string; kind: "same" | "added" | "removed" };

export function wordDiff(before: string, after: string): DiffPart[] {
  const a = before.split(/(\s+)/);
  const b = after.split(/(\s+)/);
  const n = a.length;
  const m = b.length;
  const lcs: number[][] = Array.from({ length: n + 1 }, () => new Array<number>(m + 1).fill(0));
  for (let i = n - 1; i >= 0; i -= 1) {
    for (let j = m - 1; j >= 0; j -= 1) {
      lcs[i]![j] = a[i] === b[j] ? lcs[i + 1]![j + 1]! + 1 : Math.max(lcs[i + 1]![j]!, lcs[i]![j + 1]!);
    }
  }
  const parts: DiffPart[] = [];
  const push = (text: string, kind: DiffPart["kind"]) => {
    const last = parts[parts.length - 1];
    if (last && last.kind === kind) last.text += text;
    else parts.push({ text, kind });
  };
  let i = 0;
  let j = 0;
  while (i < n && j < m) {
    if (a[i] === b[j]) {
      push(a[i]!, "same");
      i += 1;
      j += 1;
    } else if (lcs[i + 1]![j]! >= lcs[i]![j + 1]!) {
      push(a[i]!, "removed");
      i += 1;
    } else {
      push(b[j]!, "added");
      j += 1;
    }
  }
  while (i < n) {
    push(a[i]!, "removed");
    i += 1;
  }
  while (j < m) {
    push(b[j]!, "added");
    j += 1;
  }
  return parts;
}