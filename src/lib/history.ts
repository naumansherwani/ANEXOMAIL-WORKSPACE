/**
 * History search (calendar #10 / E64) — client side of the Rust `calendar.history` proc.
 * ENGINE (Rust + SQL E64): who may search (active member of this workspace), what matches, in which order, how many.
 * BROWSER: asks, draws, and links to the meeting. It never filters, ranks or counts on its own.
 * Built for a lifetime of meetings (100 years): newest/oldest pages follow a cursor, so page 500 is as fast as page 1; the year strip shows every year that has a match.
 * There is no relevance percentage, only WHERE a word was found.
 */
import { keepPreviousData, useInfiniteQuery, type InfiniteData } from "@tanstack/react-query";

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

export type HistoryCursor = { ts: string; id: string };
export type HistoryPage = {
  events: HistoryEvent[];
  has_more: boolean;
  /** Where the next page starts (newest/oldest order); null for relevance, which pages by offset. */
  next: HistoryCursor | null;
  /** { "2006": 3, ... } — matches per year (text + person, dates ignored). Only on the first page. */
  by_year: Record<string, number> | null;
  q: string | null;
  person: string | null;
  order: HistoryOrder;
  limit: number;
  offset: number;
};

/** What a page asks for: the very first page, a cursor (newest/oldest), or an offset (relevance). */
export type HistoryPageParam = { cursor?: HistoryCursor; offset?: number };

/** `by_year` -> newest-first list for the year strip. */
export function yearList(by: Record<string, number> | null | undefined): { year: number; count: number }[] {
  if (!by) return [];
  return Object.entries(by)
    .map(([y, c]) => ({ year: Number(y), count: Number(c) }))
    .filter((r) => Number.isFinite(r.year) && r.count > 0)
    .sort((a, b) => b.year - a.year);
}

/** A whole calendar year as the From/To date-input values. */
export function yearRange(year: number): { from: string; to: string } {
  const y = String(year).padStart(4, "0");
  return { from: `${y}-01-01`, to: `${y}-12-31` };
}

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
  return useInfiniteQuery<HistoryPage, ApiError, InfiniteData<HistoryPage, HistoryPageParam>, readonly unknown[], HistoryPageParam>({
    queryKey: ["calendar", "history", p.q.trim(), p.person.trim(), p.from, p.to, p.order],
    initialPageParam: {} as HistoryPageParam,
    queryFn: ({ pageParam }) =>
      rpc<HistoryPage>("calendar.history", {
        ...(p.q.trim().length >= 2 ? { q: p.q.trim() } : {}),
        ...(p.person.trim().length >= 2 ? { person: p.person.trim() } : {}),
        ...(p.from ? { from: dayStartIso(p.from) } : {}),
        ...(p.to ? { to: dayStartIso(p.to, 1) } : {}),
        order: p.order,
        limit: PAGE,
        ...(pageParam.cursor ? { after_ts: pageParam.cursor.ts, after_id: pageParam.cursor.id } : {}),
        ...(pageParam.offset ? { offset: pageParam.offset } : {}),
        // the year strip is asked for once, with the first page
        ...(!pageParam.cursor && !pageParam.offset ? { facets: true } : {}),
      }),
    getNextPageParam: (last): HistoryPageParam | undefined =>
      !last.has_more ? undefined : last.next ? { cursor: last.next } : { offset: last.offset + last.limit },
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
