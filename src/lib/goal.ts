/**
 * Outcome colours (calendar #9 / E63). The organiser writes ONE line — what the meeting is for ("contract signed") — and taps
 * Achieved or Missed afterwards. The colour is the clock plus that tap, nothing else: no score, no percentage, no guess.
 *
 *   upcoming  not started yet                      -> hollow ring (neutral)
 *   due       started / ended < 24 h ago, untapped -> yellow
 *   late      ended >= 24 h ago, untapped          -> red
 *   achieved  the organiser tapped Achieved        -> green
 *   missed    the organiser tapped Missed          -> grey (a fact, not a failure colour)
 *
 * Mirror of Rust `cal_core::goal_tone` (the engine is the source of truth for the rule; this only paints it).
 * A meeting with no goal line and no tap is not drawn at all. Repeating series are never marked (one row = many days).
 * The red NOW line of the day grid is a different thing and stays red.
 */
import { useMutation, useQueryClient } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import type { CalendarEvent } from "@/lib/calendar";
import { rpc } from "@/lib/rpc";

export type GoalState = "open" | "achieved" | "missed";
export type GoalTone = "upcoming" | "due" | "late" | "achieved" | "missed";

export const GOAL_MAX = 200;
const DAY_MS = 86_400_000;

type GoalFields = Pick<CalendarEvent, "starts_at" | "ends_at" | "recurring" | "status"> & {
  goal?: string | null;
  goal_state?: GoalState | null;
};

/** The tone to paint, or null when this meeting is not tracked. */
export function goalTone(ev: GoalFields, now: number = Date.now()): GoalTone | null {
  if (ev.recurring || ev.status === "cancelled") return null;
  const state: GoalState = ev.goal_state === "achieved" || ev.goal_state === "missed" ? ev.goal_state : "open";
  if (state !== "open") return state;
  if (!ev.goal) return null;
  const start = new Date(ev.starts_at).getTime();
  const end = new Date(ev.ends_at).getTime();
  if (now < start) return "upcoming";
  return now < end + DAY_MS ? "due" : "late";
}

/** Dot classes (tokens only, both themes). */
export const GOAL_DOT: Record<GoalTone, string> = {
  upcoming: "border border-muted-foreground/70 bg-transparent",
  due: "bg-warning",
  late: "bg-danger",
  achieved: "bg-success",
  missed: "bg-muted-foreground",
};

/** Said in words as well as colour (never colour alone). */
export const GOAL_WORD: Record<GoalTone, string> = {
  upcoming: "Not started",
  due: "Waiting for your outcome",
  late: "No outcome after a day",
  achieved: "Achieved",
  missed: "Missed",
};

export function goalLabel(ev: GoalFields, now?: number): string {
  const t = goalTone(ev, now);
  if (!t) return "";
  return `${GOAL_WORD[t]}${ev.goal ? ` — ${ev.goal}` : ""}`;
}

export function useSetGoal() {
  const qc = useQueryClient();
  return useMutation<unknown, ApiError, { id: string; goal?: string | null; goal_state?: GoalState }>({
    mutationFn: (p) => rpc("calendar.meta.set", p),
    onSuccess: () => void qc.invalidateQueries({ queryKey: ["calendar"] }),
  });
}
