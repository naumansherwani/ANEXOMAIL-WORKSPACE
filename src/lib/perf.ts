/**
 * Phase 27 — Performance Platform (transport only).
 *
 * 6 locked advance features (Google/Zoho ke pass nahi):
 *   1. Speed receipts     — har action ka p50/p95/p99 asli samples se, budget ke saath
 *   2. Prefetch brain     — predictive open, hit-rate aur bachaye gaye milliseconds
 *   3. Cold-start killer  — first paint / warm map, kaun surface thanda hai
 *   4. Query lab          — search ka stage-by-stage waterfall, slowest stage named
 *   5. Device twin        — per-device network class + kaunsi surface us par slow hai
 *   6. Regression sentinel— release-over-release latency diff + rollback advice
 *
 * NO MOCK: endpoint missing = honest "not wired" state, fake number kabhi nahi.
 */

import { useMutation, useQuery } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type PerfBudget = {
  action: string;
  label: string;
  budget_ms: number;
  p50_ms: number | null;
  p95_ms: number | null;
  p99_ms: number | null;
  samples: number;
  state: "pass" | "warn" | "fail" | "no_data";
  worst_surface: string | null;
};

export type PerfDashboard = {
  score: number;
  p95_ms: number | null;
  budgets_passing: number;
  budgets_total: number;
  prefetch_hit_rate: number | null;
  ms_saved_24h: number | null;
  cold_starts_24h: number | null;
  open_regressions: number;
  advice: { title: string; detail: string; severity: "low" | "medium" | "high" }[];
  slowest: { action: string; p95_ms: number; budget_ms: number }[];
};

export type PrefetchState = {
  hit_rate: number | null;
  hits: number;
  misses: number;
  ms_saved: number;
  predictions: { surface: string; predicted: number; opened: number; accuracy: number; avg_saved_ms: number }[];
  cold_surfaces: { surface: string; first_paint_ms: number | null; warm_ms: number | null; cold_starts: number }[];
};

export type SearchTrace = {
  id: string;
  query: string;
  at: string;
  total_ms: number;
  rows: number;
  cached: boolean;
  stages: { stage: string; ms: number }[];
  slowest_stage: string | null;
};

export type DeviceTwin = {
  id: string;
  label: string;
  platform: string | null;
  browser: string | null;
  network: "wifi" | "4g" | "3g" | "ethernet" | "unknown";
  downlink_mbps: number | null;
  rtt_ms: number | null;
  p95_ms: number | null;
  samples: number;
  slow_surfaces: { surface: string; p95_ms: number }[];
  last_seen_at: string;
};

export type Regression = {
  id: string;
  action: string;
  release: string;
  previous_release: string | null;
  before_p95_ms: number | null;
  after_p95_ms: number | null;
  delta_pct: number | null;
  state: "open" | "acknowledged" | "resolved";
  detected_at: string;
  advice: string | null;
};

export type FounderPerf = {
  tenants: number;
  p95_ms: number | null;
  budgets_failing: number;
  open_regressions: number;
  cold_starts_24h: number | null;
  ms_saved_24h: number | null;
  worst_tenants: { tenant: string; p95_ms: number; failing: number }[];
};

const get = <T,>(procedure: string, path: string) => rpcOrRest<T>(procedure, { path });

export const usePerfDashboard = () =>
  useQuery<PerfDashboard, ApiError>({
    queryKey: ["perf", "dashboard"],
    queryFn: () => get<PerfDashboard>("perf.dashboard", "/api/perf/dashboard"),
    retry: false,
  });

export const usePerfBudgets = () =>
  useQuery<{ budgets: PerfBudget[] }, ApiError>({
    queryKey: ["perf", "budgets"],
    queryFn: () => get<{ budgets: PerfBudget[] }>("perf.budgets", "/api/perf/budgets"),
    retry: false,
  });

export const usePrefetch = () =>
  useQuery<PrefetchState, ApiError>({
    queryKey: ["perf", "prefetch"],
    queryFn: () => get<PrefetchState>("perf.prefetch", "/api/perf/prefetch"),
    retry: false,
  });

export const useSearchTraces = () =>
  useQuery<{ traces: SearchTrace[] }, ApiError>({
    queryKey: ["perf", "search"],
    queryFn: () => get<{ traces: SearchTrace[] }>("perf.search", "/api/perf/search"),
    retry: false,
  });

export const useDeviceTwins = () =>
  useQuery<{ devices: DeviceTwin[] }, ApiError>({
    queryKey: ["perf", "devices"],
    queryFn: () => get<{ devices: DeviceTwin[] }>("perf.devices", "/api/perf/devices"),
    retry: false,
  });

export const useRegressions = () =>
  useQuery<{ regressions: Regression[] }, ApiError>({
    queryKey: ["perf", "regressions"],
    queryFn: () => get<{ regressions: Regression[] }>("perf.regressions", "/api/perf/regressions"),
    retry: false,
  });

/** Query lab: asli query chalti hai server par, stage timings wapas aati hain. */
export const useRunQueryLab = () =>
  useMutation<{ trace: SearchTrace }, ApiError, { query: string }>({
    mutationFn: (body) => rpcOrRest("perf.runQuery", { path: "/api/perf/search/run", method: "POST", body }),
  });

export const useFounderPerf = () =>
  useQuery<FounderPerf, ApiError>({
    queryKey: ["founder", "perf"],
    queryFn: () => get<FounderPerf>("founder.perf", "/api/founder/perf/overview"),
    retry: false,
  });

export const BUDGET_TONE: Record<PerfBudget["state"], string> = {
  pass: "text-emerald-400",
  warn: "text-amber-400",
  fail: "text-red-400",
  no_data: "text-steel",
};

export const ms = (v: number | null | undefined) => (v == null ? "—" : `${Math.round(v)}ms`);