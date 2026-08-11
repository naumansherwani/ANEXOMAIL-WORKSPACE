/**
 * Phase 23 — Settings Center (transport only).
 *
 * NO DUPLICATE: validation, policy resolution, blast-radius math, version
 * history, scheduled apply aur auto-rollback sab server par (Server 2 -> Supabase 4).
 * NO MOCK: endpoint missing = honest "not wired" state.
 * AI LOCK: "Explain this setting" ka text Leo se aata hai, lekin woh sirf
 * ai.anexomail.com / founder surface par visible hota hai.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type Scope = "personal" | "workspace" | "appearance" | "notifications" | "privacy" | "ai";

export type SettingKind = "toggle" | "choice" | "number" | "text";

export type Setting = {
  key: string;
  scope: Scope;
  label: string;
  help: string;
  kind: SettingKind;
  value: string | number | boolean | null;
  default_value: string | number | boolean | null;
  options: { value: string; label: string }[] | null;
  /** Org policy is winning — user cannot change it. */
  locked_by_policy: string | null;
  /** Server-side recommendation drift: how far this is from the safe baseline. */
  drift: "aligned" | "loose" | "risky" | null;
  updated_at: string | null;
  updated_by: string | null;
};

export type SettingVersion = {
  id: string;
  key: string;
  from_value: string | null;
  to_value: string | null;
  changed_by: string;
  changed_at: string;
  reason: string | null;
  reverted: boolean;
};

export type BlastRadius = {
  key: string;
  members_affected: number;
  mailboxes_affected: number;
  automations_affected: number;
  severity: "low" | "medium" | "high";
  breaks: string[];
  reversible: boolean;
};

export type Explanation = {
  key: string;
  plain: string;
  example: string;
  tradeoff: string | null;
  source: "leo" | "server";
};

export type DriftReport = {
  score: number;
  aligned: number;
  loose: number;
  risky: number;
  items: { key: string; label: string; drift: "loose" | "risky"; recommended: string }[];
};

export type ScheduledChange = {
  id: string;
  key: string;
  to_value: string;
  apply_at: string;
  auto_rollback_minutes: number | null;
  state: "scheduled" | "applied" | "rolled_back" | "cancelled";
  requested_by: string;
};

export type FounderSettings = {
  tenants: number;
  changes_24h: number;
  reverts_7d: number;
  risky_tenants: { tenant: string; risky: number; score: number }[];
  most_changed: { key: string; changes: number }[];
  pending_scheduled: number;
};

const get = <T,>(procedure: string, path: string, input?: unknown) => rpcOrRest<T>(procedure, { path }, input);
const post = <T,>(procedure: string, path: string, body: unknown) =>
  rpcOrRest<T>(procedure, { path, method: "POST", body }, body);

export function useSettings(scope: Scope) {
  return useQuery<{ settings: Setting[] }, ApiError>({
    queryKey: ["settings", scope],
    queryFn: () => get<{ settings: Setting[] }>("settings.list", `/api/settings/${scope}`),
    retry: false,
  });
}

/** Feature 3 — blast radius: save se PEHLE sach. */
export function useBlastRadius(key: string | null) {
  return useQuery<BlastRadius, ApiError>({
    queryKey: ["settings", "blast", key],
    queryFn: () => get<BlastRadius>("settings.blastRadius", `/api/settings/blast-radius?key=${key!}`),
    enabled: Boolean(key),
    retry: false,
  });
}

/** Feature 2 — Explain this setting (Leo, plain language + real example). */
export function useExplain(key: string | null) {
  return useQuery<Explanation, ApiError>({
    queryKey: ["settings", "explain", key],
    queryFn: () => get<Explanation>("settings.explain", `/api/settings/explain?key=${key!}`),
    enabled: Boolean(key),
    retry: false,
  });
}

export function useSaveSetting() {
  const qc = useQueryClient();
  return useMutation<Setting, ApiError, { key: string; value: string | number | boolean; reason?: string }>({
    mutationFn: (body) => post("settings.save", "/api/settings/save", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["settings"] }),
  });
}

/** Feature 1 — Time Machine: har change ka version + one-click revert. */
export function useSettingHistory(key?: string) {
  return useQuery<{ versions: SettingVersion[] }, ApiError>({
    queryKey: ["settings", "history", key ?? "all"],
    queryFn: () =>
      get<{ versions: SettingVersion[] }>(
        "settings.history",
        key ? `/api/settings/history?key=${key}` : "/api/settings/history",
      ),
    retry: false,
  });
}

export function useRevertSetting() {
  const qc = useQueryClient();
  return useMutation<Setting, ApiError, { version_id: string }>({
    mutationFn: (body) => post("settings.revert", "/api/settings/revert", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["settings"] }),
  });
}

/** Feature 4 — drift baseline: recommended vs yours, ek score. */
export function useDrift() {
  return useQuery<DriftReport, ApiError>({
    queryKey: ["settings", "drift"],
    queryFn: () => get<DriftReport>("settings.drift", "/api/settings/drift"),
    retry: false,
  });
}

/** Feature 5 — scheduled change + auto-rollback agar kuch tootay. */
export function useScheduled() {
  return useQuery<{ changes: ScheduledChange[] }, ApiError>({
    queryKey: ["settings", "scheduled"],
    queryFn: () => get<{ changes: ScheduledChange[] }>("settings.scheduled", "/api/settings/scheduled"),
    retry: false,
  });
}

export function useScheduleChange() {
  const qc = useQueryClient();
  return useMutation<
    ScheduledChange,
    ApiError,
    { key: string; to_value: string; apply_at: string; auto_rollback_minutes?: number }
  >({
    mutationFn: (body) => post("settings.schedule", "/api/settings/schedule", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["settings", "scheduled"] }),
  });
}

/** Feature 6 — dry run: kuch save karne se pehle simulate karo, koi write nahi. */
export function useSimulate() {
  return useMutation<
    { ok: boolean; warnings: string[]; blast: BlastRadius | null },
    ApiError,
    { key: string; value: string | number | boolean }
  >({
    mutationFn: (body) => post("settings.simulate", "/api/settings/simulate", body),
  });
}

export function useFounderSettings() {
  return useQuery<FounderSettings, ApiError>({
    queryKey: ["founder", "settings"],
    queryFn: () => get<FounderSettings>("founderSettings.overview", "/api/founder/settings/overview"),
    retry: false,
  });
}

export const shortValue = (v: Setting["value"]) =>
  v === null ? "—" : typeof v === "boolean" ? (v ? "On" : "Off") : String(v);
