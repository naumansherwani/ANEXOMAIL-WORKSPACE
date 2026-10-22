/**
 * History search (calendar #10 / E64) — client side of the Rust `calendar.history` proc.
 * ENGINE (Rust + SQL E64): who may search (active member of this workspace), what matches, in which order, how many.
 * BROWSER: asks, draws, and links to the meeting. It never filters, ranks or counts on its own.
 * Honest by design: only what is in ANEXOMAIL is searched; there is no relevance percentage, only WHERE a word was found.
 */
import { keepPreviousData, useInfiniteQuery } from "@tanstack/react-query";

import type { ApiError } from "@/lib/api";
import type { GoalState } from "@/lib/goal";
import { rpc } from "@/lib/rpc";

export type HistoryMatch = "title" | "agenda" | "location" | "aim" | "notes" | "guest";
export type HistoryOrder = "recent" | "oldest" | "relevance";

export type HistoryEvent = {
  id: string;
  title: string;
  starts_at: string;
  ends_at: string;
  status: "confirmed" | "cancelled";
  organiser: string | null;
  location: string | null;
  goal: string | null;
  goal_state: GoalState | null;
  recurring: boolean;
  matched: HistoryMatch[];
  snippet: string | null;
  guest_count: number;
  guests: { address: string; name: string | null }[];
};

export type HistoryPage = { events: HistoryEvent[]; has_more: boolean; q: string | null; person: string | null; order: HistoryOrder; limit: number; offset: number };

export type HistoryParams = { q: string; person: string; from: string; to: string; order: HistoryOrder };

export const PAGE = 20;

/** The engine needs text (2+ letters), a person, or a date — otherwise it refuses (and we do not ask). */
export function historyReady(p: HistoryParams): boolean {
  return p.q.trim().length >= 2 || p.person.trim().length >= 2 || Boolean(p.from) || Boolean(p.to);
}

/** `YYYY-MM-DD` (a date input) -> start of that LOCAL day as an ISO instant; `end` = start of the next day (inclusive picker). */
export function dayStartIso(day: string, plusDays = 0): string {
  const [y, m, d] = day.split("-").map(Number);
  return new Date(y!, m! - 1, d! + plusDays, 0, 0, 0).toISOString();
}

export function useHistory(p: HistoryParams, enabled = true) {
  return useInfiniteQuery<HistoryPage, ApiError>({
    queryKey: ["calendar", "history", p.q.trim(), p.person.trim(), p.from, p.to, p.order],
    initialPageParam: 0,
    queryFn: ({ pageParam }) =>
      rpc<HistoryPage>("calendar.history", {
        ...(p.q.trim().length >= 2 ? { q: p.q.trim() } : {}),
        ...(p.person.trim().length >= 2 ? { person: p.person.trim() } : {}),
        ...(p.from ? { from: dayStartIso(p.from) } : {}),
        ...(p.to ? { to: dayStartIso(p.to, 1) } : {}),
        order: p.order,
        limit: PAGE,
        offset: pageParam as number,
      }),
    getNextPageParam: (last) => (last.has_more ? last.offset + last.limit : undefined),
    enabled: enabled && historyReady(p),
    retry: false,
    staleTime: 15_000,
    placeholderData: keepPreviousData,
  });
}

/* ------------------------------------------------------------------ words */

export const MATCH_WORD: Record<HistoryMatch, string> = {
  title: "Title",
  agenda: "Agenda",
  location: "Location",
  aim: "Aim",
  notes: "Notes",
  guest: "Guest",
};

/**
 * The engine marks matches in the snippet with control characters \u0001 … \u0002 (never HTML), so the page renders text only.
 * Returns alternating parts: { text, hit }.
 */
export function snippetParts(snippet: string | null): { text: string; hit: boolean }[] {
  if (!snippet) return [];
  const out: { text: string; hit: boolean }[] = [];
  let hit = false;
  for (const piece of snippet.split(/[\u0001\u0002]/)) {
    // split drops the markers; track by scanning original order
    out.push({ text: piece, hit });
    hit = !hit;
  }
  return out.filter((p) => p.text.length > 0);
}

/** "3 weeks ago" / "2 years ago" / "in 4 days" — plain arithmetic on the real dates, no rounding tricks. */
export function agoLabel(iso: string, now: number = Date.now()): string {
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return "";
  const diff = t - now;
  const abs = Math.abs(diff);
  const day = 86_400_000;
  const unit = (n: number, w: string) => `${n} ${w}${n === 1 ? "" : "s"}`;
  let text: string;
  if (abs < day) text = "today";
  else if (abs < 14 * day) text = unit(Math.floor(abs / day), "day");
  else if (abs < 60 * day) text = unit(Math.floor(abs / (7 * day)), "week");
  else if (abs < 730 * day) text = unit(Math.floor(abs / (30.4375 * day)), "month");
  else text = unit(Math.floor(abs / (365.25 * day)), "year");
  if (text === "today") return "today";
  return diff < 0 ? `${text} ago` : `in ${text}`;
}

/** The calendar deep link (`/app/calendar?date=…&event=…`) of a result — date in the viewer's local zone. */
export function jumpSearch(ev: Pick<HistoryEvent, "id" | "starts_at">): { date: string; event: string } {
  const d = new Date(ev.starts_at);
  const p = (n: number) => String(n).padStart(2, "0");
  return { date: `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`, event: ev.id };
}
