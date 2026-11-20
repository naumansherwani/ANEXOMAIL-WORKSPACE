// QC7a: pure helpers for the "Remind me if no reply" chip (no DOM, no network; tested in followup_pure.test.ts).
export type Followup = { id: string; message_id: string; thread_id: string; due_ms: number; state: "waiting" | "due"; rearms: number };
export const MIN_AHEAD_MS = 60_000;
export const MAX_AHEAD_MS = 90 * 86_400_000;
export const PRESETS = [{ days: 1, label: "Tomorrow" }, { days: 3, label: "In 3 days" }, { days: 7, label: "In a week" }] as const;
/** The due time for a preset: now + N days. Always inside the door's window. */
export function presetDue(now: number, days: number): number { return now + Math.min(Math.max(days, 1), 90) * 86_400_000 - 1000; }
/** Same window the Rust door and the database enforce (1 minute .. 90 days). */
export function dueOk(due: number, now: number): boolean { return Number.isFinite(due) && due >= now + MIN_AHEAD_MS && due <= now + MAX_AHEAD_MS; }
/** The reminder that belongs to one message, if any. */
export function forMessage(list: Followup[], messageId: string): Followup | undefined { return list.find((f) => f.message_id === messageId); }
/** Chip words: "Remind me if no reply", "Reminder in 3 days", "No reply yet: due". */
export function chipText(f: Followup | undefined, now: number): { text: string; tone: "idle" | "wait" | "due" } {
  if (!f) return { text: "Remind me if no reply", tone: "idle" };
  if (f.state === "due" || f.due_ms <= now) return { text: "No reply yet", tone: "due" };
  const m = Math.round((f.due_ms - now) / 60_000);
  if (m < 60) return { text: `Reminder in ${Math.max(m, 1)} min`, tone: "wait" };
  const h = Math.round(m / 60); if (h < 48) return { text: `Reminder in ${h} h`, tone: "wait" };
  return { text: `Reminder in ${Math.round(h / 24)} days`, tone: "wait" };
}
/** How many are due: the badge number. */
export function dueCount(list: Followup[], now: number): number { return list.filter((f) => f.state === "due" || f.due_ms <= now).length; }
