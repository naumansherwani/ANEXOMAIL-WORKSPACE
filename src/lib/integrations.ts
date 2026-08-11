/**
 * Phase 22 — Integrations Platform (transport only).
 *
 * NO API / NO WEBHOOK RULE (locked): awam ko public API keys ya webhooks kabhi nahi.
 * Uski jagah native provider integrations + one-click export + LEO Actions.
 * NO DUPLICATE: OAuth, IMAP sync, migration engine aur delivery checks sab server par.
 * NO MOCK: endpoint missing = honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type ProviderId =
  | "gmail"
  | "google_workspace"
  | "outlook"
  | "microsoft365"
  | "zoho"
  | "proton"
  | "imap"
  | "smtp";

export type Provider = {
  id: ProviderId;
  label: string;
  kind: "oauth" | "credentials" | "bridge";
  can_migrate: boolean;
  can_sync: boolean;
  can_send: boolean;
  notes: string | null;
  available: boolean;
};

export type Connection = {
  id: string;
  provider: ProviderId;
  account: string;
  state: "connected" | "needs_reauth" | "error" | "paused";
  scopes: string[];
  last_sync_at: string | null;
  synced_threads: number;
  error: string | null;
  created_at: string;
};

export type MigrationJob = {
  id: string;
  provider: ProviderId;
  source_account: string;
  target_mailbox: string;
  state: "queued" | "running" | "paused" | "done" | "failed";
  mode: "copy" | "mirror";
  total: number;
  done: number;
  failed: number;
  eta_minutes: number | null;
  started_at: string | null;
  finished_at: string | null;
  last_error: string | null;
};

export type DeliveryCheck = {
  key: "SPF" | "DKIM" | "DMARC" | "MX" | "MTA-STS" | "TLS-RPT" | "PTR" | "BIMI";
  state: "ok" | "warn" | "fail";
  detail: string;
  fix: string | null;
  checked_at: string | null;
};

export type DeliveryHealth = {
  domain: string;
  score: number;
  checks: DeliveryCheck[];
  blocklists: { name: string; listed: boolean }[];
  reputation: "good" | "watch" | "poor" | "unknown";
};

export type ExportJob = {
  id: string;
  scope: "mail" | "calendar" | "contacts" | "everything";
  format: "mbox" | "eml" | "ics" | "csv" | "json";
  state: "queued" | "running" | "ready" | "expired" | "failed";
  size_bytes: number;
  url: string | null;
  expires_at: string | null;
  created_at: string;
};

export type LeoAction = {
  id: string;
  label: string;
  target: string;
  description: string;
  enabled: boolean;
  requires_approval: boolean;
  runs_30d: number;
};

export type FounderIntegrations = {
  connections: number;
  needs_reauth: number;
  migrations_running: number;
  migrations_failed: number;
  threads_migrated_30d: number;
  by_provider: { provider: ProviderId; connections: number; failures: number }[];
  worst_delivery: { domain: string; score: number }[];
};

const get = <T,>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path }, input);

const post = <T,>(procedure: string, path: string, body: unknown) =>
  rpcOrRest<T>(procedure, { path, method: "POST", body }, body);

export function useProviders() {
  return useQuery<{ providers: Provider[] }, ApiError>({
    queryKey: ["integrations", "providers"],
    queryFn: () => get<{ providers: Provider[] }>("integrations.providers", "/api/integrations/providers"),
    retry: false,
  });
}

export function useConnections() {
  return useQuery<{ connections: Connection[] }, ApiError>({
    queryKey: ["integrations", "connections"],
    queryFn: () =>
      get<{ connections: Connection[] }>("integrations.connections", "/api/integrations/connections"),
    retry: false,
  });
}

/** Server OAuth ya IMAP credentials handle karta hai — frontend sirf intent bhejta hai. */
export function useConnectProvider() {
  const qc = useQueryClient();
  return useMutation<
    { id: string; state: Connection["state"]; redirect_url: string | null },
    ApiError,
    { provider: ProviderId; account?: string; host?: string; port?: number }
  >({
    mutationFn: (body) => post("integrations.connect", "/api/integrations/connect", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["integrations", "connections"] }),
  });
}

export function useDisconnectProvider() {
  const qc = useQueryClient();
  return useMutation<{ ok: true }, ApiError, { id: string }>({
    mutationFn: (body) => post("integrations.disconnect", "/api/integrations/disconnect", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["integrations", "connections"] }),
  });
}

export function useMigrations() {
  return useQuery<{ jobs: MigrationJob[] }, ApiError>({
    queryKey: ["integrations", "migrations"],
    queryFn: () => get<{ jobs: MigrationJob[] }>("integrations.migrations", "/api/integrations/migrations"),
    refetchInterval: 15_000,
    retry: false,
  });
}

export function useStartMigration() {
  const qc = useQueryClient();
  return useMutation<
    MigrationJob,
    ApiError,
    { connection_id: string; target_mailbox: string; mode: MigrationJob["mode"] }
  >({
    mutationFn: (body) => post("integrations.startMigration", "/api/integrations/migrations", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["integrations", "migrations"] }),
  });
}

export function useControlMigration() {
  const qc = useQueryClient();
  return useMutation<MigrationJob, ApiError, { id: string; action: "pause" | "resume" | "retry" | "cancel" }>({
    mutationFn: (body) => post("integrations.controlMigration", "/api/integrations/migrations/control", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["integrations", "migrations"] }),
  });
}

export function useDeliveryHealth() {
  return useQuery<DeliveryHealth, ApiError>({
    queryKey: ["integrations", "delivery"],
    queryFn: () => get<DeliveryHealth>("integrations.delivery", "/api/integrations/delivery/health"),
    retry: false,
  });
}

export function useExports() {
  return useQuery<{ jobs: ExportJob[] }, ApiError>({
    queryKey: ["integrations", "exports"],
    queryFn: () => get<{ jobs: ExportJob[] }>("integrations.exports", "/api/integrations/exports"),
    retry: false,
  });
}

/** User Freedom: one-click export, no lock-in. */
export function useRequestExport() {
  const qc = useQueryClient();
  return useMutation<ExportJob, ApiError, { scope: ExportJob["scope"]; format: ExportJob["format"] }>({
    mutationFn: (body) => post("integrations.export", "/api/integrations/exports", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["integrations", "exports"] }),
  });
}

export function useLeoActions() {
  return useQuery<{ actions: LeoAction[] }, ApiError>({
    queryKey: ["integrations", "leo-actions"],
    queryFn: () => get<{ actions: LeoAction[] }>("integrations.leoActions", "/api/integrations/leo-actions"),
    retry: false,
  });
}

export function useToggleLeoAction() {
  const qc = useQueryClient();
  return useMutation<LeoAction, ApiError, { id: string; enabled: boolean }>({
    mutationFn: (body) => post("integrations.toggleLeoAction", "/api/integrations/leo-actions/toggle", body),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["integrations", "leo-actions"] }),
  });
}

export function useFounderIntegrations() {
  return useQuery<FounderIntegrations, ApiError>({
    queryKey: ["founder", "integrations"],
    queryFn: () =>
      get<FounderIntegrations>("founderIntegrations.overview", "/api/founder/integrations/overview"),
    retry: false,
  });
}

export const bytes = (n: number) =>
  n >= 1e9 ? `${(n / 1e9).toFixed(1)} GB` : n >= 1e6 ? `${(n / 1e6).toFixed(1)} MB` : `${Math.round(n / 1e3)} KB`;

export const pct = (done: number, total: number) =>
  total <= 0 ? 0 : Math.min(100, Math.round((done / total) * 100));
