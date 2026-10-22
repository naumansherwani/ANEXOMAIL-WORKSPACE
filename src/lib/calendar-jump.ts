/**
 * Deep link into the calendar: `/app/calendar?date=2006-03-14&event=<id>` opens that month with that meeting's detail.
 * Used by history search. Both calendar layouts read it once, on mount, as their starting state — nothing else changes.
 */
import { useSearch } from "@tanstack/react-router";

export type CalendarJump = { date?: string; event?: string };

const DATE = /^\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\d|3[01])$/;
const ID = /^[A-Za-z0-9~:_.-]{6,80}$/;

/** Router validateSearch: keeps only well-formed values (anything else is dropped, never trusted). */
export function validateJump(search: Record<string, unknown>): CalendarJump {
  const date = typeof search["date"] === "string" && DATE.test(search["date"]) ? search["date"] : undefined;
  const event = typeof search["event"] === "string" && ID.test(search["event"]) ? search["event"] : undefined;
  return { ...(date ? { date } : {}), ...(event ? { event } : {}) };
}

/** Local noon of the given day (no time-zone surprises near midnight). */
export function jumpAnchor(j: CalendarJump): Date {
  if (j.date) {
    const [y, m, d] = j.date.split("-").map(Number);
    const at = new Date(y!, m! - 1, d!, 12, 0, 0);
    if (!Number.isNaN(at.getTime())) return at;
  }
  return new Date();
}

export function useCalendarJump(): CalendarJump {
  const s = useSearch({ strict: false }) as Record<string, unknown>;
  return validateJump(s);
}
