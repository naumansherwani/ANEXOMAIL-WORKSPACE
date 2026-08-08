/**
 * Compose Studio — Phase 9.
 *
 * NO DUPLICATE rule: drafts, versions, templates, snippets, signatures, the
 * send queue (undo-send hold), the follow-up promise tracker and the pre-send
 * confidence scan ALL live on the server (Server 2 -> Supabase 4). This file
 * only speaks HTTP.
 * NO MOCK rule: a missing endpoint surfaces as an honest "not wired" state —
 * nothing is faked in the browser.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, ApiError } from "@/lib/api";

export type ComposeTone = "warm" | "direct" | "formal" | "short" | "apologetic";

export type DraftPayload = {
  id?: string;
  thread_id?: string;
  identity?: string;
  to: string;
  cc?: string;
  bcc?: string;
  subject: string;
  body: string;
  send_at?: string;
  language?: string;
};

export type DraftRecord = { id: string; version: number; saved_at: string };

export type DraftVersion = {
  id: string;
  version: number;
  saved_at: string;
  subject: string | null;
  body: string | null;
};

export type MailTemplate = {
  id: string;
  name: string;
  scope: "org" | "personal";
  subject: string | null;
  body: string;
  variables: string[];
};

export type MailSnippet = { id: string; shortcut: string; body: string };

export type MailSignature = {
  id: string;
  identity: string;
  name: string;
  body: string;
  is_default: boolean;
};

export type ConfidenceIssue = {
  kind:
    | "missing_variable"
    | "attachment_promised"
    | "external_domain"
    | "empty_subject"
    | "risky_tone"
    | "broken_link"
    | "wrong_identity";
  severity: "block" | "warn" | "note";
  message: string;
};

export type ConfidenceReport = {
  score: number;
  issues: ConfidenceIssue[];
};

export type FollowUp = {
  id: string;
  thread_id: string | null;
  subject: string | null;
  remind_at: string;
  status: "pending" | "kept" | "missed";
};

export type ScheduledMail = {
  id: string;
  subject: string | null;
  to: string;
  status: "holding" | "queued" | "sent" | "cancelled";
  send_at: string | null;
};

export type ThreadInsights = {
  opened: boolean | null;
  open_count: number;
  last_opened_at: string | null;
  response_rate: number | null;
  avg_response_minutes: number | null;
  best_send_hour: number | null;
  recipient_timezone: string | null;
};

/* ------------------------------------------------------------------ drafts */

/** Autosave — called on a 3s debounce from the studio. Server owns versions. */
export function useSaveDraft() {
  const qc = useQueryClient();
  return useMutation<DraftRecord, ApiError, DraftPayload>({
    mutationFn: (payload) =>
      api<DraftRecord>("/api/mail/drafts", {
        method: "POST",
        body: JSON.stringify(payload),
      }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["mail", "drafts"] }),
  });
}

export function useDraftVersions(draftId: string | undefined) {
  return useQuery<{ versions: DraftVersion[] }, ApiError>({
    queryKey: ["mail", "drafts", draftId, "versions"],
    queryFn: () => api<{ versions: DraftVersion[] }>(`/api/mail/drafts/${draftId}`),
    enabled: Boolean(draftId),
    retry: false,
  });
}

/* --------------------------------------------------- templates / snippets */

export function useTemplates() {
  return useQuery<{ templates: MailTemplate[] }, ApiError>({
    queryKey: ["mail", "templates"],
    queryFn: () => api<{ templates: MailTemplate[] }>("/api/mail/templates"),
    retry: false,
    staleTime: 60_000,
  });
}

export function useSnippets() {
  return useQuery<{ snippets: MailSnippet[] }, ApiError>({
    queryKey: ["mail", "snippets"],
    queryFn: () => api<{ snippets: MailSnippet[] }>("/api/mail/snippets"),
    retry: false,
    staleTime: 60_000,
  });
}

export function useSignatures() {
  return useQuery<{ signatures: MailSignature[] }, ApiError>({
    queryKey: ["mail", "signatures"],
    queryFn: () => api<{ signatures: MailSignature[] }>("/api/mail/signatures"),
    retry: false,
    staleTime: 60_000,
  });
}

/* --------------------------------------------------------- pre-send checks */

export function useSendConfidence() {
  return useMutation<ConfidenceReport, ApiError, DraftPayload & { attachments?: number }>({
    mutationFn: (payload) =>
      api<ConfidenceReport>("/api/mail/send-confidence", {
        method: "POST",
        body: JSON.stringify(payload),
      }),
  });
}

/* ------------------------------------------------- queue / undo-send hold */

/**
 * Undo Send is a real server-side hold: the row lands in mail_scheduled with
 * status `holding` and only becomes `queued` when the hold window passes.
 */
export function useScheduleSend() {
  const qc = useQueryClient();
  return useMutation<
    { id: string; status: ScheduledMail["status"] },
    ApiError,
    DraftPayload & { hold_seconds?: number }
  >({
    mutationFn: (payload) =>
      api("/api/mail/schedule", { method: "POST", body: JSON.stringify(payload) }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["mail"] }),
  });
}

export function useCancelScheduled() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { id: string }>({
    mutationFn: ({ id }) =>
      api(`/api/mail/schedule/${id}/cancel`, { method: "POST", body: JSON.stringify({}) }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["mail"] }),
  });
}

/* ------------------------------------------------------- follow-up promise */

export function useCreateFollowUp() {
  const qc = useQueryClient();
  return useMutation<FollowUp, ApiError, { thread_id?: string; subject?: string; remind_at: string }>(
    {
      mutationFn: (payload) =>
        api<FollowUp>("/api/mail/follow-up", {
          method: "POST",
          body: JSON.stringify(payload),
        }),
      onSuccess: () => void qc.invalidateQueries({ queryKey: ["mail", "follow-ups"] }),
    },
  );
}

export function useFollowUps() {
  return useQuery<{ follow_ups: FollowUp[] }, ApiError>({
    queryKey: ["mail", "follow-ups"],
    queryFn: () => api<{ follow_ups: FollowUp[] }>("/api/mail/follow-up"),
    retry: false,
  });
}

/* -------------------------------------------------------- thread analytics */

export function useThreadInsights(threadId: string | undefined) {
  return useQuery<ThreadInsights, ApiError>({
    queryKey: ["mail", "thread", threadId, "insights"],
    queryFn: () => api<ThreadInsights>(`/api/mail/thread/${threadId}/insights`),
    enabled: Boolean(threadId),
    retry: false,
  });
}

/* ------------------------------------------------------------ Leo / Jimmy */

export type LeoComposeTask =
  | { task: "COMPOSE"; intent: string }
  | { task: "REWRITE"; tone: ComposeTone }
  | { task: "SUBJECT" }
  | { task: "TRANSLATE"; language: string }
  | { task: "COACH" };

export type LeoComposeResult = {
  reply: string;
  subject?: string;
  language?: string;
  notes?: string[];
};

/** Draft coach / rewrite / subject / translate — all one Leo COMPOSE surface. */
export function useLeoCompose() {
  return useMutation<
    LeoComposeResult,
    ApiError,
    LeoComposeTask & { body?: string; subject?: string; thread_id?: string; to?: string }
  >({
    mutationFn: (payload) =>
      api<LeoComposeResult>("/api/leo/chat", {
        method: "POST",
        body: JSON.stringify(payload),
      }),
  });
}

/** Feature 21 — Jimmy escalation (paid/business tier, Sherlock-audited draft). */
export function useAskJimmy() {
  return useMutation<
    LeoComposeResult & { audited_by?: string },
    ApiError,
    { thread_id?: string; to?: string; subject?: string; body?: string; question?: string }
  >({
    mutationFn: (payload) =>
      api("/api/leo/escalate", { method: "POST", body: JSON.stringify(payload) }),
  });
}

/* ------------------------------------------------------------- utilities */

/** Variables in a template body: {{first_name}} — resolved before send. */
export function findVariables(text: string): string[] {
  return Array.from(new Set([...text.matchAll(/{{\s*([\w.]+)\s*}}/g)].map((m) => m[1]!)));
}

export function applyVariables(text: string, values: Record<string, string>) {
  return text.replace(/{{\s*([\w.]+)\s*}}/g, (whole, key: string) => values[key] ?? whole);
}

/** Read time + reading level indicator (presentation only). */
export function readingStats(text: string) {
  const words = text.trim() ? text.trim().split(/\s+/).length : 0;
  const sentences = Math.max(1, (text.match(/[.!?]+/g) ?? []).length);
  const perSentence = words / sentences;
  const level = perSentence > 24 ? "complex" : perSentence > 16 ? "slightly complex" : "easy";
  return { words, seconds: Math.round((words / 220) * 60), level };
}