/**
 * Phase 15 — Organization Center (transport only).
 *
 * NO DUPLICATE rule: seats, roles, capability matrix, policy simulation, blast
 * radius, anomaly detection, hash-chain ledger and DNS proof ALL live on the
 * server (Server 2 -> Supabase 4). This file only speaks HTTP/RPC.
 * NO MOCK rule: a missing endpoint surfaces as an honest "not wired" state.
 *
 * Awam surface: anexomail.com -> /app/org/*
 * Founder surface: founderworkspace.anexomail.com/app/founder/org (IP locked)
 * No AI on this surface — AI belongs to ai.anexomail.com only.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

/* ------------------------------------------------------------------ types */

export type OrgRole = "owner" | "admin" | "manager" | "member" | "viewer";

export type OrgOverview = {
  name: string;
  primary_domain: string | null;
  plan: string | null;
  seats_used: number;
  seats_total: number;
  members_active: number;
  members_suspended: number;
  departments: number;
  policies_active: number;
  /** 0-100, server-computed from MFA, DNS, sessions, privilege findings. */
  security_score: number | null;
  dns_all_green: boolean | null;
  open_risks: number;
  last_audit_at: string | null;
};

export type OrgMember = {
  user_id: string;
  email: string;
  display_name: string | null;
  role: OrgRole;
  department: string | null;
  status: "active" | "invited" | "suspended" | "revoked";
  mfa: boolean;
  sessions: number;
  last_active_at: string | null;
  /** Least-privilege radar input — null means never used. */
  admin_power_last_used_at: string | null;
};

export type Capability = { key: string; label: string; roles: OrgRole[] };

export type RoleSummary = {
  role: OrgRole;
  label: string;
  description: string;
  members: number;
};

export type PrivilegeFinding = {
  user_id: string;
  email: string;
  role: OrgRole;
  days_unused: number;
  recommendation: string;
};

export type Department = {
  id: string;
  name: string;
  shared_address: string | null;
  members: number;
  sla_minutes: number | null;
  escalation_chain: string[];
  budget_monthly: number | null;
  currency: string | null;
  open_threads: number;
  breached_sla: number;
};

export type Policy = {
  id: string;
  name: string;
  kind: "access" | "retention" | "sending" | "device" | "sharing";
  description: string;
  enabled: boolean;
  updated_at: string | null;
};

export type PolicySimulation = {
  policy_id: string;
  members_blocked: number;
  workflows_broken: number;
  examples: string[];
};

export type BlastRadius = {
  user_id: string;
  threads_orphaned: number;
  shared_addresses: number;
  pending_approvals: number;
  calendar_events: number;
  transfer_to: string | null;
};

export type SessionDevice = {
  id: string;
  email: string;
  ip: string | null;
  city: string | null;
  country: string | null;
  device: string | null;
  browser: string | null;
  current: boolean;
  last_seen_at: string;
};

export type AnomalyAlert = {
  id: string;
  kind: "impossible_travel" | "new_country" | "brute_force" | "mass_export" | "token_reuse";
  email: string;
  detail: string;
  severity: "low" | "medium" | "high";
  state: "open" | "frozen" | "cleared";
  created_at: string;
};

export type ProofTile = {
  key: "SPF" | "DKIM" | "DMARC" | "MTA-STS" | "TLS-RPT" | "DNSSEC";
  state: "ok" | "warn" | "fail";
  detail: string;
  checked_at: string | null;
};

export type LedgerEntry = {
  id: string;
  seq: number;
  actor: string;
  action: string;
  target: string | null;
  ip: string | null;
  hash: string;
  prev_hash: string | null;
  created_at: string;
};

export type LedgerVerdict = {
  ok: boolean;
  checked: number;
  broken_at_seq: number | null;
  verified_at: string;
};

export type GraphNode = {
  id: string;
  email: string;
  label: string;
  role: OrgRole;
  department: string | null;
  /** Server truth: how central this person is to company communication. */
  centrality: number | null;
  bottleneck: boolean;
};

export type GraphEdge = { from: string; to: string; weight: number };

export type OrgGraph = {
  nodes: GraphNode[];
  edges: GraphEdge[];
  window_days: number;
};

export type ComplianceSnapshot = {
  retention_days: number | null;
  export_enabled: boolean;
  delete_is_real: boolean;
  data_region: string | null;
  dpa_url: string | null;
  subprocessors: { name: string; purpose: string; region: string }[];
  evidence_pack_ready: boolean;
};

export type BreakGlassGrant = {
  id: string;
  actor: string;
  reason: string;
  granted_at: string;
  expires_at: string;
  state: "active" | "expired" | "revoked";
};

export type FounderOrgState = {
  /** Kill switch — server truth. False = every org write refused. */
  org_writes_enabled: boolean;
  organisations: number;
  users: number;
  seats_paid: number;
  mrr: number;
  currency: string;
  break_glass_active: number;
  ledger_ok: boolean | null;
  last_write_at: string | null;
};

export type FounderOrgRow = {
  id: string;
  name: string;
  primary_domain: string | null;
  plan: string | null;
  seats_used: number;
  seats_paid: number;
  writes_enabled: boolean;
  security_score: number | null;
  created_at: string;
};

/* ------------------------------------------------------------------ reads */

const get = <T,>(procedure: string, path: string, input?: unknown) =>
  rpcOrRest<T>(procedure, { path }, input);

export function useOrgOverview() {
  return useQuery<OrgOverview, ApiError>({
    queryKey: ["org", "overview"],
    queryFn: () => get<OrgOverview>("org.overview", "/api/org/overview"),
    retry: false,
  });
}

export function useOrgMembers(status: OrgMember["status"] | "all") {
  return useQuery<{ members: OrgMember[] }, ApiError>({
    queryKey: ["org", "members", status],
    queryFn: () =>
      get<{ members: OrgMember[] }>("org.members", `/api/org/members?status=${status}`, { status }),
    retry: false,
  });
}

export function useOrgRoles() {
  return useQuery<{ roles: RoleSummary[]; capabilities: Capability[] }, ApiError>({
    queryKey: ["org", "roles"],
    queryFn: () =>
      get<{ roles: RoleSummary[]; capabilities: Capability[] }>("org.roles", "/api/org/roles"),
    retry: false,
  });
}

export function usePrivilegeRadar() {
  return useQuery<{ findings: PrivilegeFinding[] }, ApiError>({
    queryKey: ["org", "privilege-radar"],
    queryFn: () =>
      get<{ findings: PrivilegeFinding[] }>("org.privilegeRadar", "/api/org/privilege-radar"),
    retry: false,
  });
}

export function useDepartments() {
  return useQuery<{ departments: Department[] }, ApiError>({
    queryKey: ["org", "departments"],
    queryFn: () => get<{ departments: Department[] }>("org.departments", "/api/org/departments"),
    retry: false,
  });
}

export function usePolicies() {
  return useQuery<{ policies: Policy[] }, ApiError>({
    queryKey: ["org", "policies"],
    queryFn: () => get<{ policies: Policy[] }>("org.policies", "/api/org/policies"),
    retry: false,
  });
}

export function useOrgSessions() {
  return useQuery<{ sessions: SessionDevice[] }, ApiError>({
    queryKey: ["org", "sessions"],
    queryFn: () => get<{ sessions: SessionDevice[] }>("org.sessions", "/api/org/sessions"),
    retry: false,
  });
}

export function useAnomalies() {
  return useQuery<{ alerts: AnomalyAlert[] }, ApiError>({
    queryKey: ["org", "anomalies"],
    queryFn: () => get<{ alerts: AnomalyAlert[] }>("org.anomalies", "/api/org/anomalies"),
    retry: false,
  });
}

export function useOwnershipProof() {
  return useQuery<{ tiles: ProofTile[]; domain: string | null; pdf_url: string | null }, ApiError>({
    queryKey: ["org", "proof"],
    queryFn: () =>
      get<{ tiles: ProofTile[]; domain: string | null; pdf_url: string | null }>(
        "org.proof",
        "/api/org/proof",
      ),
    retry: false,
  });
}

export function useOrgLedger() {
  return useQuery<{ entries: LedgerEntry[] }, ApiError>({
    queryKey: ["org", "audit"],
    queryFn: () => get<{ entries: LedgerEntry[] }>("org.audit", "/api/org/audit"),
    retry: false,
  });
}

export function useOrgGraph(days: number) {
  return useQuery<OrgGraph, ApiError>({
    queryKey: ["org", "graph", days],
    queryFn: () => get<OrgGraph>("org.graph", `/api/org/graph?days=${days}`, { days }),
    retry: false,
  });
}

export function useCompliance() {
  return useQuery<ComplianceSnapshot, ApiError>({
    queryKey: ["org", "compliance"],
    queryFn: () => get<ComplianceSnapshot>("org.compliance", "/api/org/compliance"),
    retry: false,
  });
}

export function useBreakGlass() {
  return useQuery<{ grants: BreakGlassGrant[] }, ApiError>({
    queryKey: ["org", "break-glass"],
    queryFn: () => get<{ grants: BreakGlassGrant[] }>("org.breakGlass", "/api/org/break-glass"),
    retry: false,
  });
}

export function useFounderOrgState() {
  return useQuery<FounderOrgState, ApiError>({
    queryKey: ["founder", "org", "state"],
    queryFn: () => get<FounderOrgState>("founder.org.state", "/api/founder/org/state"),
    retry: false,
  });
}

export function useFounderOrgList() {
  return useQuery<{ organisations: FounderOrgRow[] }, ApiError>({
    queryKey: ["founder", "org", "list"],
    queryFn: () =>
      get<{ organisations: FounderOrgRow[] }>("founder.org.list", "/api/founder/org/list"),
    retry: false,
  });
}

/* -------------------------------------------------------------- mutations */

function useOrgMutation<TInput, TOutput>(
  procedure: string,
  path: string,
  invalidate: string[][],
) {
  const qc = useQueryClient();
  return useMutation<TOutput, ApiError, TInput>({
    mutationFn: (input) => rpcOrRest<TOutput>(procedure, { path, method: "POST", body: input }, input),
    onSuccess: () => {
      for (const key of invalidate) void qc.invalidateQueries({ queryKey: key });
    },
  });
}

/** Instant revoke — one call, server does sessions + devices + aliases + handover. */
export function useRevokeMember() {
  return useOrgMutation<{ user_id: string; transfer_to?: string }, { ok: true; ms: number }>(
    "org.members.revoke",
    "/api/org/members/revoke",
    [["org", "members"], ["org", "overview"], ["org", "audit"], ["org", "sessions"]],
  );
}

/** Blast radius preview — never destructive, read-only POST. */
export function useBlastRadius() {
  return useOrgMutation<{ user_id: string }, BlastRadius>(
    "org.members.blastRadius",
    "/api/org/members/blast-radius",
    [],
  );
}

export function useKillSession() {
  return useOrgMutation<{ session_id: string }, { ok: true }>(
    "org.sessions.kill",
    "/api/org/sessions/kill",
    [["org", "sessions"], ["org", "audit"]],
  );
}

export function useSimulatePolicy() {
  return useOrgMutation<{ policy_id: string }, PolicySimulation>(
    "org.policies.simulate",
    "/api/org/policies/simulate",
    [],
  );
}

export function useTogglePolicy() {
  return useOrgMutation<{ policy_id: string; enabled: boolean }, { ok: true }>(
    "org.policies.toggle",
    "/api/org/policies/toggle",
    [["org", "policies"], ["org", "overview"], ["org", "audit"]],
  );
}

export function useVerifyLedger() {
  return useOrgMutation<Record<string, never>, LedgerVerdict>(
    "org.audit.verify",
    "/api/org/audit/verify",
    [],
  );
}

export function useGrantBreakGlass() {
  return useOrgMutation<{ reason: string; minutes: number }, BreakGlassGrant>(
    "org.breakGlass.grant",
    "/api/org/break-glass",
    [["org", "break-glass"], ["org", "audit"]],
  );
}

export function useFounderOrgKillSwitch() {
  return useOrgMutation<
    { org_writes_enabled?: boolean; organisation_id?: string; writes_enabled?: boolean },
    { ok: true }
  >("founder.org.killSwitch", "/api/founder/org/kill-switch", [
    ["founder", "org", "state"],
    ["founder", "org", "list"],
  ]);
}

/** Impersonate-with-audit — the audit row is written before the session is minted. */
export function useImpersonate() {
  return useOrgMutation<{ user_id: string; reason: string }, { ok: true; audit_id: string }>(
    "founder.org.impersonate",
    "/api/founder/org/impersonate",
    [["org", "audit"]],
  );
}