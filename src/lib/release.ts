/**
 * Phase 30 — Production & Founder Lock (transport + gate maths only).
 *
 * NO MOCK: har number backend ke asli rows se aata hai. Endpoint missing =
 * honest "not wired" state, koi farzi verdict nahi.
 * NO AI: is phase mein Leo ka koi role nahi.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect, useState } from "react";

import { api, type ApiError } from "@/lib/api";
import * as offline from "@/lib/offline";
import { rpcOrRest } from "@/lib/rpc";

/* --------------------------------- types -------------------------------- */

export type CheckStatus = "pass" | "warn" | "fail" | "skip";
export type Gate = "locked" | "ready" | "blocked" | "unknown";

export type ReleaseCheck = {
  id: string;
  suite: string;
  name: string;
  status: CheckStatus;
  ms: number | null;
  code: number | null;
  detail: string | null;
  at: string;
};

export type ReleaseRun = {
  id: string;
  started_at: string;
  finished_at: string | null;
  passed: number;
  warned: number;
  failed: number;
  skipped: number;
  total: number;
  ms: number | null;
  verdict: "green" | "watch" | "red";
};

export type ReleaseOverview = {
  gate: Gate;
  version: string | null;
  locked_at: string | null;
  latest_run: ReleaseRun | null;
  blockers: { id: string; label: string; suite: string; detail: string | null }[];
  checklist_open: number;
  checklist_total: number;
  last_deployment: Deployment | null;
};

export type ChecklistItem = {
  id: string;
  area: string;
  label: string;
  detail: string | null;
  state: "open" | "done" | "blocker";
  owner: string | null;
  updated_at: string | null;
};

export type Deployment = {
  id: string;
  target: "preview" | "production";
  commit_sha: string;
  commit_subject: string | null;
  actor: string | null;
  started_at: string;
  finished_at: string | null;
  ms: number | null;
  state: "running" | "live" | "failed" | "rolled_back";
  rollback_of: string | null;
  changed_since_green: string[];
};

export type ReleaseLock = {
  id: string;
  version: string;
  signed_by: string;
  signature_hash: string;
  verdict: string;
  frozen_at: string;
  notes: string | null;
};

export type RoadmapItem = {
  id: string;
  title: string;
  area: string;
  impact: number;
  effort: number;
  revenue_link: string | null;
  state: "idea" | "next" | "building" | "shipped";
};

export type StatusPage = {
  state: "operational" | "degraded" | "down";
  updated_at: string;
  components: { name: string; state: "operational" | "degraded" | "down"; note: string | null }[];
  last_incident: { title: string; started_at: string; resolved_at: string | null } | null;
};

export type RevenuePipeline = {
  target_gbp: number;
  committed_mrr_gbp: number;
  pipeline_mrr_gbp: number;
  one_off_cash_gbp: number;
  gap_gbp: number;
  committed: { stream: string; mrr_gbp: number; accounts: number }[];
  pipeline: {
    id: string;
    reference: string;
    company: string;
    stage: string;
    weight: number;
    plan_seats: number;
    expected_mrr_gbp: number;
    one_off_gbp: number | null;
  }[];
};

/* ------------------------------ gate maths ------------------------------ */

/** Gate ka faisla frontend mein bhi dohraya jata hai — button kabhi jhooth na bole. */
export function gateFrom(overview: ReleaseOverview | undefined): Gate {
  if (!overview) return "unknown";
  if (overview.locked_at) return "locked";
  const run = overview.latest_run;
  if (!run || run.total === 0) return "unknown";
  if (run.failed > 0 || overview.blockers.length > 0) return "blocked";
  return "ready";
}

export const GATE_COPY: Record<Gate, { label: string; body: string }> = {
  locked: { label: "v1.0 LOCKED", body: "Signed and frozen. New work goes to the v2.0 roadmap." },
  ready: { label: "READY TO LOCK", body: "Every check green and no open blocker. Signing is allowed." },
  blocked: { label: "LAUNCH BLOCKED", body: "A failing check or an open blocker is holding the gate shut." },
  unknown: { label: "NO VERDICT", body: "No QA run yet — run the suite to get a real verdict." },
};

export const verdictOf = (c: CheckStatus): "green" | "watch" | "fail" =>
  c === "pass" ? "green" : c === "fail" ? "fail" : "watch";

export const ms = (n: number | null | undefined) => (n == null ? "—" : `${Math.round(n)}ms`);
export const gbp = (n: number | null | undefined) =>
  n == null ? "—" : `£${Math.round(n).toLocaleString("en-GB")}`;

/* -------------------------------- founder ------------------------------- */

export function useReleaseOverview() {
  return useQuery<ReleaseOverview, ApiError>({
    queryKey: ["release", "overview"],
    queryFn: () => rpcOrRest<ReleaseOverview>("founder.release.overview", { path: "/api/founder/release/overview" }),
    retry: false,
  });
}

export function useReleaseChecks() {
  return useQuery<{ runs: ReleaseRun[]; checks: ReleaseCheck[] }, ApiError>({
    queryKey: ["release", "checks"],
    queryFn: () => api<{ runs: ReleaseRun[]; checks: ReleaseCheck[] }>("/api/founder/release/checks"),
    retry: false,
  });
}

/** Single-flight: ek waqt mein ek hi run — server bhi 409 deta hai. */
export function useRunQa() {
  const qc = useQueryClient();
  return useMutation<{ run: ReleaseRun; checks: ReleaseCheck[] }, ApiError, { suite?: string }>({
    mutationFn: (input) =>
      api<{ run: ReleaseRun; checks: ReleaseCheck[] }>("/api/founder/release/run", {
        method: "POST",
        body: JSON.stringify({ suite: input.suite ?? "all" }),
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["release"] });
    },
  });
}

export function useChecklist() {
  return useQuery<{ items: ChecklistItem[] }, ApiError>({
    queryKey: ["release", "checklist"],
    queryFn: () => api<{ items: ChecklistItem[] }>("/api/founder/release/checklist"),
    retry: false,
  });
}

export function useChecklistUpdate() {
  const qc = useQueryClient();
  return useMutation<ChecklistItem, ApiError, { id: string; state: ChecklistItem["state"] }>({
    mutationFn: (input) =>
      api<ChecklistItem>("/api/founder/release/checklist/item", {
        method: "POST",
        body: JSON.stringify(input),
      }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["release"] });
    },
  });
}

export function useDeployments() {
  return useQuery<{ deployments: Deployment[] }, ApiError>({
    queryKey: ["release", "deployments"],
    queryFn: () => api<{ deployments: Deployment[] }>("/api/founder/release/deployments"),
    retry: false,
  });
}

export function useLocks() {
  return useQuery<{ locks: ReleaseLock[] }, ApiError>({
    queryKey: ["release", "locks"],
    queryFn: () => api<{ locks: ReleaseLock[] }>("/api/founder/release/lock"),
    retry: false,
  });
}

export function useSignLock() {
  const qc = useQueryClient();
  return useMutation<ReleaseLock, ApiError, { version: string; notes?: string; override_reason?: string }>({
    mutationFn: (input) =>
      api<ReleaseLock>("/api/founder/release/lock", { method: "POST", body: JSON.stringify(input) }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["release"] });
    },
  });
}

export function useRoadmap() {
  return useQuery<{ items: RoadmapItem[] }, ApiError>({
    queryKey: ["release", "roadmap"],
    queryFn: () => api<{ items: RoadmapItem[] }>("/api/founder/release/roadmap"),
    retry: false,
  });
}

export function useRoadmapAdd() {
  const qc = useQueryClient();
  return useMutation<RoadmapItem, ApiError, Omit<RoadmapItem, "id" | "state"> & { state?: RoadmapItem["state"] }>({
    mutationFn: (input) =>
      api<RoadmapItem>("/api/founder/release/roadmap", { method: "POST", body: JSON.stringify(input) }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["release", "roadmap"] });
    },
  });
}

export function useRevenuePipeline() {
  return useQuery<RevenuePipeline, ApiError>({
    queryKey: ["founder", "revenue", "pipeline"],
    queryFn: () => api<RevenuePipeline>("/api/founder/revenue/pipeline"),
    retry: false,
  });
}

/* ------------------------------- public --------------------------------- */

export function useStatusPage() {
  return useQuery<StatusPage, ApiError>({
    queryKey: ["public", "status"],
    queryFn: () => api<StatusPage>("/api/public/status", { auth: false }),
    retry: false,
    refetchInterval: 60_000,
  });
}

/* --------------------------- offline outbox ----------------------------- */

export type OutboxItem = {
  key: string;
  to: string;
  subject: string;
  body: string;
  thread_id?: string;
  attempts: number;
  next_retry_at: number;
  state: "queued" | "sending" | "sent" | "failed";
  error?: string;
  queued_at: number;
};

const backoff = (attempts: number) => Math.min(15 * 60_000, 5_000 * 2 ** attempts);

export async function queueOutbox(input: { to: string; subject: string; body: string; thread_id?: string }) {
  const key = `ob_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`;
  const item: OutboxItem = {
    key,
    ...input,
    attempts: 0,
    next_retry_at: Date.now(),
    state: "queued",
    queued_at: Date.now(),
  };
  await offline.put("outbox", key, item);
  return item;
}

export async function readOutbox(): Promise<OutboxItem[]> {
  const rows = await offline.all<OutboxItem>("outbox");
  return rows.map((r) => r.value).filter(Boolean).sort((a, b) => b.queued_at - a.queued_at);
}

/**
 * Flush = server ki confirmation. Jab tak server "sent" na kahe, item Sent
 * folder mein nahi jaata — hum "sent" ka jhooth nahi bolte.
 */
export async function flushOutbox(): Promise<{ sent: number; failed: number; kept: number }> {
  const items = await readOutbox();
  let sent = 0;
  let failed = 0;
  let kept = 0;

  for (const item of items) {
    if (item.state === "sent") continue;
    if (item.next_retry_at > Date.now()) {
      kept += 1;
      continue;
    }
    await offline.put("outbox", item.key, { ...item, state: "sending" } satisfies OutboxItem);
    try {
      await api("/api/mail/outbox/send", {
        method: "POST",
        headers: { "idempotency-key": item.key },
        body: JSON.stringify({
          idempotency_key: item.key,
          to: item.to,
          subject: item.subject,
          body: item.body,
          ...(item.thread_id ? { thread_id: item.thread_id } : {}),
        }),
      });
      await offline.remove("outbox", item.key);
      sent += 1;
    } catch (e) {
      const err = e as ApiError;
      const attempts = item.attempts + 1;
      await offline.put("outbox", item.key, {
        ...item,
        attempts,
        state: attempts >= 6 ? "failed" : "queued",
        next_retry_at: Date.now() + backoff(attempts),
        error: err.isNotImplemented ? "Server route not wired yet" : err.message,
      } satisfies OutboxItem);
      failed += 1;
    }
  }
  return { sent, failed, kept };
}

export async function dropOutbox(key: string) {
  await offline.remove("outbox", key);
}

/** Outbox live view + online hote hi auto-flush. */
export function useOutbox() {
  const [items, setItems] = useState<OutboxItem[] | null>(null);
  const [flushing, setFlushing] = useState(false);

  const reload = useCallback(async () => {
    setItems(await readOutbox());
  }, []);

  const flush = useCallback(async () => {
    setFlushing(true);
    try {
      const result = await flushOutbox();
      await reload();
      return result;
    } finally {
      setFlushing(false);
    }
  }, [reload]);

  useEffect(() => {
    void reload();
    const onOnline = () => void flush();
    window.addEventListener("online", onOnline);
    if (navigator.onLine) void flush();
    return () => window.removeEventListener("online", onOnline);
  }, [reload, flush]);

  return { items, flushing, reload, flush, drop: async (key: string) => { await dropOutbox(key); await reload(); } };
}
