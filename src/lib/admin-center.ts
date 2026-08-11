/**
 * Phase 25 — Admin Center (transport only).
 *
 * 6 locked advance features:
 *   1. Self-healing health   — check -> auto-remedy -> proof
 *   2. Storage forecast      — days-until-full + reclaimable bytes
 *   3. Incident timeline     — blame-free replay + postmortem
 *   4. Delivery watchtower   — queue/defer/bounce reasons in plain English
 *   5. Log lens              — trace id + human translation
 *   6. Diagnostics proof pack — DNS/DKIM/SPF/DMARC/TLS/SMTP/IMAP, exportable
 *
 * NO DUPLICATE: saara hisaab Server 2 -> Supabase 4 par. NO MOCK: endpoint
 * missing = honest "not wired" state, fake number kabhi nahi.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type HealthCheck = {
  key: string;
  label: string;
  category: "mail" | "dns" | "system" | "storage" | "security" | "ai";
  status: "ok" | "warn" | "fail" | "unknown";
  detail: string | null;
  can_self_heal: boolean;
  remedy: string | null;
  heals_24h: number;
  last_healed_at: string | null;
  checked_at: string | null;
};

export type HealthOverview = {
  score: number;
  checks: HealthCheck[];
  self_heals_24h: number;
  last_run: string | null;
  recent: { key: string; action: string; outcome: string; created_at: string }[];
};

export type StorageForecast = {
  used_bytes: number;
  quota_bytes: number;
  growth_bytes_per_day: number;
  days_until_full: number | null;
  reclaimable_bytes: number;
  mailboxes: {
    mailbox: string;
    used_bytes: number;
    quota_bytes: number;
    growth_bytes_per_day: number;
    days_until_full: number | null;
    reclaimable_bytes: number;
  }[];
  reclaim: { label: string; bytes: number; safe: boolean }[];
};

export type Incident = {
  id: string;
  title: string;
  severity: "minor" | "major" | "critical";
  status: "open" | "mitigated" | "resolved";
  surface: string;
  started_at: string;
  resolved_at: string | null;
  minutes: number | null;
  impact: string | null;
  cause: string | null;
  fix: string | null;
  prevention: string | null;
  auto_detected: boolean;
  events: { at: string; actor: string; kind: string; message: string }[];
};

export type Watchtower = {
  window_hours: number;
  sent: number;
  queued: number;
  deferred: number;
  bounced: number;
  rejected: number;
  delivery_rate: number;
  reasons: { reason_code: string; human_reason: string; count: number; fixable: boolean }[];
  recent: {
    id: string;
    at: string;
    direction: "in" | "out";
    address: string | null;
    remote: string | null;
    state: string;
    human_reason: string | null;
  }[];
};

export type LogLine = {
  id: string;
  at: string;
  level: "debug" | "info" | "warn" | "error";
  source: string;
  trace_id: string | null;
  route: string | null;
  status: number | null;
  duration_ms: number | null;
  message: string;
  plain: string | null;
};

export type Report = {
  id: string;
  period: string;
  title: string;
  status: "building" | "ready" | "failed";
  numbers: Record<string, number | string>;
  highlights: string[];
  created_at: string;
};

export type DiagnosticRun = {
  id: string;
  started_at: string;
  finished_at: string | null;
  scope: string;
  passed: number;
  failed: number;
  proof_hash: string | null;
  export_ready: boolean;
  probes: {
    probe: string;
    target: string | null;
    result: "pass" | "fail" | "skip" | "unknown";
    observed: string | null;
    expected: string | null;
    fix: string | null;
    ms: number;
  }[];
};

export type FounderAdmin = {
  tenants: number;
  failing_checks: number;
  self_heals_24h: number;
  open_incidents: number;
  deferred_1h: number;
  errors_1h: number;
  storage_used_bytes: number;
  worst_tenants: { tenant: string; failing: number; checks: number }[];
};

const get = <T,>(procedure: string, path: string) => rpcOrRest<T>(procedure, { path });

export const useHealth = () =>
  useQuery<HealthOverview, ApiError>({
    queryKey: ["admin", "health"],
    queryFn: () => get<HealthOverview>("admin.health", "/api/admin/health"),
    retry: false,
  });

export const useHeal = () => {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean; outcome: string; proof: unknown }, ApiError, { key: string }>({
    mutationFn: (body) => rpcOrRest("admin.heal", { path: "/api/admin/health/heal", method: "POST", body }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["admin", "health"] }),
  });
};

export const useStorageForecast = () =>
  useQuery<StorageForecast, ApiError>({
    queryKey: ["admin", "storage"],
    queryFn: () => get<StorageForecast>("admin.storage", "/api/admin/storage"),
    retry: false,
  });

export const useIncidents = () =>
  useQuery<{ incidents: Incident[] }, ApiError>({
    queryKey: ["admin", "incidents"],
    queryFn: () => get<{ incidents: Incident[] }>("admin.incidents", "/api/admin/incidents"),
    retry: false,
  });

export const useWatchtower = () =>
  useQuery<Watchtower, ApiError>({
    queryKey: ["admin", "monitoring"],
    queryFn: () => get<Watchtower>("admin.monitoring", "/api/admin/monitoring"),
    refetchInterval: 20_000,
    retry: false,
  });

export const useLogs = (level: string, q: string) =>
  useQuery<{ logs: LogLine[] }, ApiError>({
    queryKey: ["admin", "logs", level, q],
    queryFn: () =>
      get<{ logs: LogLine[] }>(
        "admin.logs",
        `/api/admin/logs?level=${encodeURIComponent(level)}&q=${encodeURIComponent(q)}`,
      ),
    retry: false,
  });

export const useReports = () =>
  useQuery<{ reports: Report[] }, ApiError>({
    queryKey: ["admin", "reports"],
    queryFn: () => get<{ reports: Report[] }>("admin.reports", "/api/admin/reports"),
    retry: false,
  });

export const useGenerateReport = () => {
  const qc = useQueryClient();
  return useMutation<{ report: Report }, ApiError, { period: string }>({
    mutationFn: (body) => rpcOrRest("admin.generateReport", { path: "/api/admin/reports/generate", method: "POST", body }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["admin", "reports"] }),
  });
};

export const useDiagnostics = () =>
  useQuery<{ runs: DiagnosticRun[] }, ApiError>({
    queryKey: ["admin", "diagnostics"],
    queryFn: () => get<{ runs: DiagnosticRun[] }>("admin.diagnostics", "/api/admin/diagnostics"),
    retry: false,
  });

export const useRunDiagnostics = () => {
  const qc = useQueryClient();
  return useMutation<{ run: DiagnosticRun }, ApiError, { scope?: string }>({
    mutationFn: (body) => rpcOrRest("admin.runDiagnostics", { path: "/api/admin/diagnostics/run", method: "POST", body }),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["admin", "diagnostics"] }),
  });
};

export const useFounderAdmin = () =>
  useQuery<FounderAdmin, ApiError>({
    queryKey: ["founder", "admin"],
    queryFn: () => get<FounderAdmin>("founderAdmin.overview", "/api/founder/admin/overview"),
    retry: false,
  });

export const bytes = (n: number) => {
  if (!n) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  const i = Math.min(units.length - 1, Math.floor(Math.log(n) / Math.log(1024)));
  return `${(n / 1024 ** i).toFixed(i === 0 ? 0 : 1)} ${units[i]}`;
};

export const STATUS_TONE: Record<HealthCheck["status"], string> = {
  ok: "text-emerald-400",
  warn: "text-amber-400",
  fail: "text-red-400",
  unknown: "text-steel",
};
