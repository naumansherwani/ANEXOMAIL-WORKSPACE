/**
 * Phase 24 — Analytics Center (transport only).
 *
 * NO VANITY: koi open-rate / click-rate nahi. Sirf woh numbers jo kaam badalte hain —
 * response debt (£ cost of delay), thread economics, deep work, attention leaks,
 * promise SLA, aur next-week forecast.
 * NO DUPLICATE: saara hisaab server par (Server 2 -> Supabase 4 mail_threads/messages).
 * NO MOCK: endpoint missing = honest "not wired".
 */

import { useQuery } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

export type ResponseDebt = {
  waiting_people: number;
  waiting_threads: number;
  oldest_hours: number;
  median_hours: number;
  /** £ — server-side: waiting hours x blended hourly rate of the people waiting. */
  cost_of_delay: number;
  currency: string;
  worst: { thread_id: string; subject: string; person: string; hours: number; cost: number }[];
  trend_7d: { day: string; debt: number }[];
};

export type ThreadEconomics = {
  threads_30d: number;
  minutes_total: number;
  people_hours: number;
  cost_total: number;
  currency: string;
  avg_minutes: number;
  worst: {
    thread_id: string;
    subject: string;
    messages: number;
    participants: number;
    minutes: number;
    cost: number;
    resolved: boolean;
  }[];
};

export type DeepWork = {
  deep_hours: number;
  inbox_hours: number;
  meeting_hours: number;
  longest_focus_minutes: number;
  fragmentation: number;
  best_window: string | null;
  days: { day: string; deep: number; inbox: number; meeting: number }[];
};

export type AttentionLeak = {
  source: string;
  kind: "person" | "list" | "automation" | "notification";
  interruptions_7d: number;
  minutes_7d: number;
  fix: string | null;
};

export type PromiseSla = {
  made_30d: number;
  kept: number;
  late: number;
  broken: number;
  keep_rate: number;
  avg_late_hours: number;
  at_risk: { thread_id: string; subject: string; due_at: string; person: string }[];
};

export type Forecast = {
  next_week_threads: number;
  next_week_hours: number;
  confidence: number;
  drivers: { label: string; delta: number }[];
  advice: string | null;
};

export type TeamAnalytics = {
  members: {
    email: string;
    display_name: string | null;
    response_debt: number;
    keep_rate: number;
    deep_hours: number;
    load: "light" | "healthy" | "heavy" | "drowning";
  }[];
  unbalanced: boolean;
};

export type FounderAnalytics = {
  tenants: number;
  total_debt_cost: number;
  currency: string;
  worst_tenants: { tenant: string; debt: number; waiting: number }[];
  platform_keep_rate: number;
  threads_30d: number;
};

const get = <T,>(procedure: string, path: string) => rpcOrRest<T>(procedure, { path });

export const useResponseDebt = () =>
  useQuery<ResponseDebt, ApiError>({
    queryKey: ["analytics", "debt"],
    queryFn: () => get<ResponseDebt>("analytics.responseDebt", "/api/analytics/response-debt"),
    retry: false,
  });

export const useThreadEconomics = () =>
  useQuery<ThreadEconomics, ApiError>({
    queryKey: ["analytics", "threads"],
    queryFn: () => get<ThreadEconomics>("analytics.threadEconomics", "/api/analytics/thread-economics"),
    retry: false,
  });

export const useDeepWork = () =>
  useQuery<DeepWork, ApiError>({
    queryKey: ["analytics", "deep-work"],
    queryFn: () => get<DeepWork>("analytics.deepWork", "/api/analytics/deep-work"),
    retry: false,
  });

export const useAttentionLeaks = () =>
  useQuery<{ leaks: AttentionLeak[] }, ApiError>({
    queryKey: ["analytics", "leaks"],
    queryFn: () => get<{ leaks: AttentionLeak[] }>("analytics.attentionLeaks", "/api/analytics/attention-leaks"),
    retry: false,
  });

export const usePromiseSla = () =>
  useQuery<PromiseSla, ApiError>({
    queryKey: ["analytics", "promises"],
    queryFn: () => get<PromiseSla>("analytics.promiseSla", "/api/analytics/promise-sla"),
    retry: false,
  });

export const useForecast = () =>
  useQuery<Forecast, ApiError>({
    queryKey: ["analytics", "forecast"],
    queryFn: () => get<Forecast>("analytics.forecast", "/api/analytics/forecast"),
    retry: false,
  });

export const useTeamAnalytics = () =>
  useQuery<TeamAnalytics, ApiError>({
    queryKey: ["analytics", "team"],
    queryFn: () => get<TeamAnalytics>("analytics.team", "/api/analytics/team"),
    retry: false,
  });

export const useFounderAnalytics = () =>
  useQuery<FounderAnalytics, ApiError>({
    queryKey: ["founder", "analytics"],
    queryFn: () => get<FounderAnalytics>("founderAnalytics.overview", "/api/founder/analytics/overview"),
    retry: false,
  });

export const money = (n: number, currency = "GBP") =>
  new Intl.NumberFormat("en-GB", { style: "currency", currency, maximumFractionDigits: 0 }).format(n);

export const hours = (n: number) => (n < 1 ? `${Math.round(n * 60)}m` : `${n.toFixed(1)}h`);
