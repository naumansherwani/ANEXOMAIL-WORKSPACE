/**
 * Founder Command Center — data layer.
 *
 * One Rust call (`founder.brain.command`) returns the whole picture: system pulse, money, move-in, release gate
 * and a ranked "needs you" list. Every rule that decides what lands on that list lives in Rust
 * (server/rust/b5_core.rs `attention`), unit-tested — the screen only draws what the server concluded.
 * There is deliberately NO Bun twin: this is new capability, so when Rust is down the screen says so plainly.
 */

import { useQuery } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpc } from "@/lib/rpc";

export type BrainLevel = "critical" | "high" | "normal" | "info";
export type BrainLight = "red" | "amber" | "green";

export type BrainItem = {
  id: string;
  severity: 0 | 1 | 2 | 3;
  level: BrainLevel;
  title: string;
  detail: string;
  /** Always an in-app founder route (the server guarantees the `/app/founder` prefix). */
  href: string;
};

export type FounderCommand = {
  generated_at: string;
  light: BrainLight;
  attention: BrainItem[];
  /** Signals the server could not read — shown as "not measured", never as calm. */
  blind_spots: string[];
  pulse: {
    brain: { status: "pass" | "warn" | "fail"; ms: number | null };
    rust: { status: "pass" };
    outbox_held: number | null;
  };
  release: {
    gate: "locked" | "ready" | "blocked" | "unknown" | null;
    version: string | null;
    locked_at: string | null;
    last_run_verdict: string | null;
    last_run_age_hours: number | null;
    blockers: number | null;
    checklist_open: number | null;
  };
  movein: {
    active_moves: number;
    blocked: number;
    waitlisted: number;
    cutovers_tonight: number;
    exceptions_open: number;
    outstanding_gbp: number;
    overdue_gbp: number;
  } | null;
  money: {
    committed_mrr_gbp: number;
    target_gbp: number;
    gap_gbp: number;
    subscriptions_mrr_gbp: number;
    priority_support_mrr_gbp: number;
    priority_support_accounts: number;
    partner_mrr_gbp: number;
    live_accounts: number;
    new_leads: number | null;
    oldest_new_lead_hours: number | null;
  } | null;
};

export function useFounderCommand() {
  return useQuery<FounderCommand, ApiError>({
    queryKey: ["founder", "command"],
    queryFn: () => rpc<FounderCommand>("founder.brain.command", {}),
    staleTime: 30_000,
    refetchInterval: 60_000,
    refetchOnWindowFocus: true,
    retry: false,
  });
}
