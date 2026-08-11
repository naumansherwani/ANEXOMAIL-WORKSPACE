/**
 * Phase 26 — Security Platform (transport only).
 *
 * 6 locked advance features (Google/Zoho ke pass nahi):
 *   1. Device Trust        — fingerprint + live trust score + one-click kill (API keys ki jagah)
 *   2. Impossible travel   — geo/velocity anomaly, server pehle freeze karta hai
 *   3. Ownership proof     — DKIM/SPF/DMARC/TLS ka hashed, exportable proof
 *   4. Encryption ledger   — at-rest + in-transit per-surface, koi "trust us" nahi
 *   5. Login replay        — har login ka risk story + "yeh main nahi tha" revoke
 *   6. Blast-radius kill   — sab sessions + devices ek click, hash-chained ledger
 *
 * NO MOCK: endpoint missing = honest "not wired" state, fake number kabhi nahi.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type TrustDevice = {
  id: string;
  label: string;
  fingerprint: string;
  platform: string | null;
  browser: string | null;
  state: "trusted" | "pending" | "blocked";
  trust_score: number;
  reasons: string[];
  first_seen_at: string;
  last_seen_at: string;
  city: string | null;
  country: string | null;
  ip: string | null;
  current: boolean;
};

export type SecuritySession = {
  id: string;
  device_label: string | null;
  ip: string | null;
  city: string | null;
  country: string | null;
  started_at: string;
  last_seen_at: string;
  expires_at: string | null;
  current: boolean;
  risk: "low" | "medium" | "high";
};

export type LoginEvent = {
  id: string;
  at: string;
  email: string;
  method: "password" | "google" | "apple" | "passkey" | "recovery";
  outcome: "success" | "failed" | "blocked" | "challenged";
  ip: string | null;
  city: string | null;
  country: string | null;
  device_label: string | null;
  risk_score: number;
  story: string | null;
  disowned: boolean;
};

export type Anomaly = {
  id: string;
  kind: "impossible_travel" | "new_country" | "token_reuse" | "mass_export" | "brute_force";
  severity: "low" | "medium" | "high";
  state: "open" | "frozen" | "cleared";
  detail: string;
  km: number | null;
  minutes: number | null;
  created_at: string;
};

export type EncryptionState = {
  at_rest: { surface: string; algorithm: string; state: "on" | "off" | "partial"; detail: string | null }[];
  in_transit: { hop: string; protocol: string; cipher: string | null; state: "on" | "off" | "partial" }[];
  key_rotated_at: string | null;
  next_rotation_at: string | null;
  ledger: { at: string; action: string; surface: string; hash: string }[];
};

export type OwnershipProof = {
  id: string;
  domain: string;
  ran_at: string;
  passed: number;
  failed: number;
  proof_hash: string | null;
  checks: { check: string; result: "pass" | "fail" | "skip"; observed: string | null; fix: string | null }[];
};

export type SecurityDashboard = {
  score: number;
  devices_trusted: number;
  devices_pending: number;
  sessions_live: number;
  failed_logins_24h: number;
  open_anomalies: number;
  encryption_ok: boolean;
  ownership_ok: boolean;
  ledger: { at: string; action: string; actor: string; hash: string; prev_hash: string | null }[];
  advice: { title: string; detail: string; severity: "low" | "medium" | "high" }[];
};

export type FounderSecurity = {
  tenants: number;
  devices_blocked: number;
  open_anomalies: number;
  frozen_accounts: number;
  failed_logins_24h: number;
  kill_switches_30d: number;
  worst_tenants: { tenant: string; anomalies: number; failed_logins: number }[];
};

const get = <T,>(procedure: string, path: string) => rpcOrRest<T>(procedure, { path });

export const useSecurityDashboard = () =>
  useQuery<SecurityDashboard, ApiError>({
    queryKey: ["security", "dashboard"],
    queryFn: () => get<SecurityDashboard>("security.dashboard", "/api/security/dashboard"),
    retry: false,
  });

export const useTrustDevices = () =>
  useQuery<{ devices: TrustDevice[] }, ApiError>({
    queryKey: ["security", "devices"],
    queryFn: () => get<{ devices: TrustDevice[] }>("security.devices", "/api/security/devices"),
    retry: false,
  });

const invalidate = (keys: string[][]) => (qc: ReturnType<typeof useQueryClient>) =>
  keys.forEach((k) => void qc.invalidateQueries({ queryKey: k }));

export const useSetDeviceState = () => {
  const qc = useQueryClient();
  return useMutation<{ device: TrustDevice }, ApiError, { device_id: string; state: TrustDevice["state"] }>({
    mutationFn: (body) =>
      rpcOrRest("security.deviceState", { path: "/api/security/devices/state", method: "POST", body }),
    onSuccess: () => invalidate([["security", "devices"], ["security", "dashboard"]])(qc),
  });
};

export const useSecuritySessions = () =>
  useQuery<{ sessions: SecuritySession[] }, ApiError>({
    queryKey: ["security", "sessions"],
    queryFn: () => get<{ sessions: SecuritySession[] }>("security.sessions", "/api/security/sessions"),
    retry: false,
  });

export const useKillSecuritySession = () => {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean }, ApiError, { session_id: string }>({
    mutationFn: (body) =>
      rpcOrRest("security.killSession", { path: "/api/security/sessions/kill", method: "POST", body }),
    onSuccess: () => invalidate([["security", "sessions"], ["security", "dashboard"]])(qc),
  });
};

/** Blast-radius: sab sessions + non-current devices, ek click, ledger entry ke saath. */
export const useKillSwitch = () => {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean; sessions_killed: number; devices_blocked: number; hash: string }, ApiError, { reason?: string }>({
    mutationFn: (body) =>
      rpcOrRest("security.killSwitch", { path: "/api/security/kill-switch", method: "POST", body }),
    onSuccess: () =>
      invalidate([
        ["security", "sessions"],
        ["security", "devices"],
        ["security", "dashboard"],
      ])(qc),
  });
};

export const useLoginHistory = (outcome: string) =>
  useQuery<{ events: LoginEvent[]; anomalies: Anomaly[] }, ApiError>({
    queryKey: ["security", "history", outcome],
    queryFn: () =>
      get<{ events: LoginEvent[]; anomalies: Anomaly[] }>(
        "security.history",
        `/api/security/history?outcome=${encodeURIComponent(outcome)}`,
      ),
    retry: false,
  });

export const useDisownLogin = () => {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean; sessions_killed: number }, ApiError, { event_id: string }>({
    mutationFn: (body) =>
      rpcOrRest("security.disown", { path: "/api/security/history/disown", method: "POST", body }),
    onSuccess: () => invalidate([["security", "history"], ["security", "sessions"]])(qc),
  });
};

export const useEncryption = () =>
  useQuery<EncryptionState, ApiError>({
    queryKey: ["security", "encryption"],
    queryFn: () => get<EncryptionState>("security.encryption", "/api/security/encryption"),
    retry: false,
  });

export const useRotateKeys = () => {
  const qc = useQueryClient();
  return useMutation<{ ok: boolean; rotated_at: string }, ApiError, { surface?: string }>({
    mutationFn: (body) =>
      rpcOrRest("security.rotate", { path: "/api/security/encryption/rotate", method: "POST", body }),
    onSuccess: () => invalidate([["security", "encryption"]])(qc),
  });
};

export const useOwnershipProofs = () =>
  useQuery<{ proofs: OwnershipProof[] }, ApiError>({
    queryKey: ["security", "proof"],
    queryFn: () => get<{ proofs: OwnershipProof[] }>("security.proof", "/api/security/proof"),
    retry: false,
  });

export const useRunOwnershipProof = () => {
  const qc = useQueryClient();
  return useMutation<{ proof: OwnershipProof }, ApiError, { domain?: string }>({
    mutationFn: (body) =>
      rpcOrRest("security.runProof", { path: "/api/security/proof/run", method: "POST", body }),
    onSuccess: () => invalidate([["security", "proof"], ["security", "dashboard"]])(qc),
  });
};

export const useFounderSecurity = () =>
  useQuery<FounderSecurity, ApiError>({
    queryKey: ["founder", "security"],
    queryFn: () => get<FounderSecurity>("founderSecurity.overview", "/api/founder/security/overview"),
    retry: false,
  });

export const TRUST_TONE: Record<TrustDevice["state"], string> = {
  trusted: "text-emerald-400",
  pending: "text-amber-400",
  blocked: "text-red-400",
};

export const RISK_TONE: Record<SecuritySession["risk"], string> = {
  low: "text-emerald-400",
  medium: "text-amber-400",
  high: "text-red-400",
};