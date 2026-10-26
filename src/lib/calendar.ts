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

import { withoutRooms } from "@/lib/rooms";

import type { ApiError } from "@/lib/api";
import { rpc, rpcOrRest } from "@/lib/rpc";
import { cityOf, fmtTime, fmtTimeIn } from "@/lib/timeFormat";

/* ------------------------------------------------------------------ types */

export type AttendeeLocalTime = {
  address: string;
  display_name: string | null;
  timezone: string | null;
  local_start: string | null;
  /** Server decides what "unsociable" means for that person's working hours. */
  unsociable: boolean;
  /** Calendar v2 (engine): the guest's answer and what happened to their invitation. */
  response?: RsvpResponse;
  invite_status?: InviteStatus;
  invite_error?: string | null;
  rsvp_at?: string | null;
};

export type RsvpResponse = "needs_action" | "accepted" | "tentative" | "declined";
export type InviteStatus = "not_sent" | "sent" | "failed";

/** What the engine reports after it tried to e-mail the invitations — never guessed in the browser. */
export type InviteResult = {
  address: string;
  status: "sent" | "failed" | "skipped";
  error?: string;
};
export type InviteSummary = {
  engine?: string;
  sent: number;
  failed: number;
  skipped: number;
  results: InviteResult[];
  note?: string;
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
  /** iTIP SEQUENCE — goes up every time the organiser changes or cancels. */
  sequence?: number;
  /** Repeating meetings (B7b). `id` of an occurrence is "<series>~<start epoch>"; the engine understands it. */
  rrule?: string | null;
  recurring?: boolean;
  series_id?: string | null;
  recurrence_id?: string | null;
  /** True for one occurrence that was changed on its own. */
  is_exception?: boolean;
  timezone?: string | null;
  /** Which of the viewer's calendars (name + colour) the meeting sits in — E58. */
  calendar_key?: string | null;
  /** Only for events from an outside calendar you follow (#4c): its own colour. Read-only rows. */
  color?: string | null;
  /** Reminders: minutes before the start — E58. */
  remind_min?: number[] | null;
  /** Outcome colours (E63): the organiser's one-line aim, and the tap that closed it. See `lib/goal.ts`. */
  goal?: string | null;
  goal_state?: "open" | "achieved" | "missed" | null;
  goal_state_at?: string | null;
};

export type GuestRow = {
  address: string;
  role: string;
  response: RsvpResponse;
  rsvp_at: string | null;
  rsvp_comment: string | null;
  /** How the answer arrived: the link in the mail, or the guest's own calendar app (iMIP). Null on older servers. */
  rsvp_via?: "link" | "calendar_app" | null;
  invite_status: InviteStatus;
  invite_sent_at: string | null;
  invite_error: string | null;
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
    select: (d) => ({
      ...d,
      events: d.events.map((e) => ({ ...e, attendees: withoutRooms(e.attendees ?? []) })),
    }),
    retry: false,
    staleTime: 15_000,
  });
}

export function useCalendarEvent(id: string | undefined) {
  return useQuery<
    { event: CalendarEvent; outcome: MeetingOutcome | null; tasks: WorkTask[] },
    ApiError
  >({
    queryKey: ["calendar", "event", id],
    queryFn: () => rpcOrRest("calendar.event", { path: `/api/calendar/events/${id}` }, { id }),
    select: (d) => ({
      ...d,
      event: { ...d.event, attendees: withoutRooms(d.event.attendees ?? []) },
    }),
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
        { date, tz_offset: -new Date().getTimezoneOffset() },
      ),
    retry: false,
    staleTime: 10_000,
  });
}

/** Meeting cost rates (Pro+). One typed call each, through the WASM kernel (Rule 52) — no REST twin. */
export type MeetingRates = { self: number; guest: number; currency: string };

export function useMeetingRates(enabled: boolean) {
  return useQuery<MeetingRates, ApiError>({
    queryKey: ["calendar", "rates"],
    queryFn: () => rpc<MeetingRates>("calendar.rates", {}),
    enabled,
    retry: false,
    staleTime: 60_000,
  });
}

export function useSaveMeetingRates() {
  const qc = useQueryClient();
  return useMutation<MeetingRates, ApiError, { self?: number; guest?: number }>({
    mutationFn: (input) => rpc<MeetingRates>("calendar.rates.set", input),
    onSuccess: (data) => {
      qc.setQueryData(["calendar", "rates"], data);
      void qc.invalidateQueries({ queryKey: ["calendar", "events"] });
      void qc.invalidateQueries({ queryKey: ["calendar", "event"] });
    },
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
  /** false = save only, send no e-mail. The engine default is to invite. */
  invite?: boolean;
  /** Human readable time in the organiser's zone, printed in the invitation mail. */
  when_label?: string;
  organiser_name?: string;
  /** RFC 5545 rule from buildRrule(); omitted = one meeting. */
  rrule?: string;
  /** Organiser's UTC offset in minutes (east positive) — keeps the series right if the server has no tz database. */
  tz_offset_min?: number;
  calendar_key?: string;
  remind_min?: number[];
};

export type CreatedMeeting = {
  event: CalendarEvent;
  /** Absent when the old route answered: the meeting was saved but NO invitation went out. */
  invites?: InviteSummary;
  ignored?: { invalid: string[]; duplicate: string[] };
};

export function useCreateMeeting() {
  const qc = useQueryClient();
  return useMutation<CreatedMeeting, ApiError, NewMeeting>({
    mutationFn: (payload) =>
      rpcOrRest<CreatedMeeting>(
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

export type MeetingChange = {
  id: string;
  starts_at?: string;
  duration_minutes?: number;
  title?: string;
  agenda?: string;
  location?: string;
  cancel?: boolean;
  /** Tell the guests (default on). */
  notify?: boolean;
  when_label?: string;
  organiser_name?: string;
  /** Repeating meetings: "this" = only this one, "all" = the whole series. The engine defaults to "this". */
  scope?: "this" | "all";
  /** Change the repeat rule (scope "all" only). */
  rrule?: string;
};

/** Reschedule / edit / cancel. The engine bumps SEQUENCE and mails every guest the update or the cancellation. */
export function useUpdateMeeting() {
  const qc = useQueryClient();
  return useMutation<{ event: CalendarEvent; invites?: InviteSummary }, ApiError, MeetingChange>({
    mutationFn: (payload) =>
      rpcOrRest(
        "calendar.update",
        { path: `/api/calendar/events/${payload.id}`, method: "PATCH", body: payload },
        payload,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["calendar"] });
    },
  });
}

/** Re-send only to the guests whose invitation failed or who have not answered. */
export function useResendInvites() {
  const qc = useQueryClient();
  return useMutation<
    { event: CalendarEvent; invites: InviteSummary },
    ApiError,
    { id: string; when_label?: string; organiser_name?: string }
  >({
    mutationFn: (payload) =>
      rpcOrRest(
        "calendar.invites.resend",
        { path: `/api/calendar/events/${payload.id}/invites`, method: "POST", body: payload },
        payload,
      ),
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["calendar"] });
    },
  });
}

/** RSVP + invitation ledger for one meeting (engine only — no legacy twin exists). */
export function useGuests(id: string | undefined) {
  return useQuery<
    {
      event_id: string;
      status: string;
      sequence: number;
      organiser: string | null;
      is_organiser: boolean;
      attendees: GuestRow[];
    },
    ApiError
  >({
    queryKey: ["calendar", "guests", id],
    queryFn: () => rpc("calendar.guests", { id }),
    enabled: Boolean(id),
    retry: false,
    staleTime: 5_000,
  });
}

export type TimeWindow = { start: string; end: string };
export type FindTimeResult = { slots: TimeWindow[]; checked: string[]; engine?: string };

/** Exact common-free-time maths runs in the engine (UTC intervals); the browser only supplies the hours to search. */
export function useFindTime() {
  return useMutation<
    FindTimeResult,
    ApiError,
    {
      addresses: string[];
      windows: TimeWindow[];
      duration_minutes: number;
      step_minutes?: number;
      buffer_minutes?: number;
      limit?: number;
    }
  >({
    mutationFn: (payload) => rpc<FindTimeResult>("calendar.findtime", payload),
  });
}

/* ---------------------------------------------------------- public RSVP */

export type RsvpView = {
  found: boolean;
  title: string;
  agenda: string | null;
  location: string | null;
  starts_at: string;
  ends_at: string;
  organiser: string | null;
  cancelled: boolean;
  address: string;
  response: RsvpResponse;
  rsvp_at: string | null;
  error?: string;
  /** E77: the same address's other meetings at this time — count + up to 3 time ranges, never titles. */
  conflicts?: { count: number; overlaps: { starts_at: string; ends_at: string }[] };
};

export function rsvpLookup(token: string) {
  return rpc<RsvpView>("calendar.rsvp.lookup", { token });
}

export function rsvpRespond(token: string, response: "yes" | "maybe" | "no", comment?: string) {
  return rpc<RsvpView>("calendar.rsvp.respond", { token, response, comment: comment ?? "" });
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
    {
      title: string;
      thread_id?: string;
      event_id?: string;
      due_at?: string | null;
      owner?: string | null;
    }
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
  const value =
    cost.total >= 1000 ? Math.round(cost.total).toLocaleString() : cost.total.toFixed(2);
  return `${symbol}${value}${symbol ? "" : ` ${cost.currency}`}`;
}

export function clockRange(startIso: string, endIso: string) {
  return `${fmtTime(startIso)} – ${fmtTime(endIso)}`;
}

export function minutesLabel(minutes: number) {
  if (minutes < 60) return `${Math.round(minutes)}m`;
  const hours = minutes / 60;
  return `${hours % 1 === 0 ? hours : hours.toFixed(1)}h`;
}

/** "Monday 19 October 2026, 3:00 PM–3:30 PM Karachi" — printed in the invitation mail, in the organiser's own zone. */
export function whenLabel(startIso: string, minutes: number, timeZone?: string) {
  const start = new Date(startIso);
  const end = new Date(start.getTime() + minutes * 60_000);
  const opts = timeZone ? { timeZone } : {};
  const day = start.toLocaleDateString("en-GB", {
    weekday: "long",
    day: "numeric",
    month: "long",
    year: "numeric",
    ...opts,
  });
  const clock = (d: Date) => fmtTimeIn(d, timeZone);
  const zone = cityOf(timeZone);
  return `${day}, ${clock(start)}–${clock(end)}${zone ? ` ${zone}` : ""}`;
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
