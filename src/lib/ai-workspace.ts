/**
 * Phase 16 — ANEXOMAIL AI Workspace (transport only).
 *
 * AI LOCK: ye poora surface sirf ai.anexomail.com / aiemail.anexomail.com ka
 * hissa hai. anexomail.com ke Basic/Pro/Business mein AI kabhi nahi.
 * NO DUPLICATE: model routing, escalation chain (Leo -> Jimmy -> Sherlock),
 * guardrails, credits, tokens aur memory sab server par (Server 2 -> Supabase 4).
 * NO MOCK: missing endpoint = honest "not wired" state, dummy data kabhi nahi.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { ApiError, sessionToken, type ApiError as ApiErrorType } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

const BASE = (import.meta.env['VITE_API_URL'] as string | undefined)?.replace(/\/$/, "") ?? "";

export type AiAgentKey = "leo" | "jimmy" | "sherlock";

export type AiSession = {
  id: string;
  title: string;
  model: string;
  created_at: string;
  updated_at: string | null;
  turns: number;
  cost: number;
  currency: string;
};

export type AiSource = { title: string; ref: string; kind: string | null };

export type AiReceipt = {
  id: string;
  turn_id: string;
  model: string;
  input_tokens: number;
  output_tokens: number;
  cost: number;
  currency: string;
  ttft_ms: number | null;
  latency_ms: number | null;
  sources: AiSource[];
  escalated_to: AiAgentKey | null;
  sherlock_verdict: string | null;
  created_at: string;
};

export type AiGuardrailEvent = {
  id: string;
  turn_id: string | null;
  keyword: string;
  reason: string;
  state: "paused" | "released" | "refused";
  created_at: string;
};

export type AiTurn = {
  id: string;
  parent_turn_id: string | null;
  role: "user" | "assistant";
  content: string;
  model: string | null;
  agent: AiAgentKey | null;
  created_at: string;
  receipt: AiReceipt | null;
  guardrail: AiGuardrailEvent | null;
};

export type AiMemoryItem = {
  id: string;
  key: string;
  value: string;
  source: string | null;
  session_id: string | null;
  created_at: string;
};

export type AiPrompt = {
  id: string;
  name: string;
  description: string | null;
  latest_version: number;
  forked_from: string | null;
  updated_at: string | null;
};

export type AiPromptVersion = {
  id: string;
  prompt_id: string;
  version: number;
  body: string;
  variables: string[];
  note: string | null;
  created_at: string;
};

export type AiArenaEntry = {
  agent: string;
  model: string;
  answer: string;
  latency_ms: number | null;
  cost: number;
  sherlock_score: number | null;
};

export type AiArenaRun = {
  id: string;
  question: string;
  created_at: string;
  winner: string | null;
  entries: AiArenaEntry[];
};

export type AiCredits = {
  unlimited: boolean;
  balance: number;
  spent_today: number;
  spent_month: number;
  currency: string;
  rate_per_1k: number | null;
};

export const ARENA_DEFAULT: AiAgentKey[] = ["leo", "jimmy", "sherlock"];

export const AGENT_LABEL: Record<AiAgentKey, string> = {
  leo: "LEO",
  jimmy: "Jimmy John",
  sherlock: "Sherlock",
};

const get = <T,>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path }, input);

export function useAiSessions() {
  return useQuery<{ sessions: AiSession[] }, ApiErrorType>({
    queryKey: ["ai", "sessions"],
    queryFn: () => get<{ sessions: AiSession[] }>("ai.sessions", "/api/ai/sessions"),
    retry: false,
  });
}

export function useAiSession(sessionId: string | null) {
  return useQuery<{ session: AiSession; turns: AiTurn[] }, ApiErrorType>({
    queryKey: ["ai", "session", sessionId],
    queryFn: () =>
      get<{ session: AiSession; turns: AiTurn[] }>(
        "ai.session",
        `/api/ai/sessions/${sessionId}`,
        { session_id: sessionId },
      ),
    enabled: Boolean(sessionId),
    retry: false,
  });
}

export function useAiCredits() {
  return useQuery<AiCredits, ApiErrorType>({
    queryKey: ["ai", "credits"],
    queryFn: () => get<AiCredits>("ai.credits", "/api/ai/credits"),
    retry: false,
  });
}

export function useAiReceipts() {
  return useQuery<{ receipts: AiReceipt[]; total_cost: number; currency: string }, ApiErrorType>({
    queryKey: ["ai", "receipts"],
    queryFn: () =>
      get<{ receipts: AiReceipt[]; total_cost: number; currency: string }>(
        "ai.receipts",
        "/api/ai/receipts",
      ),
    retry: false,
  });
}

export function useAiMemory() {
  return useQuery<{ items: AiMemoryItem[] }, ApiErrorType>({
    queryKey: ["ai", "memory"],
    queryFn: () => get<{ items: AiMemoryItem[] }>("ai.memory", "/api/ai/memory"),
    retry: false,
  });
}

export function useAiPrompts() {
  return useQuery<{ prompts: AiPrompt[] }, ApiErrorType>({
    queryKey: ["ai", "prompts"],
    queryFn: () => get<{ prompts: AiPrompt[] }>("ai.prompts", "/api/ai/prompts"),
    retry: false,
  });
}

export function useAiPromptVersions(promptId: string | null) {
  return useQuery<{ versions: AiPromptVersion[] }, ApiErrorType>({
    queryKey: ["ai", "prompt-versions", promptId],
    queryFn: () =>
      get<{ versions: AiPromptVersion[] }>(
        "ai.promptVersions",
        `/api/ai/prompts/${promptId}/versions`,
        { prompt_id: promptId },
      ),
    enabled: Boolean(promptId),
    retry: false,
  });
}

export function useAiArenaRuns() {
  return useQuery<{ runs: AiArenaRun[] }, ApiErrorType>({
    queryKey: ["ai", "arena"],
    queryFn: () => get<{ runs: AiArenaRun[] }>("ai.arenaRuns", "/api/ai/arena"),
    retry: false,
  });
}

export function useAiGuardrailEvents() {
  return useQuery<{ events: AiGuardrailEvent[] }, ApiErrorType>({
    queryKey: ["ai", "guardrail"],
    queryFn: () => get<{ events: AiGuardrailEvent[] }>("ai.guardrail", "/api/ai/guardrail"),
    retry: false,
  });
}

export function useCreateAiSession() {
  const qc = useQueryClient();
  return useMutation<{ session: AiSession }, ApiErrorType, { title?: string; model?: string }>({
    mutationFn: (body) =>
      rpcOrRest<{ session: AiSession }>(
        "ai.createSession",
        { path: "/api/ai/sessions", method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai", "sessions"] }),
  });
}

export function useForgetMemory() {
  const qc = useQueryClient();
  return useMutation<{ deleted: number }, ApiErrorType, { id: string }>({
    mutationFn: (body) =>
      rpcOrRest<{ deleted: number }>(
        "ai.forgetMemory",
        { path: `/api/ai/memory/${body.id}`, method: "DELETE" },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai", "memory"] }),
  });
}

export function useRunArena() {
  const qc = useQueryClient();
  return useMutation<{ run: AiArenaRun }, ApiErrorType, { question: string; agents: string[] }>({
    mutationFn: (body) =>
      rpcOrRest<{ run: AiArenaRun }>(
        "ai.runArena",
        { path: "/api/ai/arena", method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai", "arena"] }),
  });
}

export function useForkPrompt() {
  const qc = useQueryClient();
  return useMutation<{ prompt: AiPrompt }, ApiErrorType, { prompt_id: string; name: string }>({
    mutationFn: (body) =>
      rpcOrRest<{ prompt: AiPrompt }>(
        "ai.forkPrompt",
        { path: `/api/ai/prompts/${body.prompt_id}/fork`, method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai", "prompts"] }),
  });
}

export function useSavePromptVersion() {
  const qc = useQueryClient();
  return useMutation<
    { version: AiPromptVersion },
    ApiErrorType,
    { prompt_id: string; body: string; note?: string }
  >({
    mutationFn: (input) =>
      rpcOrRest<{ version: AiPromptVersion }>(
        "ai.savePromptVersion",
        { path: `/api/ai/prompts/${input.prompt_id}/versions`, method: "POST", body: input },
        input,
      ),
    onSuccess: (_d, v) => {
      void qc.invalidateQueries({ queryKey: ["ai", "prompt-versions", v.prompt_id] });
      void qc.invalidateQueries({ queryKey: ["ai", "prompts"] });
    },
  });
}

export function useDecideGuardrail() {
  const qc = useQueryClient();
  return useMutation<{ state: string }, ApiErrorType, { id: string; decision: "release" | "refuse" }>({
    mutationFn: (body) =>
      rpcOrRest<{ state: string }>(
        "ai.decideGuardrail",
        { path: `/api/ai/guardrail/${body.id}`, method: "POST", body },
        body,
      ),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["ai", "guardrail"] }),
  });
}

export type ChatStreamEvent =
  | { type: "delta"; text: string }
  | { type: "ttft"; ms: number }
  | { type: "escalation"; agent: AiAgentKey; note?: string }
  | { type: "guardrail"; event: AiGuardrailEvent }
  | { type: "done"; turn: AiTurn }
  | { type: "error"; message: string };

export async function streamAiChat(
  input: {
    session_id: string;
    message: string;
    parent_turn_id?: string | null;
    model?: string;
    prompt_id?: string;
  },
  onEvent: (event: ChatStreamEvent) => void,
  signal?: AbortSignal,
): Promise<void> {
  if (!BASE) throw new ApiError("API base URL is not configured (VITE_API_URL).", 0, "no_api_url");

  const headers = new Headers({ "content-type": "application/json", accept: "text/event-stream" });
  const token = sessionToken.get();
  if (token) headers.set("authorization", `Bearer ${token}`);

  const started = performance.now();
  const res = await fetch(`${BASE}/api/ai/chat`, {
    method: "POST",
    headers,
    body: JSON.stringify(input),
    ...(signal ? { signal } : {}),
  });

  if (!res.ok || !res.body) {
    const text = await res.text().catch(() => "");
    throw new ApiError(text || `Chat failed (${res.status})`, res.status);
  }

  const reader = res.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let firstSeen = false;

  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    if (!firstSeen) {
      firstSeen = true;
      onEvent({ type: "ttft", ms: Math.round(performance.now() - started) });
    }
    buffer += decoder.decode(value, { stream: true });
    const lines = buffer.split("\n");
    buffer = lines.pop() ?? "";
    for (const raw of lines) {
      const line = raw.trim();
      if (!line) continue;
      const payload = line.startsWith("data:") ? line.slice(5).trim() : line;
      if (!payload || payload === "[DONE]") continue;
      if (!payload.startsWith("{")) {
        onEvent({ type: "delta", text: payload });
        continue;
      }
      try {
        onEvent(JSON.parse(payload) as ChatStreamEvent);
      } catch {
        onEvent({ type: "delta", text: payload });
      }
    }
  }
}

export function exportSession(
  session: AiSession,
  turns: AiTurn[],
  format: "md" | "json",
): { filename: string; mime: string; content: string } {
  if (format === "json") {
    return {
      filename: `${session.title || "leo-session"}.json`,
      mime: "application/json",
      content: JSON.stringify({ session, turns }, null, 2),
    };
  }
  const lines = [`# ${session.title || "LEO session"}`, "", `Model: ${session.model}`, ""];
  for (const t of turns) {
    lines.push(`## ${t.role === "user" ? "You" : AGENT_LABEL[t.agent ?? "leo"]}`);
    lines.push("");
    lines.push(t.content);
    if (t.receipt) {
      lines.push("");
      lines.push(
        `> ${t.receipt.model} · ${t.receipt.input_tokens}+${t.receipt.output_tokens} tokens · ` +
          `${t.receipt.currency} ${t.receipt.cost.toFixed(4)} · ${t.receipt.latency_ms ?? "?"}ms`,
      );
    }
    lines.push("");
  }
  return {
    filename: `${session.title || "leo-session"}.md`,
    mime: "text/markdown",
    content: lines.join("\n"),
  };
}

export function downloadFile(file: { filename: string; mime: string; content: string }) {
  const blob = new Blob([file.content], { type: file.mime });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = file.filename;
  a.click();
  URL.revokeObjectURL(url);
}