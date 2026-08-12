/**
 * Phase 37 — Move-In Operations & Revenue Cockpit (frontend data layer only).
 *
 * Sara faisla Supabase RPC karti hai: state machine, payment gates, capacity,
 * DNS proof, health score. Yahan koi business rule duplicate NAHI hai.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import { api, type ApiError } from "@/lib/api";

export type MoveInResult =
  | "PENDING" | "IN_PROGRESS" | "VERIFIED" | "WARNING" | "BLOCKED" | "FAILED"
  | "RETRY_REQUIRED" | "CUSTOMER_ACTION_REQUIRED" | "ROLLBACK_REQUIRED" | "SKIPPED";

export type CapacityMonth = {
  month: string;
  slots_total: number;
  slots_booked: number;
  slots_free: number;
  waitlisted: number;
};

export type CockpitDeal = {
  id: string;
  reference: string;
  company: string;
  state: string;
  band: string | null;
  price_gbp: number;
  health: number;
  waitlisted: boolean;
  mailboxes: number;
  deposit_paid: boolean;
  final_paid: boolean;
  cutover_window_start: string | null;
  updated_at: string;
};

export type Cockpit = {
  active_moves: number;
  capacity: Partial<CapacityMonth>;
  waitlisted: number;
  cash: {
    booked_gbp: number;
    deposits_expected_gbp: number;
    deposits_paid_gbp: number;
    final_expected_gbp: number;
    final_paid_gbp: number;
    outstanding_gbp: number;
    overdue_gbp: number;
  };
  cutovers_tonight: number;
  blocked: number;
  exceptions_open: number;
  dns_proof_pct: number;
  mailbox_verification_pct: number;
  attention: { deal_id: string; reference: string; kind: string; message: string; state: string }[];
  board: CockpitDeal[];
  generated_at: string;
};

export type EvidenceBundle = {
  reference: string;
  company: string;
  domain: string | null;
  band: string | null;
  price_gbp: number;
  state: string;
  scope: { mailboxes: number; source_provider: string | null; cutover_window_start: string | null; cutover_window_end: string | null };
  payments: { leg: string; amount_gbp: number; state: string; paid_at: string | null }[];
  mailbox_ledger: Record<string, unknown>[];
  dns_proof: { phase: string; record: string; result: MoveInResult; observed: string | null; resolver: string | null; verification_id: string; checked_at: string }[];
  runbook: { label: string; result: MoveInResult; evidence: string | null; completed_at: string | null }[];
  exceptions: { scope: string; ref: string | null; severity: MoveInResult; reason: string; required_action: string | null; resolved_at: string | null }[];
  rollback: { label: string; available: boolean; created_at: string }[];
  audit: { actor: string; action: string; from_state: string | null; to_state: string | null; reason: string | null; evidence: string | null; at: string }[];
  health: Record<string, number>;
  cutover_note: string;
  generated_at: string;
};

export type CustomerDeal = {
  reference: string;
  company: string;
  state: string;
  progress: number;
  cutover_window: { start: string | null; end: string | null };
  cutover_note: string;
  payments: { leg: string; amount_gbp: number; state: string }[];
  dns_proof: { phase: string; record: string; result: MoveInResult; checked_at: string }[];
  mailboxes_verified: number;
  mailboxes_total: number;
  customer_action: { reason: string; required_action: string | null }[];
  health: Record<string, number>;
};

/* ------------------------------- public -------------------------------- */

export function useMoveInCapacity() {
  return useQuery<{ months: CapacityMonth[] }, ApiError>({
    queryKey: ["movein", "capacity"],
    queryFn: () => api("/api/public/movein/capacity", { auth: false }),
    retry: false,
  });
}

export type MoveInRequest = {
  company: string;
  email: string;
  mailboxes: number;
  domain?: string;
  provider?: string;
  contact_name?: string;
  month?: string;
};

export function useRequestMoveIn() {
  return useMutation<
    { deal_id: string; reference: string; band: string; price_gbp: number; deposit_gbp: number; capacity: unknown },
    ApiError,
    MoveInRequest
  >({
    mutationFn: (body) =>
      api("/api/public/movein/request", { method: "POST", body: JSON.stringify(body), auth: false }),
  });
}

/* ------------------------------ customer ------------------------------- */

export function useMyMoveIn() {
  return useQuery<{ deal: CustomerDeal | null }, ApiError>({
    queryKey: ["movein", "mine"],
    queryFn: () => api("/api/movein/deal"),
    retry: false,
  });
}

/* ------------------------------- founder ------------------------------- */

export function useMoveInCockpit() {
  return useQuery<Cockpit, ApiError>({
    queryKey: ["founder", "movein", "cockpit"],
    queryFn: () => api("/api/founder/movein/cockpit"),
    retry: false,
  });
}

export function useMoveInDeal(id: string | null) {
  return useQuery<{ deal: EvidenceBundle }, ApiError>({
    queryKey: ["founder", "movein", "deal", id],
    queryFn: () => api(`/api/founder/movein/deal/${id}`),
    enabled: !!id,
    retry: false,
  });
}

function useCockpitMutation<TBody>(path: string) {
  const qc = useQueryClient();
  return useMutation<Record<string, unknown>, ApiError, TBody>({
    mutationFn: (body) => api(path, { method: "POST", body: JSON.stringify(body) }),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["founder", "movein"] });
    },
  });
}

export const useMoveInTransition = () =>
  useCockpitMutation<{ deal_id: string; to: string; reason?: string; evidence?: string }>(
    "/api/founder/movein/transition",
  );

export const useMoveInSchedule = () =>
  useCockpitMutation<{ deal_id: string; month: string; window_start?: string; window_end?: string }>(
    "/api/founder/movein/schedule",
  );

export const useMoveInArm = () =>
  useCockpitMutation<{ deal_id: string }>("/api/founder/movein/arm");

export const useMoveInRunbookStep = () =>
  useCockpitMutation<{ deal_id: string; step_key: string; result: MoveInResult; evidence?: string }>(
    "/api/founder/movein/runbook",
  );

export const useMoveInMailbox = () =>
  useCockpitMutation<Record<string, unknown>>("/api/founder/movein/mailbox");

export const useMoveInDnsCheck = () =>
  useCockpitMutation<{
    deal_id: string; domain: string; record: string; phase?: "PRE" | "POST";
    result?: MoveInResult; observed?: string; resolver?: string; expected?: string; reason?: string;
  }>("/api/founder/movein/dns");

export const useMoveInException = () =>
  useCockpitMutation<
    | { deal_id: string; reason: string; scope?: string; ref?: string; severity?: MoveInResult; required_action?: string; blocks_cutover?: boolean }
    | { deal_id: string; resolve_id: string }
  >("/api/founder/movein/exception");

export const useMoveInRollback = () =>
  useCockpitMutation<{ deal_id: string; label?: string; use_id?: string; reason?: string }>(
    "/api/founder/movein/rollback",
  );

export const useMoveInInvoice = () =>
  useCockpitMutation<{ deal_id: string; leg: "deposit" | "final"; intent_id?: string; due_at?: string }>(
    "/api/founder/movein/invoice",
  );

export const gbp = (n: number | null | undefined) =>
  n == null ? "—" : `£${Math.round(Number(n)).toLocaleString("en-GB")}`;

export const RESULT_TONE: Record<string, string> = {
  VERIFIED: "text-emerald-500",
  IN_PROGRESS: "text-sky-500",
  PENDING: "text-muted-foreground",
  SKIPPED: "text-muted-foreground",
  WARNING: "text-amber-500",
  RETRY_REQUIRED: "text-amber-500",
  CUSTOMER_ACTION_REQUIRED: "text-amber-500",
  BLOCKED: "text-destructive",
  FAILED: "text-destructive",
  ROLLBACK_REQUIRED: "text-destructive",
};

/** Founder ke liye readable stage label (DB state hi truth hai). */
export const stateLabel = (s: string) =>
  s.replace(/_/g, " ").toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());
