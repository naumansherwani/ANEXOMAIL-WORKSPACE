/**
 * Calendar & Work — Phase 11.
 *
 * Speed rule (locked): every read goes to the Rust engine first
 * (`/rpc/calendar.*`, `/rpc/work.*`). If that procedure is not on Rust yet,
 * `rpcOrRest` falls back to the legacy Express brain (`/api/calendar/*`,
 * `/api/work/*`) — zero downtime, zero rewrite.
 *
 * NO DUPLICATE rule: free/busy maths, travel buffers, meeting cost, agenda
 * gate enforcement, promise detection, follow-through scoring and outcome
 * extraction ALL live on the server. This file speaks transport only.
 * NO MOCK rule: a missing endpoint surfaces as an honest "not wired" state.
 */

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import { rpcOrRest } from "@/lib/rpc";

/* ------------------------------------------------------------------ types */

export type AttendeeLocalTime = {
  address: string;
  display_name: string | null;
  timezone: string | null;
  local_start: string | null;
  /** Server decides what "unsociable" means for that person's working hours. */
  unsociable: boolean;
};

export type MeetingCost = {
  currency: string;
  /** Total money burn for the meeting, decided by the server. */
  total: number;
  attendees: number;
  minutes: number;
  /** null when no hourly rates are configured yet. */
  hourly_total: number | null;
};

export type CalendarEvent = {
  id: string;
  title: string;
  starts_at: string;
  ends_at: string;
  all_day: boolean;
  location: string | null;
  agenda: string | null;
  organiser: string | null;
  attendees: AttendeeLocalTime[];
  /** Thread this meeting was born from — context never breaks. */
  thread_id: string | null;
  thread_subject: string | null;
  kind: "meeting" | "focus" | "hold" | "personal";
  status: "confirmed" | "tentative" | "cancelled";
  cost: MeetingCost | null;
  conflict: boolean;
  /** Set when the event collides with a protected deep-work window. */
  shield_conflict: boolean;
};

export type AvailabilitySlot = {
  starts_at: string;
  ends_at: string;
  /** Server-side truth: busy, buffered by travel, or protected focus time. */
  state: "free" | "busy" | "travel_buffer" | "focus";
  label: string | null;
};

export type FocusWindow = {
  id: string;
  label: string;
  weekday: number;
  start_minute: number;
  end_minute: number;
  protected: boolean;
};

export type TeamLoad = {
  member: string;
  display_name: string | null;
  meeting_minutes: number;
  open_tasks: number;
  /** Server flags overload — the red state is not guessed in the browser. */
  overloaded: boolean;
};

export type MeetingOutcome = {
  id: string;
  event_id: string;
  decisions: string[];
  action_items: { id: string; title: string; owner: string | null; due_at: string | null }[];
  posted_to_thread: boolean;
  created_at: string;
};

export type WorkTask = {
  id: string;
  title: string;
  status: "todo" | "doing" | "waiting" | "done";
  owner: string | null;
  due_at: string | null;
  /** A task is always a child of a thread or a meeting — never an island. */
  thread_id: string | null;
  thread_subject: string | null;
  event_id: string | null;
  source: "manual" | "promise" | "meeting_outcome";
  created_at: string;
  completed_at: string | null;
  /** Server truth: closed after the promised date. */
  late: boolean;
};

export const TASK_COLUMNS: { id: WorkTask["status"]; label: string }[] = [
  { id: "todo", label: "To do" },
  { id: "doing", label: "Doing" },
  { id: "waiting", label: "Waiting" },
  { id: "done", label: "Done" },
];

export type PromiseSuggestion = {
  id: string;
  /** The exact sentence LEO found — nothing invented. */
  quote: string;
  suggested_title: string;
  suggested_due_at: string | null;
  thread_id: string;
  thread_subject: string | null;
  detected_at: string;
  confidence: number;
};

export type FollowThrough = {
  scope: "person" | "team";
  subject: string;
  display_name: string | null;
  promises_made: number;
  kept_on_time: number;
  kept_late: number;
  broken: number;
  /** 0–100, server calculated. */
  score: number | null;
};

export type WorkNote = {
  id: string;
  body: string;
  thread_id: string | null;
  event_id: string | null;
  updated_at: string;
  updated_by: string | null;
};

/* ------------------------------------------------------------------ reads */

export function useCalendarEvents(range: { from: string; to: string }) {
  return useQuery<{ events: CalendarEvent[] }, ApiError>({
    queryKey: ["calendar", "events", range],
    queryFn: () =>
      rpcOrRest<{ events: CalendarEvent[] }>(
        "calendar.events",
        { path: `/api/calendar/events?from=${range.from}&to=${range.to}` },
        range,
      ),
    retry: false,
    staleTime: 15_000,
  });
}

export function useCalendarEvent(id: string | undefined) {
  return useQuery<{ event: CalendarEvent; outcome: MeetingOutcome | null; tasks: WorkTask[] }, ApiError>({
    queryKey: ["calendar", "event", id],
    queryFn: () =>
      rpcOrRest("calendar.event", { path: `/api/calendar/events/${id}` }, { id }),
    enabled: Boolean(id),
    retry: false,
  });
}

export function useAvailability(date: string) {
  return useQuery<{ slots: AvailabilitySlot[]; share_url: string | null }, ApiError>({
    queryKey: ["calendar", "availability", date],
    queryFn: () =>
      rpcOrRest(
        "calendar.availability",
        { path: `/api/calendar/availability?date=${date}` },
        { date },
      ),
    retry: false,
    staleTime: 10_000,
  });
}

export function useFocusWindows() {
  return useQuery<{ windows: FocusWindow[] }, ApiError>({
    queryKey: ["calendar", "focus"],
    queryFn: () => rpcOrRest("calendar.focus", { path: "/api/calendar/focus" }),
    retry: false,
    staleTime: 60_000,
  });
}

export function useTeamLoad(range: { from: string; to: string }) {
  return useQuery<{ load: TeamLoad[] }, ApiError>({
    queryKey: ["calendar", "load", range],
    queryFn: () =>
      rpcOrRest<{ load: TeamLoad[] }>(
        "calendar.load",
        { path: `/api/calendar/load?from=${range.from}&to=${range.to}` },
        range,
      ),
    retry: false,
    staleTime: 30_000,
  });
}

export function useTasks(query: { view?: string; thread_id?: string; event_id?: string } = {}) {
  const search = new URLSearchParams(
    Object.entries(query).filter(([, v]) => Boolean(v)) as [string, string][],
  ).toString();
  return useQuery<{ tasks: WorkTask[] }, ApiError>({
    queryKey: ["work", "tasks", query],
    queryFn: () =>
      rpcOrRest<{ tasks: WorkTask[] }>(
        "work.tasks",
        { path: `/api/work/tasks${search ? `?${search}` : ""}` },
        query,
      ),
    retry: false,
    staleTime: 10_000,
  });
}

export function usePromises() {
  return useQuery<{ promises: PromiseSuggestion[] }, ApiError>({
    queryKey: ["work", "promises"],
    queryFn: () => rpcOrRest("work.promises", { path: "/api/work/promises" }),
    retry: false,
    staleTime: 20_000,
  });
}

export function useFollowThrough(scope: "person" | "team") {
  return useQuery<{ rows: FollowThrough[] }, ApiError>({
    queryKey: ["work", "follow-through", scope],
    queryFn: () =>
      rpcOrRest<{ rows: FollowThrough[] }>(
        "work.followThrough",
        { path: `/api/work/follow-through?scope=${scope}` },
        { scope },
      ),
    retry: false,
    staleTime: 60_000,
  });
}

export function useNote(target: { thread_id?: string; event_id?: string }) {
  const key = target.thread_id ?? target.event_id;
  const search = new URLSearchParams(
    Object.entries(target).filter(([, v]) => Boolean(v)) as [string, string][],
  ).toString();
  return useQuery<{ note: WorkNote | null }, ApiError>({
    queryKey: ["work", "note", target],
    queryFn: () =>
      rpcOrRest<{ note: WorkNote | null }>(
        "work.note",
        { path: `/api/work/notes?${search}` },
        target,
      ),
    enabled: Boolean(key),
    retry: false,
  });
}

/* -------------------------------------------------------------- mutations */

export type NewMeeting = {
  title: string;
  starts_at: string;
  duration_minutes: number;
  attendees: string[];
  agenda: string;
  location?: string;
  thread_id?: string;
  timezone?: string;
};

export function useCreateMeeting() {
  const qc = useQueryClient();
  return useMutation<{ event: CalendarEvent }, ApiError, NewMeeting>({
    mutationFn: (payload) =>
      rpcOrRest<{ event: CalendarEvent }>(
        "calendar.create",
        { path: "/api/calendar/events", method: "POST", body: payload },
        payload,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["calendar"] });
      void qc.invalidateQueries({ queryKey: ["dashboard"] });
    },
  });
}

export function useTaskAction() {
  const qc = useQueryClient();
  return useMutation<
    unknown,
    ApiError,
    { id: string; status?: WorkTask["status"]; owner?: string | null; due_at?: string | null }
  >({
    mutationFn: ({ id, ...patch }) =>
      rpcOrRest(
        "work.task.update",
        { path: `/api/work/tasks/${id}`, method: "PATCH", body: patch },
        { id, ...patch },
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["work"] });
    },
  });
}

export function useCreateTask() {
  const qc = useQueryClient();
  return useMutation<
    unknown,
    ApiError,
    { title: string; thread_id?: string; event_id?: string; due_at?: string | null; owner?: string | null }
  >({
    mutationFn: (payload) =>
      rpcOrRest(
        "work.task.create",
        { path: "/api/work/tasks", method: "POST", body: payload },
        payload,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["work"] });
    },
  });
}

/** Promise detection stays a suggestion until the human commits it. */
export function usePromiseDecision() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { id: string; decision: "commit" | "dismiss" }>({
    mutationFn: ({ id, decision }) =>
      rpcOrRest(
        `work.promise.${decision}`,
        { path: `/api/work/promises/${id}/${decision}`, method: "POST", body: {} },
        { id },
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["work"] });
    },
  });
}

export function useSaveNote() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { body: string; thread_id?: string; event_id?: string }>({
    mutationFn: (payload) =>
      rpcOrRest(
        "work.note.save",
        { path: "/api/work/notes", method: "POST", body: payload },
        payload,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["work", "note"] });
    },
  });
}

/** Meeting -> outcome loop. LEO drafts; the human posts it to the thread. */
export function usePostOutcome() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { event_id: string }>({
    mutationFn: ({ event_id }) =>
      rpcOrRest(
        "calendar.outcome.post",
        { path: `/api/calendar/events/${event_id}/outcome`, method: "POST", body: {} },
        { event_id },
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["calendar"] });
      void qc.invalidateQueries({ queryKey: ["work"] });
    },
  });
}

/* ------------------------------------------------------------------ format */

export function money(cost: MeetingCost) {
  const symbol = cost.currency === "GBP" ? "£" : cost.currency === "USD" ? "$" : "";
  const value = cost.total >= 1000 ? Math.round(cost.total).toLocaleString() : cost.total.toFixed(2);
  return `${symbol}${value}${symbol ? "" : ` ${cost.currency}`}`;
}

export function clockRange(startIso: string, endIso: string) {
  const fmt = (iso: string) =>
    new Date(iso).toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
  return `${fmt(startIso)} – ${fmt(endIso)}`;
}

export function minutesLabel(minutes: number) {
  if (minutes < 60) return `${Math.round(minutes)}m`;
  const hours = minutes / 60;
  return `${hours % 1 === 0 ? hours : hours.toFixed(1)}h`;
}

export function isoDate(date: Date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(
    date.getDate(),
  ).padStart(2, "0")}`;
}

/** Monday-first week that contains `date`. */
export function weekRange(date: Date) {
  const start = new Date(date);
  const shift = (start.getDay() + 6) % 7;
  start.setDate(start.getDate() - shift);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(start.getDate() + 7);
  return { start, end, from: start.toISOString(), to: end.toISOString() };
}

export function dayRange(date: Date) {
  const start = new Date(date);
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(start.getDate() + 1);
  return { start, end, from: start.toISOString(), to: end.toISOString() };
}

/** ICS + JSON export are plain GETs on the API — ownership pillar, no lock-in. */
export function exportPath(format: "ics" | "json") {
  return `/api/calendar/export?format=${format}`;
}